import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../conflict.dart';
import '../context.dart';
import '../contract/cancel.dart';
import '../contract/change.dart';
import '../contract/delivery.dart';
import '../contract/failures.dart';
import '../contract/pull.dart';
import '../contract/session.dart';
import '../contract/transport.dart';
import '../entity/sync_entity.dart';
import '../events.dart';
import '../journal/sync_journal.dart';
import '../options.dart';
import '../report.dart';
import '../schema/schema.dart';
import '../sync_table.dart';

/// The offline-first sync engine.
///
/// Construction is asynchronous because the package-owned schema is installed
/// and validated against the caller's database.
final class UniversalSync<DB extends GeneratedDatabase> {
  UniversalSync._({
    required this.db,
    required this.entities,
    required this.transport,
    required this.session,
    required this.options,
    required this.schema,
    required this.journal,
    required this.bootstrapPolicy,
    required this.instanceId,
    required this.installId,
  }) : _byName = {for (final entity in entities) entity.ref.table: entity},
       _lastUser = session.userId {
    _context = SyncContext(
      db: db,
      schema: schema,
      journal: journal,
      options: options,
      session: session,
      emit: _emit,
      onWrite: _scheduleAutoDrain,
    );
    _sessionSub = session.userIdChanges.listen(_onUserChanged);
  }

  /// Installs the sync schema, validates entities and capabilities, and
  /// recovers leases left behind by a previous process.
  static Future<UniversalSync<DB>> open<DB extends GeneratedDatabase>({
    required DB database,
    required List<SyncEntityBase> entities,
    required SyncTransport transport,
    SyncSession session = const AnonymousSession(),
    SyncOptions options = const SyncOptions(),
    SyncBootstrap bootstrap = const SkipBootstrap(),
  }) async {
    final byName = <String, SyncEntityBase>{};
    for (final entity in entities) {
      if (byName.containsKey(entity.ref.table)) {
        throw ArgumentError(
          'Entity "${entity.ref.table}" is registered twice. Each table may '
          'only be synced once.',
        );
      }
      byName[entity.ref.table] = entity;
    }

    final capabilities = transport.capabilities;
    for (final entity in entities) {
      if (entity.ref.serverManagedColumns.isNotEmpty && !capabilities.serverTimestamps) {
        throw SyncCapabilityMismatch(
          entity: entity.ref.table,
          requirement: 'server timestamps (server-managed columns are declared)',
        );
      }
      if (entity.expectedColumns.isNotEmpty) {
        await _validateEntityColumns(database, entity);
      }
    }

    final schema = await SyncSchema.install(
      database,
      validate: options.validateSchema,
    );

    final journal = SyncJournal(
      db: database,
      schema: schema,
      options: options,
      clock: options.clock,
    );
    await journal.recoverLeases();

    return UniversalSync._(
      db: database,
      entities: List.unmodifiable(entities),
      transport: transport,
      session: session,
      options: options,
      schema: schema,
      journal: journal,
      bootstrapPolicy: bootstrap,
      installId: await schema.metaValue('install_id') ?? 'install',
      instanceId:
          options.instanceId ??
          'inst-${DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36)}'
              '-${Random().nextInt(1 << 32).toRadixString(36)}',
    );
  }

  final DB db;
  final List<SyncEntityBase> entities;
  final SyncTransport transport;
  final SyncSession session;
  final SyncOptions options;
  final SyncSchema schema;
  final SyncJournal journal;
  final SyncBootstrap bootstrapPolicy;
  final String instanceId;
  final String installId;

  final Map<String, SyncEntityBase> _byName;
  late final SyncContext _context;
  StreamSubscription<String?>? _sessionSub;
  String? _lastUser;

  DateTime get _now => options.clock.now().toUtc();

  // ── Public surface ────────────────────────────────────────────────────────

  final StreamController<SyncEvent> _events = StreamController<SyncEvent>.broadcast();

  Stream<SyncEvent> get events => _events.stream;

  final StreamController<SyncStatus> _statusController = StreamController<SyncStatus>.broadcast();

  SyncStatus _status = SyncStatus.idle;

  SyncStatus get status => _status;

  Stream<SyncStatus> get statusStream => _statusController.stream;

  String? _lastError;

  /// Typed write facade for [entity].
  SyncTable<Tbl, Row, Key> table<Tbl extends Table, Row extends DataClass, Key extends Object>(
    SyncEntity<Tbl, Row, Key> entity,
  ) => SyncTable<Tbl, Row, Key>(_context, entity);

  Future<SyncReport>? _drainInFlight;
  Timer? _debounce;

  /// Pushes pending changes. Concurrent calls share one drain.
  Future<SyncReport> drain({SyncCancelToken? cancel}) {
    final inFlight = _drainInFlight;
    if (inFlight != null) return inFlight;
    final future = _drain(cancel).whenComplete(() => _drainInFlight = null);
    _drainInFlight = future;
    return future;
  }

  /// Pulls remote changes for every registered entity.
  Future<SyncReport> pull({SyncCancelToken? cancel}) async {
    final watch = Stopwatch()..start();
    _setStatus(SyncStatus.pulling);
    var pulled = 0;
    var conflicts = 0;
    try {
      for (final adapter in entities) {
        if (cancel?.isCancelled ?? false) break;
        var cursor = await journal.cursorFor(adapter.ref.table);
        var hasMore = true;
        while (hasMore) {
          if (cancel?.isCancelled ?? false) break;

          final PullPage page;
          try {
            page = await transport.pull(
              PullPageRequest(
                entity: adapter.ref,
                cursor: cursor,
                limit: options.pullPageSize,
              ),
            );
          } on AuthFailure catch (error) {
            _lastError = error.message;
            _emit(AuthRequired(at: _now, error: error));
            _setStatus(SyncStatus.authRequired);
            return SyncReport(pulled: pulled, conflicts: conflicts);
          } on SyncFailure catch (error) {
            _lastError = error.message;
            _emit(OfflineDetected(at: _now, error: error));
            _setStatus(SyncStatus.offline);
            return SyncReport(pulled: pulled, conflicts: conflicts);
          }

          if (page.hasMore && page.nextCursor == null) {
            _emit(
              TransportContractViolation(
                at: _now,
                message:
                    'hasMore is true but nextCursor is null for '
                    '${adapter.ref.table}',
              ),
            );
            break;
          }

          var pagePulled = 0;
          await db.transaction(() async {
            final rows = <Map<String, Object?>>[];
            final keys = <String>[];
            for (final row in page.rows) {
              try {
                final parts = adapter.keyPartsFromJsonRow(row);
                rows.add(row);
                keys.add(adapter.keyJsonOfParts(parts));
              } catch (error) {
                _emit(
                  SyncRowRejected(
                    at: _now,
                    entity: adapter.ref.table,
                    message: 'Could not derive a key: $error',
                  ),
                );
              }
            }

            final tombstones = await journal.tombstoneKeys(
              adapter.ref.table,
              keys,
            );
            final pending = await journal.pendingKeys(adapter.ref.table, keys);

            for (final row in rows) {
              final parts = adapter.keyPartsFromJsonRow(row);
              final keyJson = adapter.keyJsonOfParts(parts);

              if (tombstones.contains(keyJson)) continue;

              final owner = adapter.ownerFromJson(row);
              final user = session.userId;
              if (owner != null && user != null && owner != user) {
                _emit(
                  SyncRowRejected(
                    at: _now,
                    entity: adapter.ref.table,
                    message: 'Row owned by $owner was skipped for user $user',
                  ),
                );
                continue;
              }

              if (pending.contains(keyJson)) {
                final outcome = await _resolveConflict(adapter, parts, row);
                conflicts += outcome.conflicts;
                if (outcome.applied) pagePulled++;
                continue;
              }

              if (options.skipUnchangedPulls) {
                final local = await adapter.readLocalByParts(db, parts);
                if (local != null) {
                  final localTs = adapter.updatedAtFromJson(local);
                  final remoteTs = adapter.updatedAtFromJson(row);
                  if (localTs != null && remoteTs != null && !remoteTs.isAfter(localTs)) {
                    continue;
                  }
                }
              }

              try {
                await adapter.applyRemoteRow(db, row);
                pagePulled++;
              } catch (error) {
                _emit(
                  SyncRowRejected(
                    at: _now,
                    entity: adapter.ref.table,
                    message: 'Could not apply remote row: $error',
                  ),
                );
              }
            }

            for (final parts in page.deletedKeys) {
              final pendingEntries = await journal.entriesForKey(
                adapter.ref.table,
                parts,
              );

              if (pendingEntries.isNotEmpty) {
                final policy = options.conflictPolicy;
                if (policy is ClientWins) {
                  conflicts++;
                  continue;
                }
                if (policy is ManualConflicts) {
                  await journal.openConflict(
                    entity: adapter.ref.table,
                    keyParts: parts,
                    local: pendingEntries.first.row,
                    remote: const {'__deleted__': true},
                    localStatus: pendingEntries.first.state,
                  );
                  conflicts++;
                  continue;
                }
                await journal.deleteOutboxForKey(adapter.ref.table, parts);
              }

              await journal.recordRemoteTombstone(adapter.ref.table, parts);
              await adapter.deleteByParts(db, parts);
            }

            await journal.setCursor(adapter.ref.table, page.nextCursor);
          });

          pulled += pagePulled;
          _emit(
            RowsPulled(
              at: _now,
              entity: adapter.ref.table,
              rowCount: pagePulled,
              hadMore: page.hasMore,
            ),
          );

          cursor = page.nextCursor;
          hasMore = page.hasMore;
        }
      }
    } finally {
      watch.stop();
      if (_status == SyncStatus.pulling) {
        _setStatus(SyncStatus.idle);
      }
    }
    return SyncReport(
      pulled: pulled,
      conflicts: conflicts,
      elapsed: watch.elapsed,
    );
  }

  /// Push, then pull. Bootstraps once if configured.
  Future<SyncReport> syncNow({
    bool push = true,
    bool pull = false,
    SyncCancelToken? cancel,
  }) async {
    final bootstrapReport = await bootstrap();
    final pushReport = push ? await drain(cancel: cancel) : const SyncReport();
    final pullReport = pull ? await this.pull(cancel: cancel) : const SyncReport();
    return SyncReport(
      pushed: pushReport.pushed + bootstrapReport.pushed,
      failed: pushReport.failed + pullReport.failed,
      parked: pushReport.parked,
      pulled: pullReport.pulled,
      conflicts: pullReport.conflicts,
      coalesced: bootstrapReport.coalesced,
      cancelled: pushReport.cancelled,
      elapsed: pushReport.elapsed + pullReport.elapsed,
    );
  }

  /// Runs the configured first-run policy exactly once.
  Future<SyncReport> bootstrap() async {
    if (await schema.metaValue('bootstrap_done') == '1') {
      return const SyncReport();
    }

    switch (bootstrapPolicy) {
      case SkipBootstrap():
        await schema.setMetaValue('bootstrap_done', '1');
        return const SyncReport();

      case ServerWinsBootstrap():
        await journal.resetCursors();
        await schema.setMetaValue('bootstrap_done', '1');
        return const SyncReport();

      case UploadLocal():
      case MergeByUpdatedAt():
        var enqueued = 0;
        await db.transaction(() async {
          for (final adapter in entities) {
            final rows = await adapter.readAllLocal(db);
            for (final row in rows) {
              final parts = adapter.keyPartsFromJsonRow(row);
              await journal.enqueueUpsert(adapter.ref.table, parts, row);
              enqueued++;
            }
          }
        });
        await schema.setMetaValue('bootstrap_done', '1');
        return SyncReport(coalesced: enqueued);
    }
  }

  Future<SyncDiagnostics> diagnostics() async {
    final installId = await schema.metaValue('install_id') ?? 'unknown';
    final schemaVersion = int.tryParse(await schema.metaValue('schema_version') ?? '') ?? 0;
    return SyncDiagnostics(
      pending: await journal.countOutbox('pending'),
      inflight: await journal.countOutbox('inflight'),
      tombstones: await journal.countTombstones(),
      conflicts: await journal.countConflicts(),
      parked: await journal.countDeadLetters(),
      outboxBytes: await journal.outboxBytes(),
      installId: installId,
      schemaVersion: schemaVersion,
      lastError: _lastError,
    );
  }

  Future<List<ConflictRecord>> conflicts() => journal.listConflicts();

  Stream<List<ConflictRecord>> watchConflicts() async* {
    yield await conflicts();
    yield* Stream<void>.periodic(const Duration(seconds: 2)).asyncMap((_) => conflicts());
  }

  Future<void> resolveConflict(int id, ConflictResolution resolution) async {
    final record = await journal.conflictById(id);
    if (record == null) return;
    final adapter = _byName[record.entity];
    if (adapter == null) return;

    if (resolution is AcceptServer) {
      final parts = (jsonDecode(record.keyJson) as List).cast<Object?>();
      await db.transaction(() async {
        await adapter.applyRemoteRow(db, record.remote);
        await journal.deleteOutboxForKey(record.entity, parts);
        await journal.resolveConflictRow(id);
      });
    } else {
      await journal.resolveConflictRow(id);
    }
  }

  Future<int> retryParked() => journal.retryParked();

  Future<int> discardParked() => journal.discardParked();

  Future<void> purge({bool localData = false}) async {
    await journal.purgeAll();
    if (localData) {
      for (final adapter in entities) {
        await adapter.deleteAllLocal(db);
      }
    }
    await schema.setMetaValue('bootstrap_done', '0');
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _sessionSub?.cancel();
    await journal.recoverLeases();
    await transport.close();
    await _events.close();
    await _statusController.close();
  }

  // ── Drain internals ───────────────────────────────────────────────────────

  Future<SyncReport> _drain(SyncCancelToken? cancel) async {
    final watch = Stopwatch()..start();
    _setStatus(SyncStatus.draining);
    _emit(DrainStarted(at: _now));
    var pushed = 0;
    var failed = 0;
    var parked = 0;

    try {
      var iterations = 0;
      var stop = false;

      while (!stop && iterations < options.maxDrainIterations && watch.elapsed < options.drainTimeBudget) {
        if (cancel?.isCancelled ?? false) break;

        final claimed = await journal.claim(
          limit: options.pushBatchSize,
          instanceId: instanceId,
          lease: options.lease,
        );
        if (claimed.isEmpty) break;

        final groups = <String, List<OutboxEntry>>{};
        for (final entry in claimed) {
          groups.putIfAbsent(entry.entity, () => []).add(entry);
        }

        for (final group in groups.entries) {
          if (cancel?.isCancelled ?? false) break;
          final adapter = _byName[group.key];
          if (adapter == null) {
            await db.transaction(() async {
              for (final entry in group.value) {
                await journal.releaseMaybeApplied(
                  entry,
                  const PermanentFailure('entity is no longer registered'),
                  _now,
                  countFailure: true,
                );
              }
            });
            failed += group.value.length;
            continue;
          }

          for (final chunk in _chunks(group.value)) {
            final batch = PushBatch(
              entity: adapter.ref,
              changes: [
                for (final entry in chunk) entry.toChange(installId, adapter.ref),
              ],
              attempt: chunk.first.attempts,
            );

            final PushOutcome outcome;
            try {
              outcome = await transport.push(batch);
            } on SyncFailure catch (error) {
              final next = _retryAt(chunk.first, error);
              final notSent =
                  error.certainty == DeliveryCertainty.notSent && (error is TransientFailure || error is RateLimited);
              await db.transaction(() async {
                for (final entry in chunk) {
                  if (notSent) {
                    final newer = await journal.releaseNotSent(
                      entry,
                      error,
                      next,
                    );
                    if (newer != null) {
                      await _promoteEntry(adapter, newer);
                    }
                  } else {
                    await journal.releaseMaybeApplied(
                      entry,
                      error,
                      next,
                      countFailure: false,
                    );
                  }
                }
              });
              failed += chunk.length;
              if (error is AuthFailure) {
                _lastError = error.message;
                _emit(AuthRequired(at: _now, error: error));
                _setStatus(SyncStatus.authRequired);
              } else {
                _lastError = error.message;
                _emit(
                  RetryScheduled(
                    at: _now,
                    entity: adapter.ref.table,
                    keyJson: chunk.first.keyJson,
                    nextAttemptAt: next,
                    failure: error,
                  ),
                );
                _emit(OfflineDetected(at: _now, error: error));
              }
              stop = true;
              break;
            }

            final stats = await _handleOutcome(batch, chunk, adapter, outcome);
            pushed += stats.pushed;
            failed += stats.failed;
            parked += stats.parked;
            if (stats.stop) {
              stop = true;
              break;
            }
          }
          if (stop) break;
        }

        iterations++;
      }

      await _maintenance();
    } finally {
      watch.stop();
      if (_status == SyncStatus.draining) {
        _setStatus(SyncStatus.idle);
      }
      _emit(DrainCompleted(at: _now, pushed: pushed, failed: failed));
    }

    return SyncReport(
      pushed: pushed,
      failed: failed,
      parked: parked,
      elapsed: watch.elapsed,
    );
  }

  /// Splits an entity batch so a push request respects [SyncOptions.maxBatchBytes].
  List<List<OutboxEntry>> _chunks(List<OutboxEntry> entries) {
    final chunks = <List<OutboxEntry>>[];
    var current = <OutboxEntry>[];
    var bytes = 0;
    for (final entry in entries) {
      final size = utf8.encode(entry.payloadJson).length + entry.keyJson.length;
      if (current.isNotEmpty && bytes + size > options.maxBatchBytes) {
        chunks.add(current);
        current = <OutboxEntry>[];
        bytes = 0;
      }
      current.add(entry);
      bytes += size;
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  Future<_DrainStats> _handleOutcome(
    PushBatch batch,
    List<OutboxEntry> entries,
    SyncEntityBase adapter,
    PushOutcome outcome,
  ) async {
    final acks = outcome.normalizedAcks;
    final bySequence = <int, ChangeAck>{};
    var invalid = false;
    for (final ack in acks) {
      if (bySequence.containsKey(ack.sequence)) invalid = true;
      bySequence[ack.sequence] = ack;
    }
    if (invalid || entries.any((entry) => !bySequence.containsKey(entry.sequence))) {
      await db.transaction(() async {
        for (final entry in entries) {
          await journal.releaseMaybeApplied(
            entry,
            const TransientFailure('transport returned incomplete acks'),
            _now,
            countFailure: false,
          );
        }
      });
      _emit(
        TransportContractViolation(
          at: _now,
          message:
              'Transport acks do not cover every sequence for '
              '${adapter.ref.table}',
        ),
      );
      return const _DrainStats(stop: true);
    }

    var pushed = 0;
    var failed = 0;
    var parked = 0;
    var stop = false;

    await db.transaction(() async {
      for (final entry in entries) {
        final ack = bySequence[entry.sequence]!;

        switch (ack.status) {
          case ChangeStatus.applied:
          case ChangeStatus.superseded:
            if (ack.serverRow != null && entry.kind != SyncChangeKind.delete) {
              try {
                await adapter.applyRemoteRow(db, ack.serverRow!);
              } catch (error) {
                _emit(
                  SyncRowRejected(
                    at: _now,
                    entity: adapter.ref.table,
                    message: 'Invalid serverRow in ack: $error',
                  ),
                );
              }
            }
            await journal.ack(entry);
            pushed++;
            _emit(
              ChangePushed(
                at: _now,
                entity: entry.entity,
                keyJson: entry.keyJson,
                kind: entry.kind,
              ),
            );

          case ChangeStatus.rejected:
            final failure = ack.failure;
            if (failure == null) {
              await journal.releaseMaybeApplied(
                entry,
                const TransientFailure('rejected ack without a failure'),
                _now,
                countFailure: false,
              );
              failed++;
              stop = true;
              _emit(
                TransportContractViolation(
                  at: _now,
                  message: 'Rejected ack without a SyncFailure',
                ),
              );
              break;
            }

            if (failure is AuthFailure) {
              await journal.releaseMaybeApplied(
                entry,
                failure,
                _now,
                countFailure: false,
              );
              failed++;
              stop = true;
              _lastError = failure.message;
              _emit(AuthRequired(at: _now, error: failure));
              _setStatus(SyncStatus.authRequired);
            } else if (failure is RevisionConflict) {
              if (failure.serverRow != null) {
                await adapter.applyRemoteRow(db, failure.serverRow!);
              }
              await journal.ack(entry);
              pushed++;
              _emit(
                ConflictResolved(
                  at: _now,
                  entity: entry.entity,
                  keyJson: entry.keyJson,
                  serverWon: true,
                ),
              );
            } else if (failure is TransientFailure || failure is RateLimited) {
              final next = _retryAt(entry, failure);
              if (failure.certainty == DeliveryCertainty.notSent) {
                final newer = await journal.releaseNotSent(
                  entry,
                  failure,
                  next,
                );
                if (newer != null) {
                  await _promoteEntry(adapter, newer);
                }
              } else {
                await journal.releaseMaybeApplied(
                  entry,
                  failure,
                  next,
                  countFailure: false,
                );
              }
              failed++;
              _emit(
                RetryScheduled(
                  at: _now,
                  entity: entry.entity,
                  keyJson: entry.keyJson,
                  nextAttemptAt: next,
                  failure: failure,
                ),
              );
              stop = true;
            } else {
              final failures = entry.failures + 1;
              if (failures >= options.maxAttempts) {
                await journal.park(entry, failure);
                parked++;
                _emit(
                  ChangeParked(
                    at: _now,
                    entity: entry.entity,
                    keyJson: entry.keyJson,
                    failure: failure,
                  ),
                );
                await _promoteNextAfterPark(adapter, entry);
              } else {
                final next = _retryAt(entry, failure);
                await journal.releaseMaybeApplied(
                  entry,
                  failure,
                  next,
                  countFailure: true,
                );
                failed++;
                _emit(
                  RetryScheduled(
                    at: _now,
                    entity: entry.entity,
                    keyJson: entry.keyJson,
                    nextAttemptAt: next,
                    failure: failure,
                  ),
                );
              }
            }
        }
      }
    });

    return _DrainStats(
      pushed: pushed,
      failed: failed,
      parked: parked,
      stop: stop,
    );
  }

  Future<_ConflictOutcome> _resolveConflict(
    SyncEntityBase adapter,
    List<Object?> parts,
    Map<String, Object?> row,
  ) async {
    final entries = await journal.entriesForKey(adapter.ref.table, parts);
    if (entries.isEmpty) {
      await adapter.applyRemoteRow(db, row);
      return const _ConflictOutcome(applied: true, conflicts: 0);
    }

    final localEntry = entries.first;
    final policy = options.conflictPolicy;
    final keyJson = adapter.keyJsonOfParts(parts);

    _emit(
      ConflictDetected(
        at: _now,
        entity: adapter.ref.table,
        keyJson: keyJson,
        policy: policy.toString(),
      ),
    );

    var applied = false;
    var serverWon = false;

    switch (policy) {
      case ServerWins():
        await adapter.applyRemoteRow(db, row);
        await journal.deleteOutboxForKey(adapter.ref.table, parts);
        applied = true;
        serverWon = true;

      case ClientWins():
        break;

      case NewestWins():
        final localJson = localEntry.row ?? await adapter.readLocalByParts(db, parts);
        final localTs = localJson == null ? null : adapter.updatedAtFromJson(localJson);
        final remoteTs = adapter.updatedAtFromJson(row);
        serverWon = localTs == null || remoteTs == null || !localTs.isAfter(remoteTs);
        if (serverWon) {
          await adapter.applyRemoteRow(db, row);
          await journal.deleteOutboxForKey(adapter.ref.table, parts);
          applied = true;
        }

      case ManualConflicts():
        await journal.openConflict(
          entity: adapter.ref.table,
          keyParts: parts,
          local: localEntry.row ?? await adapter.readLocalByParts(db, parts),
          remote: row,
          localStatus: localEntry.state,
        );
    }

    _emit(
      ConflictResolved(
        at: _now,
        entity: adapter.ref.table,
        keyJson: keyJson,
        serverWon: serverWon,
      ),
    );

    return _ConflictOutcome(applied: applied, conflicts: 1);
  }

  Future<void> _promoteEntry(SyncEntityBase adapter, OutboxEntry entry) async {
    if (!options.promoteDependentUpdates) return;
    if (entry.kind != SyncChangeKind.update) return;

    final parts = (jsonDecode(entry.keyJson) as List).cast<Object?>();
    final row = await adapter.readLocalByParts(db, parts);
    if (row == null) {
      await journal.park(
        entry,
        const PermanentFailure('base row no longer exists'),
      );
      _emit(
        ChangeParked(
          at: _now,
          entity: entry.entity,
          keyJson: entry.keyJson,
          failure: const PermanentFailure('base row no longer exists'),
        ),
      );
      return;
    }

    await journal.promoteToUpsert(entry.sequence, row);
    _emit(
      ChangePromoted(at: _now, entity: entry.entity, keyJson: entry.keyJson),
    );
  }

  Future<void> _promoteNextAfterPark(
    SyncEntityBase adapter,
    OutboxEntry parkedEntry,
  ) async {
    final next = await journal.nextPendingForKey(
      parkedEntry.entity,
      parkedEntry.keyHash,
    );
    if (next != null) {
      await _promoteEntry(adapter, next);
    }
  }

  Future<void> _maintenance() async {
    await journal.purgeTombstones();
    final bytes = await journal.outboxBytes();
    if (bytes > options.maxOutboxBytes) {
      _emit(
        OutboxPressure(at: _now, bytes: bytes, limit: options.maxOutboxBytes),
      );
    }
  }

  DateTime _retryAt(OutboxEntry entry, SyncFailure failure) {
    final delay = failure.retryAfter ?? options.backoff.delayFor(entry.failures);
    return _now.add(delay);
  }

  // ── Lifecycle helpers ─────────────────────────────────────────────────────

  void _emit(SyncEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _setStatus(SyncStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void _onUserChanged(String? userId) {
    if (!options.purgeOnUserChange) return;
    if (userId == _lastUser) return;
    _lastUser = userId;
    unawaited(purge());
  }

  void _scheduleAutoDrain() {
    if (!options.autoDrain) return;
    _debounce?.cancel();
    _debounce = Timer(options.autoDrainDebounce, () {
      unawaited(
        drain().catchError((Object error) {
          _lastError = error.toString();
          return const SyncReport();
        }),
      );
    });
  }

  static Future<void> _validateEntityColumns(
    GeneratedDatabase db,
    SyncEntityBase entity,
  ) async {
    final rows = await db.customSelect('PRAGMA table_info(${entity.ref.table})').get();
    final actual = rows.map((row) => row.read<String>('name')).toSet();
    final missing = entity.expectedColumns.where((c) => !actual.contains(c)).toSet();
    if (missing.isNotEmpty) {
      throw SyncSchemaMismatch(
        table: entity.ref.table,
        missing: missing,
        actual: actual,
      );
    }
  }
}

final class _DrainStats {
  const _DrainStats({
    this.pushed = 0,
    this.failed = 0,
    this.parked = 0,
    this.stop = false,
  });

  final int pushed;
  final int failed;
  final int parked;
  final bool stop;
}

final class _ConflictOutcome {
  const _ConflictOutcome({required this.applied, required this.conflicts});

  final bool applied;
  final int conflicts;
}

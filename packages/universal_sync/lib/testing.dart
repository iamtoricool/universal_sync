import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:universal_sync/universal_sync.dart';

/// In-memory backend implementing the transport contract.
///
/// Use it in application tests and as the reference implementation for adapter
/// authors. It stores full rows, assigns a monotonically increasing revision,
/// keeps tombstones, and reports authoritative `updated_at` values.
final class FakeTransport extends SyncTransport {
  FakeTransport({
    SyncTransportCapabilities? capabilities,
    this.latency = Duration.zero,
  }) : capabilities =
           capabilities ??
           const SyncTransportCapabilities(
             serverTimestamps: true,
             tombstones: true,
             idempotency: true,
             deliveryCertainty: true,
           );

  @override
  final SyncTransportCapabilities capabilities;

  final Duration latency;

  final Map<String, Map<String, Map<String, Object?>>> _rows = {};
  final Map<String, Map<String, int>> _rowRevisions = {};
  final Map<String, Map<String, int>> _tombstones = {};
  int _revision = 0;

  SyncFailure? _nextPushFailure;
  final Map<int, SyncFailure> _nextRejections = {};
  final Set<int> _appliedSequences = {};

  /// Every sequence accepted by [push], in the order it was applied.
  final List<int> pushedSequences = [];

  /// When true, acks omit the last change to exercise contract validation.
  bool dropLastAck = false;

  /// When true, an already-applied idempotency key is acked as `superseded`.
  bool dedupeByIdempotency = false;

  /// Fails the next [push] call by throwing [failure].
  void failNextPush(SyncFailure failure) => _nextPushFailure = failure;

  /// Rejects the next send of [sequence] with [failure].
  void rejectNext(int sequence, SyncFailure failure) => _nextRejections[sequence] = failure;

  /// Seeds a row as if another device wrote it.
  void seed(
    String entity,
    Map<String, Object?> row, {
    List<String> primaryKey = const ['id'],
  }) {
    final keyJson = _keyJsonOf(primaryKey, {
      for (final column in primaryKey) column: row[column],
    });
    _rows.putIfAbsent(entity, () => {})[keyJson] = Map.of(row);
    _rowRevisions.putIfAbsent(entity, () => {})[keyJson] = ++_revision;
    _tombstones.putIfAbsent(entity, () => {}).remove(keyJson);
  }

  /// Rows currently held by the fake server.
  List<Map<String, Object?>> rowsFor(String entity) => [
    for (final row in (_rows[entity] ?? {}).values) Map.of(row),
  ];

  /// Tombstone key JSONs currently held by the fake server.
  Set<String> tombstonesFor(String entity) => {...?(_tombstones[entity]?.keys)};

  @override
  Future<PushOutcome> push(PushBatch batch) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    final pendingFailure = _nextPushFailure;
    if (pendingFailure != null) {
      _nextPushFailure = null;
      throw pendingFailure;
    }

    final entity = batch.entity.table;
    final rows = _rows.putIfAbsent(entity, () => {});
    final revisions = _rowRevisions.putIfAbsent(entity, () => {});
    final tombstones = _tombstones.putIfAbsent(entity, () => {});
    final acks = <ChangeAck>[];

    for (final change in batch.changes) {
      final rejection = _nextRejections.remove(change.sequence);
      if (rejection != null) {
        acks.add(ChangeAck.rejected(change.sequence, rejection));
        continue;
      }

      if (dedupeByIdempotency && _appliedSequences.contains(_sequenceOf(change.idempotencyKey))) {
        acks.add(ChangeAck.superseded(change.sequence));
        continue;
      }

      final keyJson = _keyJsonOf(batch.entity.primaryKey, change.key);
      pushedSequences.add(change.sequence);
      switch (change.kind) {
        case SyncChangeKind.upsert:
          final row = <String, Object?>{...change.row};
          for (final column in batch.entity.primaryKey) {
            row.putIfAbsent(column, () => change.key[column]);
          }
          _stamp(batch.entity, row);
          rows[keyJson] = row;
          revisions[keyJson] = ++_revision;
          tombstones.remove(keyJson);
          _appliedSequences.add(change.sequence);
          acks.add(ChangeAck.applied(change.sequence, serverRow: Map.of(row)));

        case SyncChangeKind.update:
          final current = rows[keyJson];
          if (current == null) {
            acks.add(
              ChangeAck.rejected(
                change.sequence,
                const PermanentFailure('row does not exist remotely'),
              ),
            );
            continue;
          }
          final row = <String, Object?>{...current, ...?change.delta};
          _stamp(batch.entity, row);
          rows[keyJson] = row;
          revisions[keyJson] = ++_revision;
          _appliedSequences.add(change.sequence);
          acks.add(ChangeAck.applied(change.sequence, serverRow: Map.of(row)));

        case SyncChangeKind.delete:
          rows.remove(keyJson);
          revisions.remove(keyJson);
          tombstones[keyJson] = ++_revision;
          _appliedSequences.add(change.sequence);
          acks.add(ChangeAck.applied(change.sequence));
      }
    }

    if (dropLastAck && acks.isNotEmpty) acks.removeLast();
    return PushOutcome(acks);
  }

  @override
  Future<PullPage> pull(PullPageRequest request) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    final entity = request.entity.table;
    final rows = _rows[entity] ?? const {};
    final revisions = _rowRevisions[entity] ?? const {};
    final tombstones = _tombstones[entity] ?? const {};

    final since =
        int.tryParse(
          request.cursor is OpaqueCursor ? (request.cursor! as OpaqueCursor).token : '',
        ) ??
        0;

    final events = <({int revision, String keyJson, Map<String, Object?>? row})>[
      for (final entry in rows.entries)
        if ((revisions[entry.key] ?? 0) > since)
          (
            revision: revisions[entry.key]!,
            keyJson: entry.key,
            row: entry.value,
          ),
      for (final entry in tombstones.entries)
        if (entry.value > since) (revision: entry.value, keyJson: entry.key, row: null),
    ]..sort((a, b) => a.revision.compareTo(b.revision));

    final page = events.take(request.limit).toList();
    final next = page.isEmpty ? request.cursor : OpaqueCursor(page.last.revision.toString());

    return PullPage(
      rows: [
        for (final event in page)
          if (event.row != null) Map.of(event.row!),
      ],
      deletedKeys: [
        for (final event in page)
          if (event.row == null) (jsonDecode(event.keyJson) as List).cast<Object?>(),
      ],
      nextCursor: next,
      hasMore: events.length > request.limit,
    );
  }

  static int _sequenceOf(String idempotencyKey) {
    final index = idempotencyKey.lastIndexOf(':');
    return int.tryParse(idempotencyKey.substring(index + 1)) ?? -1;
  }

  static String _keyJsonOf(List<String> primaryKey, Map<String, Object?> key) =>
      jsonEncode([for (final column in primaryKey) key[column]]);

  static void _stamp(SyncEntityRef entity, Map<String, Object?> row) {
    final column = entity.updatedAtColumn;
    if (column != null) {
      row[column] = DateTime.now().toUtc().toIso8601String();
    }
  }
}

/// Convenience harness wiring a Drift database to the engine and a fake server.
final class SyncTestHarness {
  SyncTestHarness._({required this.sync, required this.server});

  final UniversalSync<GeneratedDatabase> sync;
  final FakeTransport server;

  static Future<SyncTestHarness> create({
    required GeneratedDatabase database,
    required List<SyncEntityBase> entities,
    SyncOptions options = const SyncOptions(),
    SyncBootstrap bootstrap = const SkipBootstrap(),
    FakeTransport? server,
    SyncSession session = const AnonymousSession(),
  }) async {
    final fake = server ?? FakeTransport();
    final sync = await UniversalSync.open<GeneratedDatabase>(
      database: database,
      entities: entities,
      transport: fake,
      session: session,
      options: options,
      bootstrap: bootstrap,
    );
    return SyncTestHarness._(sync: sync, server: fake);
  }

  /// Runs full cycles until the queue is empty or [maxCycles] is reached.
  Future<SyncReport> settle({int maxCycles = 5}) async {
    var report = const SyncReport();
    for (var i = 0; i < maxCycles; i++) {
      report = await sync.syncNow(push: true, pull: true);
      final diagnostics = await sync.diagnostics();
      if (diagnostics.pending == 0 && diagnostics.inflight == 0) break;
    }
    return report;
  }
}

import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

final class _Transport extends SyncTransport {
  @override
  SyncTransportCapabilities get capabilities => const SyncTransportCapabilities();

  @override
  Future<PushOutcome> push(PushBatch batch) async =>
      PushOutcome.appliedAll([for (final change in batch.changes) change.sequence]);

  @override
  Future<PullPage> pull(PullPageRequest request) async => const PullPage.empty();
}

void main() {
  group('cursors', () {
    test('opaque cursor round-trips', () {
      const cursor = OpaqueCursor('abc');
      final decoded = SyncCursor.decode(cursor.encode());
      expect(decoded, cursor);
      expect(decoded.hashCode, cursor.hashCode);
    });

    test('keyset cursor round-trips with composite keys', () {
      final cursor = KeysetCursor(
        updatedAt: DateTime.utc(2026, 1, 2),
        key: const ['a', 2, true],
      );
      final decoded = SyncCursor.decode(cursor.encode());
      expect(decoded, cursor);
      expect(decoded.hashCode, cursor.hashCode);
      expect(
        decoded,
        isNot(
          KeysetCursor(
            updatedAt: DateTime.utc(2026, 1, 2),
            key: const ['a', 3, true],
          ),
        ),
      );
    });

    test('null, malformed and unknown cursors decode to null', () {
      expect(SyncCursor.decode(null), isNull);
      expect(SyncCursor.decode('not json'), isNull);
      expect(SyncCursor.decode('{"type":"fromTheFuture"}'), isNull);
      expect(SyncCursor.decode('[]'), isNull);
    });
  });

  group('entity refs and changes', () {
    test('entity refs compare by wire-relevant fields', () {
      const a = SyncEntityRef(table: 'tasks', primaryKey: ['id']);
      const b = SyncEntityRef(
        table: 'tasks',
        primaryKey: ['other'],
        updatedAtColumn: 'updated_at',
      );
      const c = SyncEntityRef(table: 'tasks', primaryKey: ['id']);
      expect(a, c);
      expect(a.hashCode, c.hashCode);
      expect(a, isNot(b));
      expect(a.toString(), contains('tasks'));
    });

    test('change carries key, row, delta and idempotency key', () {
      const change = SyncChange(
        sequence: 7,
        kind: SyncChangeKind.update,
        idempotencyKey: 'install:7',
        key: {'id': 't1'},
        delta: {'title': 'x'},
      );
      expect(change.sequence, 7);
      expect(change.key, {'id': 't1'});
      expect(change.delta, {'title': 'x'});
      expect(change.row, isEmpty);
    });

    test('ack constructors and outcome normalization', () {
      const applied = ChangeAck.applied(1, serverRow: {'id': 'x'});
      const superseded = ChangeAck.superseded(2);
      final rejected = ChangeAck.rejected(3, const PermanentFailure('bad'));
      expect(applied.status, ChangeStatus.applied);
      expect(applied.serverRow, {'id': 'x'});
      expect(superseded.status, ChangeStatus.superseded);
      expect(rejected.status, ChangeStatus.rejected);
      expect(rejected.failure!.code, SyncFailureCode.permanent);

      final outcome = PushOutcome.appliedAll([1, 2, 3]);
      expect(outcome.normalizedAcks, hasLength(3));
      expect(outcome.normalizedAcks.map((a) => a.status), everyElement(ChangeStatus.applied));
    });

    test('capabilities have secure defaults', () {
      const caps = SyncTransportCapabilities();
      expect(caps.serverTimestamps, isFalse);
      expect(caps.tombstones, isFalse);
      expect(caps.idempotency, isFalse);
      expect(caps.atomicMultiEntity, isFalse);
      expect(caps.deliveryCertainty, isFalse);
      expect(caps.cursors, {CursorKind.opaque, CursorKind.keyset});
    });
  });

  group('transport defaults', () {
    test('pushMany loops over push and close is a no-op', () async {
      final transport = _Transport();
      const batchA = PushBatch(
        entity: SyncEntityRef(table: 'a', primaryKey: ['id']),
        changes: [
          SyncChange(
            sequence: 1,
            kind: SyncChangeKind.upsert,
            idempotencyKey: 'i:1',
          ),
        ],
      );
      const batchB = PushBatch(
        entity: SyncEntityRef(table: 'b', primaryKey: ['id']),
        changes: [
          SyncChange(
            sequence: 2,
            kind: SyncChangeKind.delete,
            idempotencyKey: 'i:2',
          ),
        ],
      );
      final results = await transport.pushMany([batchA, batchB]);
      expect(results.keys, hasLength(2));
      expect(results[batchA.entity]!.normalizedAcks.single.sequence, 1);
      await transport.close();
    });
  });

  group('failures', () {
    test('every failure variant round-trips through JSON', () {
      final failures = <SyncFailure>[
        const AuthFailure('auth'),
        const ForbiddenFailure('forbidden'),
        const RateLimited('rate', retryAfter: Duration(seconds: 3)),
        const TransientFailure('not sent', certainty: DeliveryCertainty.notSent),
        const TransientFailure('maybe applied'),
        const RevisionConflict('conflict', serverRow: {'id': 't1'}),
        const PermanentFailure('permanent'),
        const UnknownFailure('unknown', certainty: DeliveryCertainty.notSent),
      ];
      for (final failure in failures) {
        final restored = SyncFailure.fromJson(failure.toJson());
        expect(restored.code, failure.code);
        expect(restored.message, failure.message);
        expect(restored.certainty, failure.certainty);
        expect(restored.retryAfter, failure.retryAfter);
        expect(restored.toString(), contains(failure.code.name));
      }
    });

    test('revision conflicts preserve the server row', () {
      const failure = RevisionConflict('conflict', serverRow: {'id': 't1'});
      final restored = SyncFailure.fromJson(failure.toJson());
      expect((restored as RevisionConflict).serverRow, {'id': 't1'});
    });

    test('retryability matches the taxonomy', () {
      expect(const AuthFailure('x').retryable, isFalse);
      expect(const ForbiddenFailure('x').retryable, isFalse);
      expect(const PermanentFailure('x').retryable, isFalse);
      expect(const UnknownFailure('x').retryable, isFalse);
      expect(const RateLimited('x').retryable, isTrue);
      expect(const TransientFailure('x').retryable, isTrue);
      expect(const RevisionConflict('x').retryable, isTrue);
    });

    test('unknown codes remain loadable', () {
      final restored = SyncFailure.fromJson({'code': 'future'});
      expect(restored, isA<UnknownFailure>());
      expect(restored.code, SyncFailureCode.unknown);
    });
  });

  group('backoff and clock', () {
    test('exponential backoff grows, caps and honours zero jitter', () {
      const backoff = ExponentialBackoff(jitter: 0);
      expect(backoff.delayFor(0), const Duration(seconds: 1));
      expect(backoff.delayFor(1), const Duration(seconds: 2));
      expect(backoff.delayFor(2), const Duration(seconds: 4));
      expect(backoff.delayFor(100), const Duration(minutes: 5));
    });

    test('exponential jitter stays within the configured spread', () {
      const backoff = ExponentialBackoff(jitter: 0.5);
      for (var i = 0; i < 50; i++) {
        final delay = backoff.delayFor(2);
        expect(delay.inMilliseconds, inInclusiveRange(2000, 6000));
      }
    });

    test('fixed and no backoff', () {
      expect(const FixedBackoff(Duration(seconds: 9)).delayFor(3), const Duration(seconds: 9));
      expect(const NoBackoff().delayFor(3), Duration.zero);
    });

    test('test clock advances and sets absolute time', () {
      final clock = TestClock(DateTime.utc(2026, 1, 1));
      expect(clock.now(), DateTime.utc(2026, 1, 1));
      clock.advance(const Duration(hours: 2));
      expect(clock.now(), DateTime.utc(2026, 1, 1, 2));
      clock.set(DateTime.utc(2025));
      expect(clock.now(), DateTime.utc(2025));
    });
  });

  group('misc public types', () {
    test('anonymous session and cancel token', () {
      const session = AnonymousSession();
      expect(session.userId, isNull);
      expect(session.userIdChanges, emitsDone);

      final token = SyncCancelToken();
      expect(token.isCancelled, isFalse);
      token.throwIfCancelled();
      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(token.throwIfCancelled, throwsStateError);
    });

    test('report and diagnostics render useful summaries', () {
      const report = SyncReport();
      expect(report.isEmpty, isTrue);
      expect(report.toString(), contains('pushed: 0'));
      const busy = SyncReport(pushed: 1, pulled: 2);
      expect(busy.isEmpty, isFalse);

      const diagnostics = SyncDiagnostics(
        pending: 1,
        inflight: 2,
        tombstones: 3,
        conflicts: 4,
        parked: 5,
        outboxBytes: 6,
        installId: 'i',
        schemaVersion: 1,
        lastError: null,
      );
      expect(diagnostics.toString(), contains('pending: 1'));
    });

    test('local exceptions explain themselves', () {
      expect(
        const PayloadTooLargeException(bytes: 2, limit: 1).toString(),
        contains('limit'),
      );
      expect(
        const OwnershipViolation(table: 'tasks', owner: 'u2').toString(),
        contains('u2'),
      );
    });
  });
}

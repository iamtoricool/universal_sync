import 'package:test/test.dart';
import 'package:universal_sync/src/model/sync_state.dart';

void main() {
  group('SyncState', () {
    group('SyncIdle', () {
      test('stores fields correctly', () {
        final idle = SyncIdle(lastSyncedAt: DateTime(2024), pendingCount: 5);
        expect(idle.lastSyncedAt, DateTime(2024));
        expect(idle.pendingCount, 5);
      });

      test('uses default pendingCount of 0', () {
        final idle = SyncIdle();
        expect(idle.pendingCount, 0);
        expect(idle.lastSyncedAt, isNull);
      });
    });

    group('SyncInProgress', () {
      test('stores fields correctly', () {
        final prog = SyncInProgress(
          phase: SyncPhase.pushing,
          processed: 3,
          total: 10,
        );
        expect(prog.phase, SyncPhase.pushing);
        expect(prog.processed, 3);
        expect(prog.total, 10);
      });

      test('progress returns correct ratio', () {
        final prog = SyncInProgress(
          phase: SyncPhase.pulling,
          processed: 3,
          total: 10,
        );
        expect(prog.progress, closeTo(0.3, 0.001));
      });

      test('progress returns 0.0 when total == 0', () {
        final prog = SyncInProgress(
          phase: SyncPhase.pushing,
          processed: 0,
          total: 0,
        );
        expect(prog.progress, 0.0);
      });
    });

    group('SyncError', () {
      test('stores fields correctly', () {
        final error = StateError('sync failed');
        final stack = StackTrace.current;
        final syncError = SyncError(
          error: error,
          stackTrace: stack,
          pendingCount: 3,
        );
        expect(syncError.error, error);
        expect(syncError.stackTrace, stack);
        expect(syncError.pendingCount, 3);
      });
    });
  });
}

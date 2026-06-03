import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

void main() {
  group('SyncIdle', () {
    test('defaults to no lastSyncedAt and zero pendingCount', () {
      const s = SyncIdle();
      expect(s.lastSyncedAt, isNull);
      expect(s.pendingCount, 0);
    });

    test('stores lastSyncedAt', () {
      const s = SyncIdle(pendingCount: 5);
      expect(s.pendingCount, 5);
    });

    test('equality checks match same values', () {
      const a = SyncIdle(pendingCount: 3);
      const b = SyncIdle(pendingCount: 3);
      expect(a.pendingCount, b.pendingCount);
    });

    test('equality checks differ on pendingCount', () {
      const a = SyncIdle(pendingCount: 3);
      const b = SyncIdle(pendingCount: 5);
      expect(a.pendingCount, isNot(b.pendingCount));
    });
  });

  group('SyncInProgress', () {
    test('stores phase, processed, total', () {
      const s = SyncInProgress(phase: SyncPhase.pushing, processed: 2, total: 5);
      expect(s.phase, SyncPhase.pushing);
      expect(s.processed, 2);
      expect(s.total, 5);
    });

    test('progress is 0.0 when total is 0', () {
      const s = SyncInProgress(phase: SyncPhase.pushing, processed: 0, total: 0);
      expect(s.progress, 0.0);
    });

    test('progress is 0.5 when half done', () {
      const s = SyncInProgress(phase: SyncPhase.pulling, processed: 3, total: 6);
      expect(s.progress, 0.5);
    });

    test('progress is 1.0 when done', () {
      const s = SyncInProgress(phase: SyncPhase.pushing, processed: 5, total: 5);
      expect(s.progress, 1.0);
    });

    test('equality matches same values', () {
      const a = SyncInProgress(phase: SyncPhase.pushing, processed: 1, total: 3);
      const b = SyncInProgress(phase: SyncPhase.pushing, processed: 1, total: 3);
      expect(a.processed, b.processed);
      expect(a.total, b.total);
    });

    test('equality differs on processed', () {
      const a = SyncInProgress(phase: SyncPhase.pushing, processed: 1, total: 3);
      const b = SyncInProgress(phase: SyncPhase.pushing, processed: 2, total: 3);
      expect(a.processed, isNot(b.processed));
    });
  });

  group('SyncError', () {
    test('stores error, stackTrace, pendingCount', () {
      const state = SyncError(error: 'err', stackTrace: StackTrace.empty, pendingCount: 2);
      expect(state.error, 'err');
      expect(state.pendingCount, 2);
    });

    test('equality matches same values', () {
      const a = SyncError(error: 'x', stackTrace: StackTrace.empty, pendingCount: 1);
      const b = SyncError(error: 'x', stackTrace: StackTrace.empty, pendingCount: 1);
      expect(a.pendingCount, b.pendingCount);
    });

    test('equality differs on pendingCount', () {
      const a = SyncError(error: 'x', stackTrace: StackTrace.empty, pendingCount: 1);
      const b = SyncError(error: 'x', stackTrace: StackTrace.empty, pendingCount: 2);
      expect(a.pendingCount, isNot(b.pendingCount));
    });
  });
}

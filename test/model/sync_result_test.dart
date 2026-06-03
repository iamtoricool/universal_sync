import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

void main() {
  group('SyncResult', () {
    test('defaults to all zeros', () {
      const r = SyncResult();
      expect(r.pushed, 0);
      expect(r.pulled, 0);
      expect(r.failed, 0);
      expect(r.conflicted, 0);
      expect(r.isClean, isTrue);
      expect(r.duration, Duration.zero);
    });

    test('isClean is true when all counts are zero', () {
      const r = SyncResult();
      expect(r.isClean, isTrue);
    });

    test('isClean is true when only pushed > 0', () {
      const r = SyncResult(pushed: 1);
      expect(r.isClean, isTrue);
    });

    test('isClean is true when only pulled > 0', () {
      const r = SyncResult(pulled: 1);
      expect(r.isClean, isTrue);
    });

    test('isClean is false when failed > 0', () {
      const r = SyncResult(failed: 1);
      expect(r.isClean, isFalse);
    });

    test('isClean is false when conflicted > 0', () {
      const r = SyncResult(conflicted: 1);
      expect(r.isClean, isFalse);
    });

    test('hasErrors is true when failed > 0', () {
      const r = SyncResult(failed: 1);
      expect(r.hasErrors, isTrue);
    });

    test('hasErrors is false when failed is 0', () {
      const r = SyncResult(pushed: 1);
      expect(r.hasErrors, isFalse);
    });

    test('hasErrors is false when only conflicted > 0', () {
      const r = SyncResult(conflicted: 1);
      expect(r.hasErrors, isFalse);
    });

    test('hasConflicts is true when conflicted > 0', () {
      const r = SyncResult(conflicted: 1);
      expect(r.hasConflicts, isTrue);
    });

    test('isClean is false when both failed and conflicted > 0', () {
      const r = SyncResult(failed: 2, conflicted: 3);
      expect(r.isClean, isFalse);
    });

    test('duration is stored', () {
      const r = SyncResult(duration: Duration(seconds: 5));
      expect(r.duration, Duration(seconds: 5));
    });
  });
}

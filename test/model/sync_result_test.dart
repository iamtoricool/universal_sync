import 'package:test/test.dart';
import 'package:universal_sync/src/model/sync_result.dart';

void main() {
  group('SyncResult', () {
    test('hasErrors is true when failed > 0', () {
      final result = SyncResult(failed: 2);
      expect(result.hasErrors, isTrue);
    });

    test('hasErrors is false when failed == 0', () {
      final result = SyncResult();
      expect(result.hasErrors, isFalse);
    });

    test('hasConflicts is true when conflicted > 0', () {
      final result = SyncResult(conflicted: 1);
      expect(result.hasConflicts, isTrue);
    });

    test('hasConflicts is false when conflicted == 0', () {
      final result = SyncResult();
      expect(result.hasConflicts, isFalse);
    });

    test('isClean is true when no errors and no conflicts', () {
      final result = SyncResult(pushed: 5, pulled: 3);
      expect(result.isClean, isTrue);
    });

    test('isClean is false when there are errors', () {
      final result = SyncResult(pushed: 5, failed: 1);
      expect(result.isClean, isFalse);
    });

    test('isClean is false when there are conflicts', () {
      final result = SyncResult(pushed: 5, conflicted: 1);
      expect(result.isClean, isFalse);
    });
  });
}

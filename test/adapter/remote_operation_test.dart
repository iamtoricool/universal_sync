import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

void main() {
  group('RemoteOperation', () {
    test('constructor assigns all fields', () {
      final op = RemoteOperation(
        entityType: 'Product',
        entityId: '1',
        operation: SyncOperation.update,
        payload: {'name': 'test'},
        serverSequence: 42,
      );
      expect(op.entityType, 'Product');
      expect(op.entityId, '1');
      expect(op.operation, SyncOperation.update);
      expect(op.payload, {'name': 'test'});
      expect(op.serverSequence, 42);
    });

    test('supports insert operation', () {
      final op = RemoteOperation(
        entityType: 'A',
        entityId: '1',
        operation: SyncOperation.insert,
        payload: {},
        serverSequence: 1,
      );
      expect(op.operation, SyncOperation.insert);
    });

    test('supports delete operation', () {
      final op = RemoteOperation(
        entityType: 'A',
        entityId: '1',
        operation: SyncOperation.delete,
        payload: {},
        serverSequence: 1,
      );
      expect(op.operation, SyncOperation.delete);
    });
  });
}

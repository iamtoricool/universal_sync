import 'package:test/test.dart';
import 'package:universal_sync/src/model/sync_entity.dart';

class _TestEntity extends SyncEntity {
  @override
  final String id;
  @override
  final int version;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  _TestEntity({
    required this.id,
    this.version = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  @override
  Map<String, dynamic> toSyncJson() => {'id': id, 'version': version};
}

void main() {
  group('SyncEntity', () {
    test('isDeleted returns true when deletedAt is non-null', () {
      final entity = _TestEntity(
        id: '1',
        version: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        deletedAt: DateTime(2024),
      );
      expect(entity.isDeleted, isTrue);
    });

    test('isNew returns true when version == 0', () {
      final entity = _TestEntity(
        id: '2',
        version: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(entity.isNew, isTrue);
    });

    test('isNew returns false when version > 0', () {
      final entity = _TestEntity(
        id: '3',
        version: 5,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(entity.isNew, isFalse);
    });

    test('toSyncJson is implemented by subclass', () {
      final entity = _TestEntity(
        id: '4',
        version: 2,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(entity.toSyncJson(), equals({'id': '4', 'version': 2}));
    });
  });
}

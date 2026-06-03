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
  final String name;

  _TestEntity({
    required this.id,
    this.version = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.name = '',
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  @override
  Map<String, dynamic> toSyncJson() => {
    'id': id,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'name': name,
  };
}

void main() {
  group('SyncEntity', () {
    test('id is exposed as a non-null string', () {
      final entity = _TestEntity(
        id: 'abc',
        version: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(entity.id, isA<String>());
      expect(entity.id, 'abc');
    });

    test('version is exposed as an integer', () {
      final entity = _TestEntity(
        id: '1',
        version: 3,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(entity.version, isA<int>());
      expect(entity.version, 3);
    });

    test('createdAt is exposed as a DateTime', () {
      final dt = DateTime(2024, 6, 1);
      final entity = _TestEntity(
        id: '1',
        version: 1,
        createdAt: dt,
        updatedAt: DateTime(2024),
      );
      expect(entity.createdAt, isA<DateTime>());
      expect(entity.createdAt, dt);
    });

    test('updatedAt is exposed as a DateTime', () {
      final dt = DateTime(2024, 6, 1);
      final entity = _TestEntity(
        id: '1',
        version: 1,
        createdAt: DateTime(2024),
        updatedAt: dt,
      );
      expect(entity.updatedAt, isA<DateTime>());
      expect(entity.updatedAt, dt);
    });

    test('deletedAt is nullable', () {
      final without = _TestEntity(
        id: '1',
        version: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(without.deletedAt, isNull);

      final withValue = _TestEntity(
        id: '2',
        version: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        deletedAt: DateTime(2024),
      );
      expect(withValue.deletedAt, isA<DateTime>());
    });

    test('createdAt defaults to now when null', () async {
      final before = DateTime.now();
      await Future(() {});
      final entity = _TestEntity(
        id: '1',
        version: 1,
        createdAt: null as dynamic,
        updatedAt: DateTime(2024),
      );
      await Future(() {});
      final after = DateTime.now();
      expect(entity.createdAt, isA<DateTime>());
      expect(entity.createdAt.isAfter(before), isTrue);
      expect(entity.createdAt.isBefore(after), isTrue);
    });

    test('updatedAt defaults to now when null', () async {
      final before = DateTime.now();
      await Future(() {});
      final entity = _TestEntity(
        id: '1',
        version: 1,
        createdAt: DateTime(2024),
        updatedAt: null as dynamic,
      );
      await Future(() {});
      final after = DateTime.now();
      expect(entity.updatedAt, isA<DateTime>());
      expect(entity.updatedAt.isAfter(before), isTrue);
      expect(entity.updatedAt.isBefore(after), isTrue);
    });

    test('isDeleted returns false when deletedAt is null', () {
      final entity = _TestEntity(
        id: '1',
        version: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(entity.isDeleted, isFalse);
    });

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

    test('toSyncJson includes id field', () {
      final entity = _TestEntity(
        id: '4',
        version: 2,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final json = entity.toSyncJson();
      expect(json['id'], '4');
    });

    test('toSyncJson includes version field', () {
      final entity = _TestEntity(
        id: '5',
        version: 5,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      expect(entity.toSyncJson()['version'], 5);
    });

    test('toSyncJson includes createdAt as ISO 8601 string', () {
      final entity = _TestEntity(
        id: '6',
        version: 1,
        createdAt: DateTime(2024, 6, 15, 10, 30),
        updatedAt: DateTime(2024),
      );
      final json = entity.toSyncJson();
      expect(json['createdAt'], isA<String>());
      expect(json['createdAt'], '2024-06-15T10:30:00.000');
    });

    test('toSyncJson includes updatedAt as ISO 8601 string', () {
      final entity = _TestEntity(
        id: '7',
        version: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 6, 15, 10, 30),
      );
      final json = entity.toSyncJson();
      expect(json['updatedAt'], isA<String>());
      expect(json['updatedAt'], '2024-06-15T10:30:00.000');
    });

    test('toSyncJson includes deletedAt as ISO 8601 string when set', () {
      final deletedAt = DateTime(2024, 6, 15, 10, 30);
      final entity = _TestEntity(
        id: '8',
        version: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        deletedAt: deletedAt,
      );
      final json = entity.toSyncJson();
      expect(json['deletedAt'], isA<String>());
      expect(json['deletedAt'], deletedAt.toIso8601String());
    });

    test('toSyncJson includes deletedAt as null when not set', () {
      final entity = _TestEntity(
        id: '9',
        version: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final json = entity.toSyncJson();
      expect(json.containsKey('deletedAt'), isTrue);
      expect(json['deletedAt'], isNull);
    });

    test('toSyncJson includes all entity-specific fields', () {
      final entity = _TestEntity(
        id: '10',
        version: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        name: 'Widget',
      );
      final json = entity.toSyncJson();
      expect(json['name'], 'Widget');
    });
  });
}

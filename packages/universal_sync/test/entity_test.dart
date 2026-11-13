import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

import 'support/entities.dart';
import 'support/rig.dart';
import 'support/test_db.dart';

void main() {
  late TestDatabase db;
  late SyncEntity<Tasks, Task, String> entity;

  setUp(() {
    db = TestDatabase(NativeDatabase.memory());
    entity = tasksEntity(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('entity ref exposes the wire metadata', () {
    expect(entity.ref.table, 'tasks');
    expect(entity.ref.primaryKey, ['id']);
    expect(entity.ref.updatedAtColumn, 'updated_at');
    expect(entity.ref.ownerColumn, 'user_id');
    expect(entity.ref.serverManagedColumns, {'updated_at'});
    expect(entity.expectedColumns, containsAll(['id', 'title', 'updated_at']));
  });

  test('key codec is canonical, stable and compact', () {
    final a = entity.keyHashOfParts(['t1']);
    final b = entity.keyHashOfParts(['t1']);
    final c = entity.keyHashOfParts(['t2']);
    expect(a, b);
    expect(a, isNot(c));
    expect(a.length, 8);
    expect(entity.keyJsonOfParts(['t1', 2]), '["t1",2]');
  });

  test('keyPartsFromJsonRow falls back to decoding the row', () {
    final fallback = SyncEntity<Tasks, Task, String>(
      table: db.tasks,
      keyColumns: const ['id'],
      keyOf: entity.keyOf,
      whereKey: entity.whereKey,
      encode: entity.encode,
      decode: entity.decode,
      keyParts: entity.keyParts,
      keyFromParts: entity.keyFromParts,
      updatedAtOf: entity.updatedAtOf,
      updatedAtColumn: 'updated_at',
      ownerOf: entity.ownerOf,
      ownerColumn: 'user_id',
    );

    expect(fallback.keyPartsFromJsonRow(taskRow('t9', 'x')), ['t9']);
    expect(entity.keyPartsFromJsonRow(taskRow('t8', 'x')), ['t8']);
  });

  test('remote rows can be applied, read, deleted and cleared', () async {
    await entity.applyRemoteRow(db, taskRow('t1', 'a'));
    expect((await entity.readLocalByParts(db, ['t1']))!['title'], 'a');

    await entity.applyRemoteRow(db, taskRow('t1', 'b'));
    expect((await entity.readLocalByParts(db, ['t1']))!['title'], 'b');

    await entity.applyRemoteRow(db, taskRow('t2', 'c'));
    expect(await entity.readAllLocal(db), hasLength(2));

    expect(await entity.deleteByParts(db, ['t1']), isTrue);
    expect(await entity.deleteByParts(db, ['t1']), isFalse);
    expect(await entity.readLocalByParts(db, ['t1']), isNull);

    expect(await entity.deleteAllLocal(db), 1);
    expect(await entity.readAllLocal(db), isEmpty);
  });

  test('timestamp, owner and payload helpers', () {
    final row = taskRow('t1', 'a', userId: 'u1', updatedAt: DateTime.utc(2024));
    expect(entity.updatedAtFromJson(row), DateTime.utc(2024));
    expect(entity.ownerFromJson(row), 'u1');
    expect(entity.payloadBytes(row), greaterThan(0));

    final bare = SyncEntity<Tasks, Task, String>(
      table: db.tasks,
      keyColumns: const ['id'],
      keyOf: entity.keyOf,
      whereKey: entity.whereKey,
      encode: entity.encode,
      decode: entity.decode,
      keyParts: entity.keyParts,
      keyFromParts: entity.keyFromParts,
    );
    expect(bare.updatedAtFromJson(row), isNull);
    expect(bare.ownerFromJson(row), isNull);
  });

  test('entity applyRemoteRow rejects undecodable rows', () async {
    await expectLater(
      entity.applyRemoteRow(db, const {'id': 't1'}),
      throwsA(anything),
    );
  });
}

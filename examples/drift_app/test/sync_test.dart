import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:universal_sync/testing.dart';

import 'package:universal_sync_example/db.dart';
import 'package:universal_sync_example/db.sync.dart';

void main() {
  test('generated registry and extension sync without hand-written entities', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final server = FakeTransport();
    final sync = await openSync(db, transport: server);
    addTearDown(() async {
      await sync.dispose();
      await db.close();
    });

    // `sync.tasks` and `TasksCompanion` come entirely from generated code.
    await sync.tasks.create(
      TasksCompanion.insert(
        id: 't1',
        title: 'generated',
        updatedAt: DateTime.utc(2026),
      ),
    );

    final report = await sync.drain();
    expect(report.pushed, 1);

    final pushed = server.rowsFor('tasks').single;
    expect(pushed['title'], 'generated');
    expect(pushed['updated_at'], isA<String>());

    await sync.tasks.patch('t1', TasksCompanion(title: const Value('patched')));
    await sync.drain();
    expect(server.rowsFor('tasks').single['title'], 'patched');

    await sync.tasks.remove('t1');
    await sync.drain();
    expect(server.rowsFor('tasks'), isEmpty);
    expect(server.tombstonesFor('tasks'), isNotEmpty);

    expect(await sync.tasks.find('t1'), isNull);
  });

  test('int keys and .named() columns use runtime SQL names', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final server = FakeTransport();
    final sync = await openSync(db, transport: server);
    addTearDown(() async {
      await sync.dispose();
      await db.close();
    });

    final note = await sync.notes.create(NotesCompanion.insert(body: 'hello'));
    await sync.drain();

    final wire = server.rowsFor('notes').single;
    expect(wire['id'], note.id);
    expect(wire['note_body'], 'hello');
    expect(wire.containsKey('body'), isFalse);
  });

  test('generated registry exposes every annotated table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final entities = db.syncEntities;
    expect(entities, hasLength(2));
    expect(entities.map((e) => e.ref.table), containsAll(['tasks', 'notes']));
    final tasks = entities.firstWhere((e) => e.ref.table == 'tasks');
    expect(tasks.ref.primaryKey, ['id']);
    expect(tasks.ref.updatedAtColumn, 'updated_at');
    expect(tasks.ref.ownerColumn, 'user_id');
    expect(tasks.ref.serverManagedColumns, {'updated_at'});
  });
}

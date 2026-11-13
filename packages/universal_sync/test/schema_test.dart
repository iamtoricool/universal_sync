import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

import 'support/rig.dart';
import 'support/test_db.dart';

void main() {
  late TestDatabase db;

  setUp(() {
    db = TestDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('install is idempotent and keeps the install id', () async {
    final first = await SyncSchema.install(db);
    final firstId = await first.metaValue('install_id');
    final version = await first.metaValue('schema_version');

    final second = await SyncSchema.install(db);
    expect(await second.metaValue('install_id'), firstId);
    expect(await second.metaValue('schema_version'), version);
    expect(version, '$kSyncSchemaVersion');
  });

  test('meta values can be written and read', () async {
    final schema = await SyncSchema.install(db);
    expect(await schema.metaValue('missing'), isNull);
    await schema.setMetaValue('bootstrap_done', '1');
    expect(await schema.metaValue('bootstrap_done'), '1');
    await schema.setMetaValue('bootstrap_done', '0');
    expect(await schema.metaValue('bootstrap_done'), '0');
  });

  test('a newer schema version is refused', () async {
    await db.customStatement(
      "CREATE TABLE IF NOT EXISTS us_meta (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)",
    );
    await db.customStatement(
      "INSERT OR REPLACE INTO us_meta (key, value) VALUES ('schema_version', '999')",
    );
    await expectLater(
      SyncSchema.install(db),
      throwsA(isA<SyncSchemaTooNew>()),
    );
  });

  test('missing columns are reported as a schema mismatch', () async {
    final schema = await SyncSchema.install(db);
    await db.customStatement('DROP TABLE us_outbox');
    await db.customStatement(
      'CREATE TABLE us_outbox (sequence INTEGER NOT NULL PRIMARY KEY)',
    );

    await expectLater(
      schema.validate(),
      throwsA(
        isA<SyncSchemaMismatch>().having(
          (e) => e.missing,
          'missing',
          contains('entity'),
        ),
      ),
    );
  });

  test('install(validate: false) skips column validation', () async {
    final schema = await SyncSchema.install(db, validate: false);
    expect(await schema.metaValue('schema_version'), '$kSyncSchemaVersion');
  });

  test('all schema SQL statements are idempotent', () async {
    for (final statement in kSyncSchemaSql) {
      await db.customStatement(statement);
    }
    for (final statement in kSyncSchemaSql) {
      await db.customStatement(statement);
    }
    final schema = await SyncSchema.install(db);
    await schema.validate();
  });

  test('rig installs the schema for engine tests', () async {
    final rig = await TestRig.create();
    addTearDown(rig.dispose);
    expect((await rig.sync.diagnostics()).schemaVersion, kSyncSchemaVersion);
  });
}

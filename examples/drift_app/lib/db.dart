import 'package:drift/drift.dart';
import 'package:universal_sync/universal_sync.dart';

part 'db.g.dart';

@Syncable(
  key: #id,
  updatedAt: #updatedAt,
  owner: #userId,
  serverManagedColumns: [#updatedAt],
)
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A second synced table without timestamps/owner, an int key and a renamed
/// SQL column, to exercise the generator's variant paths.
@Syncable(key: #id)
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get body => text().named('note_body')();

  @override
  Set<Column> get primaryKey => {id};
}

@SyncDatabase()
@DriftDatabase(tables: [Tasks, Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

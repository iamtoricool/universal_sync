import 'package:drift/drift.dart';

part 'test_db.g.dart';

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Tasks])
class TestDatabase extends _$TestDatabase {
  TestDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('generated output matches the committed golden', () {
    final actual = File('lib/db.sync.dart').readAsStringSync();
    final golden = File('test/goldens/db.sync.dart').readAsStringSync();
    expect(actual, golden);
  });

  test('the generated file is wired into the public API', () {
    final source = File('lib/db.sync.dart').readAsStringSync();
    expect(source, contains('SyncTable<Tasks, Task, String> get tasks'));
    expect(source, contains('List<SyncEntityBase> get syncEntities'));
    expect(source, contains('Future<UniversalSync<AppDatabase>> openSync('));
  });
}

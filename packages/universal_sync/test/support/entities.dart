import 'package:drift/drift.dart';
import 'package:universal_sync/universal_sync.dart';

import 'test_db.dart';

/// Hand-written adapter for the test table. This is the shape the build_runner
/// generator will emit (see the roadmap: P4).
SyncEntity<Tasks, Task, String> tasksEntity(TestDatabase db) => SyncEntity(
  table: db.tasks,
  keyColumns: const ['id'],
  keyOf: (task) => task.id,
  whereKey: (table, key) => table.id.equals(key),
  encode: (task) => {
    'id': task.id,
    'title': task.title,
    'done': task.done,
    'user_id': task.userId,
    'updated_at': task.updatedAt.toUtc().toIso8601String(),
  },
  decode: (json) => Task(
    id: json['id'] as String,
    title: json['title'] as String,
    done: json['done'] as bool? ?? false,
    userId: json['user_id'] as String?,
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
  ),
  keyParts: (key) => [key],
  keyFromParts: (parts) => parts.first as String,
  keyPartsFromRow: (json) => [json['id']],
  updatedAtOf: (task) => task.updatedAt,
  updatedAtColumn: 'updated_at',
  ownerOf: (task) => task.userId,
  ownerColumn: 'user_id',
  stampUpdatedAt: (companion, now) => (companion as TasksCompanion).copyWith(updatedAt: Value(now)),
  stampOwner: (companion, owner) => (companion as TasksCompanion).copyWith(userId: Value(owner)),
  serverManagedColumns: const {'updated_at'},
  expectedColumns: const ['id', 'title', 'done', 'user_id', 'updated_at'],
);

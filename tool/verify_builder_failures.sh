#!/usr/bin/env bash
# Runs the builder against a series of invalid schemas and asserts that each
# one produces the intended diagnostic. Used by CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/lib"
cat > "$WORK/pubspec.yaml" <<YAML
name: universal_sync_negative_fixture
publish_to: none
environment:
  sdk: ^3.14.0
dependencies:
  drift: ^2.35.4
  universal_sync:
    path: $ROOT/packages/universal_sync
dev_dependencies:
  build_runner: ^2.4.0
  drift_dev: ^2.35.3
  universal_sync_builder:
    path: $ROOT/packages/universal_sync_builder
dependency_overrides:
  universal_sync:
    path: $ROOT/packages/universal_sync
YAML

(
  cd "$WORK"
  dart pub get >/dev/null
)

run_case() {
  local name="$1"
  local expected="$2"
  local source="$3"

  printf '%s\n' "$source" > "$WORK/lib/db.dart"
  if (
    cd "$WORK"
    dart run build_runner build > build.log 2>&1
  ); then
    echo "FAIL [$name]: build unexpectedly succeeded"
    cat "$WORK/build.log"
    return 1
  fi
  if ! grep -qF "$expected" "$WORK/build.log"; then
    echo "FAIL [$name]: expected diagnostic not found: $expected"
    cat "$WORK/build.log"
    return 1
  fi
  echo "PASS [$name]"
}

HEADER="import 'package:drift/drift.dart';
import 'package:universal_sync/universal_sync.dart';"

run_case "key-not-a-column" 'key "#nope" does not name a column' "$HEADER
@Syncable(key: #nope)
class Tasks extends Table {
  TextColumn get id => text()();
  @override
  Set<Column> get primaryKey => {id};
}
@SyncDatabase()
@DriftDatabase(tables: [Tasks])
class AppDatabase { Tasks get tasks => throw UnimplementedError(); }"

run_case "unsupported-key-type" 'unsupported type DateTime' "$HEADER
@Syncable(key: #createdAt)
class Tasks extends Table {
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {createdAt};
}
@SyncDatabase()
@DriftDatabase(tables: [Tasks])
class AppDatabase { Tasks get tasks => throw UnimplementedError(); }"

run_case "updatedAt-not-datetime" 'must name a DateTime column' "$HEADER
@Syncable(key: #id, updatedAt: #title)
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  @override
  Set<Column> get primaryKey => {id};
}
@SyncDatabase()
@DriftDatabase(tables: [Tasks])
class AppDatabase { Tasks get tasks => throw UnimplementedError(); }"

run_case "owner-not-string" 'must name a String column' "$HEADER
@Syncable(key: #id, owner: #count)
class Tasks extends Table {
  TextColumn get id => text()();
  IntColumn get count => integer()();
  @override
  Set<Column> get primaryKey => {id};
}
@SyncDatabase()
@DriftDatabase(tables: [Tasks])
class AppDatabase { Tasks get tasks => throw UnimplementedError(); }"

run_case "server-managed-unknown" 'serverManagedColumns contains "#nope"' "$HEADER
@Syncable(key: #id, serverManagedColumns: [#nope])
class Tasks extends Table {
  TextColumn get id => text()();
  @override
  Set<Column> get primaryKey => {id};
}
@SyncDatabase()
@DriftDatabase(tables: [Tasks])
class AppDatabase { Tasks get tasks => throw UnimplementedError(); }"

run_case "blob-column" 'is a blob' "$HEADER
@Syncable(key: #id)
class Tasks extends Table {
  TextColumn get id => text()();
  BlobColumn get payload => blob()();
  @override
  Set<Column> get primaryKey => {id};
}
@SyncDatabase()
@DriftDatabase(tables: [Tasks])
class AppDatabase { Tasks get tasks => throw UnimplementedError(); }"

run_case "no-columns" 'no columns were discovered' "$HEADER
@Syncable(key: #id)
class Tasks extends Table {
  @override
  Set<Column> get primaryKey => {};
}
@SyncDatabase()
@DriftDatabase(tables: [Tasks])
class AppDatabase { Tasks get tasks => throw UnimplementedError(); }"

run_case "missing-drift-database" 'requires a @DriftDatabase' "$HEADER
@SyncDatabase()
class AppDatabase { Tasks get tasks => throw UnimplementedError(); }"

echo 'All negative builder fixtures passed.'

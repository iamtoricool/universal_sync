# universal_sync_builder

`build_runner` generator for [`universal_sync`](../universal_sync).

It reads `@SyncDatabase` / `@Syncable` annotations and emits a standalone
`.sync.dart` library next to your database file.

## Usage

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  universal_sync_builder: ^0.1.0
```

```dart
@Syncable(key: #id, updatedAt: #updatedAt, owner: #userId)
class Tasks extends Table { ... }

@SyncDatabase()
@DriftDatabase(tables: [Tasks])
class AppDatabase extends _$AppDatabase { ... }
```

```bash
dart run build_runner build
```

The generated file (`lib/db.sync.dart` for `lib/db.dart`) contains:

- `tasksSyncEntity(AppDatabase db)` — a fully typed `SyncEntity`.
- `extension AppDatabaseSync` — `List<SyncEntityBase> get syncEntities`.
- `extension AppDatabaseSyncEngine` — `sync.tasks` typed write facades.
- `openSync(db, transport: ...)` — opens the engine with the registry wired up.

## Notes

- Column names are resolved at runtime from Drift's table info, so `.named()`
  columns and drift's JSON-key options work without configuration.
- Row encoding/decoding uses Drift's generated `toJson`/`fromJson`, with
  `DateTime` values serialized as ISO-8601 to match the wire protocol.
- v1 supports `TextColumn`, `IntColumn`, `BoolColumn`, `DateTimeColumn`,
  `RealColumn`, single-column `String` / `int` / `double` / `bool` keys.
  Blob columns and other custom column types need a hand-written `SyncEntity`.

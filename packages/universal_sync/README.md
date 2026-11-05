# universal_sync

**A Drift-native, compile-time-typed, offline-first sync core for Dart.**

`universal_sync` owns the outbox, cursors, tombstones, conflicts and retry
machinery. It ships **no backend adapters**: you implement one small transport
contract (or install an adapter package such as `universal_sync_supabase`) and
keep using normal Drift queries, companions, joins and transactions.

```
app write ──► SyncTable<Tasks, Task, String> ──► one Drift transaction
                                                     │
                                     user tables + us_outbox
                                                     │
                                          SyncTransport (your adapter)
                                                     │
                                                remote backend
```

## Why it is different

- **Typed end to end.** `sync.tasks.save(TasksCompanion(...))`, no table-name
  strings, no `Map<String, dynamic>` at the API boundary.
- **Atomic writes.** The local row and its outbox entry commit in the same
  Drift transaction, including inside your existing `db.transaction`.
- **No bundled adapters.** One contract, implemented per backend and validated
  at `open()` through capability negotiation.
- **Correct offline editing.** Coalescing, per-key ordering, delivery
  certainty, tombstones, cursor pagination and durable conflicts instead of
  "last write wins by device clock".
- **No silent data loss.** Permanent failures become dead letters; nothing is
  auto-deleted.

## Install

```yaml
dependencies:
  universal_sync: ^0.1.0
  drift: ^2.35.0

dev_dependencies:
  build_runner: ^2.4.0
  universal_sync_builder: ^0.1.0
```

The runtime dependency is `drift` only. Import:

```dart
import 'package:universal_sync/universal_sync.dart';
import 'package:universal_sync/testing.dart'; // FakeTransport + SyncTestHarness
```

## Quick start

### 1. Annotate tables and the database

```dart
@Syncable(key: #id, updatedAt: #updatedAt, owner: #userId)
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@SyncDatabase()
@DriftDatabase(tables: [Tasks])
class AppDatabase extends _$AppDatabase { ... }
```

Run the generator:

```bash
dart run build_runner build
```

It writes `lib/<your_db>.sync.dart` with a typed descriptor per `@Syncable`
table, `db.syncEntities`, `sync.tasks` extension getters and an `openSync(...)`
convenience function. No hand-written entity code is required: the generated
descriptors use Drift's own `toJson`/`fromJson` and resolve SQL column names
from the table info at runtime, so renamed columns keep working.

### 2. Open the engine

```dart
import 'db.sync.dart';

final sync = await openSync(
  db,
  transport: MyTransport(),            // from an adapter package
  session: mySession,                  // optional: userId + userIdChanges
  bootstrap: const MergeByUpdatedAt(), // first run on an existing app
  options: const SyncOptions(),
);
```

`openSync` installs the package-owned tables (`us_outbox`, `us_cursors`,
`us_tombstones`, `us_conflicts`, `us_dead_letters`, `us_meta`) in your database,
validates them with `PRAGMA table_info`, checks transport capabilities and
recovers abandoned leases. Your `@DriftDatabase`, `schemaVersion` and generated
code are untouched.

For unusual schemas (blob columns, custom converters) a hand-written
`SyncEntity` is still supported; the generated descriptor is the normal path.

### 3. Write

```dart
await sync.tasks.create(TasksCompanion.insert(
  id: 't1', title: 'Ship it', updatedAt: clock.now(),
));

await sync.tasks.patch('t1', TasksCompanion(title: const Value('Done')));
await sync.tasks.remove('t1');

// Atomic across entities, inside your own transaction:
await db.transaction(() async {
  await sync.tasks.create(...);
  await sync.projects.save(...);
});
```

`create` / `save` / `patch` / `remove` write locally **and** queue the change in
one transaction. `saveAll` and `removeMany` do it in one batch transaction.
`markDirty(key, kind:)` queues a change for a row written by your own DAO (not
atomic; prefer the typed methods).

### 4. Sync

```dart
await sync.syncNow(push: true, pull: true); // bootstrap once, then push + pull
await sync.drain();                          // push only
await sync.pull();                           // pull only
```

`drain()` is single-flight, claims work atomically, loops until the queue is
empty or its time budget is spent, and never blocks concurrent callers.
`pull()` paginates per entity until `hasMore` is false.

## API at a glance

| Member | Purpose |
|---|---|
| `UniversalSync.open<DB>(...)` | Install/validate schema, recover leases |
| `sync.table(entity)` | Typed write facade |
| `sync.drain()`, `pull()`, `syncNow()` | Sync cycles |
| `sync.bootstrap()` | Run the first-run policy exactly once |
| `sync.events` | Typed lifecycle stream |
| `sync.status`, `statusStream` | `idle / draining / pulling / offline / authRequired` |
| `sync.diagnostics()` | Queue depth, bytes, tombstones, conflicts, install id |
| `sync.conflicts()`, `resolveConflict()` | Durable manual conflicts |
| `sync.retryParked()`, `discardParked()` | Explicit dead-letter control |
| `sync.purge({localData})` | Wipe sync state (and optionally local rows) |
| `sync.dispose()` | Release leases/timers; never closes your database |

### Options

`batchSize`, `pullPageSize`, payload and batch byte limits, `Backoff`
(exponential/fixed/none), `maxAttempts`, `lease`, `tombstoneRetention`,
`maxOutboxBytes`, `autoDrain` + debounce, `skipUnchangedPulls`,
`purgeOnUserChange`, `stampUpdatedAt`, `cancelUnsyncedCreateThenDelete`,
`promoteDependentUpdates`, `conflictPolicy`, injectable `SyncClock`.

### Conflict policies

`NewestWins` (default, compares `updated_at`), `ServerWins`, `ClientWins`,
`ManualConflicts` (stored in `us_conflicts` and resolved via the API).

## Guarantees

- **At-least-once push**; `upsert` / `update` / `delete` are naturally
  idempotent, and `idempotencyKey` is stable per change.
- **Per-key causal ordering**: a newer change for a key is never sent before an
  older one resolves.
- **Crash safety**: the cursor commits with its page, and leases make a killed
  process resumable.
- **Offline coalescing**: create+update → one upsert; create+update+delete →
  one idempotent delete (configurable); not-sent failures stay coalescible.
- **No resurrection**: tombstones suppress stale remote rows even after the
  delete is acknowledged.
- **No silent loss**: permanent failures are parked in `us_dead_letters`.

Full details (repository):
[guarantees](https://github.com/iamtoricool/universal_sync/blob/main/packages/universal_sync/doc/guarantees.md) ·
[protocol](https://github.com/iamtoricool/universal_sync/blob/main/packages/universal_sync/doc/protocol.md) ·
[adapter guide](https://github.com/iamtoricool/universal_sync/blob/main/packages/universal_sync/doc/adapter-guide.md).

## Testing

`package:universal_sync/testing.dart` ships the reference test doubles:

- `FakeTransport` — in-memory server with revision cursors, tombstones,
  authoritative timestamps, failure injection and idempotency dedupe.
- `SyncTestHarness` — wires a Drift database, the engine and the fake server;
  `settle()` runs cycles until the queue is empty.

```dart
final harness = await SyncTestHarness.create(
  database: db,
  entities: [tasksEntity(db)],
);
await harness.sync.table(tasksEntity(db)).create(...);
await harness.settle();
expect(harness.server.rowsFor('tasks'), hasLength(1));
```

## Releasing

1. Bump `version:` in `pubspec.yaml` and add a `CHANGELOG.md` entry.
2. Push a matching tag:

   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

The `Publish` workflow runs formatting, analysis and tests, verifies that the
tag matches the pubspec version, then publishes to pub.dev using trusted
publishing (OIDC). Pull requests targeting `main` run the `CI` workflow only.

## Status

MVP is implemented and tested: contracts, schema, journal, engine, typed write
facade, `build_runner` generator (`@Syncable` / `@SyncDatabase`), test doubles
and docs. Remaining: reconcile/isolate extras (P6). Backend adapters are
intentionally out of scope for this package.

## License

MIT.

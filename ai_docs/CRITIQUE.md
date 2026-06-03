# loxia_sync — Critical Code Analysis

> A thorough code-level audit of `loxia_sync` to identify design weaknesses,
> missing features, implementation bugs, and opportunities for improvement.
> Every finding here directly informs the `universal_sync` design.

---

## 1. Model Layer

### SyncEntity (`lib/src/sync_entity.dart`)

**What it does:** Abstract base class that every synced entity extends. Ships `id`, `version`,
`createdAt`, `updatedAt`, `deletedAt` built-in. Extends Loxia's `Entity`.

**Problems:**

| # | Issue | Consequence |
|---|---|---|
| 1.1 | **Extends Loxia's `Entity`** | Forces every synced entity to be a Loxia entity. Impossible to use with Drift, Hive, or any other ORM. |
| 1.2 | **No `fromJson` requirement** | `toSyncJson()` exists for serialization but there's no corresponding deserialization method. `fromJson` lives in a separate map (`entityFromJson`) passed to `LoxiaSync` — no compile-time guarantee it's implemented. |
| 1.3 | **Mutable timestamp fields** | `DateTime createdAt` and `DateTime updatedAt` are non-final. Breaks immutability; requires defensive copies. |
| 1.4 | **No `copyWith` method** | Entities can't be cloned with modifications. The pusher works around this by re-creating entities entirely via `fromJson`, which is indirect and error-prone. |
| 1.5 | **Generic SyncEntity model** | The engine casts between `Map<String, dynamic>` and typed entities in multiple places (e.g., `entity as T` in `LoxiaSync.upsert()`), indicating the abstraction isn't clean. |

**Design pattern in loxia_sync:**
```dart
abstract class SyncEntity extends Entity {  // ← hard Loxia dependency
  @PrimaryKey(uuid: true)
  final String id;

  @Column(defaultValue: 0)
  final int version;

  @CreatedAt()
  DateTime createdAt;  // ← mutable

  @UpdatedAt()
  DateTime updatedAt;  // ← mutable

  @DeletedAt()
  DateTime? deletedAt;

  Map<String, dynamic> toSyncJson();  // ← serialize only, no deserialize
}
```

---

### SyncQueueEntry (`lib/src/entities/sync_queue_entry.dart`)

**What it does:** Loxia entity for the internal sync queue table. Tracks operation type,
entity reference, payload, status, retries.

**Problems:**

| # | Issue | Consequence |
|---|---|---|
| 2.1 | **Loxia entity with code generation** | Requires `@EntityMeta`, `@PrimaryKey`, `@Column`, `part '...g.dart'`, and `build_runner`. Adds build complexity and time. |
| 2.2 | **Mutable fields** | `status`, `syncedAt`, `retryCount`, `conflictPayload` are non-final. Loxia's `@UpdatedAt` and repository methods require this, but it means entries can be mutated after creation. |
| 2.3 | **Custom `Absent` sentinel in `copyWith`** | Uses a sentinel `Absent` class to distinguish "not provided" from `null`. This is clever but non-standard and confusing to new contributors. |
| 2.4 | **`conflictPayload` is written but never read** | The field exists on the model but the pusher never stores the server's conflict payload back into the queue entry after a conflict. It only uses it in-memory during `_handleConflicted` and discards it. |

**The `Absent` sentinel pattern:**
```dart
const absent = Absent();

SyncQueueEntry copyWith({
  Object? syncedAt = absent,  // ← can't use `DateTime? syncedAt` here because null is valid
  // ...
}) {
  return SyncQueueEntry(
    syncedAt: identical(syncedAt, absent) ? this.syncedAt : syncedAt as DateTime?,
    // ...
  );
}
```

---

### SyncCheckpoint (`lib/src/entities/sync_checkpoint.dart`)

**What it does:** Loxia entity tracking the last pulled server sequence per entity type.

**Problems:**

| # | Issue | Consequence |
|---|---|---|
| 3.1 | **Same Loxia coupling** | Same code-gen and annotation requirements as SyncQueueEntry. |
| 3.2 | **Same `Absent` sentinel pattern** | Same non-standard copyWith approach as SyncQueueEntry. |
| 3.3 | **Mutable `lastServerSequence`** | The field is declared non-final (`int lastServerSequence`), making it mutable from outside. |

---

## 2. Write Path — SyncRepository (`lib/src/repository/sync_repository.dart`)

**What it does:** Wraps Loxia's `EntityRepository` for a sync-enabled entity type. Intercepts
writes to enqueue sync entries atomically. Passes reads through.

**Problems:**

| # | Issue | Consequence |
|---|---|---|
| 4.1 | **`findBy`/`findOneBy` use `Map<String, dynamic>`** | No type safety. `findBy({'prce': 10})` fails at runtime with a field-not-found error. |
| 4.2 | **Queue coalescing: update after delete** | `_enqueueUpdate` on a pending `delete` entry promotes it to `update`. This means "delete then update" becomes "update" — the delete is silently undone. The intent might be correct but it's undocumented behavior. |
| 4.3 | **Write-time payload snapshot** | `entity.toSyncJson()` is called at write time. If the entity is modified after enqueue but before sync, the payload is stale. No mechanism to refresh the payload at push time. |
| 4.4 | **Read methods are Loxia pass-through** | Returns Loxia entity instances. This is fine within loxia_sync but the abstraction can't be reused for `universal_sync`. |
| 4.5 | **Tightly coupled constructor** | Requires `EntityRepository<T, PartialEntity<T>>`, `EntityRepository<SyncQueueEntry, PartialEntity<SyncQueueEntry>>`, `DataSource`, and `LoxiaTransaction` — all Loxia-specific types. |

**The coalescing logic:**
```dart
// enqueueUpdate: if existing is delete, promote to update
existing.copyWith(
  operation: existing.operation == SyncOperation.delete
      ? SyncOperation.update   // ← delete silently becomes update
      : existing.operation,
  payload: jsonEncode(entity.toSyncJson()),
);

// enqueueDelete: if existing is already delete, skip
if (existing.operation == SyncOperation.delete) return;
// otherwise, overwrite existing update with delete
```

---

## 3. Remote Adapter — SyncAdapter (`lib/src/adapter/sync_adapter.dart`)

**What it does:** Abstract interface for remote sync. `push(PushRequest)` → `PushResponse`,
`pull(PullRequest)` → `PullResponse`.

**Problems:**

| # | Issue | Consequence |
|---|---|---|
| 5.1 | **`PushRequest` exposes internal queue entities** | Field is `List<SyncQueueEntry>`. The adapter sees the internal queue model directly. If the queue model changes, the adapter contract breaks. |
| 5.2 | **`serverSequence` type mismatch** | Field is `int?` but `.accepted()` named constructor takes a required `int`. The type system says nullable but runtime reality says non-null. |
| 5.3 | **No error classification** | `rejected` has only a string `errorMessage`. The adapter can't signal "auth error" vs "validation error" vs "server error" — the engine treats all rejections identically. |
| 5.4 | **Wrong import style** | `import 'package:loxia_sync/src/...'` used internally instead of a relative import. Works but is a code smell. |
| 5.5 | **No `SyncEntryResult` for pull** | Pull results aren't per-entry — it's a bulk operation set. This is fine for the current design but means pull errors are all-or-nothing. If one operation fails, the whole pull batch fails. |

**The type mismatch:**
```dart
class SyncEntryResult {
  final int? serverSequence;  // ← declared nullable
  // ...
  const SyncEntryResult.accepted({
    required this.entryId,
    required int serverSequence,  // ← required non-null
  }) : outcome = SyncOutcome.accepted,
       this.serverSequence = serverSequence,  // ← assigned to nullable field
       // ...
}
```

---

## 4. Configuration — SyncConfig (`lib/src/config/sync_config.dart`)

**What it does:** Stores entity order, batch size, max retries, optional conflict resolvers.

**Problems:**

| # | Issue | Consequence |
|---|---|---|
| 6.1 | **No retry delay** | Retries are immediate. No backoff strategy. If the server is transiently unavailable, immediate retries waste bandwidth and worsen the situation. |
| 6.2 | **No per-entity batch size** | All types use the same `batchSize`. Can't fine-tune for different volumes. |
| 6.3 | **`List<Type>` has no type constraint** | Nothing prevents passing `String` or `int` as an entity type. Validation is deferred to runtime assertions in `LoxiaSync.init()`. |
| 6.4 | **No logging configuration** | No `logger` or `logLevel` parameter. Warnings go to `print()`. |
| 6.5 | **`resolvers` map is untyped** | `Map<Type, ConflictResolver>` — no constraint linking the Type key to the resolver's generic parameter. You could register a `ConflictResolver<Product>` for the `Sale` key. |

---

## 5. Engine — SyncEngine (`lib/src/engine/sync_engine.dart`)

**What it does:** Orchestrates pusher and puller, manages `Stream<SyncState>`, prevents
concurrent runs.

**Problems:**

| # | Issue | Consequence |
|---|---|---|
| 7.1 | **No cancellation** | Once `sync()` starts, it can't be stopped. Mobile users navigating away waste battery and bandwidth. |
| 7.2 | **`_runOnce` uses `whenComplete`** | If `fn()` throws synchronously (before returning a `Future`), `_isRunning` is never reset. Dart async functions always return a `Future`, but if a non-async function is passed, this breaks. |
| 7.3 | **`_emitIdle`/`_emitError` are async unnecessarily** | They await `_pendingCount()` but then call the synchronous `_emitState()`. Cleaner to compute pending first, then emit synchronously. |
| 7.4 | **No event hooks** | No `onSyncStart`, `onPushComplete`, `onPullComplete`, `onConflict`, `onError` callbacks. Users must listen to the state stream and pattern-match, which is verbose for common cases. |
| 7.5 | **Progress resets between phases** | When transitioning from pushing to pulling, progress goes from `(pushing, 50/50)` to `(pulling, 0/?)`. No cumulative progress across the full sync cycle. |
| 7.6 | **Initial state never streamed** | `SyncIdle` is stored in `_currentState` but never emitted on the stream. A late listener won't see it. |

**The `_runOnce` pattern:**
```dart
Future<SyncResult> _runOnce(Future<SyncResult> Function() fn) {
  // ...
  _isRunning = true;
  return fn().whenComplete(() => _isRunning = false);  // ← brittle
}
```

---

## 6. Pusher — SyncPusher (`lib/src/engine/sync_pusher.dart`)

**What it does:** Fetches pending queue batches, sends to adapter, handles accepted /
conflicted / rejected outcomes.

**Problems:**

| # | Issue | Consequence |
|---|---|---|
| 8.1 | **Raw SQL for status updates** | `_markProcessing` and `_resetToPending` use `_dataSource.options.engine.execute()` with hardcoded table names. If Loxia's table naming changes, these queries break silently. |
| 8.2 | **Silent skip on missing `fromJson`** | `_handleAccepted` skips the version update when `fromJson == null || persister == null`. The entry is marked `synced` but the entity version is never incremented — silent data loss. |
| 8.3 | **acceptLocal drops change after max retries** | When `retryCount >= maxRetries`, the entry is marked `failed` but the local entity is NOT reverted. The user's local change remains visible but will never be synced — silent data loss. |
| 8.4 | **No rejection differentiation** | All `rejected` outcomes are treated identically. Auth errors, validation errors, and server errors all get the same retry logic. |
| 8.5 | **Progress can go backwards** | `totalPending` is calculated upfront. When an entry is re-queued (conflict → acceptLocal, or rejected with retries), it will be fetched again. `processedCount` exceeds `totalPending`, making progress > 100%. |

**The raw SQL:**
```dart
await _dataSource.options.engine.execute(
  'UPDATE loxia_sync_queue SET status = ? WHERE id IN ($placeholders)',
  ['processing', ...ids],
);
```

**The silent skip:**
```dart
if (fromJson != null && persister != null) {
  // ... update version properly
} else {
  // mark as synced but NEVER update the entity version ← silent data loss
  await _dataSource.getRepository<SyncQueueEntry>().updateEntity(
    entry.copyWith(status: SyncEntryStatus.synced, syncedAt: DateTime.now()),
  );
}
```

---

## 7. Puller — SyncPuller (`lib/src/engine/sync_puller.dart`)

**What it does:** Fetches remote operations per entity type, applies them locally, updates
checkpoints.

**Problems:**

| # | Issue | Consequence |
|---|---|---|
| 9.1 | **`print()` for warnings** | Warnings about entity type mismatches and version=0 go to stdout. No way to suppress, redirect, or filter them. |
| 9.2 | **Entity type mismatch silently skips** | If `op.entityType != entityTypeName`, it prints a warning and returns early. The operation is silently dropped — could cause data loss if the server misbehaves. |
| 9.3 | **Extra checkpoint query inside transaction** | `_upsertCheckpoint` does a `findBy` query inside the transaction to look up the existing checkpoint. The `existingCp` parameter is provided by the caller in most cases, but the fallback still queries unnecessarily. |
| 9.4 | **No serverSequence ordering** | The puller assumes the server returns operations in `serverSequence` order but never verifies or sorts them. Out-of-order operations can cause constraint violations. |
| 9.5 | **All operations in one transaction** | If a pull batch has 200 operations, they're all in one transaction. On mobile with SQLite, large transactions can cause `SQLITE_BUSY` or memory pressure. |

**The silent skip:**
```dart
if (op.entityType != entityTypeName) {
  print('[loxia_sync] WARNING: ...');  // ← just a warning
  return;  // ← operation silently dropped
}
```

---

## 8. Facade — LoxiaSync (`lib/src/loxia_sync.dart`)

**What it does:** Single entry point. Wires everything together, provides `repository<T>()`,
`engine`, `init()`, `dispose()`, `destroy()`.

**Problems:**

| # | Issue | Consequence |
|---|---|---|
| 10.1 | **Two-phase init** | Users must call `repository<T>()` for each type BEFORE `init()`. Forgetting a type causes a cryptic assertion error at runtime. |
| 10.2 | **`entityFromJson` map uses string keys** | Keys must match `entityTypeName(T)`. A mismatch between the string key and the actual class name causes a runtime assertion. No type safety. |
| 10.3 | **`destroy()` uses `dart:io`** | `File` from `dart:io` is not available on web. The `databasePath` parameter is Loxia-specific (SQLite file path). |
| 10.4 | **No type unregistration** | Once registered, a `SyncRepository` is permanent. Can't dynamically add/remove entity types. |
| 10.5 | **`engine` getter is lazy but synchronous** | Builds the entire SyncEngine (including internal maps) on first access. If construction throws, the exception propagates from a getter — unexpected in Dart (getters should not do heavy work). |

**The two-phase init:**
```dart
// Phase 1: register types
final products = loxiaSync.repository<Product>(Product.entity);
final customers = loxiaSync.repository<Customer>(Customer.entity);
// Phase 2: validate
await loxiaSync.init();
// If you forgot phase 1 for any type → runtime assertion error
```

---

## Cross-Cutting Issues

### Missing Features

| # | Missing Feature | Why It Matters |
|---|---|---|
| A | **Cancellation** | Mobile users navigate away; long syncs waste battery and bandwidth |
| B | **Queue pruning** | Synced entries accumulate forever — no cleanup mechanism |
| C | **Configurable logging** | `print()` is not configurable, filterable, or taggable |
| D | **Typed error hierarchy** | All errors are `Object` — no way to catch specific sync errors |
| E | **Retry backoff** | Immediate retries flood the server on transient failures |
| F | **Per-type batch size** | One batch size doesn't fit all entity types (users vs orders) |
| G | **Stream replay** | Late listeners to `state` stream miss the initial `SyncIdle` state |
| H | **Lifecycle hooks** | Users must pattern-match on sealed classes for common events |
| I | **FromJson compile-time safety** | No way to check that `fromJson` exists for each entity type at compile time |
| J | **Sync statistics** | No API to query "how many entries synced today? what's the failure rate?" |
| K | **Selective sync** | No way to sync only specific entities or entity types |
| L | **Server-side echo prevention** | No mechanism to tell the server "don't echo back my own changes" on pull |

### Design Pattern Issues

| # | Pattern | Problem |
|---|---|---|
| M | **Two-phase init** | Easy to forget `repository<T>()` before `init()`, causes runtime errors |
| N | **`Map<Type, ConflictResolver>`** | No type constraint — a `ConflictResolver<Product>` can be registered under the `Sale` key |
| O | **Raw SQL in internal code** | `_markProcessing` uses hardcoded table names — fragile under schema changes |
| P | **Silent skips** | `_handleAccepted` and `_applyOperation` silently skip on missing `fromJson` — data loss |
| Q | **Mutable models** | Queue entries have non-final fields — can be mutated after creation |
| R | **`Absent` sentinel** | Non-standard pattern; confusing for new contributors |
| S | **`dart:io` in core** | Prevents web compatibility unnecessarily |
| T | **Engine getter throws** | Synchronous getter does async work (in spirit) — anti-pattern in Dart |
| U | **Progress goes backwards** | Re-queued entries cause `processed > total` — confusing for UI |

---

## What `loxia_sync` Did Well

To be fair, these patterns should be preserved:

- Clean separation of concerns (pusher / puller / engine / config / conflict)
- Well-defined remote adapter interface with request/response models
- Atomic transactions for local writes (entity + queue)
- Queue ordering via `localSequence` (not timestamps)
- Sealed `SyncState` hierarchy with pattern-matchable states
- Broadcast state stream for UI listeners
- No Flutter dependency in core package
- Comprehensive test suite with in-memory data source
- Version-based optimistic concurrency
- Soft-delete instead of hard-delete for all synced entities

---

## Summary: Concrete Design Decisions for `universal_sync`

| Concern | `loxia_sync` | `universal_sync` |
|---|---|---|
| **Local storage** | Hardcoded to Loxia ORM | `LocalAdapter` interface — any storage |
| **Models** | Annotated Loxia entities + code gen | Pure Dart immutable classes, no code gen |
| **Serialization** | `toSyncJson()` without `fromJson` | Both `toSyncJson()` and `fromJson` required |
| **Init** | Two-phase (`repository()` then `init()`) | Single-phase, validate at construction |
| **Mutations** | Mutable fields on queue/checkpoint | All models immutable, `copyWith` for changes |
| **Error handling** | `print()` + generic throws | Logger + typed `SyncException` hierarchy |
| **Retry** | Immediate, fixed count | Configurable delay + exponential backoff |
| **Cancellation** | Not possible | `cancel()` method with cooperative checks |
| **Queue cleanup** | Never prunes | Pruning API or auto-cleanup of old synced entries |
| **Event hooks** | None | Optional lifecycle callbacks (`onSyncStart`, etc.) |
| **Progress** | Resets between phases | Cumulative across full sync cycle |
| **Batch size** | Global only | Per-type overrides supported |
| **Raw SQL** | Used in internal code | Never; always through `LocalAdapter` |
| **Silent failures** | Skip on missing `fromJson` | Fail fast with clear error messages |
| **Remote adapter** | Receives internal queue entities | Receives dedicated push models (decoupled) |
| **Platform coupling** | `dart:io` in `destroy()` | Pure Dart; platform concerns isolated to adapter impls |
| **Stream start** | Never emits initial state | Replays or emits initial `SyncIdle` on subscribe |
| **Dependencies** | `loxia`, `uuid`, `build_runner` | **Zero runtime dependencies** |

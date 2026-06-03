# universal_sync — Task Breakdown

> Actionable tasks for the full development cycle.
> Each task includes the files to create/modify and the tests that must pass.
> Order: strict within a phase, parallel where indicated.

---

## Phase 0 — Project Setup

**Depends on:** Nothing
**Goal:** Clean scaffold, deps, directory structure, tooling.

- [ ] **0.1** Remove placeholder files (`lib/src/universal_sync_base.dart`, `test/universal_sync_test.dart`)
- [ ] **0.2** Update `pubspec.yaml`: name, description, version, zero runtime deps, dev deps (`lints`, `test`, `mocktail`)
- [ ] **0.3** Update `analysis_options.yaml`: `recommended` lints, page width 120
- [ ] **0.4** Create directory structure:
  ```
  lib/src/model/
  lib/src/adapter/local/
  lib/src/engine/
  lib/src/conflict/
  lib/src/config/
  lib/src/internal/
  test/model/
  test/adapter/
  test/engine/
  test/conflict/
  test/config/
  test/internal/
  test/integration/
  ```
- [ ] **0.5** Write `AGENTS.md` with project overview, commands, conventions
- [ ] **0.6** Update barrel export (`lib/universal_sync.dart`) — clean placeholder, export nothing yet
- [ ] **0.7** Verify: `dart pub get` → success, `dart analyze` → clean

---

## Phase 1 — Models

**Depends on:** Phase 0
**Goal:** All data types the engine works with. Immutable, pure Dart, zero deps.

### Task 1.1 — SyncQueueEntry

- [ ] **1.1.1** Create `lib/src/model/sync_queue_entry.dart`
  - `SyncOperation` enum: `insert`, `update`, `delete`
  - `SyncEntryStatus` enum: `pending`, `processing`, `synced`, `failed`
  - `SyncQueueEntry` class: all fields `final`, `const` constructor, `copyWith` method
- [ ] **1.1.2** Create `test/model/sync_queue_entry_test.dart`
  - Constructor assigns all fields correctly
  - `copyWith` preserves unset fields, overrides set fields
  - `copyWith` with explicit `null` clears nullable fields
  - All enum values are present

### Task 1.2 — SyncCheckpoint

- [ ] **1.2.1** Create `lib/src/model/sync_checkpoint.dart`
  - `SyncCheckpoint` class: all fields `final`, `const` constructor, `copyWith` method
- [ ] **1.2.2** Create `test/model/sync_checkpoint_test.dart`
  - Constructor assigns fields
  - `copyWith` works correctly (including clearing `lastSyncedAt` with null)

### Task 1.3 — SyncEntity

- [ ] **1.3.1** Create `lib/src/model/sync_entity.dart`
  - Abstract class with getters: `id`, `version`, `createdAt`, `updatedAt`, `deletedAt`
  - Computed getters: `isDeleted`, `isNew`
  - Abstract method: `toSyncJson()`
  - No `fromJson` — lives in user-provided map
- [ ] **1.3.2** Create `test/model/sync_entity_test.dart`
  - Create a test subclass of `SyncEntity`
  - `isDeleted` returns `true` when `deletedAt` is non-null
  - `isNew` returns `true` when `version == 0`
  - `isNew` returns `false` when `version > 0`
  - `toSyncJson()` is implemented by subclass

### Task 1.4 — SyncState

- [ ] **1.4.1** Create `lib/src/model/sync_state.dart`
  - `SyncState` sealed class
  - `SyncIdle`: `lastSyncedAt`, `pendingCount`
  - `SyncInProgress`: `phase` (SyncPhase), `processed`, `total`, `progress` getter
  - `SyncError`: `error`, `stackTrace`, `pendingCount`
  - `SyncPhase` enum: `pushing`, `pulling`
- [ ] **1.4.2** Create `test/model/sync_state_test.dart`
  - `SyncIdle` stores fields correctly
  - `SyncInProgress` stores fields, `progress` returns correct ratio
  - `SyncInProgress.progress` returns `0.0` when `total == 0`
  - `SyncError` stores fields correctly

### Task 1.5 — SyncResult

- [ ] **1.5.1** Create `lib/src/model/sync_result.dart`
  - Fields: `pushed`, `pulled`, `failed`, `conflicted`, `duration`
  - Computed getters: `hasErrors`, `hasConflicts`, `isClean`
- [ ] **1.5.2** Create `test/model/sync_result_test.dart`
  - `hasErrors` is `true` when `failed > 0`
  - `hasConflicts` is `true` when `conflicted > 0`
  - `isClean` is `true` when no errors and no conflicts

### Task 1.6 — Barrel export

- [ ] **1.6.1** Update `lib/universal_sync.dart`:
  - Export `SyncEntity`
  - Export `SyncOperation`, `SyncEntryStatus`
  - Export `SyncCheckpoint`
  - Export `SyncQueueEntry` (needed by `LocalAdapter` implementations)
  - Export `SyncState`, `SyncIdle`, `SyncInProgress`, `SyncError`, `SyncPhase`
  - Export `SyncResult`

---

## Phase 2 — Adapter Interfaces + InMemoryLocalAdapter

**Depends on:** Phase 1
**Goal:** Define both adapter contracts. Ship built-in in-memory `LocalAdapter`.

### Task 2.1 — LocalAdapter interface

- [ ] **2.1.1** Create `lib/src/adapter/local_adapter.dart`
  - `LocalAdapter` abstract class with 9 methods:
    - `transaction<T>(Future<T> Function())`
    - `enqueue(SyncQueueEntry)`
    - `updateQueueEntryStatus(String, SyncEntryStatus, {int? retryCount, String? errorMessage})`
    - `fetchPendingEntries(String entityType, int limit) → List<SyncQueueEntry>`
    - `nextSequence() → int`
    - `readCheckpoint(String entityType) → SyncCheckpoint?`
    - `writeCheckpoint(SyncCheckpoint)`
    - `upsertEntity(String entityType, Map<String, dynamic>)`
    - `softDeleteEntity(String entityType, String entityId)`
- [ ] **2.1.2** Create `test/adapter/local_adapter_test.dart`
  - Compile-time test: create a concrete implementation
  - Verify all 9 methods are present

### Task 2.2 — RemoteAdapter interface + models

- [ ] **2.2.1** Create `lib/src/adapter/remote_adapter.dart`
  - `RemoteAdapter` interface: `push(PushRequest)` → `PushResponse`, `pull(PullRequest)` → `PullResponse`
  - `PushEntry` model: `id`, `entityType`, `entityId`, `operation`, `payload`, `localSequence`
  - `PushRequest`: wraps `List<PushEntry>`, `toJson()`
  - `PushResponse`: wraps `List<SyncEntryResult>`, `factory fromJson()`
  - `SyncEntryResult`: named constructors `.accepted()`, `.conflicted()`, `.rejected()`, `fromJson()`
  - `SyncOutcome` enum: `accepted`, `conflicted`, `rejected`
  - `PullRequest`: `entityType`, `sinceSequence`
  - `PullResponse`: `List<RemoteOperation>`, `latestSequence`, `fromJson()`
  - `RemoteOperation`: `entityType`, `entityId`, `operation`, `payload`, `serverSequence`, `fromJson()`
- [ ] **2.2.2** Create `test/adapter/remote_adapter_test.dart`
  - `PushEntry` constructor and `toJson()` produces correct map
  - `PushRequest.toJson()` produces correct structure
  - `SyncEntryResult.accepted()` sets `outcome == SyncOutcome.accepted` and `serverSequence`
  - `SyncEntryResult.conflicted()` sets `outcome == SyncOutcome.conflicted` and `serverPayload`
  - `SyncEntryResult.rejected()` sets `outcome == SyncOutcome.rejected` and `errorMessage`
  - `SyncEntryResult.fromJson()` parses all three outcomes
  - `SyncEntryResult.fromJson()` throws `ArgumentError` on unknown outcome
  - `PushResponse.fromJson()` parses correctly
  - `PullRequest` stores fields
  - `RemoteOperation.fromJson()` parses correctly
  - `PullResponse.fromJson()` parses correctly

### Task 2.3 — InMemoryLocalAdapter

- [ ] **2.3.1** Create `lib/src/adapter/local/in_memory_local_adapter.dart`
  - Implement all 9 methods
  - Entity storage: `Map<String, Map<String, Map<String, dynamic>>>`
  - Queue storage: `List<SyncQueueEntry>`
  - Checkpoint storage: `Map<String, SyncCheckpoint>`
  - Sequence: internal `int` counter, initialized to 0
  - `transaction()`: immediate execution (no-op wrapping since in-memory is inherently atomic)
  - `reset()`: clear all internal state (for tests)
- [ ] **2.3.2** Create `test/adapter/in_memory_local_adapter_test.dart`
  - `nextSequence()` starts at 0, increments each call
  - `enqueue` + `fetchPendingEntries` returns entries in sequence order
  - `fetchPendingEntries` filters by entity type and status
  - `fetchPendingEntries` respects the `limit` parameter
  - `updateQueueEntryStatus` updates status, retryCount, and errorMessage
  - `readCheckpoint` returns null when no checkpoint exists
  - `writeCheckpoint` stores and `readCheckpoint` retrieves
  - `writeCheckpoint` overwrites existing
  - `upsertEntity` creates new entity
  - `upsertEntity` overwrites existing with same ID
  - `softDeleteEntity` sets `deletedAt` field
  - `findEntityById` returns stored entity
  - `findAllEntities` returns entities (with/without deleted filter)... wait, `findAllEntities` isn't in the contract. Let me re-check...

Actually, the LocalAdapter doesn't have `findEntityById` or `findAllEntities`. Those are the user's responsibility through their own ORM. The adapter only has `upsertEntity` and `softDeleteEntity` for writes during pull/conflict resolution.

Let me fix the test spec:

  - `upsertEntity` creates new entity (stored internally for later operations)
  - `upsertEntity` overwrites existing with same entity ID
  - `softDeleteEntity` does nothing if entity doesn't exist (no-op)
  - `softDeleteEntity` marks existing entity with `deletedAt`
  - `transaction` executes callback and returns result
  - `transaction` does NOT rollback on exception (in-memory is intrinsically atomic)
  - `reset()` clears all state

### Task 2.4 — Barrel export update

- [ ] **2.4.1** Update `lib/universal_sync.dart`:
  - Export `LocalAdapter`
  - Export `RemoteAdapter`, `PushRequest`, `PushResponse`, `PushEntry`, `SyncEntryResult`, `SyncOutcome`
  - Export `PullRequest`, `PullResponse`, `RemoteOperation`
  - Export `InMemoryLocalAdapter`

---

## Phase 3 — Internal Utilities

**Depends on:** Nothing (can be done in parallel with Phase 2)
**Goal:** Shared helpers.

### Task 3.1 — type_utils

- [ ] **3.1.1** Create `lib/src/internal/type_utils.dart`
  - `String entityTypeName(Type type)` function
- [ ] **3.1.2** Create `test/internal/type_utils_test.dart`
  - Returns simple class name for non-generic type (`Product` → `'Product'`)
  - Strips generic parameters (`List<Product>` → `'List'`)
  - Strips library prefix (`some_library.Product` → `'Product'`)
  - Throws `ArgumentError` on empty name (edge case)

---

## Phase 4 — Conflict Resolution

**Depends on:** Phase 1 (SyncEntity, SyncQueueEntry)
**Goal:** Interface + two built-in resolvers.

### Task 4.1 — ConflictResolver interface

- [ ] **4.1.1** Create `lib/src/conflict/conflict_resolver.dart`
  - `ConflictResolver<T extends SyncEntity>` interface with `resolve(ConflictContext<T>)`
  - `ConflictContext<T>`: `local`, `remote`, `operation`
  - `ConflictResolution<T>`: named constructors `.acceptRemote()`, `.acceptLocal()`, `.merge()`
  - `ConflictStrategy` enum: `acceptRemote`, `acceptLocal`, `merge`

### Task 4.2 — ServerWinsResolver

- [ ] **4.2.1** Create `lib/src/conflict/server_wins_resolver.dart`
  - `ServerWinsResolver<T>` implementing `ConflictResolver<T>`
  - `resolve()` always returns `ConflictResolution.acceptRemote(context.remote)`

### Task 4.3 — ClientWinsResolver

- [ ] **4.3.1** Create `lib/src/conflict/client_wins_resolver.dart`
  - `ClientWinsResolver<T>` implementing `ConflictResolver<T>`
  - `resolve()` always returns `ConflictResolution.acceptLocal(context.local)`

### Task 4.4 — Tests

- [ ] **4.4.1** Create `test/conflict/conflict_resolver_test.dart`
  - `ConflictContext` stores `local`, `remote`, `operation`
  - `ConflictResolution.acceptRemote` has strategy `acceptRemote` and entity is remote
  - `ConflictResolution.acceptLocal` has strategy `acceptLocal` and entity is local
  - `ConflictResolution.merge` has strategy `merge` and entity is merged
  - `ServerWinsResolver` returns `acceptRemote` with remote entity
  - `ClientWinsResolver` returns `acceptLocal` with local entity

### Task 4.5 — Barrel export

- [ ] **4.5.1** Update `lib/universal_sync.dart`:
  - Export `ConflictResolver`, `ConflictContext`, `ConflictResolution`, `ConflictStrategy`
  - Export `ServerWinsResolver`, `ClientWinsResolver`

---

## Phase 5 — SyncPusher

**Depends on:** Phase 2 (adapters), Phase 4 (conflict), Phase 3 (type_utils)
**Goal:** Push pending queue entries to the remote server.

### Task 5.1 — Internal PushResult model

- [ ] **5.1.1** Add `PushResult` class to `lib/src/engine/sync_pusher.dart`
  - Fields: `pushed`, `failed`, `conflicted` (all `int`)

### Task 5.2 — SyncPusher implementation

- [ ] **5.2.1** Create `lib/src/engine/sync_pusher.dart`
  - Constructor takes: `LocalAdapter`, `RemoteAdapter`, `SyncConfig`, `Map<Type, ConflictResolver<SyncEntity>>?`, `Map<String, SyncEntity Function(Map<String, dynamic>)>`
  - `Future<PushResult> run({void Function(int, int)? onProgress, Future<bool> Function()? isCancelled})`:
    1. Iterate entity types in `config.entityOrder`
    2. Fetch pending batch via `localAdapter.fetchPendingEntries(type, batchSize)`
    3. Call `localAdapter.updateQueueEntryStatus(entries, processing)`
    4. Call `remoteAdapter.push(PushRequest(converted entries))`
    5. Handle outcomes:
       - **accepted**: deserialize payload → increment version → `localAdapter.upsertEntity()` → `localAdapter.updateQueueEntryStatus(entryId, synced)`
       - **conflicted**: deserialize both → resolve → `localAdapter.upsertEntity()` or re-enqueue → `localAdapter.updateQueueEntryStatus()`
       - **rejected**: `localAdapter.updateQueueEntryStatus(entryId, pending/failed, retryCount++, errorMessage)`
    6. On adapter exception: reset all processing entries to pending, rethrow
    7. Respect cancellation between batches

### Task 5.3 — Tests

- [ ] **5.3.1** Create `test/engine/sync_pusher_test.dart`
  - Uses `InMemoryLocalAdapter` + `MockRemoteAdapter` (mocktail)
  - Empty queue → no adapter push call
  - Single accepted entry → version updated, entry synced
  - Multiple accepted entries → all processed
  - Conflicted + ServerWins → entity overwritten with remote, entry synced
  - Conflicted + ClientWins → entry re-queued, retryCount incremented
  - Conflicted + ClientWins + max retries → entry marked failed
  - Conflicted + merge → merged entity saved, new entry enqueued
  - Rejected + retries remaining → entry reset to pending
  - Rejected + max retries → entry marked failed
  - Adapter throws → entries reset to pending
  - Progress callback invoked
  - Cancellation stops after current batch

---

## Phase 6 — SyncPuller

**Depends on:** Phase 2 (adapters), Phase 3 (type_utils)
**Goal:** Pull remote changes and apply them locally.

### Task 6.1 — Internal PullResult model

- [ ] **6.1.1** Add `PullResult` class to `lib/src/engine/sync_puller.dart`
  - Fields: `pulled` (`int`)

### Task 6.2 — SyncPuller implementation

- [ ] **6.2.1** Create `lib/src/engine/sync_puller.dart`
  - Constructor takes: `LocalAdapter`, `RemoteAdapter`, `SyncConfig`, `Map<String, SyncEntity Function(Map<String, dynamic>)>`
  - `Future<PullResult> run({void Function(int, int)? onProgress, Future<bool> Function()? isCancelled})`:
    1. For each entity type in `entityOrder`:
       - Read checkpoint → if null, `lastServerSequence = 0`
       - `remoteAdapter.pull(PullRequest(entityType, sinceSequence))`
       - If no operations: update checkpoint with `latestSequence` if newer
       - If operations exist: `localAdapter.transaction()`:
         - Sort by `serverSequence`
         - For each: insert/update → `localAdapter.upsertEntity()`; delete → `localAdapter.softDeleteEntity()`
         - `localAdapter.writeCheckpoint(newCheckpoint)`
    2. Respect cancellation between entity types

### Task 6.3 — Tests

- [ ] **6.3.1** Create `test/engine/sync_puller_test.dart`
  - Uses `InMemoryLocalAdapter` + `MockRemoteAdapter`
  - Empty pull → checkpoint updated
  - Remote insert → entity created
  - Remote update → entity overwritten
  - Remote delete → entity soft-deleted
  - Multiple entity types → each processed in order
  - Initial pull (since=0) → full fetch
  - Incremental pull → uses stored checkpoint
  - No re-enqueuing → upsertEntity called, NOT enqueue
  - Progress callback invoked
  - Cancellation stops after current type

---

## Phase 7 — SyncEngine

**Depends on:** Phase 5 (pusher), Phase 6 (puller)
**Goal:** Orchestrate pusher + puller, manage state stream, cancellation.

### Task 7.1 — SyncEngine implementation

- [ ] **7.1.1** Create `lib/src/engine/sync_engine.dart`
  - Constructor: `LocalAdapter`, `RemoteAdapter`, `SyncConfig`, `fromJson` map, `resolvers` map, optional event hooks
  - Lazy-creates `SyncPusher` and `SyncPuller`
  - `Stream<SyncState> get state` — broadcast, emits initial `SyncIdle` on listen
  - `SyncState get currentState` — synchronous snapshot
  - `Future<SyncResult> sync()` — push then pull
  - `Future<SyncResult> push()` — push only
  - `Future<SyncResult> pull()` — pull only
  - `void cancel()` — sets cancellation flag
  - `void dispose()` — closes stream
  - Concurrent guard: throws `StateError` if sync is already running
  - Error handling: catches exceptions → emits `SyncError` → rethrows
  - Event hooks: `onSyncStart`, `onSyncComplete`, `onError`, `onConflict`

### Task 7.2 — Tests

- [ ] **7.2.1** Create `test/engine/sync_engine_test.dart`
  - Uses `InMemoryLocalAdapter` + `MockRemoteAdapter`
  - Initial state is `SyncIdle`
  - `sync()` runs push then pull, returns combined `SyncResult`
  - `push()` runs push only
  - `pull()` runs pull only
  - Concurrent call throws `StateError`
  - Error in push emits `SyncError`
  - Error in pull emits `SyncError`
  - State stream: idle → pushing → pulling → idle
  - `cancel()` stops sync and returns partial result
  - Event hooks fire at correct times
  - Disposed engine throws `StateError` on `sync()`

---

## Phase 8 — UniversalSync Facade

**Depends on:** Phase 7 (engine)
**Goal:** Single entry point for users.

### Task 8.1 — UniversalSync

- [ ] **8.1.1** Create `lib/src/universal_sync.dart`
  - Constructor: `LocalAdapter`, `RemoteAdapter`, `SyncConfig`, `Map<Type, SyncEntity Function(Map<String, dynamic>)> entityFromJson`
  - `Future<void> init()`: validates all types in `config.entityOrder` have `fromJson` factories; initialises `LocalSequence`; marks ready
  - `SyncEngine get engine`: lazy-built on first access
  - `Future<void> dispose()`: disposes engine, resets state
- [ ] **8.1.2** Update `lib/universal_sync.dart` barrel:
  - Export `UniversalSync`
  - Export `SyncConfig`

### Task 8.2 — Tests

- [ ] **8.2.1** Create `test/universal_sync_test.dart`
  - Constructor stores adapter and config references
  - `init()` succeeds with complete `fromJson` map
  - `init()` throws `ArgumentError` with missing `fromJson` entry
  - `engine` getter is lazy (same instance returned)
  - `dispose()` shuts down engine
  - Full lifecycle: init → engine.sync() → dispose

### Task 8.3 — SyncConfig

- [ ] **8.3.1** Create `lib/src/config/sync_config.dart`
  - `entityOrder: List<Type>` (required)
  - `batchSize: int` (default 50)
  - `maxRetries: int` (default 3)
  - `retryDelay: Duration` (default 5 seconds)
  - `resolvers: Map<Type, ConflictResolver>?` (optional)
  - Constructor asserts: `entityOrder` not empty, `batchSize > 0`, `maxRetries >= 0`, `retryDelay > Duration.zero`, resolver keys in entityOrder
- [ ] **8.3.2** Create `test/config/sync_config_test.dart`
  - Default values applied
  - Assertions fire on invalid input
  - Resolver keys validated against entityOrder

---

## Integration Tests

**Depends on:** All phases
**Goal:** End-to-end verification of the full sync cycle.

### Task 9.1 — Full sync cycle

- [ ] **9.1.1** Create `test/integration/full_sync_cycle_test.dart`
  - Full sync cycle: create entity → push → pull → verify
  - Multi-entity cycle respecting `entityOrder`
  - Conflict resolution in full cycle (server returns conflicted)
  - Error recovery (adapter throws, retry succeeds)
  - Concurrent write during sync

---

## Task Completion Summary

| Phase | Tasks | Test files | Status |
|---|---|---|---|
| 0 — Setup | 7 | — | ◻ |
| 1 — Models | 6 | 5 | ◻ |
| 2 — Adapters | 4 | 3 | ◻ |
| 3 — Internal | 1 | 1 | ◻ |
| 4 — Conflict | 5 | 1 | ◻ |
| 5 — Pusher | 3 | 1 | ◻ |
| 6 — Puller | 3 | 1 | ◻ |
| 7 — Engine | 2 | 1 | ◻ |
| 8 — Facade | 3 | 2 | ◻ |
| 9 — Integration | 1 | 1 | ◻ |
| **Total** | **35** | **16** | |

---

## Development Notes

### Running tests for a specific phase

```bash
# Phase 1 — all model tests
dart test test/model/

# Phase 2 — all adapter tests
dart test test/adapter/

# Single file
dart test test/engine/sync_pusher_test.dart
```

### Before committing

1. `dart analyze` — must be clean
2. `dart test` — all tests must pass
3. `dart format .` — code must be formatted

### Mocking conventions

- Use `mocktail` for `RemoteAdapter` mocks
- Use `InMemoryLocalAdapter` as the concrete `LocalAdapter` in all tests
- Never mock `LocalAdapter` in engine tests — always use `InMemoryLocalAdapter`

---

## Pending

- [ ] **Server `handlePull` deduplication**: Collapse sync log entries to latest-per-entity before returning, so a device pulling with `sinceSequence=0` gets only the final state of each entity, not the full change history. See `example/servers/nestjs/src/sync/sync.service.ts:handlePull`.

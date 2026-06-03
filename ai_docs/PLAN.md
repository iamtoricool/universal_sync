# universal_sync — Development Plan

> ORM-agnostic offline-first sync engine for Dart & Flutter.
> Built from scratch, inspired by `loxia_sync`, but with a **two-adapter architecture**
> that decouples ALL storage dependencies.

---

## Architecture — The Key Difference from `loxia_sync`

`loxia_sync` is **monolithic**: it depends on Loxia ORM directly. `SyncEntity` extends Loxia's
`Entity`, all internal models (queue, checkpoints) are Loxia entities, and storage is hardcoded.

`universal_sync` introduces a **two-adapter architecture** that separates ALL storage concerns:

```
┌─────────────────────────────────────────────────┐
│                  universal_sync                   │
│                                                   │
│   ┌──────────────┐     ┌──────────────────────┐   │
│   │ LocalAdapter  │     │   RemoteAdapter      │   │
│   │  (abstract)   │     │     (abstract)       │   │
│   └──────┬────────┘     └──────────┬───────────┘   │
│          │                        │               │
│   ┌──────┴────────┐     ┌──────────┴───────────┐   │
│   │  Any storage   │     │    Any backend API    │   │
│   │ (Drift/Hive/   │     │  (REST/GraphQL/gRPC) │   │
│   │  Loxia/SQLite) │     │                       │   │
│   └───────────────┘     └───────────────────────┘   │
│                                                   │
│   ┌───────────────────────────────────────────┐   │
│   │              SyncEngine                    │   │
│   │  Orchestrates push/pull via adapters       │   │
│   └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### What `LocalAdapter` abstracts

The `LocalAdapter` interface encapsulates **all local storage operations** the engine needs:

| Operation | Purpose |
|---|---|
| `insertEntity` / `updateEntity` / `softDeleteEntity` / `find*` | User entity CRUD |
| `enqueue` / `updateQueueEntry` / `getPendingEntries` / `markAs*` | Sync queue management |
| `getCheckpoint` / `upsertCheckpoint` | Pull checkpoint tracking |
| `nextLocalSequence` | Monotonic queue ordering |
| `transaction(callback)` | Atomic write support |

Users implement this interface for their ORM of choice. The core package **ships a built-in
`InMemoryLocalAdapter`** for testing and basic use.

---

## Package Structure

```
lib/
  universal_sync.dart                        # Barrel export
  src/
    universal_sync.dart                      # UniversalSync facade
    model/
      sync_entity.dart                       # SyncEntity abstract class (pure Dart)
      sync_queue_entry.dart                  # SyncQueueEntry model + enums
      sync_checkpoint.dart                   # SyncCheckpoint model
      sync_state.dart                        # SyncState sealed hierarchy
      sync_result.dart                       # SyncResult
    adapter/
      local_adapter.dart                     # LocalAdapter interface
      remote_adapter.dart                    # RemoteAdapter interface + models
      local/
        in_memory_local_adapter.dart         # Built-in in-memory implementation
    engine/
      sync_engine.dart                       # SyncEngine orchestrator
      sync_pusher.dart                       # SyncPusher (internal)
      sync_puller.dart                       # SyncPuller (internal)
    conflict/
      conflict_resolver.dart                 # ConflictResolver interface, context, resolution
      server_wins_resolver.dart
      client_wins_resolver.dart
    config/
      sync_config.dart                       # SyncConfig
    internal/
      local_sequence.dart                    # LocalSequence
      type_utils.dart                        # entityTypeName()

test/
  model/
    sync_entity_test.dart
    sync_queue_entry_test.dart
    sync_checkpoint_test.dart
    sync_state_test.dart
    sync_result_test.dart
  adapter/
    local_adapter_test.dart
    remote_adapter_test.dart
    in_memory_local_adapter_test.dart
  engine/
    sync_engine_test.dart
    sync_pusher_test.dart
    sync_puller_test.dart
  conflict/
    conflict_resolver_test.dart
    server_wins_resolver_test.dart
    client_wins_resolver_test.dart
  config/
    sync_config_test.dart
  internal/
    local_sequence_test.dart
    type_utils_test.dart
  integration/
    full_sync_cycle_test.dart
```

---

## Phase-by-Phase Implementation

### Phase 0 — Project Setup

- Clean existing scaffold (remove `Awesome` class, placeholder files)
- Set up `pubspec.yaml` with **zero runtime dependencies**
- Set up `analysis_options.yaml` with recommended lints, page width 120
- Create the full directory structure for `lib/` and `test/`
- Write `AGENTS.md` with project overview, build commands, conventions

### Phase 1 — Models (Pure Dart, Zero Dependencies)

**Files to create:**
- `lib/src/model/sync_entity.dart` — abstract `SyncEntity` class
- `lib/src/model/sync_queue_entry.dart` — `SyncQueueEntry` + enums (`SyncOperation`, `SyncEntryStatus`)
- `lib/src/model/sync_checkpoint.dart` — `SyncCheckpoint`
- `lib/src/model/sync_state.dart` — sealed `SyncState` hierarchy (`SyncIdle`, `SyncInProgress`, `SyncError`) + `SyncPhase`
- `lib/src/model/sync_result.dart` — `SyncResult`

**SyncEntity:**
```dart
abstract class SyncEntity {
  String get id;
  int get version;
  DateTime get createdAt;
  DateTime get updatedAt;
  DateTime? get deletedAt;
  bool get isDeleted => deletedAt != null;
  bool get isNew => version == 0;
  Map<String, dynamic> toSyncJson();
}
```

Pure Dart, no extends, no ORM imports. Users implement this in their domain entities
alongside their ORM's entity system.

**SyncQueueEntry:**
- Immutable model with `copyWith`
- Fields: id, entityType, entityId, operation (SyncOperation), payload (JSON string), version,
  localSequence, status (SyncEntryStatus), createdAt, syncedAt, retryCount,
  conflictPayload, errorMessage

**SyncCheckpoint:**
- Immutable model with `copyWith`
- Fields: id, entityType, lastServerSequence, lastSyncedAt

**Test files:**
- `test/model/sync_entity_test.dart`
- `test/model/sync_queue_entry_test.dart`
- `test/model/sync_checkpoint_test.dart`
- `test/model/sync_state_test.dart`
- `test/model/sync_result_test.dart`

### Phase 2 — Adapter Interfaces

**Files to create:**
- `lib/src/adapter/local_adapter.dart` — `LocalAdapter` interface
- `lib/src/adapter/remote_adapter.dart` — `RemoteAdapter` interface + push/pull models
- `lib/src/adapter/local/in_memory_local_adapter.dart` — `InMemoryLocalAdapter`

**LocalAdapter:**
```dart
abstract class LocalAdapter {
  // User entity storage
  Future<void> insertEntity(String entityType, Map<String, dynamic> data);
  Future<void> updateEntity(String entityType, String id, Map<String, dynamic> data);
  Future<void> softDeleteEntity(String entityType, String id);
  Future<Map<String, dynamic>?> findEntityById(String entityType, String id);
  Future<List<Map<String, dynamic>>> findAllEntities(String entityType, {bool includeDeleted = false});

  // Sync queue storage
  Future<void> enqueue(SyncQueueEntry entry);
  Future<void> updateQueueEntry(SyncQueueEntry entry);
  Future<List<SyncQueueEntry>> getPendingEntries(String entityType, int limit);
  Future<int> countPending({String? entityType});
  Future<void> markAsProcessing(List<String> entryIds);
  Future<void> markAsPending(List<String> entryIds);

  // Checkpoint storage
  Future<SyncCheckpoint?> getCheckpoint(String entityType);
  Future<void> upsertCheckpoint(SyncCheckpoint checkpoint);

  // Sequence
  Future<int> nextLocalSequence();

  // Atomicity
  Future<T> transaction<T>(Future<T> Function() callback);
}
```

**RemoteAdapter:**
```dart
abstract class RemoteAdapter {
  Future<PushResponse> push(PushRequest request);
  Future<PullResponse> pull(PullRequest request);
}
```

Request/response models (all with `toJson()` / `fromJson()`):
- `PushRequest` — list of entries
- `PushResponse` — list of `SyncEntryResult`
- `SyncEntryResult` — named constructors: `.accepted()`, `.conflicted()`, `.rejected()`
- `SyncOutcome` — enum: `accepted`, `conflicted`, `rejected`
- `PullRequest` — entityType, sinceSequence
- `PullResponse` — operations, latestSequence
- `RemoteOperation` — entityType, entityId, operation, payload, serverSequence

**InMemoryLocalAdapter:**
- Full in-memory implementation of `LocalAdapter`
- Uses `Map<String, List<Map<String, dynamic>>>` for entities,
  `List<SyncQueueEntry>` for queue, `Map<String, SyncCheckpoint>` for checkpoints
- `transaction()` uses a simple reentrant lock
- `reset()` method to wipe all state (for test isolation)

**Test files:**
- `test/adapter/local_adapter_test.dart` — interface contract
- `test/adapter/remote_adapter_test.dart` — serialization + model tests
- `test/adapter/in_memory_local_adapter_test.dart` — full implementation coverage

### Phase 3 — Internal Utilities

**Files to create:**
- `lib/src/internal/local_sequence.dart` — monotonic counter
- `lib/src/internal/type_utils.dart` — `entityTypeName()`

**LocalSequence:** Shared monotonic counter. Initialized from adapter's max sequence on first
call, then incremented in memory.

**Test files:**
- `test/internal/local_sequence_test.dart`
- `test/internal/type_utils_test.dart`

### Phase 4 — Conflict Resolution

**Files to create:**
- `lib/src/conflict/conflict_resolver.dart` — `ConflictResolver<T>` interface,
  `ConflictContext<T>`, `ConflictResolution<T>`, `ConflictStrategy`
- `lib/src/conflict/server_wins_resolver.dart`
- `lib/src/conflict/client_wins_resolver.dart`

Same design as loxia_sync:
- `ConflictResolver<T extends SyncEntity>` with `resolve(ConflictContext<T>)`
- `ConflictContext<T>` with `local`, `remote`, `operation`
- `ConflictResolution<T>` with named constructors: `.acceptRemote()`, `.acceptLocal()`, `.merge()`
- `ConflictStrategy` enum: `acceptRemote`, `acceptLocal`, `merge`
- `ServerWinsResolver` — always returns `acceptRemote` (default)
- `ClientWinsResolver` — always returns `acceptLocal`

**Test files:**
- `test/conflict/conflict_resolver_test.dart`
- `test/conflict/server_wins_resolver_test.dart`
- `test/conflict/client_wins_resolver_test.dart`

### Phase 5 — SyncPusher

**File:** `lib/src/engine/sync_pusher.dart`

**Algorithm:**
1. For each entity type in `config.entityOrder`:
2. Fetch next batch of pending entries via `localAdapter.getPendingEntries(type, batchSize)`
3. Mark them as `processing` via `localAdapter.markAsProcessing()`
4. Call `remoteAdapter.push(PushRequest(entries))`
5. For each result:
   - **accepted**: Update local entity version (increment or set to 1 for inserts),
     mark queue entry as `synced`
   - **conflicted**: Deserialize local/remote from JSON, invoke `ConflictResolver`,
     apply strategy (acceptRemote → save remote; acceptLocal → re-queue; merge →
     save merged + re-queue)
   - **rejected**: Increment retry count; if >= maxRetries → mark `failed`,
     else reset to `pending`
6. Repeat until no pending entries remain for current type
7. Emit progress via `onProgress(processed, total)`

**Key rules:**
- All entity writes (for accepted/conflicted resolutions) go through
  `LocalAdapter.transaction()` and bypass the queue (use `updateEntity` directly,
  not `enqueue`)
- Adapter exceptions reset all processing entries back to `pending` and rethrow

**PushResult:** internal model with `pushed`, `failed`, `conflicted` counts.

**Test file:** `test/engine/sync_pusher_test.dart`

Scenarios:
- Empty queue → no-op
- Single accepted entry → version updated, status synced
- Multiple accepted entries in batch
- Conflicted + ServerWinsResolver → local overwritten with remote
- Conflicted + ClientWinsResolver → local re-queued, retries
- Conflicted + merge → merged entity saved + re-enqueued
- Rejected + retries available → reset to pending
- Rejected + max retries → marked failed
- Progress callback invoked correctly
- Adapter exception → entries reset to pending
- Entity type ordering respected

### Phase 6 — SyncPuller

**File:** `lib/src/engine/sync_puller.dart`

**Algorithm:**
1. For each entity type in `config.entityOrder`:
2. Read checkpoint: `localAdapter.getCheckpoint(type)` → defaults to `{lastServerSequence: 0}`
3. Call `remoteAdapter.pull(PullRequest(entityType, sinceSequence))`
4. For each `RemoteOperation`:
   - **insert / update**: Deserialize JSON payload, upsert via `localAdapter.updateEntity()`
     (directly, never through enqueue — would cause infinite loop)
   - **delete**: Soft-delete via `localAdapter.softDeleteEntity()`
5. Update checkpoint: `localAdapter.upsertCheckpoint(updated)`

**PullResult:** internal model with `pulled` count.

**Test file:** `test/engine/sync_puller_test.dart`

Scenarios:
- Empty pull response → no changes, checkpoint updated
- Remote insert → entity created locally
- Remote update → entity updated locally
- Remote delete → entity soft-deleted locally
- Multiple entity types pulled in order
- Initial pull (sinceSequence=0) → fetches all
- Incremental pull → checkpoint preserved
- No re-enqueuing during pull (bypasses write path)
- Progress callback invoked correctly

### Phase 7 — SyncEngine

**File:** `lib/src/engine/sync_engine.dart`

- Orchestrates `SyncPusher` + `SyncPuller`
- Exposes:
  - `Stream<SyncState> get state` — broadcast stream
  - `SyncState get currentState` — synchronous snapshot
  - `Future<SyncResult> sync()` — push then pull
  - `Future<SyncResult> push()` — push only
  - `Future<SyncResult> pull()` — pull only
  - `void dispose()` — close state stream
- Guards against concurrent runs: throws `StateError` if already in progress
- State transitions: `SyncIdle → SyncInProgress(pushing) → SyncInProgress(pulling) → SyncIdle`
  (or `→ SyncError` on failure)

**Test file:** `test/engine/sync_engine_test.dart`

Scenarios:
- Initial state is SyncIdle
- sync() runs push then pull, returns combined SyncResult
- push() runs only push phase
- pull() runs only pull phase
- Concurrent sync() throws StateError
- Error during push emits SyncError and rethrows
- Error during pull emits SyncError and rethrows
- State stream emits correct sequence (idle → pushing → pulling → idle)
- Disposed engine throws on sync() call
- Disposal closes state stream
- State stream is broadcast (multiple listeners)

### Phase 8 — UniversalSync Facade

**File:** `lib/src/universal_sync.dart`

```dart
class UniversalSync {
  UniversalSync({
    required LocalAdapter localAdapter,
    required RemoteAdapter remoteAdapter,
    required SyncConfig config,
    required Map<String, SyncEntity Function(Map<String, dynamic>)> entityFromJson,
  });

  Future<void> init();
  SyncEngine get engine;
  Future<void> dispose();
  Future<void> destroy({String? databasePath});
}
```

**init() validation:**
- Every type in `config.entityOrder` must have a corresponding `fromJson` factory in
  `entityFromJson` map

**Test file:** `test/universal_sync_test.dart`

Scenarios:
- Constructor stores adapters and config
- init() validates entityFromJson keys match entityOrder
- init() throws assertion error on missing fromJson factories
- engine getter is lazy (same instance on repeated calls)
- dispose() shuts down engine
- destroy() disposes engine + resets state

### Integration Tests

**File:** `test/integration/full_sync_cycle_test.dart`

- End-to-end: write entity → push → pull → verify
- Multi-entity sync cycle with ordering
- Conflict resolution in full cycle
- Error recovery in full cycle
- Concurrent write + sync cycle

---

## Key Improvements Over `loxia_sync`

| Aspect | `loxia_sync` | `universal_sync` |
|---|---|---|
| ORM coupling | Tight (Loxia-only) | None (adapter-based) |
| Storage backend | Loxia only | Any (Drift, Hive, SQLite, etc.) |
| Transaction model | Loxia-specific | Abstract `LocalAdapter.transaction()` |
| Entity base class | `SyncEntity extends Entity` (Loxia) | `SyncEntity` pure abstract class |
| Built-in mock storage | None | `InMemoryLocalAdapter` |
| Queue/checkpoint models | Loxia entities (code-gen required) | Pure Dart models (no code-gen) |
| Dependencies | `loxia`, `uuid`, `build_runner` | Zero runtime deps |
| Testability | Requires `MockSyncAdapter` | Built-in mocks + in-memory adapter |

---

## Pubspec Dependencies

```yaml
name: universal_sync
description: ORM-agnostic offline-first sync engine for Dart & Flutter.
version: 0.0.1+1-alpha

environment:
  sdk: ^3.12.1

dependencies:
  # Zero runtime dependencies — pure Dart
  # Users bring their own ORM/storage

dev_dependencies:
  lints: ^6.0.0
  test: ^1.25.6
  mocktail: ^1.0.0
```

No `build_runner`, no `uuid`, no `loxia`. The core is completely dependency-free.

---

## Commands

```bash
dart pub get              # install deps
dart analyze              # static analysis
dart test                 # run all tests
dart test test/<file>     # run single test file
dart format .             # format code
```

---

## Design Decisions Still Open

1. **SyncEntity: abstract class or mixin?** An abstract class enforces required fields at
   compile time, but a mixin is more flexible when users need to extend their ORM's base
   entity class.

2. **Queue deduplication:** Should sequential updates on the same entity be coalesced
   (like loxia_sync does)?

3. **Retry strategy:** Simple max-retry-count vs exponential backoff
   (`retryDelay * 2^retryCount`)?

4. **Initial sync:** Should `sinceSequence=0` support a "wipe and replace" mode vs
   "merge only" mode?

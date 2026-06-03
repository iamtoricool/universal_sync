# universal_sync — Implementation Plan

> ORM-agnostic offline-first sync engine for Dart & Flutter.
> Zero runtime dependencies. Pure Dart immutable models.
> Built around a simplified 8-method `LocalAdapter` interface.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     universal_sync                        │
│                                                           │
│   ┌────────────────────────┐  ┌────────────────────────┐ │
│   │      LocalAdapter       │  │      RemoteAdapter     │ │
│   │     (8 methods)         │  │    push() / pull()     │ │
│   └───────────┬────────────┘  └───────────┬────────────┘ │
│               │                           │              │
│               ▼                           ▼              │
│   ┌──────────────────────────────────────────────────┐   │
│   │                   SyncEngine                      │   │
│   │     SyncPusher (push cycle)                      │   │
│   │     SyncPuller (pull cycle)                      │   │
│   │     State management + cancellation              │   │
│   └──────────────────────────────────────────────────┘   │
│                                                           │
│   ┌──────────────────────────────────────────────────┐   │
│   │           UniversalSync (facade)                  │   │
│   │     init, engine getter, dispose, destroy         │   │
│   └──────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

### The `LocalAdapter` contract

```dart
abstract class LocalAdapter {
  /// Wrap multiple operations in an atomic transaction.
  /// If the callback throws, all changes are rolled back.
  Future<T> transaction<T>(Future<T> Function() callback);

  /// Add a new entry to the sync queue.
  /// The adapter assigns [SyncQueueEntry.localSequence] internally.
  Future<void> enqueue(SyncQueueEntry entry);

  /// Update a queue entry's status after a push attempt.
  Future<void> updateQueueEntryStatus(
    String entryId,
    SyncEntryStatus status, {
    int? retryCount,
    String? errorMessage,
  });

  /// Fetch the next batch of pending entries for an entity type,
  /// ordered by localSequence ascending.
  Future<List<SyncQueueEntry>> fetchPendingEntries(
    String entityType,
    int limit,
  );

  /// Get the next local sequence number for queue ordering.
  /// Must be monotonically increasing and persist across restarts.
  Future<int> nextSequence();

  /// Read the pull checkpoint for an entity type.
  /// Returns null if no checkpoint exists yet (initial pull).
  Future<SyncCheckpoint?> readCheckpoint(String entityType);

  /// Save or update a pull checkpoint.
  Future<void> writeCheckpoint(SyncCheckpoint checkpoint);

  /// Create or overwrite a user entity with server data (pull / conflict resolution).
  /// Never enqueues — this is a direct write that bypasses the queue.
  Future<void> upsertEntity(String entityType, Map<String, dynamic> data);

  /// Soft-delete a user entity by ID (pull / conflict resolution).
  /// Never enqueues — direct write that bypasses the queue.
  Future<void> softDeleteEntity(String entityType, String entityId);
}
```

### What the engine owns

| Concern | Owner |
|---|---|
| User entity CRUD | User's own ORM (read) / `LocalAdapter` (write from sync) |
| Sync queue storage | `LocalAdapter` |
| Pull checkpoint storage | `LocalAdapter` |
| Sequence generation | `LocalAdapter.nextSequence()` |
| Push orchestration | `SyncPusher` |
| Pull orchestration | `SyncPuller` |
| Conflict resolution | `ConflictResolver` (user-provided) |
| State management | `SyncEngine` (stream + current state) |
| Lifecycle | `UniversalSync` facade |

### What never leaves the engine

- `SyncQueueEntry` — never exposed beyond the engine's internals
- `SyncCheckpoint` — never exposed beyond the engine's internals
- `SyncPusher`, `SyncPuller` — internal engine components

---

## File Structure

```
lib/
  universal_sync.dart                          # Barrel export
  src/
    universal_sync.dart                        # UniversalSync facade
    model/
      sync_entity.dart                         # SyncEntity abstract class
      sync_queue_entry.dart                    # SyncQueueEntry + enums
      sync_checkpoint.dart                     # SyncCheckpoint
      sync_state.dart                          # SyncState sealed hierarchy
      sync_result.dart                         # SyncResult
    adapter/
      local_adapter.dart                       # LocalAdapter interface
      remote_adapter.dart                      # RemoteAdapter + request/response models
      local/
        in_memory_local_adapter.dart           # Built-in implementation
    engine/
      sync_engine.dart                         # SyncEngine orchestrator
      sync_pusher.dart                         # SyncPusher (internal)
      sync_puller.dart                         # SyncPuller (internal)
    conflict/
      conflict_resolver.dart                   # ConflictResolver interface + models
      server_wins_resolver.dart
      client_wins_resolver.dart
    config/
      sync_config.dart                         # SyncConfig
    internal/
      type_utils.dart                          # entityTypeName()

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
    sync_pusher_test.dart
    sync_puller_test.dart
    sync_engine_test.dart
  conflict/
    conflict_resolver_test.dart
  config/
    sync_config_test.dart
  internal/
    type_utils_test.dart
  integration/
    full_sync_cycle_test.dart
```

---

## Phase 0 — Project Setup

**Goal:** Clean scaffold, deps, directory structure, tooling.

**Actions:**
- Remove placeholder `Awesome` class and its test
- Set `pubspec.yaml` with `sdk: ^3.12.1`, zero runtime deps, dev deps: `lints`, `test`, `mocktail`
- Set `analysis_options.yaml`: `recommended` lints, page width 120
- Create all directories under `lib/src/` and `test/`
- Write `AGENTS.md` with commands and conventions

**Verification:** `dart pub get` succeeds, `dart analyze` passes clean.

---

## Phase 1 — Models (Pure Dart, Zero Dependencies)

**Goal:** All data types the engine works with. Immutable, no annotations, no code gen.

### 1.1 SyncQueueEntry

```dart
enum SyncOperation { insert, update, delete }

enum SyncEntryStatus { pending, processing, synced, failed }

class SyncQueueEntry {
  final String id;
  final String entityType;
  final String entityId;
  final SyncOperation operation;
  final String payload;            // JSON string from toSyncJson()
  final int version;               // entity.version at enqueue time
  final int localSequence;         // assigned by LocalAdapter.nextSequence()
  final SyncEntryStatus status;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final int retryCount;
  final String? errorMessage;      // populated on rejection/failure

  const SyncQueueEntry({...});

  SyncQueueEntry copyWith({...});
}
```

### 1.2 SyncCheckpoint

```dart
class SyncCheckpoint {
  final String id;
  final String entityType;
  final int lastServerSequence;
  final DateTime? lastSyncedAt;

  const SyncCheckpoint({...});
  SyncCheckpoint copyWith({...});
}
```

### 1.3 SyncEntity

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
  // fromJson is NOT on SyncEntity — lives in the user's fromJson map passed to UniversalSync
}
```

### 1.4 SyncState

```dart
sealed class SyncState {
  const SyncState();
}

class SyncIdle extends SyncState {
  final DateTime? lastSyncedAt;
  final int pendingCount;
  const SyncIdle({this.lastSyncedAt, this.pendingCount = 0});
}

class SyncInProgress extends SyncState {
  final SyncPhase phase;
  final int processed;
  final int total;
  const SyncInProgress({required this.phase, required this.processed, required this.total});
  double get progress => total == 0 ? 0.0 : processed / total;
}

class SyncError extends SyncState {
  final Object error;
  final StackTrace stackTrace;
  final int pendingCount;
  const SyncError({required this.error, required this.stackTrace, required this.pendingCount});
}

enum SyncPhase { pushing, pulling }
```

### 1.5 SyncResult

```dart
class SyncResult {
  final int pushed;
  final int pulled;
  final int failed;
  final int conflicted;
  final Duration duration;
  const SyncResult({...});
  bool get hasErrors => failed > 0;
  bool get hasConflicts => conflicted > 0;
  bool get isClean => !hasErrors && !hasConflicts;
}
```

### Tests needed per model

| Model | Test scenarios |
|---|---|
| `SyncQueueEntry` | Constructor, `copyWith` preserves/overrides fields, enum values |
| `SyncCheckpoint` | Constructor, `copyWith` |
| `SyncEntity` | Subclass must implement all getters, `isDeleted`, `isNew` |
| `SyncState` | Sealed class variants store correct data, `SyncInProgress.progress` |
| `SyncResult` | Constructor, `hasErrors`, `hasConflicts`, `isClean` |

---

## Phase 2 — Adapter Interfaces + InMemoryLocalAdapter

**Goal:** Define the two adapter contracts. Ship a built-in in-memory `LocalAdapter`.

### 2.1 LocalAdapter interface

9 methods (increased from 8 to include `nextSequence` for proper queue ordering):

```dart
abstract class LocalAdapter {
  Future<T> transaction<T>(Future<T> Function() callback);
  Future<void> enqueue(SyncQueueEntry entry);
  Future<void> updateQueueEntryStatus(String entryId, SyncEntryStatus status,
      {int? retryCount, String? errorMessage});
  Future<List<SyncQueueEntry>> fetchPendingEntries(String entityType, int limit);
  Future<int> nextSequence();
  Future<SyncCheckpoint?> readCheckpoint(String entityType);
  Future<void> writeCheckpoint(SyncCheckpoint checkpoint);
  Future<void> upsertEntity(String entityType, Map<String, dynamic> data);
  Future<void> softDeleteEntity(String entityType, String entityId);
}
```

### 2.2 RemoteAdapter interface

```dart
abstract class RemoteAdapter {
  Future<PushResponse> push(PushRequest request);
  Future<PullResponse> pull(PullRequest request);
}
```

### 2.3 Request/Response models (all with toJson/fromJson)

| Model | Key fields |
|---|---|
| `PushRequest` | `entries: List<PushEntry>` |
| `PushEntry` | `id, entityType, entityId, operation, payload, localSequence` |
| `PushResponse` | `results: List<SyncEntryResult>` |
| `SyncEntryResult` | Named constructors: `.accepted()`, `.conflicted()`, `.rejected()` |
| `SyncOutcome` | `enum { accepted, conflicted, rejected }` |
| `PullRequest` | `entityType, sinceSequence` |
| `PullResponse` | `operations: List<RemoteOperation>, latestSequence` |
| `RemoteOperation` | `entityType, entityId, operation, payload, serverSequence` |

### 2.4 InMemoryLocalAdapter

Stores everything in `Map`s and `List`s. Implements all 9 methods:

- `transaction()`: simple mutex (or immediate execution for in-memory)
- `enqueue()`: appends to a `List<SyncQueueEntry>`
- `updateQueueEntryStatus()`: finds by ID and updates via `copyWith`
- `fetchPendingEntries()`: filters by `entityType` + `pending`, sorts by `localSequence`, limits
- `nextSequence()`: internal counter, initialised to 0, increments on each call
- `readCheckpoint()`: looks up in `Map<String, SyncCheckpoint>`
- `writeCheckpoint()`: upserts in the map
- `upsertEntity()`: stores in `Map<String, Map<String, Map<String, dynamic>>>` keyed by `[entityType][id]`
- `softDeleteEntity()`: sets `deletedAt` in the stored map
- `reset()`: clears all state (for test isolation)

### Tests

| Test file | Coverage |
|---|---|
| `local_adapter_test.dart` | Contract test — interface compiles, methods exist |
| `remote_adapter_test.dart` | All model constructors, `toJson`, `fromJson`, error cases |
| `in_memory_local_adapter_test.dart` | Full implementation: CRUD, queue lifecycle, checkpoints, sequences, transactions, concurrency |

---

## Phase 3 — Internal Utilities

**Goal:** Shared helpers with no external dependencies.

### 3.1 type_utils.dart — `entityTypeName()`

```dart
String entityTypeName(Type type) {
  // Strips generic params, library prefixes, returns simple class name
  // e.g. Type -> 'Product', List<Product> -> 'List'
}
```

### Tests

| Test file | Coverage |
|---|---|
| `type_utils_test.dart` | Simple name, generic types, library-prefixed types, empty/minified edge case |

---

## Phase 4 — Conflict Resolution

**Goal:** Interface + two built-in resolvers.

### Files

| File | Contents |
|---|---|
| `conflict_resolver.dart` | `ConflictResolver<T>` interface, `ConflictContext<T>`, `ConflictResolution<T>`, `ConflictStrategy` |
| `server_wins_resolver.dart` | Always accepts remote |
| `client_wins_resolver.dart` | Always accepts local, re-queues |

### ConflictResolution strategies

```dart
enum ConflictStrategy { acceptRemote, acceptLocal, merge }
```

### Tests

| Test file | Coverage |
|---|---|
| `conflict_resolver_test.dart` | ServerWins returns acceptRemote, ClientWins returns acceptLocal, custom resolver with merge, ConflictContext stores data, ConflictResolution constructors |

---

## Phase 5 — SyncPusher

**Goal:** Drain the local queue to the remote server.

**File:** `lib/src/engine/sync_pusher.dart` (internal, not exported)

### Algorithm

```
for each entityType in config.entityOrder:
  while true:
    entries = localAdapter.fetchPendingEntries(type, batchSize)
    if entries.isEmpty: break
    localAdapter.updateQueueEntryStatus(entries, processing)
    try:
      response = remoteAdapter.push(PushRequest(entries))
    catch:
      localAdapter.updateQueueEntryStatus(entries, pending)
      rethrow
    for each result in response.results:
      switch result.outcome:
        accepted → update local entity version, mark entry synced
        conflicted → invoke ConflictResolver, apply strategy
        rejected → increment retry, maybe fail if max reached
    if any entries were re-queued: continue loop (they'll be re-fetched)
```

### Key rules

- Accepted entries: increment version (insert → 1, update → version+1)
- Conflicted acceptLocal: reset to pending with incremented retryCount
- Conflicted acceptLocal + maxRetries reached: mark as failed (local change never synced)
- Conflicted acceptRemote: overwrite local entity with server version, mark synced
- Conflicted merge: save merged entity locally + re-enqueue with merged payload
- Rejected: if retryCount < maxRetries → reset to pending; else → mark failed
- Adapter exception: reset ALL processing entries back to pending, rethrow
- Progress: `onProgress(processed, total)` callback
- Cancellation: check a `cancelToken` between batches

### Tests

| Scenario | Verifies |
|---|---|
| Empty queue | No adapter calls, returns zero counts |
| Single accepted entry | Version incremented, status synced |
| Multiple accepted in batch | All processed correctly |
| Conflicted + ServerWins | Remote entity persisted, entry synced |
| Conflicted + ClientWins | Entry re-queued with retry, retryCount incremented |
| Conflicted + ClientWins + max retries | Entry marked failed |
| Conflicted + merge | Merged entity persisted, new entry enqueued |
| Rejected + retries remaining | Entry reset to pending, retryCount++ |
| Rejected + max retries | Entry marked failed |
| Adapter throws | All processing entries reset to pending |
| Progress callback | Called with correct processed/total |
| Cancellation | Stops after current batch |

---

## Phase 6 — SyncPuller

**Goal:** Pull remote changes and apply them locally.

**File:** `lib/src/engine/sync_puller.dart` (internal, not exported)

### Algorithm

```
for each entityType in config.entityOrder:
  checkpoint = localAdapter.readCheckpoint(type) ?? lastServerSequence=0
  response = remoteAdapter.pull(PullRequest(type, checkpoint.lastServerSequence))
  if response.operations.isEmpty:
    if checkpoint was null or latestSequence > old sequence:
      localAdapter.writeCheckpoint(new checkpoint with latestSequence)
    continue
  localAdapter.transaction(() {
    for each op in response.operations (sorted by serverSequence):
      switch op.operation:
        insert/update → deserialize payload, localAdapter.upsertEntity(type, data)
        delete → localAdapter.softDeleteEntity(type, op.entityId)
    localAdapter.writeCheckpoint(new checkpoint with response.latestSequence)
  })
```

### Key rules

- Never enqueue pulled changes — direct writes via `upsertEntity` / `softDeleteEntity`
- Sort operations by `serverSequence` before applying
- Progress: `onProgress(processed, total)` callback
- Cancellation: check a `cancelToken` between batches

### Tests

| Scenario | Verifies |
|---|---|
| Empty pull response | Checkpoint updated with latestSequence |
| Remote insert | Entity persisted via upsertEntity |
| Remote update | Entity updated via upsertEntity |
| Remote delete | Entity soft-deleted |
| Multiple entity types | Processed in entityOrder |
| Initial pull (sinceSequence=0) | Fetches all, writes checkpoint |
| Incremental pull | Uses existing checkpoint |
| No re-enqueuing | upsertEntity called, NOT enqueue |
| Progress callback | Called with correct counts |
| Cancellation | Stops after current entity type |

---

## Phase 7 — SyncEngine

**Goal:** Orchestrate pusher + puller, manage state stream, support cancellation.

**File:** `lib/src/engine/sync_engine.dart`

### Public API

```dart
class SyncEngine {
  Stream<SyncState> get state;         // broadcast, replays initial idle
  SyncState get currentState;

  Future<SyncResult> sync();           // push → pull
  Future<SyncResult> push();           // push only
  Future<SyncResult> pull();           // pull only

  void cancel();                       // request cancellation
  void dispose();                      // close streams
}
```

### State machine

```
SyncIdle ──sync()/push()/pull()──► SyncInProgress(pushing)
                                       │
                                  (push complete)
                                       │
                                       ▼
                               SyncInProgress(pulling)
                                       │
                                  (pull complete)
                                       │
                                       ▼
                                  SyncIdle

Any phase on error ──► SyncError ──► (next sync() resets to SyncInProgress)
```

### Key features

- `cancel()` sets an internal flag; pusher/puller check it between batches
- Initial `SyncIdle` is emitted on the stream so late subscribers get it
- Concurrent call guard: throws `StateError` if already running
- Event hooks: optional `onSyncStart`, `onSyncComplete`, `onError`, `onConflict` callbacks

### Tests

| Scenario | Verifies |
|---|---|
| Initial state SyncIdle | currentState and stream |
| sync() runs push then pull | Both phases execute |
| push() runs push only | Only push phase |
| pull() runs pull only | Only pull phase |
| Concurrent call guard | Throws StateError |
| Error in push | SyncError emitted, rethrows |
| Error in pull | SyncError emitted, rethrows |
| State stream sequence | idle → pushing → pulling → idle |
| Cancellation | Returns partial SyncResult |
| Disposed engine | Throws StateError |
| Event hooks | Callbacks invoked at correct times |

---

## Phase 8 — UniversalSync Facade

**Goal:** Single entry point for users.

**File:** `lib/src/universal_sync.dart`

### Public API

```dart
class UniversalSync {
  UniversalSync({
    required LocalAdapter localAdapter,
    required RemoteAdapter remoteAdapter,
    required SyncConfig config,
    required Map<Type, SyncEntity Function(Map<String, dynamic>)> entityFromJson,
  });

  Future<void> init();             // validates config, readies internal state
  SyncEngine get engine;           // lazy-built
  Future<void> dispose();          // shut down engine
}
```

### Validation in `init()`

- Every type in `config.entityOrder` must have a `fromJson` factory in `entityFromJson`
- Throws `ArgumentError` with clear message on missing entries

### Tests

| Scenario | Verifies |
|---|---|
| Constructor stores references | Adapters/config accessible |
| init() validates all fromJson exist | Passes with complete map, throws with missing keys |
| engine getter is lazy | Same instance on repeated calls |
| dispose() shuts down engine | engine.state stream closed |
| Full lifecycle | init → engine.sync() → dispose |

---

## Pubspec

```yaml
name: universal_sync
description: ORM-agnostic offline-first sync engine for Dart & Flutter.
version: 0.0.1+1-alpha

environment:
  sdk: ^3.12.1

dependencies:
  # Zero runtime dependencies

dev_dependencies:
  lints: ^6.0.0
  test: ^1.25.6
  mocktail: ^1.0.0
```

---

## Commands

```bash
dart pub get              # install deps
dart analyze              # static analysis (recommended lints)
dart test                 # run all tests
dart test test/<path>     # run single test file
dart format .             # format code
```

---

## Dependency Graph

```
Phase 0  (setup)
  │
  ▼
Phase 1  (models) ←────── Phase 3  (type_utils)
  │                              │
  ▼                              ▼
Phase 2  (adapters) ────── Phase 4  (conflict)
  │                              │
  ▼                              │
Phase 5  (pusher) ←──────────────┘
  │
  ▼
Phase 6  (puller)
  │
  ▼
Phase 7  (engine) ←──── Phase 8  (facade)
```

Phases are sequential within a chain but parallel where branches exist.
E.g., Phases 3 and 4 can be done in parallel after Phase 1 is complete.
Phase 5 depends on Phases 2, 3, and 4.
Phase 7 depends on Phases 5 and 6.
Phase 8 depends on Phase 7.

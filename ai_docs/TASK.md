# universal_sync — Task Breakdown

> Actionable tasks for the full development cycle.
> Each task includes the files to create/modify and the tests that must pass.
> Order: strict within a phase, parallel where indicated.

---

## Phase 0 — Project Setup

**Depends on:** Nothing
**Goal:** Clean scaffold, deps, directory structure, tooling.

- [x] **0.1** Remove placeholder files (`lib/src/universal_sync_base.dart`, `test/universal_sync_test.dart`)
- [x] **0.2** Update `pubspec.yaml`: name, description, version, zero runtime deps, dev deps (`lints`, `test`, `mocktail`)
- [x] **0.3** Update `analysis_options.yaml`: `recommended` lints, page width 120
- [x] **0.4** Create directory structure
- [x] **0.5** Write `AGENTS.md` with project overview, commands, conventions
- [x] **0.6** Update barrel export (`lib/universal_sync.dart`)
- [x] **0.7** Verify: `dart pub get` → success, `dart analyze` → clean

---

## Phase 1 — Models

**Depends on:** Phase 0
**Goal:** All data types the engine works with. Immutable, pure Dart, zero deps.

### Task 1.1 — SyncQueueEntry

- [x] **1.1.1** Create `lib/src/model/sync_queue_entry.dart`
  - `SyncOperation` enum: `insert`, `update`, `delete`
  - `SyncEntryStatus` enum: `pending`, `synced`, `failed`
  - `SyncQueueEntry` class: fields `id`, `idempotencyKey`, `entityType`, `entityId`, `operation`, `payload`, `version`, `localSequence`, `createdAt` — all `final`, `const` constructor, `copyWith`
- [x] **1.1.2** Create `test/model/sync_queue_entry_test.dart`

### Task 1.2 — SyncCheckpoint

- [x] **1.2.1** Create `lib/src/model/sync_checkpoint.dart`
- [x] **1.2.2** Create `test/model/sync_checkpoint_test.dart`

### Task 1.3 — SyncEntity

- [x] **1.3.1** Create `lib/src/model/sync_entity.dart`
- [x] **1.3.2** Create `test/model/sync_entity_test.dart`

### Task 1.4 — SyncState

- [x] **1.4.1** Create `lib/src/model/sync_state.dart`
  - `SyncState` sealed class
  - `SyncIdle`: `lastSyncedAt`
  - `SyncInProgress`: `phase` (SyncPhase), `processed`, `total`, `progress` getter
  - `SyncError`: `error`, `stackTrace`
  - `SyncPhase` enum: `pushing`, `pulling`
- [x] **1.4.2** Create `test/model/sync_state_test.dart`

### Task 1.5 — SyncResult

- [x] **1.5.1** Create `lib/src/model/sync_result.dart`
- [x] **1.5.2** Create `test/model/sync_result_test.dart`

### Task 1.6 — Barrel export

- [x] **1.6.1** Update `lib/universal_sync.dart`: export all model types

---

## Phase 2 — Adapter Interfaces + InMemoryLocalAdapter

**Depends on:** Phase 1
**Goal:** Define both adapter contracts. Ship built-in in-memory `LocalAdapter`.

### Task 2.1 — LocalAdapter interface

- [x] **2.1.1** Create `lib/src/adapter/local_adapter.dart`
  - 9 methods: `transaction`, `enqueue`, `updateQueueEntryStatus(String, SyncEntryStatus)`, `fetchPendingEntries`, `nextSequence`, `readCheckpoint`, `writeCheckpoint`, `upsertEntity`, `softDeleteEntity`
- [x] **2.1.2** Create `test/adapter/local_adapter_test.dart`

### Task 2.2 — RemoteAdapter interface + models

- [x] **2.2.1** Create `lib/src/adapter/remote_adapter.dart`
  - `PushEntry`: `id`, `idempotencyKey`, `entityType`, `entityId`, `operation`, `payload`, `localSequence`
  - `PushRequest`, `PushResponse`, `SyncEntryResult`, `SyncOutcome`
  - `PullRequest`, `PullResponse`, `RemoteOperation`
- [x] **2.2.2** Create `test/adapter/remote_adapter_test.dart`

### Task 2.3 — InMemoryLocalAdapter

- [x] **2.3.1** Create `lib/src/adapter/local/in_memory_local_adapter.dart`
- [x] **2.3.2** Create `test/adapter/in_memory_local_adapter_test.dart`

### Task 2.4 — Barrel export

- [x] **2.4.1** Update `lib/universal_sync.dart`

---

## Phase 3 — Internal Utilities

**Depends on:** Nothing (parallel with Phase 2)
**Goal:** Shared helpers.

- [x] **3.1** Create `lib/src/internal/type_utils.dart` + tests

---

## Phase 4 — Conflict Resolution

**Depends on:** Phase 1
**Goal:** Interface + two built-in resolvers.

- [x] **4.1** Create `lib/src/conflict/conflict_resolver.dart` (interface + context + resolution)
- [x] **4.2** Create `lib/src/conflict/server_wins_resolver.dart`
- [x] **4.3** Create `lib/src/conflict/client_wins_resolver.dart`
- [x] **4.4** Create `test/conflict/conflict_resolver_test.dart`
- [x] **4.5** Update barrel export

---

## Phase 5 — SyncPusher

**Depends on:** Phase 2, Phase 4, Phase 3
**Goal:** Push pending queue entries to the remote server.

### Task 5.1 — Internal PushResult model

- [x] **5.1.1** Add `PushResult` class to `lib/src/engine/sync_pusher.dart`

### Task 5.2 — SyncPusher implementation

- [x] **5.2.1** Create `lib/src/engine/sync_pusher.dart`
  - Constructor: `LocalAdapter`, `RemoteAdapter`, `SyncConfig`, `entityFromJson` map, optional `resolvers`
  - `Future<PushResult> run({onProgress, isCancelled})`:
    1. Iterate entity types in `config.entityOrder`
    2. Fetch pending batch via `localAdapter.fetchPendingEntries(type, batchSize)`
    3. Call `remoteAdapter.push(PushRequest(converted entries))`
    4. Handle outcomes per entry:
       - **accepted**: deserialize payload → increment version → `upsertEntity` → `updateQueueEntryStatus(synced)`
       - **conflicted**: deserialize both → resolve → `upsertEntity` or re-enqueue → `updateQueueEntryStatus(synced)`
       - **rejected**: `updateQueueEntryStatus(failed)`
    5. On network error: entries stay pending (idempotency keys prevent duplicate apply on retry), rethrow
    6. Respect cancellation between batches

### Task 5.3 — Tests

- [x] **5.3.1** Create `test/engine/sync_pusher_test.dart`

---

## Phase 6 — SyncPuller

**Depends on:** Phase 2, Phase 3
**Goal:** Pull remote changes and apply them locally.

### Task 6.1 — Internal PullResult model

- [x] **6.1.1** Add `PullResult` class to `lib/src/engine/sync_puller.dart`

### Task 6.2 — SyncPuller implementation

- [x] **6.2.1** Create `lib/src/engine/sync_puller.dart`

### Task 6.3 — Tests

- [x] **6.3.1** Create `test/engine/sync_puller_test.dart`

---

## Phase 7 — SyncEngine

**Depends on:** Phase 5, Phase 6
**Goal:** Orchestrate pusher + puller, manage state stream, cancellation.

### Task 7.1 — SyncEngine implementation

- [x] **7.1.1** Create `lib/src/engine/sync_engine.dart`

### Task 7.2 — Tests

- [x] **7.2.1** Create `test/engine/sync_engine_test.dart`

---

## Phase 8 — UniversalSync Facade

**Depends on:** Phase 7
**Goal:** Single entry point for users.

### Task 8.1 — UniversalSync

- [x] **8.1.1** Create `lib/src/universal_sync.dart`
- [x] **8.1.2** Update barrel export

### Task 8.2 — Tests

- [x] **8.2.1** Create `test/universal_sync_test.dart`

### Task 8.3 — SyncConfig

- [x] **8.3.1** Create `lib/src/config/sync_config.dart`
  - `entityOrder: List<Type>` (required)
  - `batchSize: int` (default 50)
  - `resolvers: Map<Type, ConflictResolver>?` (optional)
  - Constructor asserts: `entityOrder` not empty, `batchSize > 0`, resolver keys in entityOrder
- [x] **8.3.2** Create `test/config/sync_config_test.dart`

---

## Integration Tests

- [x] **9.1** Create `test/integration/full_sync_cycle_test.dart`

---

## Summary

| Phase | Tasks | Test files | Status |
|---|---|---|---|
| 0 — Setup | 7 | — | ✅ |
| 1 — Models | 6 | 5 | ✅ |
| 2 — Adapters | 4 | 3 | ✅ |
| 3 — Internal | 1 | 1 | ✅ |
| 4 — Conflict | 5 | 1 | ✅ |
| 5 — Pusher | 3 | 1 | ✅ |
| 6 — Puller | 3 | 1 | ✅ |
| 7 — Engine | 2 | 1 | ✅ |
| 8 — Facade | 3 | 2 | ✅ |
| 9 — Integration | 1 | 1 | ✅ |
| **Total** | **35** | **16** | **✅** |

All 230 tests pass, `dart analyze` clean.

---

## Completed This Session

- [x] **Add `idempotencyKey` to `SyncQueueEntry` and `PushEntry`**: Enables server-side idempotency dedup. See `lib/src/model/sync_queue_entry.dart`, `lib/src/adapter/remote_adapter.dart`.
- [x] **Remove retry state machine**: Removed `retryCount`, `errorMessage` from `SyncQueueEntry`; removed `processing` status; removed `maxRetries`/`retryDelay` from `SyncConfig`; simplified `SyncPusher` (no retry loops).
- [x] **Remove `pendingCount` from `SyncState`**: `SyncIdle` and `SyncError` no longer track `pendingCount` — query the adapter directly via `fetchPendingEntries`.
- [x] **Simplify `LocalAdapter.updateQueueEntryStatus`**: Signature is now `(String entryId, SyncEntryStatus status)` — no optional retry fields.
- [x] **Server `handlePull` deduplication**: Collapse sync log entries to latest-per-entity before returning. See `example/servers/nestjs/src/sync/sync.service.ts:157-161`.
- [x] **Server `nextSequence` initialization**: Initialize from `MAX(serverSequence)` from `sync_log` table, not hardcoded 1. See `example/servers/nestjs/src/sync/sync.service.ts:177-188`.
- [x] **Client UUID for queue entry `id`**: Changed `id: 'q_$seq'` to `id: const Uuid().v4()` so server dedup by `entryId` works across app restarts. See `example/lib/todos/providers.dart`.

## Remaining / Future

- [ ] **Persistent `LocalAdapter` example**: Ship a `DriftLocalAdapter` or similar for SQLite-backed persistence (checkpoint survives restarts).
- [ ] **Server push response `serverSequence` alignment**: Ensure `nextSequence` counter is persisted correctly and never rolls back.
- [ ] **Conflict resolution UI**: Example app doesn't surface conflicts to the user; `merge` strategy is untested in the UI.
- [ ] **Multi-device reconciliation test**: Automated test that simulates two clients diverging then syncing via the same server.
- [ ] **Disconnect/reconnect resilience**: Test that entries queued while offline are pushed in order when connectivity returns.

---

## Development Notes

### Running tests

```bash
dart analyze          # static analysis
dart test             # all tests
dart test test/<path> # single file
dart format .         # format code
```

### Before committing

1. `dart analyze` — must be clean
2. `dart test` — all tests must pass
3. `dart format .` — code must be formatted

### Mocking conventions

- Use `mocktail` for `RemoteAdapter` mocks
- Use `InMemoryLocalAdapter` as the concrete `LocalAdapter` in all tests
- Never mock `LocalAdapter` — always use `InMemoryLocalAdapter`

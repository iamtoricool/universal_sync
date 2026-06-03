# Stress-Testing Plan: Real-World Scenarios

## Current Coverage Gaps

| Gap | Detail |
|-----|--------|
| Persistent adapter | Only `InMemoryLocalAdapter` exists; data lost on restart |
| Multi-device sync | No test simulates two clients diverging then reconciling |
| Disconnect/reconnect | No test for offline queued entries being pushed on reconnect |
| Stress/load | No tests with 100s/1000s of entries, no benchmarks |
| Real HTTP integration | All remote adapter tests use `mocktail` mocks |
| Batch boundary edge cases | No test for partial batch success or exact-size batches |
| Concurrent access | No multi-isolate tests |
| Complex relationships | Only two entity types (`Todo`, `TodoCategory`) with a simple FK |

---

## Feature 1 — Persistent LocalAdapter

**Stress angle:** Data survival across restarts, SQL transaction semantics, journaling/WAL mode with concurrent reads/writes.

**What:**
- New `SqliteLocalAdapter` implementing `LocalAdapter` using `sqflite` (Flutter) or `drift`
- Configurable via `SyncConfig` and swappable via DI in `providers.dart`
- Tests: full sync cycle with app restart simulation (hot restart clears in-memory state but SQLite data and server data survive)

**Key risks to validate:**
- All 9 `LocalAdapter` methods work under SQL transactions
- Concurrent reads don't block writes (WAL mode)
- Large blobs in payload fields don't cause OOM
- Schema migration when entity fields change

**Files:**
- `lib/src/adapter/local/sqlite_local_adapter.dart`
- `test/adapter/sqlite_local_adapter_test.dart`
- Updated `example/lib/todos/providers.dart` (conditional adapter selection)

---

## Feature 2 — Bulk Data Generator + Paginated UI

**Stress angle:** Batch boundaries, large queue sizes, memory pressure, serialization throughput.

**What:**
- `seed_data.dart` — utility page with buttons: "Generate 10", "100", "1000", "10000" Todos/Categories
- Each generation: create UUIDs, upsert entities, enqueue queue entries, then trigger sync
- `ListView.builder` with 50-item page fetch from adapter (not loading all into memory at once)
- Sync progress indicator shows `processed/total` during large pushes

**Key risks to validate:**
- `fetchPendingEntries` with thousands of entries (sorting + limit)
- Batch processing loops don't block UI thread
- Large push responses parsed correctly
- Server-side `PushRequestDto` validation with many entries
- Memory doesn't grow unbounded during bulk sync

**Files:**
- `example/lib/todos/seed_data.dart`
- Updated `example/lib/todos/home_page.dart` (paginated list)
- Updated `example/lib/todos/providers.dart` (paginated fetch)

---

## Feature 3 — Offline Queue Viewer + Manual Toggle

**Stress angle:** Retry correctness, idempotency, ordering preservation, failure recovery.

**What:**
- Settings toggle: "Simulate Offline" — blocks all HTTP in `RestRemoteAdapter` via a boolean flag
- `sync_queue_page.dart` — shows all queue entries (pending/synced/failed) with timestamps, entity type, operation, localSequence
- Badge on queue icon showing total pending count
- "Retry Failed" button: resets `failed` entries back to `pending`
- "Clear Synced" button: removes synced entries from view

**Key risks to validate:**
- Entries survive failed push without corruption
- `localSequence` ordering preserved across retry cycles
- Idempotency keys prevent duplicate server entries on retry
- Failed entries don't block subsequent pending entries
- Queue doesn't grow unbounded (no memory leak)

**Files:**
- `example/lib/todos/sync_queue_page.dart`
- Updated `example/lib/todos/rest_remote_adapter.dart` (offline flag)
- Updated `example/lib/todos/providers.dart` (queue stats)

---

## Feature 4 — Conflict Stress Page

**Stress angle:** All conflict resolution code paths exercised with real entity data at scale.

**What:**
- `conflict_debug_page.dart` — two panels representing Device A and Device B with independent `InMemoryLocalAdapter` instances feeding the same sync engine
- Buttons: "Edit on A", "Edit on B", "Sync A", "Sync B"
- Deliberately create diverging edits to trigger conflicts
- Shows outcome: which version won, what the merged result is
- Tests all three strategies: `ServerWinsResolver`, `ClientWinsResolver`, custom `MergeResolver`
- Supports all entity types (Todo, Category)

**Key risks to validate:**
- Conflict detection works at scale (hundreds of entries with overlapping edits)
- Merge strategy produces consistent results (no data loss)
- Delete-vs-update conflict handled correctly
- Version counter monotonicity preserved across conflicts

**Files:**
- `example/lib/todos/conflict_debug_page.dart`
- Updated `example/lib/todos/providers.dart` (second adapter/engine for Device B)

---

## Feature 5 — Multi-User Sharing (Ownership + Permissions)

**Stress angle:** Server-side query complexity, multi-tenant data isolation, cross-user sync correctness.

**What:**
- Add `ownerId` (required) and `sharedWith` (optional `List<String>`) to entity models
- Server `handlePull`: return entities where `userId == ownerId OR sharedWith CONTAINS userId`
- Server `handlePush`: validate ownership (existing pattern) + `sharedWith` permissions
- Client UI: "Share with user" dialog that adds a user ID to an entity's `sharedWith`
- Two-device test scenario: User A creates + shares, User B pulls and sees shared entities

**Key risks to validate:**
- Permission filter on server pull doesn't miss entities at batch boundaries
- Cross-user push doesn't violate ownership constraints
- Shared entity updates from non-owner are properly gated or allowed
- Checkpoint correctness when entity visibility changes (user added/removed from `sharedWith`)

**Files:**
- Updated `example/lib/todos/todo.dart` (add `ownerId`, `sharedWith`)
- Updated `example/lib/todos/category.dart` (add `ownerId`, `sharedWith`)
- Updated `example/servers/nestjs/src/sync/entities/*.entity.ts`
- Updated `example/servers/nestjs/src/sync/sync.service.ts` (handlePull filter)

---

## Feature 6 — Complex Entity Graph

**Stress angle:** Entity ordering, referential integrity across sync cycles, cascading operations.

**Entities to add:**

| Entity | Parent | Fields |
|--------|--------|--------|
| `Project` | — | name, description, color |
| `Tag` | — | name, color |
| `TodoTag` | Todo, Tag | todoId, tagId (join entity) |
| `Comment` | Todo | todoId, authorId, text |

**SyncConfig.entityOrder:**
```
[Project, Tag, TodoCategory, Todo, TodoTag, Comment]
```

**Server:** All new entities handled by extending the generic `processEntity` dispatcher in `sync.service.ts` — the refactored architecture already supports this with per-entity insert/update/camel helpers.

**Key risks to validate:**
- Foreign key ordering guarantees (Project before Category, Todo before Comment)
- Join entity sync (TodoTag pushed after both Todo and Tag are confirmed on server)
- Cascading visibility (delete Project → server cascades to Categories → Todos → Comments)
- No circular dependencies in entity graph

**Files:**
- `example/lib/todos/project.dart`, `tag.dart`, `todo_tag.dart`, `comment.dart`
- `example/lib/todos/project_providers.dart`, `tag_providers.dart`, `comment_providers.dart`
- `example/servers/nestjs/src/sync/entities/*.entity.ts` (4 new entities)
- Updated `example/servers/nestjs/src/sync/sync.service.ts` (4 new processor branches)
- Updated `example/lib/todos/providers.dart` (entityOrder and entityFromJson)

---

## Feature 7 — Sync Benchmark Dashboard

**Stress angle:** Performance measurement, regression detection, large-batch timing.

**What:**
- `benchmark_page.dart` — runs configurable sync cycles with timing capture
- Metrics per entity type: push time, pull time, entries pushed, entries pulled
- Summary stats: min/max/avg/median duration across N runs
- "Generate data, then benchmark" flow: seed N entries, run sync, show results
- Results persisted locally to compare across sessions/code changes

**Key risks to validate:**
- First sync vs incremental sync timing (cold vs warm)
- Push vs pull time ratio as queue depth grows
- Server-side processing time per entry (should be O(n) not O(n²))
- Memory usage during large sync cycles

**Files:**
- `example/lib/todos/benchmark_page.dart`
- `example/lib/todos/benchmark_store.dart` (local results persistence)

---

## Priority Matrix

| # | Feature | Stress Angle | Effort | Impact |
|---|---------|-------------|--------|--------|
| 1 | Persistent LocalAdapter | Data survival, SQL transactions | High | Critical |
| 2 | Bulk Data Generator | Batch boundaries, large queues | Medium | High |
| 3 | Offline Queue Viewer | Retry, idempotency, ordering | Medium | High |
| 4 | Conflict Stress Page | All resolution code paths | Medium | High |
| 5 | Multi-User Sharing | Permissions, cross-user isolation | High | Medium |
| 6 | Complex Entity Graph | Entity ordering, referential integrity | High | High |
| 7 | Benchmark Dashboard | Performance measurement | Low | Medium |

## Parallel Workstreams

```
Week 1: [1] PersistentLocalAdapter ──────────────────────────
         [2] BulkDataGenerator     ────────
         [7] BenchmarkDashboard    ────────

Week 2: [3] OfflineQueueViewer     ────────────
         [4] ConflictStressPage     ────────────
         [1] (integration tests)

Week 3: [5] MultiUserSharing       ─────────────────
         [6] ComplexEntityGraph    ─────────────────
         [2] (paginated UI polish)
```

Items **2, 3, 7** can be built in parallel (independent UI pages). Items **5, 6** are the highest effort and depend on the generic `processEntity` dispatcher on the server side (already in place).

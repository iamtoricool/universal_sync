# Universal Sync — Comprehensive Codebase Assessment

> Generated: 2026-06-04 | Source code state: pre-REFACTOR_PLAN

---

## Table of Contents

1. [Finding Summary](#1-finding-summary)
2. [P0 — Must Fix](#2-p0--must-fix)
3. [P1 — API Simplification](#3-p1--api-simplification)
4. [P2 — Code Health & Hygiene](#4-p2--code-health--hygiene)
5. [P3 — Already in REFACTOR_PLAN](#5-p3--already-in-refactor_plan)
6. [Recommended Execution Order](#6-recommended-execution-order)

---

## 1. Finding Summary

| ID | Area | Priority | Finding | Est. LOC Saved |
|----|------|----------|---------|---------------|
| P0-1 | Packaging | **Must Fix** | `SERVER_CONTRACT.md` referenced in `.pubignore` but doesn't exist | — |
| P1-1 | Architecture | **Simplify** | `SyncPusher` + `SyncPuller` as separate classes add 150 lines of boilerplate | ~150 |
| P1-2 | Architecture | **Simplify** | `UniversalSync` facade adds `init()` ceremony without value | ~60 |
| P1-3 | API | **Simplify** | Generic `T` on conflict classes (`ConflictContext<T>`, etc.) never specialized | ~20 |
| P1-4 | API | **Simplify** | `SyncPuller.entityFromJson` stored but never used | — |
| P1-5 | API | **Simplify** | `PushResult.+` / `PullResult.+` defined but never called | — |
| P1-6 | API | **Simplify** | `PushResult` / `PullResult` as intermediate types immediately decomposed | ~40 |
| P1-7 | API | **Simplify** | `SyncPuller` has public fields while `SyncPusher` uses private — inconsistent | — |
| P1-8 | Exports | **Simplify** | Barrel exports `SyncPusher`, `SyncPuller`, `InMemoryLocalAdapter` — should be internal | ~350 surface area |
| P1-9 | Imports | **Simplify** | 6 files import the barrel that exports them (circular re-export pattern) | — |
| P2-1 | Example | **Deduplication** | `category_providers.dart` is a near-exact copy of `providers.dart` | ~120 |
| P2-2 | Example | **UX** | `triggerSync()` silently swallows all errors (`catch (_) {}`) | — |
| P2-3 | Example | **UX** | Sync error banner has no retry button | — |
| P2-4 | Example | **Boilerplate** | `SyncQueueEntry` construction repeated 7× with identical UUID/DateTime boilerplate | ~42 |
| P2-5 | Example | **Boilerplate** | `dart:convert` imported in 2 notifier files only for `jsonEncode(payload)` | — |
| P2-6 | Library | **Health** | `_Unset` sentinel duplicated in `sync_queue_entry.dart` + `sync_checkpoint.dart` | — |
| P2-7 | Library | **Health** | `Map<Type, ...>` keys fragile in release mode — prefer `String` keys | — |
| P2-8 | Library | **Defaults** | `SyncConfig.resolvers` nullable with no default; propagates null checks across 3 layers | — |
| P2-9 | Tests | **Duplication** | `MockRemoteAdapter` defined in 5 separate test files | — |
| P2-10 | Tests | **Duplication** | `_TestEntity`, `_Customer`, `_Product` duplicated across test files | — |
| P2-11 | Tests | **Duplication** | `test/adapter/remote_operation_test.dart` + `push_response_test.dart` fully overlap `remote_adapter_test.dart` | 2 files |
| P2-12 | Tests | **Coverage** | `in_memory_local_adapter_test.dart` test named "retryCount, errorMessage" but never asserts them | — |
| P2-13 | Tests | **Coverage** | `softDeleteEntity` — no test asserts `deletedAt` is actually set | — |
| P2-14 | Tests | **Flakiness** | `sync_engine_test.dart` + `full_sync_cycle_test.dart` missing `tearDown` — stream subscriptions leak | — |
| P2-15 | Tests | **Duplication** | `sync_state_test.dart` identical test (SyncIdle default lastSyncedAt) written twice | — |
| P2-16 | Tests | **Duplication** | `sync_pusher_test.dart` duplicated progress-callback and rejected-entry tests | — |
| P2-17 | Tests | **Organization** | `in_memory_local_adapter_test.dart` 1 directory level too high | — |
| P2-18 | Tests | **Duplication** | `ServerWinsResolver` / `ClientWinsResolver` are single-expression classes in separate files | 2 files→1 |
| P3-1 through P3-11 | All | **In Plan** | 11 changes already documented in `REFACTOR_PLAN.md` | See plan |

---

## 2. P0 — Must Fix

### P0-1: `.pubignore` references nonexistent file

**File:** `.pubignore` line 4

```text
# Exclude large static resources from the published package
SERVER_CONTRACT.md
```

The file `SERVER_CONTRACT.md` does not exist at the project root. Publishing would either fail or ignore a nonsensical exclusion.

**Fix:** Either create `SERVER_CONTRACT.md` or remove that line from `.pubignore`.

---

## 3. P1 — API Simplification

### P1-1: Merge `SyncPusher` / `SyncPuller` into `SyncEngine` (or private helpers)

**Files:** `lib/src/engine/sync_pusher.dart` (180 lines), `lib/src/engine/sync_puller.dart` (85 lines)

Both classes are instantiated only by `SyncEngine`. They share identical iteration boilerplate: `for (final type in config.entityOrder) { check isCancelled; derive typeName; }`. Each has its own result type (`PushResult`, `PullResult`) that is immediately decomposed in `SyncEngine`.

**Current pattern** — 3 files, 2 result types, duplicated loops:

```
SyncEngine.sync()
  → SyncPusher.run()  → returns PushResult
  → SyncPuller.run()  → returns PullResult
  → decomposes both into SyncResult
```

**Recommendation:** Inline push/pull logic directly into `SyncEngine` methods. This eliminates `SyncPusher`, `SyncPuller`, `PushResult`, and `PullResult` from the public API, saving ~150 lines and a confusing abstraction boundary.

**Tradeoff:** If push/pull logic grows significantly later, they could become private classes within `sync_engine.dart` rather than separate files.

---

### P1-2: Remove `UniversalSync` facade, fold into `SyncEngine`

**File:** `lib/src/universal_sync.dart` (61 lines)

`UniversalSync` adds `init()` for validation that could happen eagerly in the constructor, stores an `_initialized` guard, and lazily creates `SyncEngine`. After the refactoring plan moves `entityFromJson` + `resolvers` into `SyncConfig`, validation in `init()` becomes redundant (`SyncConfig` constructor validates everything).

**Current consumer experience:**

```dart
final sync = UniversalSync(localAdapter: a, remoteAdapter: r, config: c, entityFromJson: {...});
await sync.init();
sync.engine.sync();       // two hops: facade → engine
```

**Recommendation:** Fold `UniversalSync` into `SyncEngine`. Consumers go from 3 steps → 1:

```dart
final engine = SyncEngine(localAdapter: a, remoteAdapter: r, config: c);
await engine.sync();      // one hop
```

---

### P1-3: Remove generic `<T>` from conflict classes

**Files:** `lib/src/conflict/conflict_resolver.dart`, `server_wins_resolver.dart`, `client_wins_resolver.dart`

`ConflictContext<T>`, `ConflictResolution<T>`, `ConflictResolver<T>`, `ServerWinsResolver<T>`, `ClientWinsResolver<T>` all carry a generic `T` that is **never specialized** in practice. The only instantiation site:

```dart
final resolver = _resolvers?[type] ?? ServerWinsResolver<SyncEntity>();
```

Always `SyncEntity`. The `entityFromJson` map returns `SyncEntity`, so subtype info is lost before it reaches the conflict classes. The generics add angle-bracket noise without compile-time safety.

**Recommendation:** Drop `<T>`. Use `SyncEntity` directly. This touches 5 class declarations and all inline usages. Saves ~20 `<>` annotations.

---

### P1-4: Remove dead `entityFromJson` from `SyncPuller`

**File:** `lib/src/engine/sync_puller.dart` lines 19, 25

`SyncPuller` stores `entityFromJson` as a required constructor parameter and public field, but **never reads it**. The `run()` method passes raw `Map<String, dynamic>` payloads to `localAdapter.upsertEntity()` without ever deserializing.

**Recommendation:** Remove the field and constructor parameter. Already in `REFACTOR_PLAN.md` Change 6.

---

### P1-5: Remove unused `operator +` from `PushResult` and `PullResult`

**Files:**
- `lib/src/engine/sync_pusher.dart` lines 16–20: `PushResult operator +(PushResult other)`
- `lib/src/engine/sync_puller.dart` line 12: `PullResult operator +(PullResult other)`

Defined but zero call sites (confirmed via grep of entire codebase).

**Recommendation:** Remove both operators. The constructors suffice for aggregation.

---

### P1-6: Eliminate `PushResult` / `PullResult` as intermediate types

**Files:** See P1-1.

If P1-1 is accepted — push/pull inlined into `SyncEngine` — these result types vanish naturally. If P1-1 is rejected, consider replacing with `SyncResult` directly or raw `int` returns.

---

### P1-7: Make `SyncPuller` fields private

**Files:** `lib/src/engine/sync_puller.dart` lines 16–18

```dart
final LocalAdapter localAdapter;    // public
final RemoteAdapter remoteAdapter;  // public
final SyncConfig config;            // public
```

`SyncPusher` uses private fields (`_localAdapter`, etc.). `SyncPuller` exposes the same fields as public API. Inconsistent.

**Recommendation:** Prefix with `_` to match `SyncPusher` convention.

---

### P1-8: Remove internal classes from barrel exports

**File:** `lib/universal_sync.dart` lines 12, 20, 21

```dart
export 'src/adapter/local/in_memory_local_adapter.dart';  // test helper != public API
export 'src/engine/sync_pusher.dart';                      // internal; use SyncEngine
export 'src/engine/sync_puller.dart';                      // internal; use SyncEngine
```

`InMemoryLocalAdapter` is for testing. `SyncPusher`/`SyncPuller` are engine internals. All three bloat the public surface and signal "stable API" when they're implementation details.

**Recommendation:** Remove these 3 exports. Consumers who need `InMemoryLocalAdapter` for testing can import via the explicit `src/` path (standard Dart practice for test-only classes).

**If P1-1 is accepted**, `SyncPusher`/`SyncPuller` are gone from the codebase entirely — no export issue.

---

### P1-9: Fix circular re-export pattern in 6 files

**Files:**
- `lib/src/conflict/conflict_resolver.dart`
- `lib/src/conflict/server_wins_resolver.dart`
- `lib/src/conflict/client_wins_resolver.dart`
- `lib/src/engine/sync_engine.dart`
- `lib/src/engine/sync_pusher.dart`
- `lib/src/universal_sync.dart`

All 6 files use `import 'package:universal_sync/universal_sync.dart';` — the barrel that re-exports them. While Dart allows this, it creates tight coupling and makes the import graph opaque.

**Recommendation:** Replace with specific imports. Example:

```dart
// Instead of:
import 'package:universal_sync/universal_sync.dart';

// Use:
import 'package:universal_sync/src/model/sync_entity.dart';
import 'package:universal_sync/src/adapter/local_adapter.dart';
```

Follow the pattern already used by `sync_puller.dart` and `sync_config.dart`.

---

## 4. P2 — Code Health & Hygiene

### P2-1: Extract generic `EntityNotifier<T>` base class

**Files:** `example/lib/todos/providers.dart` (full CRUD × 3 ops + triggers), `example/lib/todos/category_providers.dart` (same × 3 ops)

Two notifiers with identical structure — only entity type, field names, and sort comparator differ.

**Current duplication:**

| Notifier | Lines | Unique content |
|----------|-------|---------------|
| `TodoListNotifier` | ~160 lines | `Todo` fields, sort by `createdAt` descending |
| `CategoryListNotifier` | ~150 lines | `TodoCategory` fields, sort by `name` alphabetic |

~130 lines of identical boilerplate (sequence, transaction, upsert, enqueue, invalidate).

**Recommendation:** Extract:

```dart
abstract class EntityNotifier<T extends SyncEntity> extends AsyncNotifier<List<T>> {
  String get entityType;
  T Function(Map<String, dynamic>) get fromJson;
  int Function(T, T) get sortComparator;

  Future<void> insert(T entity);
  Future<void> update(String id, T Function(T) updater);
  Future<void> delete(T entity);
  Future<void> triggerSync();
}
```

Each notifier then implements ~30 lines instead of ~160.

---

### P2-2: Surface sync errors instead of swallowing them

**File:** `example/lib/todos/providers.dart` lines 192–195

```dart
Future<void> triggerSync() async {
  try {
    final sync = await ref.read(universalSyncProvider.future);
    await sync.engine.sync();
  } catch (_) {}    // ← swallowed
}
```

Same pattern in `category_providers.dart` line 137–145.

**Recommendation:** Return `SyncResult` from `triggerSync()` so callers can inspect `.hasErrors` / `.hasConflicts`. At minimum, log the error.

---

### P2-3: Add retry button to sync error banner

**File:** `example/lib/todos/sync_status_indicator.dart`

The `SyncError` branch shows "Sync failed: ..." but provides no retry action. Users must tap the app bar sync icon.

**Recommendation:** Add a `TextButton("Retry")` callback on the error banner.

---

### P2-4: Add `LocalAdapter.enqueueFor<T>()` factory

7 call sites across the example construct `SyncQueueEntry` with the same pattern:

```dart
SyncQueueEntry<Todo>(
  id: const Uuid().v4(),
  idempotencyKey: const Uuid().v4(),
  data: todo,
  operation: SyncOperation.insert,
  version: 0 / currentVersion,
  localSequence: seq,         // from nextSequence()
  createdAt: now,             // DateTime.now()
)
```

**Recommendation:** Add a convenience method to the `LocalAdapterX` extension:

```dart
extension LocalAdapterX on LocalAdapter {
  Future<void> enqueueFor<T extends SyncEntity>(
    T entity,
    SyncOperation operation, {
    String? idempotencyKey,
  }) async {
    final seq = await nextSequence();
    await enqueue(SyncQueueEntry<T>(
      id: const Uuid().v4(),
      idempotencyKey: idempotencyKey ?? const Uuid().v4(),
      data: entity,
      operation: operation,
      version: entity.version,
      localSequence: seq,
      createdAt: DateTime.now(),
    ));
  }
}
```

Collapses each call site from 9 lines → 1 line:

```dart
await adapter.enqueueFor(todo, SyncOperation.insert);
```

---

### P2-5: Eliminate `dart:convert` from example notifiers

**Files:** `providers.dart` line 1, `category_providers.dart` line 1, `example_sync_test.dart` line 2

All import `dart:convert` solely for `jsonEncode(data)` in the now-removed `payload:` field of `SyncQueueEntry`. With the REFACTOR_PLAN's change to `T data`, these imports become unnecessary.

**Recommendation:** Remove `import 'dart:convert';` from the 3 files — handled by the REFACTOR_PLAN Change 3.

---

### P2-6: Consolidate duplicated `_Unset` sentinel

**Files:**
- `lib/src/model/sync_queue_entry.dart` lines 61–65
- `lib/src/model/sync_checkpoint.dart` lines 1–5

Both files define identical private helpers:

```dart
const _unset = _Unset();
class _Unset { const _Unset(); }
```

**Recommendation:** Extract to `lib/src/internal/_utils.dart` (or similar) and import in both files.

---

### P2-7: Replace `Map<Type, ...>` with `Map<String, ...>` keys

**Files:** `SyncConfig`, `SyncPusher`, `SyncPuller`, `SyncEngine`, `UniversalSync`

Using `Type` objects as map keys is fragile in release builds (obfuscation) and differs across platforms (VM vs web `toString()`). The `entityTypeName(Type)` function already exists to derive stable string keys.

**Recommendation:** Change all `Map<Type, ...>` to `Map<String, ...>` using the entity type name string.

---

### P2-8: Default `SyncConfig.resolvers` to empty map

**File:** `lib/src/config/sync_config.dart` line 7

```dart
final Map<Type, ConflictResolver<SyncEntity>>? resolvers;
```

Nullable with no default forces null checks in `SyncPusher` constructor and at the conflict resolution point.

**Recommendation:** Change to `const {}` default (after string-key change):

```dart
final Map<String, ConflictResolver<SyncEntity>> resolvers;
```

---

### P2-9: Extract `MockRemoteAdapter` into shared file

Defined 5 times across:

| File | Line |
|------|------|
| `test/universal_sync_test.dart` | 5 |
| `test/engine/sync_pusher_test.dart` | 7 |
| `test/engine/sync_engine_test.dart` | 8 |
| `test/engine/sync_puller_test.dart` | 5 |
| `test/integration/full_sync_cycle_test.dart` | 7 |

**Recommendation:** Extract to `test/shared/mocks.dart`.

---

### P2-10: Extract shared test entities

| Entity | Files Using It |
|--------|---------------|
| `_TestEntity` | `sync_entity_test.dart`, `sync_queue_entry_test.dart`, `conflict_resolver_test.dart`, `sync_config_test.dart` |
| `_Customer` | `sync_pusher_test.dart`, `full_sync_cycle_test.dart` |
| `_Product` | `sync_pusher_test.dart`, `full_sync_cycle_test.dart` |

All three entity types (and their `fromJson`/`toSyncJson` implementations) are duplicated.

**Recommendation:** Extract to `test/shared/test_entities.dart`.

---

### P2-11: Merge dead test files into `remote_adapter_test.dart`

- `test/adapter/remote_operation_test.dart` (43 lines) — fully covered by `remote_adapter_test.dart` lines 203–251
- `test/adapter/push_response_test.dart` (44 lines) — fully covered by `remote_adapter_test.dart` lines 151–185, 253–293

**Recommendation:** Delete both files. Merge any unique assertions into `remote_adapter_test.dart`.

---

### P2-12: Fix misleading test name in `in_memory_local_adapter_test.dart`

**Line 85:** `test('updates status, retryCount, errorMessage', ...)`

The test body asserts `entry.status` is `SyncEntryStatus.synced` and `entry.syncedAt` is not null. It never asserts `retryCount` or `errorMessage`. These fields don't exist on `SyncQueueEntry`.

**Recommendation:** Rename test to `'updates status and sets syncedAt'`.

---

### P2-13: Add `softDeleteEntity` assertion test

No test confirms that `softDeleteEntity` actually sets `deletedAt` on the stored entity map.

**Recommendation:** Add a test in `in_memory_local_adapter_test.dart`:

```dart
test('softDeleteEntity sets deletedAt', () async {
  await adapter.upsertEntity('TestEntity', {'id': 'e1'});
  await adapter.softDeleteEntity('TestEntity', 'e1');
  final stored = adapter.entities['TestEntity']!['e1'];
  expect(stored['deletedAt'], isNotNull);
});
```

---

### P2-14: Add `tearDown` to tests with stream subscriptions

**Files:**
- `test/engine/sync_engine_test.dart` — subscribes to `e.state.listen(...)` in multiple tests; if assertion fails before `sub.cancel()`, subscription leaks
- `test/integration/full_sync_cycle_test.dart` — same pattern

**Recommendation:** Add `tearDown` that cancels all tracked subscriptions and disposes the engine.

---

### P2-15: Remove duplicate `SyncIdle` test

**File:** `test/model/sync_state_test.dart` lines 6–8 and 11–13

Both tests check `SyncIdle().lastSyncedAt == null`. One should be removed.

---

### P2-16: Remove duplicate progress and rejected-entry tests

**File:** `test/engine/sync_pusher_test.dart`

- Progress callback tested at lines 386–418 AND lines 748–782 — identical
- Rejected entry tested at lines 622–647 AND lines 332–361 — identical

**Recommendation:** Remove the duplicates. Keep the more complete version of each.

---

### P2-17: Move `in_memory_local_adapter_test.dart` to correct path

**Current:** `test/adapter/in_memory_local_adapter_test.dart`
**Should be:** `test/adapter/local/in_memory_local_adapter_test.dart` (mirrors `lib/src/adapter/local/`)

---

### P2-18: Consolidate `ServerWinsResolver` / `ClientWinsResolver`

**Files:**
- `lib/src/conflict/server_wins_resolver.dart` (10 lines)
- `lib/src/conflict/client_wins_resolver.dart` (10 lines)

Both are single-expression classes differing only in one argument (`acceptRemote` vs `acceptLocal`).

**Recommendation:** Replace with a single strategy class or top-level function:

```dart
ConflictResolution resolveWithStrategy(
  ConflictStrategy strategy,
  ConflictContext context,
) {
  switch (strategy) {
    case ConflictStrategy.acceptRemote:
      return ConflictResolution.acceptRemote(context.remote);
    case ConflictStrategy.acceptLocal:
      return ConflictResolution.acceptLocal(context.local);
    case ConflictStrategy.merge:
      throw UnimplementedError('Custom merge resolvers not yet built in');
  }
}
```

Or provide pre-built constants: `const serverWinsResolver = _SimpleResolver(ConflictStrategy.acceptRemote);`

If P1-3 (remove generics) is also accepted, these become even simpler.

---

## 5. P3 — Already in REFACTOR_PLAN

These changes are documented in `ai_docs/REFACTOR_PLAN.md`:

| ID | REFACTOR_PLAN Section | Description |
|----|----------------------|-------------|
| P3-1 | Change 1 | `SyncConfig` gains `entityFromJson` map, `types` getter, validation |
| P3-2 | Change 2 | `UniversalSync` removes `entityFromJson`/`resolvers`/`init()`/`_initialized` |
| P3-3 | Change 3 | `SyncQueueEntry` becomes `<T>`, uses `T data` instead of `String payload` |
| P3-4 | Change 4 | `LocalAdapter.enqueue<T>` generic; `LocalAdapterX` extension; string-based `upsertEntity`/`softDeleteEntity` |
| P3-5 | Change 5 | `SyncPusher` reads from config, uses `entry.data` |
| P3-6 | Change 6 | `SyncPuller` removes dead `entityFromJson` |
| P3-7 | Change 7 | `SyncEngine` removes redundant `entityFromJson`/`resolvers` |
| P3-8 | Barrel | `type_utils.dart` exported from barrel |
| P3-9 | Tests | All 18 test files updated for new API |
| P3-10 | Example | Example notifiers updated for new API (data, not payload) |
| P3-11 | Validation | `dart analyze` + `dart test` + `dart format .` |

---

## 6. Recommended Execution Order

| Step | What | Depends On |
|------|------|------------|
| 1 | **P0-1**: Fix `.pubignore` (create or remove `SERVER_CONTRACT.md` reference) | Nothing |
| 2 | **REFACTOR_PLAN** (P3 items 1–11): The main structural change | Nothing |
| 3 | **P1-3**: Remove `<T>` from conflict classes | Independent, touch only conflict files |
| 4 | **P1-1 + P1-2 + P1-6**: Merge Pusher/Puller/UniversalSync into Engine | Step 2 (new API surface) |
| 5 | **P1-8 + P1-9**: Fix barrel exports and circular imports | Step 4 (Pusher/Puller may be gone) |
| 6 | **P2-6, P2-7, P2-8**: Library hygiene (sentinel, Type→String, resolver defaults) | Step 2 (changed files) |
| 7 | **P2-9, P2-10, P2-11, P2-17**: Test infrastructure (shared mocks, entities, file org) | Step 2 (test API changes) |
| 8 | **P2-1, P2-4, P2-5**: Example app (generic notifier, `enqueueFor`, remove dart:convert) | Step 2 + step 4 |
| 9 | **P2-2, P2-3**: Example app (error handling, retry button) | Step 8 |
| 10 | **P2-12 through P2-16, P2-18**: Test improvements (naming, assertions, dedup, tearDown) | Step 7 |

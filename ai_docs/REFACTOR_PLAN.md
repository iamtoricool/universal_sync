# core package refactoring plan

## files to modify

| file | change |
|------|--------|
| `lib/src/config/sync_config.dart` | new fields (`entityFromJson`, `resolvers`), validation, `types` getter |
| `lib/src/universal_sync.dart` | remove params (`entityFromJson`, `resolvers`), remove `init()`, remove `_initialized` |
| `lib/src/model/sync_queue_entry.dart` | generic `<T>`, `T data` replaces `String payload`, auto-derive `entityType`/`entityId` |
| `lib/src/adapter/local_adapter.dart` | `enqueue<T>` for generic entries; string-based `upsertEntity`/`softDeleteEntity` stay; `LocalAdapterX` extension for type-safe wrappers |
| `lib/src/adapter/local/in_memory_local_adapter.dart` | match new `enqueue` signature; keep string-keyed storage; keep non-interface `entities` getter |
| `lib/src/engine/sync_pusher.dart` | read from `config`, remove separate fields; use `entry.data` instead of `jsonDecode(entry.payload)` |
| `lib/src/engine/sync_puller.dart` | remove dead `entityFromJson` param |
| `lib/src/engine/sync_engine.dart` | remove `entityFromJson`/`resolvers` params |
| `lib/universal_sync.dart` | export `type_utils.dart` (needed by generic `SyncQueueEntry` and extension) |
| `example/lib/todos/providers.dart` | use new API |
| `example/lib/todos/category_providers.dart` | use new API |
| + 18 test files | update constructors and API calls |

---

## change 1 — SyncConfig becomes single source of truth

`entityFromJson` and `resolvers` move into `SyncConfig`. Validation
(missing fromJson factory, mismatched resolver keys) moves from
`UniversalSync.init()` into the `SyncConfig` constructor.

```dart
class SyncConfig {
  final Map<int, Type> entityOrder;
  final int batchSize;
  final Map<Type, SyncEntity Function(Map<String, dynamic>)> entityFromJson;
  final Map<Type, ConflictResolver<SyncEntity>>? resolvers;

  SyncConfig({
    required this.entityOrder,
    this.batchSize = 50,
    required this.entityFromJson,
    this.resolvers,
  }) {
    if (entityOrder.isEmpty) throw ArgumentError('entityOrder must not be empty');
    if (batchSize <= 0) throw ArgumentError('batchSize must be > 0');
    for (final type in types) {
      if (!entityFromJson.containsKey(type)) {
        throw ArgumentError('Missing fromJson factory for type: $type');
      }
    }
    if (resolvers != null && !resolvers!.keys.every((k) => types.contains(k))) {
      throw ArgumentError('All resolver types must be in entityOrder');
    }
  }

  /// Types in ascending priority order (sorted by map key).
  List<Type> get types => entityOrder.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key))
    .map((e) => e.value)
    .toList();
}
```

### usage change

```dart
// before
SyncConfig(entityOrder: [TodoCategory, Todo])

// after
SyncConfig(
  entityOrder: {0: TodoCategory, 1: Todo},
  entityFromJson: {Todo: Todo.fromJson, TodoCategory: TodoCategory.fromJson},
)
```

---

## change 2 — simplify UniversalSync

- remove `entityFromJson`, `resolvers` params (moved to `SyncConfig`)
- remove `_initialized` flag
- remove `init()` method
- engine creation stays lazy

```dart
class UniversalSync {
  final LocalAdapter localAdapter;
  final RemoteAdapter remoteAdapter;
  final SyncConfig config;
  final OnSyncStart? onSyncStart;
  final OnSyncComplete? onSyncComplete;
  final OnError? onError;

  SyncEngine? _engine;

  UniversalSync({
    required this.localAdapter,
    required this.remoteAdapter,
    required this.config,
    this.onSyncStart,
    this.onSyncComplete,
    this.onError,
  });

  SyncEngine get engine {
    _engine ??= SyncEngine(
      localAdapter: localAdapter,
      remoteAdapter: remoteAdapter,
      config: config,
      onSyncStart: onSyncStart,
      onSyncComplete: onSyncComplete,
      onError: onError,
    );
    return _engine!;
  }

  void dispose() {
    _engine?.dispose();
    _engine = null;
  }
}
```

### usage change

```dart
// before
final sync = UniversalSync(
  localAdapter: adapter,
  remoteAdapter: remote,
  config: SyncConfig(entityOrder: [TodoCategory, Todo]),
  entityFromJson: {Todo: Todo.fromJson, TodoCategory: TodoCategory.fromJson},
);
await sync.init();

// after
final sync = UniversalSync(
  localAdapter: adapter,
  remoteAdapter: remote,
  config: SyncConfig(
    entityOrder: {0: TodoCategory, 1: Todo},
    entityFromJson: {Todo: Todo.fromJson, TodoCategory: TodoCategory.fromJson},
  ),
);
```

---

## change 3 — SyncQueueEntry becomes generic with `T data`

- add `<T extends SyncEntity>` generic
- replace `String payload` with `T data`
- auto-derive `entityType` and `entityId` from `T` and `data.id`
- remove `entityType`, `entityId`, `payload` from constructor params (all derived)
- remove `entityType`, `entityId`, `payload` from `copyWith`
- no `dart:convert` import

```dart
import 'package:universal_sync/src/internal/type_utils.dart';

class SyncQueueEntry<T extends SyncEntity> {
  final String id;
  final String idempotencyKey;
  final String entityType;   // derived: entityTypeName(T)
  final String entityId;     // derived: data.id
  final T data;
  final SyncOperation operation;
  final int version;
  final int localSequence;
  final SyncEntryStatus status;
  final DateTime createdAt;
  final DateTime? syncedAt;

  SyncQueueEntry({
    required this.id,
    required this.idempotencyKey,
    required this.data,
    required this.operation,
    required this.version,
    required this.localSequence,
    this.status = SyncEntryStatus.pending,
    required this.createdAt,
    this.syncedAt,
  }) : entityType = entityTypeName(T),
       entityId = data.id;

  SyncQueueEntry<T> copyWith({
    String? id, String? idempotencyKey, T? data, SyncOperation? operation,
    int? version, int? localSequence,
    SyncEntryStatus? status, DateTime? createdAt, Object? syncedAt = _unset,
  }) {
    return SyncQueueEntry<T>(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      data: data ?? this.data,
      operation: operation ?? this.operation,
      version: version ?? this.version,
      localSequence: localSequence ?? this.localSequence,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: identical(syncedAt, _unset) ? this.syncedAt : syncedAt as DateTime?,
    );
  }
}
```

### usage change

```dart
// before
await adapter.enqueue(
  SyncQueueEntry(
    id: uuid, idempotencyKey: uuid,
    entityType: 'Todo', entityId: id,
    operation: SyncOperation.insert,
    payload: jsonEncode(data),
    version: 0, localSequence: seq, createdAt: now,
  ),
);

// after
await adapter.enqueue<Todo>(
  SyncQueueEntry<Todo>(
    id: uuid, idempotencyKey: uuid,
    data: todo,
    operation: SyncOperation.insert,
    version: 0, localSequence: seq, createdAt: now,
  ),
);
```

---

## change 4 — LocalAdapter interface (lean, string-based API)

- `enqueue` becomes generic (needed because `SyncQueueEntry` is generic)
- `upsertEntity` and `softDeleteEntity` stay string-based (adapters implement strings; pusher/puller use strings)
- NO `entities<T>()` or `allEntities` — these are `InMemoryLocalAdapter`-specific

```dart
abstract class LocalAdapter {
  Future<T> transaction<T>(Future<T> Function() callback);

  Future<void> enqueue<T extends SyncEntity>(SyncQueueEntry<T> entry);

  Future<void> updateQueueEntryStatus(String entryId, SyncEntryStatus status);

  Future<List<SyncQueueEntry<SyncEntity>>> fetchPendingEntries(
    String entityType, int limit,
  );

  Future<int> nextSequence();

  Future<SyncCheckpoint?> readCheckpoint(String entityType);

  Future<void> writeCheckpoint(SyncCheckpoint checkpoint);

  Future<void> upsertEntity(String entityType, Map<String, dynamic> data);

  Future<void> softDeleteEntity(String entityType, String entityId);
}
```

### LocalAdapterX extension (type-safe wrappers for users)

```dart
extension LocalAdapterX on LocalAdapter {
  Future<void> upsertEntityFor<T extends SyncEntity>(Map<String, dynamic> data) =>
      upsertEntity(entityTypeName(T), data);

  Future<void> softDeleteEntityFor<T extends SyncEntity>(String entityId) =>
      softDeleteEntity(entityTypeName(T), entityId);
}
```

### InMemoryLocalAdapter implementation

Storage stays string-keyed (no change from current). Only `enqueue` signature
changes. The convenience `entities` getter stays as a non-interface member.

```dart
class InMemoryLocalAdapter implements LocalAdapter {
  final _entities = <String, Map<String, Map<String, dynamic>>>{};
  final _queue = <SyncQueueEntry>[];
  final _checkpoints = <String, SyncCheckpoint>{};
  int _sequence = 0;

  @override
  Future<T> transaction<T>(Future<T> Function() callback) async => callback();

  @override
  Future<void> enqueue<T extends SyncEntity>(SyncQueueEntry<T> entry) async {
    _queue.add(entry);
  }
  // ...updateQueueEntryStatus, fetchPendingEntries — no change

  @override
  Future<void> upsertEntity(String entityType, Map<String, dynamic> data) async {
    _entities.putIfAbsent(entityType, () => {});
    _entities[entityType]![data['id'] as String] = data;
  }

  @override
  Future<void> softDeleteEntity(String entityType, String entityId) async {
    final entity = _entities[entityType]?[entityId];
    if (entity != null) entity['deletedAt'] = DateTime.now().toIso8601String();
  }

  // Non-interface convenience getter (InMemoryLocalAdapter-specific)
  Map<String, Map<String, Map<String, dynamic>>> get entities => _entities;

  void reset() { ... }
}
```

### usage change in notifiers

```dart
// before
await adapter.upsertEntity('Todo', data);
await adapter.softDeleteEntity('Todo', todo.id);

// after (via extension)
await adapter.upsertEntityFor<Todo>(data);
await adapter.softDeleteEntityFor<Todo>(todo.id);
```

Entity reads stay the same — they use the `InMemoryLocalAdapter`-specific `entities` getter:

```dart
// before & after (unchanged — not in interface)
final entities = adapter.entities;
final todoMaps = entities['Todo']?.values ?? [];
```

---

## change 5 — SyncPusher reads from config, uses `entry.data`

- remove separate `_entityFromJson`, `_resolvers` fields
- read from `_config.entityFromJson` and `_config.resolvers`
- iterate `_config.types` instead of `_config.entityOrder`
- use `entry.data` instead of `jsonDecode(entry.payload)`

```dart
class SyncPusher {
  final LocalAdapter _localAdapter;
  final RemoteAdapter _remoteAdapter;
  final SyncConfig _config;

  SyncPusher({
    required LocalAdapter localAdapter,
    required RemoteAdapter remoteAdapter,
    required SyncConfig config,
  }) : _localAdapter = localAdapter,
       _remoteAdapter = remoteAdapter,
       _config = config;

  Future<PushResult> run(...) async {
    for (final type in _config.types) {
      final typeName = entityTypeName(type);
      while (true) {
        final entries = await _localAdapter.fetchPendingEntries(
          typeName, _config.batchSize,
        );
        if (entries.isEmpty) break;

        final pushEntries = entries.map(
          (e) => PushEntry(
            id: e.id, idempotencyKey: e.idempotencyKey,
            entityType: e.entityType, entityId: e.entityId,
            operation: e.operation,
            payload: jsonEncode(e.data.toSyncJson()),
            localSequence: e.localSequence,
          ),
        ).toList();

        final response = await _remoteAdapter.push(PushRequest(pushEntries));
        // ... iterate results

        // accepted:
        final data = entry.data.toSyncJson();
        data['version'] = entry.version + 1;
        await _localAdapter.upsertEntity(typeName, data);
        // ...

        // conflicted:
        final localEntity = entry.data;         // already the entity — no fromJson needed
        final fromJson = _config.entityFromJson[type]!;
        final remoteEntity = fromJson(result.serverPayload!);
        final resolver = _config.resolvers?[type] ?? ServerWinsResolver<SyncEntity>();
        final resolution = resolver.resolve(ConflictContext(
          local: localEntity, remote: remoteEntity, operation: entry.operation,
        ));
        // ...

        // merge: construct merged entry with `data:` instead of `payload:`
        final mergedEntity = fromJson(mergedData);
        final mergedEntry = SyncQueueEntry(
          id: 'merged_$nextSeq',
          idempotencyKey: 'merged_$nextSeq',
          data: mergedEntity,
          operation: SyncOperation.update,
          version: entry.version + 1,
          localSequence: nextSeq,
          createdAt: DateTime.now(),
        );
        await _localAdapter.enqueue(mergedEntry);
      }
    }
  }
}
```

---

## change 6 — SyncPuller (remove dead field)

`entityFromJson` is stored in the constructor but never used in the
implementation. Remove it entirely.

```dart
class SyncPuller {
  final LocalAdapter localAdapter;
  final RemoteAdapter remoteAdapter;
  final SyncConfig config;

  SyncPuller({
    required this.localAdapter,
    required this.remoteAdapter,
    required this.config,
  });
  // ...
}
```

---

## change 7 — SyncEngine (remove redundant params)

```dart
class SyncEngine {
  SyncEngine({
    required LocalAdapter localAdapter,
    required RemoteAdapter remoteAdapter,
    required SyncConfig config,
    this.onSyncStart, this.onSyncComplete, this.onError,
  }) {
    _pusher = SyncPusher(
      localAdapter: localAdapter,
      remoteAdapter: remoteAdapter,
      config: config,
    );
    _puller = SyncPuller(
      localAdapter: localAdapter,
      remoteAdapter: remoteAdapter,
      config: config,
    );
  }
}
```

`entityFromJson` and `resolvers` are no longer engine params — the engine
reads them from `config` via pusher/puller which both hold `config`.

---

## test migration summary

| test file | changes |
|-----------|---------|
| `sync_config_test.dart` | add `entityFromJson` param; `entityOrder: {0: _TestEntity}`; validate missing fromJson throws |
| `universal_sync_test.dart` | remove `entityFromJson`/`resolvers` from UniversalSync; remove `init()` calls; remove "engine throws before init" test |
| `sync_pusher_test.dart` | update SyncConfig construction (entityFromJson); pusher reads from config; test `entry.data` usage instead of `jsonDecode(payload)` |
| `sync_puller_test.dart` | remove `entityFromJson` from SyncPuller constructor |
| `sync_engine_test.dart` | remove `entityFromJson` from SyncEngine constructor |
| `sync_queue_entry_test.dart` | add generic `<T>`; construct with `data:` instead of `payload:`+`entityType`+`entityId` |
| `in_memory_local_adapter_test.dart` | change `enqueue` calls to `enqueue<T>`; test string-keyed storage; `entities` getter stays non-interface |
| `local_adapter_test.dart` | update signatures (no `entities<T>()` or `allEntities` in interface) |
| `type_utils_test.dart` | unchanged |
| `sync_entity_test.dart` | unchanged |
| `conflict_resolver_test.dart` | unchanged |
| `sync_state_test.dart` | unchanged |
| `sync_result_test.dart` | unchanged |
| `sync_checkpoint_test.dart` | unchanged |
| `remote_adapter_test.dart` | unchanged |
| `full_sync_cycle_test.dart` | update SyncConfig construction, UniversalSync usage; verify `entry.data` in flow |
| `example_sync_test.dart` | update SyncConfig construction, UniversalSync usage |
| `push_response_test.dart` | unchanged |
| `remote_operation_test.dart` | unchanged |

---

## example app diff summary

```dart
// universalSyncProvider
SyncConfig(
  entityOrder: {0: TodoCategory, 1: Todo},
  entityFromJson: {Todo: Todo.fromJson, TodoCategory: TodoCategory.fromJson},
)
// no more entityFromJson/resolvers on UniversalSync
// no more await sync.init()

// addTodo
await adapter.enqueue<Todo>(
  SyncQueueEntry<Todo>(
    id: uuid, idempotencyKey: uuid,
    data: todo,                              // was: payload: jsonEncode(data)
    operation: SyncOperation.insert,          // entityType/entityId auto-derived
    version: 0, localSequence: seq, createdAt: now,
  ),
);

// updateTodo — entity read (unchanged, InMemoryLocalAdapter-specific)
final map = adapter.entities['Todo']?[id];
if (map == null) return;

// deleteTodo
adapter.softDeleteEntityFor<Todo>(todo.id);  // was: softDeleteEntity('Todo', todo.id)

// pendingCount (unchanged — string-based, internal API)
final pending = await adapter.fetchPendingEntries('Todo', 9999);
```

The same pattern applies to `category_providers.dart` with `TodoCategory`.

---

## execution order

1. `type_utils.dart` — export from barrel
2. `sync_config.dart` — new fields, validation, `types` getter
3. `sync_queue_entry.dart` — generic `<T>`, `T data`, derived fields
4. `local_adapter.dart` — new interface + extension
5. `in_memory_local_adapter.dart` — implement new interface
6. `sync_pusher.dart` — read from config, use `entry.data`
7. `sync_puller.dart` — remove dead field
8. `sync_engine.dart` — remove redundant params
9. `universal_sync.dart` — remove init/fields
10. all test files — adapt to new API
11. example app — adapt to new API
12. `dart analyze` + `dart test` + `dart format .`

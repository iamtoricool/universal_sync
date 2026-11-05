# Writing an adapter

An adapter is a pure-Dart package that implements `SyncTransport` and maps its
backend to the wire protocol in [protocol.md](protocol.md). It must not depend
on Flutter or on `universal_sync` internals.

## Skeleton

```dart
import 'package:universal_sync/universal_sync.dart';

final class MyBackendTransport extends SyncTransport {
  MyBackendTransport(this.client);

  final MyBackendClient client;

  @override
  SyncTransportCapabilities get capabilities => const SyncTransportCapabilities(
        serverTimestamps: true,
        tombstones: true,
        idempotency: true,
        deliveryCertainty: true,
        cursors: {CursorKind.opaque},
      );

  @override
  Future<PushOutcome> push(PushBatch batch) async {
    final acks = <ChangeAck>[];
    for (final change in batch.changes) {
      try {
        final row = switch (change.kind) {
          SyncChangeKind.upsert =>
            await client.upsert(batch.entity.table, change.row),
          SyncChangeKind.update =>
            await client.update(batch.entity.table, change.key, change.delta!),
          SyncChangeKind.delete =>
            await client.delete(batch.entity.table, change.key),
        };
        acks.add(ChangeAck.applied(change.sequence, serverRow: row));
      } on MyHttpError catch (error) {
        acks.add(ChangeAck.rejected(
          change.sequence,
          _classify(error),
        ));
      }
    }
    return PushOutcome(acks);
  }

  @override
  Future<PullPage> pull(PullPageRequest request) async {
    final page = await client.changes(
      table: request.entity.table,
      cursor: (request.cursor as OpaqueCursor?)?.token,
      limit: request.limit,
    );
    return PullPage(
      rows: page.rows,
      deletedKeys: page.deletedKeys,
      nextCursor: OpaqueCursor(page.cursor),
      hasMore: page.hasMore,
    );
  }

  @override
  Future<void> close() => client.close();

  SyncFailure _classify(MyHttpError error) => switch (error.status) {
        401 || 403 => AuthFailure(error.message),
        404 => const PermanentFailure('row does not exist'),
        409 => RevisionConflict(error.message, serverRow: error.serverRow),
        429 => RateLimited(error.message, retryAfter: error.retryAfter),
        >= 500 => TransientFailure(error.message), // maybeApplied by default
        _ => ForbiddenFailure(error.message),
      };
}
```

## Rules

1. **Never leak backend exceptions.** Every rejection is a `SyncFailure`
   variant; the engine never inspects messages.
2. **Delivery certainty is a promise.** Report `notSent` only when the request
   provably never reached the server. Default is `maybeApplied`.
3. **Echo applied rows.** `ChangeAck.applied(..., serverRow: row)` for any entity
   with server-managed columns (timestamps, defaults, generated ids).
4. **Idempotent deletes.** `delete` of a missing row is `applied`.
5. **Cursor + tombstones.** Keep a server-side change log (or `updated_at` +
   tombstone table). Return `deletedKeys` for removals, and never let a page
   boundary skip rows with equal timestamps.
6. **Batching.** Respect the engine's per-request size limits. A single entity
   per `push` call; use `pushMany` only if the backend is truly atomic.
7. **Auth.** Map expired tokens to `AuthFailure`; the engine stops the drain and
   emits `AuthRequired`, and the app re-authenticates.

## Testing

`package:universal_sync/testing.dart` provides:

- `FakeTransport` — reference implementation and failure injection.
- `SyncTestHarness` — Drift database + engine + fake server.

Recommended adapter test matrix:

| Test | Expectation |
|---|---|
| duplicate `idempotencyKey` | second send acked, no duplicate row |
| delete missing row | `applied` |
| timeout/5xx | `maybeApplied` transient |
| airplane mode | `notSent` (row stays coalescible) |
| expired token | `AuthFailure` |
| two pages, equal `updated_at` | no row skipped |
| delete while paging | `deletedKeys` contains the key |
| server-generated `updated_at` | returned through `serverRow` |
| large batch | respects the engine's byte budget |

## Capability matrix

| Capability | Required when |
|---|---|
| `serverTimestamps` | any entity declares `serverManagedColumns` |
| `tombstones` | deletes must sync down |
| `idempotency` | backend can dedupe retries (recommended) |
| `atomicMultiEntity` | `pushMany` is implemented atomically |
| `deliveryCertainty` | the adapter can prove `notSent` |
| `cursors` | at least one of `opaque` / `keyset` |

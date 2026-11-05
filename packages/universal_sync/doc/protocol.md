# Wire protocol

This document is the contract between `universal_sync` and a
`SyncTransport` implementation. Adapter packages must follow it exactly; the
engine validates what it can and reports `TransportContractViolation` otherwise.

## Rows

- A row is a JSON object keyed by **SQL column names** (`updated_at`, not
  `updatedAt`).
- `DateTime` → ISO-8601 UTC string; `Uint8List` → base64; enums → name
  (`enumName`) or index (`enumIndex`); `null` stays `null`.
- Pull pages contain **full rows** (all non-generated columns). Partial rows are
  a protocol error: applying them would null out local columns.
- Push payloads omit `SyncEntityRef.serverManagedColumns`.

## Push

`SyncTransport.push(PushBatch)` receives changes for exactly one entity,
ordered by local sequence.

```dart
final class SyncChange {
  final int sequence;                 // ack correlation
  final SyncChangeKind kind;          // upsert | update | delete
  final String idempotencyKey;        // '<installId>:<sequence>'
  final Map<String, Object?> key;     // primary-key columns, always present
  final Map<String, Object?> row;     // full after-image (upsert)
  final Map<String, Object?>? delta;  // changed columns only (update)
}
```

Rules:

1. `upsert`, `update` and `delete` must be idempotent. A retried `delete` for a
   missing row is `ChangeAck.applied`, never an error.
2. Adapters dedupe on `(entity, idempotencyKey)` when the backend allows it.
3. Return one `ChangeAck` per change. Missing, duplicated or unknown sequences
   are a contract violation; the engine releases the batch and retries.
4. `ChangeAck.applied` must include `serverRow` for entities that declare
   server-managed columns. `serverRow` is written back locally.
5. `ChangeStatus.superseded` means the server already holds a newer state for
   the record; the engine drops the change without error.
6. Failures are mapped to the sealed `SyncFailure` hierarchy. Never throw
   strings or backend exceptions through the contract.

### Delivery certainty

`SyncFailure.certainty` tells the engine whether the request may have been
applied:

- `DeliveryCertainty.notSent` — provably never reached the server (offline,
  DNS, connection refused, rate limited before processing). The change stays
  coalescible, so an airplane-mode create/update/delete can collapse to a
  single request.
- `DeliveryCertainty.maybeApplied` (default) — timeout, reset after write, 5xx.
  The change becomes immutable and replays as-is.

Misreporting `notSent` can drop an update. Only report it when the adapter can
prove nothing was delivered.

## Pull

`SyncTransport.pull(PullPageRequest)` returns one page:

```dart
final class PullPage {
  final List<Map<String, Object?>> rows;   // full after-images
  final List<List<Object?>> deletedKeys;   // PK value lists of tombstones
  final SyncCursor? nextCursor;
  final bool hasMore;                      // true → engine requests again
}
```

- Cursors are opaque strings (`OpaqueCursor`) or a keyset of
  `(updatedAt, key)` (`KeysetCursor`). The engine persists them and never
  derives one from the device clock.
- If `hasMore` is true, `nextCursor` must be non-null.
- Deletes must be reported through `deletedKeys`; the engine records a remote
  tombstone even when the row is absent locally.
- Rows must be ordered consistently with the cursor so a page boundary cannot
  skip a row. For keyset cursors, break ties on the primary key.
- The response must be stable enough that replaying a page is harmless; the
  engine applies pages idempotently.

## Capabilities

```dart
final class SyncTransportCapabilities {
  final bool serverTimestamps;
  final bool tombstones;
  final bool idempotency;
  final bool atomicMultiEntity;
  final bool deliveryCertainty;
  final Set<CursorKind> cursors;
}
```

`UniversalSync.open()` cross-checks capabilities against registered entities and
throws `SyncCapabilityMismatch` when a requirement cannot be met (for example,
an entity with server-managed columns on a transport without
`serverTimestamps`).

## Adapter checklist

1. Map backend/HTTP errors to `AuthFailure`, `ForbiddenFailure`, `RateLimited`,
   `TransientFailure`, `RevisionConflict`, `PermanentFailure` or
   `UnknownFailure` — never string matching in the engine.
2. Update the backend revision/`updated_at` server-side and echo the applied row.
3. Keep a tombstone or change-log table so deletes and equal timestamps are
   representable.
4. Honour the batch size and byte budget supplied by the engine.
5. Run the conformance expectations in `lib/testing.dart` against your
   implementation.

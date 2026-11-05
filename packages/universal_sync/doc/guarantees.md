# Guarantees

## Delivery

- **At-least-once push.** A change is retried until acknowledged or parked.
  `upsert` / `update` / `delete` are idempotent, and `idempotencyKey` protects
  server-side dedupe.
- **Per-key causal ordering.** A change is claimable only when no older
  pending/inflight change exists for the same `(entity, key)`. Reordering across
  keys/entities is possible and is not compensated for.
- **No silent data loss.** Permanent failures move to `us_dead_letters`; the app
  decides with `retryParked()` / `discardParked()`.
- **Crash safety.** The cursor commits in the same transaction as the page it
  describes; outbox rows are leased and recovered at `open()`.

## Offline editing

| Offline actions | Result |
|---|---|
| create + update | one `upsert` with the final row |
| update + update | one `update` with merged deltas |
| create + update + delete | one idempotent `delete` (default) |
| same sequence with `cancelUnsyncedCreateThenDelete: true` | no request; tombstone cleared |
| any change while a sent row exists | a new pending row, ordered after it |

`TransientFailure(notSent)` keeps a row coalescible. `maybeApplied` makes it
immutable so a timed-out request is never silently rewritten.

## Deletes and resurrection

- A local delete records a tombstone before the push is queued.
- The tombstone suppresses remote rows for that key **while it exists**, not
  only while unacked. It is purged only after `acked_at` and
  `tombstoneRetention`, gated by the entity cursor.
- A remote tombstone is recorded even when the local row is absent, so a stale
  replica cannot resurrect it.
- `delete → upsert` clears the local tombstone.

## Conflicts

`NewestWins` compares the entity's `updated_at`; missing timestamps fall back to
the server. `ServerWins` applies the remote row and drops pending local changes
for the key. `ClientWins` keeps the local change pending. `ManualConflicts`
stores both versions in `us_conflicts` and leaves the local change pending until
`resolveConflict()` is called.

A conflict is only detected when the record has a pending outbox entry. Reads,
joins and writes made directly through Drift are invisible to the engine unless
`markDirty()` is called.

## Sessions

- With an `owner` column, writes are checked against `SyncSession.userId`;
  mismatches throw `OwnershipViolation`.
- Pulled rows owned by another user are skipped and reported.
- `purgeOnUserChange` (default true) wipes outbox, cursors, tombstones,
  conflicts, dead letters and resets bootstrap on a user change.
- `purge(localData: true)` additionally deletes every registered local table.

## Schema

- Package tables are installed transactionally, versioned in `us_meta`, and
  validated against `PRAGMA table_info`.
- A database schema newer than the package is refused (`SyncSchemaTooNew`);
  downgrades are never attempted.
- The consumer's `@DriftDatabase`, `schemaVersion` and generated code are not
  modified.
- `ON DELETE CASCADE` on a synced table bypasses the facade; the engine does not
  see those deletes. Avoid cascades into synced tables or delete through the
  facade.

## Limits

- Ordering is per key, not global.
- Pull pages are delta-based; a full remote snapshot is not available.
- `pushConcurrency` / `pullConcurrency` are accepted but currently sequential.
- Reconcile mode (detecting writes that bypassed the facade) is not implemented;
  use the typed facade or `markDirty()`.

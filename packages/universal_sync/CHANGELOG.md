# Changelog

## 0.1.0 — MVP

First working release of the Drift-native sync core.

- **Contracts**: `SyncTransport` + `SyncTransportCapabilities`, typed
  `PushBatch`/`SyncChange`/`PushOutcome`/`ChangeAck`, `PullPageRequest` /
  `PullPage`, sealed `SyncCursor` (`OpaqueCursor`, `KeysetCursor`), sealed
  `SyncFailure` with delivery certainty and JSON round-tripping, injectable
  `SyncClock`/`SyncSession`.
- **Schema**: package-owned `us_meta`, `us_outbox`, `us_cursors`,
  `us_tombstones`, `us_conflicts`, `us_dead_letters`, installed transactionally
  into the consumer's database with version checks and column validation.
- **Journal**: coalescing (create+update, update+update, create+delete →
  delete), delivery-certainty release, per-key head-of-line ordering, atomic
  claim, supersede-on-ack, dead letters, tombstone lifecycle, cursors.
- **Engine**: single-flight `drain`, batched/paginated `pull`, conflict
  policies (`newestWins`, `serverWins`, `clientWins`, manual), durable
  conflicts with resolution, typed events, status/diagnostics, recovery at
  `open()`, bootstrap policies, purge/retry/discard.
- **Typed write facade**: `create`, `save`, `patch`, `remove`, `saveAll`,
  `removeMany`, `markDirty`, `find`, `watch`, `query` — all atomic with the
  outbox inside one Drift transaction.
- **Code generation**: `@Syncable` / `@SyncDatabase` via
  `universal_sync_builder`, generating typed `SyncEntity` descriptors,
  `db.syncEntities`, `sync.<table>` extensions and `openSync(...)`.
- **Testing utilities**: `FakeTransport`, `SyncTestHarness`.
- **Docs**: README, protocol, guarantees, adapter guide.

### Known gaps (next milestones)

- Reconcile mode, isolate runner, background scheduling hooks (roadmap P6).
- Backend adapters (intentionally separate packages, e.g.
  `universal_sync_supabase`).
- `pushConcurrency` / `pullConcurrency` are accepted but currently run
  sequentially.

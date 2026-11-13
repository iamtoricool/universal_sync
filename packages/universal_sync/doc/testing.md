# Testing

## Running

```bash
# All packages
dart pub get
dart analyze --fatal-infos
(cd packages/universal_sync && dart test)
(cd packages/universal_sync_builder && dart test)
(cd examples/drift_app && dart run build_runner build && dart test)

# Coverage (95% line gate, non-generated sources only)
./tool/coverage.sh

# Builder negative fixtures (expects each invalid schema to fail)
./tool/verify_builder_failures.sh
```

## What the suite covers

| Area | File |
|---|---|
| Contracts, cursors, failures, backoff, clocks | `test/contracts_test.dart` |
| Outbox coalescing, claims, retries, tombstones, conflicts | `test/journal_test.dart` |
| Drain acknowledgements, retries, parking, batching, lifecycle | `test/engine_drain_edge_test.dart` |
| Pull pagination, malformed rows, conflicts, deletions | `test/engine_pull_edge_test.dart` |
| Typed facade, stamping, ownership, payload limits | `test/facade_test.dart` |
| Bootstrap policies, user changes, dead letters | `test/bootstrap_test.dart` |
| Entity/key codec internals | `test/entity_test.dart` |
| Schema install, version and column validation | `test/schema_test.dart` |
| Shipped test doubles and harness | `test/testing_utils_test.dart` |
| Offline convergence and crash/replay invariants | `test/property/` |

The property suites run seeded random operation sequences (create/update/delete
across keys) and assert that the server ends in exactly the same state as the
local database. They also cover lost acknowledgements, a crash between pull
pages, and recovery of an expired lease by a new engine.

## Coverage policy

`tool/check_coverage.dart` enforces **95% line coverage** over
`packages/universal_sync/lib`, excluding generated schema code
(`sync_tables.dart`, `sync_tables.g.dart`). Current: **99.2%**.

Deliberately excluded from the metric or left untested:

- generated Drift code (`*.g.dart`) and generated adapters (`*.sync.dart`);
- random jitter distribution (bounded-range test only);
- the web-specific integer path in the key hash (same code path on the VM,
  covered by known vectors);
- defensive branches that require an inconsistent internal state (for example a
  pending entry disappearing between two statements of the same transaction);
- the periodic follow-up emissions of `watchConflicts` (the first emission is
  tested).

## Generator testing

`build_test` cannot resolve annotations inside synthetic packages, so the
generator is verified by:

1. the real `examples/drift_app` fixture (annotations → build_runner →
   generated registry → synced rows), with a committed golden;
2. `tool/verify_builder_failures.sh`, which builds a temporary package for each
   invalid schema and asserts the exact diagnostic.

The negative fixtures cover: key not a column, unsupported key type,
non-DateTime `updatedAt`, non-String `owner`, unknown `serverManagedColumns`,
blob columns, tables without columns, and a missing `@DriftDatabase`.

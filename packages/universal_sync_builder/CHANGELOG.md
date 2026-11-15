# Changelog

## 0.1.0

Initial release.

- `@SyncDatabase` / `@Syncable` code generation.
- Typed `SyncEntity` descriptors using Drift's `toJson`/`fromJson`.
- Generated registry (`db.syncEntities`), engine extensions (`sync.tasks`) and
  `openSync(...)`.
- Column names resolved from table info at runtime; ISO-8601 date-time wire
  encoding.
- Scans hand-written `lib/**.dart` libraries only; generated files are excluded
  through `generate_for` defaults and non-library inputs are detected with the
  resolver instead of path heuristics.

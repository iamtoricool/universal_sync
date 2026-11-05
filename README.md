# universal_sync

A Dart monorepo for the `universal_sync` ecosystem: a Drift-native,
compile-time-typed, offline-first sync core and its build tooling.

Managed with **Dart workspaces** (`pubspec.yaml` → `workspace`), not Melos.

## Packages

| Package | Description |
|---|---|
| [`packages/universal_sync`](packages/universal_sync) | Runtime: contracts, schema, journal, engine, typed facade, testing utilities |
| [`packages/universal_sync_builder`](packages/universal_sync_builder) | `build_runner` generator for `@Syncable` / `@SyncDatabase` |

The [`examples/drift_app`](examples/drift_app) workspace member is the
end-to-end fixture: annotations in, generated `sync.tasks` API out, no
hand-written entity code.

Backend adapters are separate packages that implement `SyncTransport`; none are
bundled here by design.

## Development

```bash
dart pub get                 # one resolution for the whole workspace
dart analyze --fatal-infos
dart test                    # run inside a package, e.g.:
(cd packages/universal_sync && dart test)
(cd packages/universal_sync_builder && dart test)
(cd examples/drift_app && dart run build_runner build && dart test)
```

Generated files (`*.g.dart`, `*.sync.dart`) are excluded from the format gate:

```bash
find packages examples \
  -path '*/.dart_tool' -prune -o \
  -path '*/build' -prune -o \
  -name '*.dart' ! -name '*.g.dart' ! -name '*.sync.dart' -print0 \
  | xargs -0 dart format --output=none --set-exit-if-changed
```

## Releasing

Version and tag the runtime package:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The publish workflow runs from `packages/universal_sync`, verifies the tag
against that package's `pubspec.yaml`, and publishes via pub.dev trusted
publishing (OIDC).

## License

MIT — see [LICENSE](LICENSE).

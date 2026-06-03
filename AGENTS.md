# universal_sync

> ORM-agnostic offline-first sync engine for Dart & Flutter.
> Zero runtime dependencies. Pure Dart immutable models.
> Built around a 9-method `LocalAdapter` interface.

## Architecture

```
┌──────────────────────────────────────────────┐
│                universal_sync                  │
│                                                │
│  ┌──────────────┐    ┌──────────────────────┐  │
│  │ LocalAdapter  │    │   RemoteAdapter      │  │
│  │ (interface)   │    │ push() / pull()      │  │
│  └──────┬────────┘    └──────────┬───────────┘  │
│         │                       │               │
│         ▼                       ▼               │
│  ┌──────────────────────────────────────────┐   │
│  │              SyncEngine                   │   │
│  │  SyncPusher + SyncPuller + State          │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │         UniversalSync (facade)            │   │
│  └──────────────────────────────────────────┘   │
└──────────────────────────────────────────────┘
```

## Commands

```bash
dart pub get              # install deps
dart analyze              # static analysis (recommended lints)
dart test                 # run all tests
dart test test/<path>     # run single test file
dart format .             # format code
```

## Phase Reference

| Phase | What | Depends on |
|-------|------|------------|
| 0 — Setup | Scaffold, deps, dirs, tooling | Nothing |
| 1 — Models | SyncEntity, SyncQueueEntry, SyncCheckpoint, SyncState, SyncResult | Phase 0 |
| 2 — Adapters | LocalAdapter, RemoteAdapter, InMemoryLocalAdapter | Phase 1 |
| 3 — Internal | type_utils | Phase 0 (parallel with 2) |
| 4 — Conflict | ConflictResolver, ServerWins, ClientWins | Phase 1 |
| 5 — Pusher | SyncPusher | Phases 2, 3, 4 |
| 6 — Puller | SyncPuller | Phases 2, 3 |
| 7 — Engine | SyncEngine (orchestrator + state) | Phases 5, 6 |
| 8 — Facade | UniversalSync entry point | Phase 7 |

See `ai_docs/TASK.md` for detailed task breakdown.

## Coding Conventions

- **Immutability**: All models use `final` fields and `const` constructors with `copyWith`.
- **No code generation**: Zero annotations, no `build_runner`.
- **No comments in implementation code**: Keep source clean; document in separate files.
- **Error handling**: Throw typed `ArgumentError`/`StateError`; never `print()` in library code.
- **No runtime dependencies**: Core package must remain dependency-free.
- **Page width**: 120 characters.

## Testing Conventions

- Use `mocktail` for `RemoteAdapter` mocks.
- Use `InMemoryLocalAdapter` as the concrete `LocalAdapter` in all tests.
- Never mock `LocalAdapter` — always use `InMemoryLocalAdapter`.
- Test files mirror the `lib/src/` structure under `test/`.

## Pre-commit Checklist

1. `dart analyze` — must be clean
2. `dart test` — all tests must pass
3. `dart format .` — code must be formatted

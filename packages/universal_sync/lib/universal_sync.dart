/// A Drift-native, compile-time-typed, offline-first sync core.
///
/// This package ships the engine, contracts and schema only. Backend adapters
/// implement [SyncTransport] in separate packages.
library;

export 'src/annotations.dart';
export 'src/conflict.dart';
export 'src/contract/cancel.dart';
export 'src/contract/change.dart';
export 'src/contract/delivery.dart';
export 'src/contract/failures.dart';
export 'src/contract/pull.dart';
export 'src/contract/session.dart';
export 'src/contract/transport.dart';
export 'src/engine/universal_sync.dart';
export 'src/entity/sync_entity.dart';
export 'src/events.dart';
export 'src/journal/sync_journal.dart' show ConflictRecord, EnqueueResult, OutboxEntry;
export 'src/options.dart';
export 'src/report.dart';
export 'src/schema/schema.dart';
export 'src/sync_table.dart';

import 'package:drift/drift.dart';

import 'contract/session.dart';
import 'events.dart';
import 'journal/sync_journal.dart';
import 'options.dart';
import 'schema/schema.dart';

/// Shared dependencies used by the typed write facade and the engine.
final class SyncContext {
  const SyncContext({
    required this.db,
    required this.schema,
    required this.journal,
    required this.options,
    required this.session,
    required this.emit,
    this.onWrite,
  });

  final GeneratedDatabase db;
  final SyncSchema schema;
  final SyncJournal journal;
  final SyncOptions options;
  final SyncSession session;
  final void Function(SyncEvent event) emit;
  final void Function()? onWrite;
}

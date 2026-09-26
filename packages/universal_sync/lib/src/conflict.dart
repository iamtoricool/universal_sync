/// How the engine resolves a remote row that collides with a pending local
/// change.
sealed class ConflictPolicy {
  const ConflictPolicy();
}

/// The server version always wins. Pending local changes for the key are
/// dropped after the remote row is applied.
final class ServerWins extends ConflictPolicy {
  const ServerWins();

  @override
  String toString() => 'serverWins';
}

/// The local pending change always wins; the remote row is ignored.
final class ClientWins extends ConflictPolicy {
  const ClientWins();

  @override
  String toString() => 'clientWins';
}

/// Compare the entity's `updatedAt` values; the newer version wins. Falls back
/// to [ServerWins] when either side has no timestamp.
final class NewestWins extends ConflictPolicy {
  const NewestWins();

  @override
  String toString() => 'newestWins';
}

/// Persist the remote row in `us_conflicts` and leave the local change pending
/// until the app resolves it explicitly.
final class ManualConflicts extends ConflictPolicy {
  const ManualConflicts();

  @override
  String toString() => 'manual';
}

/// How the app resolves a stored [ConflictRecord].
sealed class ConflictResolution {
  const ConflictResolution();
}

/// Apply the server row locally and drop the pending local change.
final class AcceptServer extends ConflictResolution {
  const AcceptServer();
}

/// Keep the pending local change; the conflict is only marked resolved.
final class KeepLocal extends ConflictResolution {
  const KeepLocal();
}

/// First-run behaviour when the package is added to an app that already has
/// local rows.
sealed class SyncBootstrap {
  const SyncBootstrap();
}

/// Do nothing: the current cursor decides what is pulled.
final class SkipBootstrap extends SyncBootstrap {
  const SkipBootstrap();
}

/// Queue every existing local row as an upsert, then pull.
final class UploadLocal extends SyncBootstrap {
  const UploadLocal();
}

/// Upload local rows and pull; `updatedAt` decides conflicts through the
/// configured [ConflictPolicy]. Recommended default for existing apps.
final class MergeByUpdatedAt extends SyncBootstrap {
  const MergeByUpdatedAt();
}

/// Pull only; local rows are left untouched unless a remote row replaces them.
final class ServerWinsBootstrap extends SyncBootstrap {
  const ServerWinsBootstrap();
}

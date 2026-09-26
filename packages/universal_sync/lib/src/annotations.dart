/// Marks a Drift table as participating in `universal_sync`.
///
/// ```dart
/// @Syncable(key: #id, updatedAt: #updatedAt, owner: #userId)
/// class Tasks extends Table { ... }
/// ```
///
/// `key` must name a single non-nullable primary-key column. `updatedAt` and
/// `owner` are optional; when present the engine stamps them on writes and uses
/// them for conflict resolution and ownership checks.
final class Syncable {
  const Syncable({
    required this.key,
    this.updatedAt,
    this.owner,
    this.serverManagedColumns = const [],
    this.dataClassName,
    this.companionName,
  });

  /// Getter name of the primary key, e.g. `#id`.
  final Symbol key;

  /// Getter name of the `updated_at` column, e.g. `#updatedAt`.
  final Symbol? updatedAt;

  /// Getter name of the owner column, e.g. `#userId`.
  final Symbol? owner;

  /// Columns the server owns (timestamps, generated ids). Omitted from pushes
  /// and required in transport acks.
  final List<Symbol> serverManagedColumns;

  /// Override the generated row class name when Drift's pluralization does not
  /// match the entity (`@DataClassName` equivalent).
  final String? dataClassName;

  /// Override the generated companion class name.
  final String? companionName;
}

/// Marks a `@DriftDatabase` class whose `@Syncable` tables should receive a
/// generated registry and typed extension methods.
///
/// ```dart
/// @SyncDatabase()
/// @DriftDatabase(tables: [Tasks, Projects])
/// class AppDatabase extends _$AppDatabase { ... }
/// ```
final class SyncDatabase {
  const SyncDatabase({this.prefix = ''});

  /// Optional prefix for generated top-level symbols, useful when several
  /// synced databases live in one package.
  final String prefix;
}

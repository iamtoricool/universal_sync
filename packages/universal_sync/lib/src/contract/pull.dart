import 'dart:convert';

/// Wire-safe description of a synced entity, generated from the Drift schema.
final class SyncEntityRef {
  const SyncEntityRef({
    required this.table,
    required this.primaryKey,
    this.updatedAtColumn,
    this.ownerColumn,
    this.deletedAtColumn,
    this.serverManagedColumns = const {},
  });

  /// SQL table name.
  final String table;

  /// Ordered primary-key column names. Composite-ready.
  final List<String> primaryKey;

  final String? updatedAtColumn;
  final String? ownerColumn;
  final String? deletedAtColumn;

  /// Columns the server owns; omitted from push payloads and required in acks.
  final Set<String> serverManagedColumns;

  @override
  bool operator ==(Object other) =>
      other is SyncEntityRef &&
      other.table == table &&
      other.updatedAtColumn == updatedAtColumn &&
      other.ownerColumn == ownerColumn &&
      other.deletedAtColumn == deletedAtColumn;

  @override
  int get hashCode => Object.hash(table, updatedAtColumn, ownerColumn, deletedAtColumn);

  @override
  String toString() => 'SyncEntityRef($table)';
}

/// Wire representation of a change kind used by pseudo-rows.
enum SyncColumnKind {
  text,
  integer,
  real,
  boolean,
  dateTime,
  blob,
  enumName,
  enumIndex,
  json,
}

/// Cursor position for a pull page.
sealed class SyncCursor {
  const SyncCursor();

  Map<String, Object?> toJson();

  String encode() => jsonEncode(toJson());

  static SyncCursor? decode(String? raw) {
    if (raw == null) return null;
    final json = jsonDecode(raw);
    if (json is! Map) return null;
    return switch (json['type']) {
      'opaque' => OpaqueCursor(json['token'] as String? ?? ''),
      'keyset' => KeysetCursor(
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
        key: (json['key'] as List?)?.cast<Object?>() ?? const [],
      ),
      _ => null,
    };
  }
}

/// Server-issued opaque cursor. Preferred: immune to timestamp collisions.
final class OpaqueCursor extends SyncCursor {
  const OpaqueCursor(this.token);

  final String token;

  @override
  Map<String, Object?> toJson() => {'type': 'opaque', 'token': token};

  @override
  bool operator ==(Object other) => other is OpaqueCursor && other.token == token;

  @override
  int get hashCode => token.hashCode;

  @override
  String toString() => 'OpaqueCursor($token)';
}

/// Keyset cursor for backends that only expose `updated_at`.
final class KeysetCursor extends SyncCursor {
  const KeysetCursor({required this.updatedAt, required this.key});

  final DateTime updatedAt;

  /// Primary-key values of the last seen row (tiebreaker).
  final List<Object?> key;

  @override
  Map<String, Object?> toJson() => {
    'type': 'keyset',
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'key': key,
  };

  @override
  bool operator ==(Object other) => other is KeysetCursor && other.updatedAt == updatedAt && _sameList(other.key, key);

  @override
  int get hashCode => Object.hash(updatedAt, Object.hashAll(key));

  static bool _sameList(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'KeysetCursor($updatedAt, $key)';
}

/// Cursor kinds a transport can serve.
enum CursorKind { opaque, keyset }

/// One page request for one entity.
final class PullPageRequest {
  const PullPageRequest({
    required this.entity,
    required this.cursor,
    required this.limit,
  });

  final SyncEntityRef entity;
  final SyncCursor? cursor;
  final int limit;
}

/// One page of remote changes.
final class PullPage {
  const PullPage({
    required this.rows,
    required this.deletedKeys,
    required this.nextCursor,
    required this.hasMore,
  });

  const PullPage.empty() : rows = const [], deletedKeys = const [], nextCursor = null, hasMore = false;

  /// Full after-images keyed by SQL column name.
  final List<Map<String, Object?>> rows;

  /// Primary-key value lists of rows deleted remotely.
  final List<List<Object?>> deletedKeys;

  final SyncCursor? nextCursor;
  final bool hasMore;
}

import 'dart:convert';

import 'package:drift/drift.dart';

import '../contract/pull.dart';
import 'key_codec.dart';

/// Erased view of a typed [SyncEntity], used inside the engine.
abstract interface class SyncEntityBase {
  SyncEntityRef get ref;

  List<Object?> keyPartsFromJsonRow(Map<String, Object?> row);

  String keyJsonOfParts(List<Object?> parts);

  Uint8List keyHashOfParts(List<Object?> parts);

  Future<void> applyRemoteRow(GeneratedDatabase db, Map<String, Object?> row);

  Future<bool> deleteByParts(GeneratedDatabase db, List<Object?> parts);

  Future<Map<String, Object?>?> readLocalByParts(
    GeneratedDatabase db,
    List<Object?> parts,
  );

  Future<List<Map<String, Object?>>> readAllLocal(GeneratedDatabase db);

  Future<int> deleteAllLocal(GeneratedDatabase db);

  DateTime? updatedAtFromJson(Map<String, Object?> row);

  String? ownerFromJson(Map<String, Object?> row);

  /// Column names the adapter expects in the physical table.
  List<String> get expectedColumns;
}

/// A typed, fully described synced table.
///
/// `Tbl` is the Drift table, `Row` its data class and `Key` the primary-key
/// Dart type. Encode/decode use SQL column names, matching the wire format.
final class SyncEntity<Tbl extends Table, Row extends DataClass, Key extends Object> implements SyncEntityBase {
  const SyncEntity({
    required this.table,
    required this.keyColumns,
    required this.keyOf,
    required this.whereKey,
    required this.encode,
    required this.decode,
    required this.keyParts,
    required this.keyFromParts,
    this.keyPartsFromRow,
    this.updatedAtOf,
    this.ownerOf,
    this.updatedAtColumn,
    this.ownerColumn,
    this.stampUpdatedAt,
    this.stampOwner,
    this.serverManagedColumns = const {},
    this.expectedColumns = const [],
  });

  final TableInfo<Tbl, Row> table;

  /// Ordered primary-key column names. v1 supports exactly one entry.
  final List<String> keyColumns;

  final Key Function(Row row) keyOf;

  final Expression<bool> Function(Tbl table, Key key) whereKey;

  /// Row -> wire map keyed by SQL column name.
  final Map<String, Object?> Function(Row row) encode;

  /// Wire map -> row. Must tolerate extra server columns.
  final Row Function(Map<String, Object?> json) decode;

  final List<Object?> Function(Key key) keyParts;

  final Key Function(List<Object?> parts) keyFromParts;

  final List<Object?> Function(Map<String, Object?> row)? keyPartsFromRow;

  final DateTime? Function(Row row)? updatedAtOf;

  final String? Function(Row row)? ownerOf;

  final String? updatedAtColumn;
  final String? ownerColumn;

  /// Injects `updated_at` when the caller omitted it. Generated adapters
  /// supply this; hand-written entities may leave it null.
  final Insertable<Row> Function(Insertable<Row> companion, DateTime now)? stampUpdatedAt;

  /// Injects the session owner when the caller omitted it.
  final Insertable<Row> Function(Insertable<Row> companion, String owner)? stampOwner;

  final Set<String> serverManagedColumns;

  /// Column names the generator expects in the physical table. Used by
  /// `open()` to fail fast on schema drift.
  @override
  final List<String> expectedColumns;

  @override
  SyncEntityRef get ref => SyncEntityRef(
    table: table.actualTableName,
    primaryKey: keyColumns,
    updatedAtColumn: updatedAtColumn,
    ownerColumn: ownerColumn,
    serverManagedColumns: serverManagedColumns,
  );

  @override
  String keyJsonOfParts(List<Object?> parts) => encodeKeyJson(parts);

  @override
  Uint8List keyHashOfParts(List<Object?> parts) => keyHashOf(encodeKeyJson(parts));

  @override
  List<Object?> keyPartsFromJsonRow(Map<String, Object?> row) {
    final direct = keyPartsFromRow;
    if (direct != null) return direct(row);
    return keyParts(keyOf(decode(row)));
  }

  @override
  Future<void> applyRemoteRow(
    GeneratedDatabase db,
    Map<String, Object?> row,
  ) async {
    final decoded = decode(row);
    // Drift data classes implement Insertable<Row>; the bound only guarantees
    // DataClass, so the compiler needs the cast.
    await db.into(table).insertOnConflictUpdate(decoded as Insertable<Row>);
  }

  @override
  Future<bool> deleteByParts(GeneratedDatabase db, List<Object?> parts) async {
    final key = keyFromParts(parts);
    final deleted = await (db.delete(
      table,
    )..where((t) => whereKey(t, key))).go();
    return deleted > 0;
  }

  @override
  Future<Map<String, Object?>?> readLocalByParts(
    GeneratedDatabase db,
    List<Object?> parts,
  ) async {
    final key = keyFromParts(parts);
    final row = await (db.select(
      table,
    )..where((t) => whereKey(t, key))).getSingleOrNull();
    return row == null ? null : encode(row);
  }

  @override
  Future<List<Map<String, Object?>>> readAllLocal(GeneratedDatabase db) async {
    final rows = await db.select(table).get();
    return [for (final row in rows) encode(row)];
  }

  @override
  Future<int> deleteAllLocal(GeneratedDatabase db) => db.delete(table).go();

  @override
  DateTime? updatedAtFromJson(Map<String, Object?> row) {
    final extract = updatedAtOf;
    if (extract == null) return null;
    return extract(decode(row));
  }

  @override
  String? ownerFromJson(Map<String, Object?> row) {
    final extract = ownerOf;
    if (extract == null) return null;
    return extract(decode(row));
  }

  /// Convenience: encoded payload size in bytes.
  int payloadBytes(Map<String, Object?> row) => utf8.encode(jsonEncode(row)).length;
}

import 'package:universal_sync/universal_sync.dart';

class TodoCategory extends SyncEntity {
  @override
  final String id;
  @override
  final int version;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;
  final String name;
  final String description;
  final String color;
  final int sortOrder;

  const TodoCategory({
    required this.id,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.name,
    this.description = '',
    this.color = '#1976D2',
    this.sortOrder = 0,
  });

  TodoCategory copyWith({
    String? id,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
    String? name,
    String? description,
    String? color,
    int? sortOrder,
  }) {
    return TodoCategory(
      id: id ?? this.id,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as DateTime?,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory TodoCategory.fromJson(Map<String, dynamic> json) {
    return TodoCategory(
      id: json['id'] as String,
      version: json['version'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      color: json['color'] as String? ?? '#1976D2',
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  @override
  Map<String, dynamic> toSyncJson() {
    return {
      'id': id,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'name': name,
      'description': description,
      'color': color,
      'sortOrder': sortOrder,
    };
  }
}

const _unset = Object();

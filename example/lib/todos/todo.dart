import 'package:universal_sync/universal_sync.dart';

class Todo extends SyncEntity {
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
  final String title;
  final String description;
  final bool isDone;

  const Todo({
    required this.id,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.title,
    this.description = '',
    this.isDone = false,
  });

  Todo copyWith({
    String? id,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
    String? title,
    String? description,
    bool? isDone,
  }) {
    return Todo(
      id: id ?? this.id,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as DateTime?,
      title: title ?? this.title,
      description: description ?? this.description,
      isDone: isDone ?? this.isDone,
    );
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      version: json['version'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      isDone: json['isDone'] is int
          ? (json['isDone'] as int) == 1
          : json['isDone'] as bool,
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
      'title': title,
      'description': description,
      'isDone': isDone,
    };
  }
}

const _unset = Object();

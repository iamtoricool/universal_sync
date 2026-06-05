import 'package:universal_sync/universal_sync.dart';

class TestEntity extends SyncEntity {
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

  TestEntity({
    required this.id,
    this.version = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : deletedAt = null,
       createdAt = createdAt ?? DateTime(2024),
       updatedAt = updatedAt ?? DateTime(2024);

  @override
  Map<String, dynamic> toSyncJson() => {
    'id': id,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TestEntity.fromJson(Map<String, dynamic> json) => TestEntity(
    id: json['id'] as String,
    version: json['version'] as int? ?? 0,
  );
}

class Product extends SyncEntity {
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

  Product({
    required this.id,
    this.version = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.name = '',
  }) : deletedAt = null,
       createdAt = createdAt ?? DateTime(2024),
       updatedAt = updatedAt ?? DateTime(2024);

  @override
  Map<String, dynamic> toSyncJson() => {
    'id': id,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'name': name,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    version: json['version'] as int? ?? 0,
    name: json['name'] as String? ?? '',
  );
}

class Customer extends SyncEntity {
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
  final String email;

  Customer({
    required this.id,
    this.version = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.email = '',
  }) : deletedAt = null,
       createdAt = createdAt ?? DateTime(2024),
       updatedAt = updatedAt ?? DateTime(2024);

  @override
  Map<String, dynamic> toSyncJson() => {
    'id': id,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'email': email,
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    version: json['version'] as int? ?? 0,
    email: json['email'] as String? ?? '',
  );
}

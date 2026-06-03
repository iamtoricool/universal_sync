import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

class _TestEntity extends SyncEntity {
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

  _TestEntity({
    required this.id,
    this.name = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : version = 0,
       deletedAt = null,
       createdAt = createdAt ?? DateTime(2024),
       updatedAt = updatedAt ?? DateTime(2024);

  @override
  Map<String, dynamic> toSyncJson() => {'id': id, 'version': version, 'name': name};
}

void main() {
  group('ConflictContext', () {
    test('stores local, remote, and operation', () {
      final local = _TestEntity(id: '1', name: 'local');
      final remote = _TestEntity(id: '1', name: 'remote');
      final context = ConflictContext<_TestEntity>(
        local: local,
        remote: remote,
        operation: SyncOperation.update,
      );

      expect(context.local, same(local));
      expect(context.remote, same(remote));
      expect(context.operation, SyncOperation.update);
    });
  });

  group('ConflictResolution', () {
    test('acceptRemote has strategy acceptRemote and correct entity', () {
      final entity = _TestEntity(id: '1', name: 'remote');
      final resolution = ConflictResolution.acceptRemote(entity);

      expect(resolution.strategy, ConflictStrategy.acceptRemote);
      expect(resolution.entity, same(entity));
    });

    test('acceptLocal has strategy acceptLocal and correct entity', () {
      final entity = _TestEntity(id: '1', name: 'local');
      final resolution = ConflictResolution.acceptLocal(entity);

      expect(resolution.strategy, ConflictStrategy.acceptLocal);
      expect(resolution.entity, same(entity));
    });

    test('merge has strategy merge and correct entity', () {
      final entity = _TestEntity(id: '1', name: 'merged');
      final resolution = ConflictResolution.merge(entity);

      expect(resolution.strategy, ConflictStrategy.merge);
      expect(resolution.entity, same(entity));
    });
  });

  group('ServerWinsResolver', () {
    test('returns acceptRemote with remote entity', () {
      final local = _TestEntity(id: '1', name: 'local');
      final remote = _TestEntity(id: '1', name: 'remote');
      final context = ConflictContext<_TestEntity>(
        local: local,
        remote: remote,
        operation: SyncOperation.update,
      );

      final resolver = ServerWinsResolver<_TestEntity>();
      final resolution = resolver.resolve(context);

      expect(resolution.strategy, ConflictStrategy.acceptRemote);
      expect(resolution.entity, same(remote));
    });
  });

  group('ClientWinsResolver', () {
    test('returns acceptLocal with local entity', () {
      final local = _TestEntity(id: '1', name: 'local');
      final remote = _TestEntity(id: '1', name: 'remote');
      final context = ConflictContext<_TestEntity>(
        local: local,
        remote: remote,
        operation: SyncOperation.update,
      );

      final resolver = ClientWinsResolver<_TestEntity>();
      final resolution = resolver.resolve(context);

      expect(resolution.strategy, ConflictStrategy.acceptLocal);
      expect(resolution.entity, same(local));
    });
  });
}

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

  group('MergeResolver (custom)', () {
    test('resolve can produce a merged entity with fields from both local and remote', () {
      final resolver = _MergeResolver();
      final local = _TestEntity(id: '1', name: 'local');
      final remote = _TestEntity(id: '1', name: 'remote');
      final context = ConflictContext<_TestEntity>(
        local: local,
        remote: remote,
        operation: SyncOperation.update,
      );

      final resolution = resolver.resolve(context);
      expect(resolution.strategy, ConflictStrategy.merge);
      expect(resolution.entity.name, 'local-remote');
    });

    test('merged entity preserves selected fields from each side', () {
      final resolver = _MergeResolver();
      final local = _TestEntity(id: '1', name: 'A');
      final remote = _TestEntity(id: '1', name: 'B');
      final context = ConflictContext<_TestEntity>(
        local: local,
        remote: remote,
        operation: SyncOperation.update,
      );

      final resolution = resolver.resolve(context);
      expect(resolution.strategy, ConflictStrategy.merge);
      expect(resolution.entity.name, 'A-B');
    });
  });

  group('ServerWinsResolver', () {
    test('returns acceptRemote strategy', () {
      final resolver = ServerWinsResolver<_TestEntity>();
      final context = ConflictContext<_TestEntity>(
        local: _TestEntity(id: '1', name: 'local'),
        remote: _TestEntity(id: '1', name: 'remote'),
        operation: SyncOperation.update,
      );
      expect(resolver.resolve(context).strategy, ConflictStrategy.acceptRemote);
    });

    test('returns the remote entity', () {
      final resolver = ServerWinsResolver<_TestEntity>();
      final remote = _TestEntity(id: '1', name: 'remote');
      final context = ConflictContext<_TestEntity>(
        local: _TestEntity(id: '1', name: 'local'),
        remote: remote,
        operation: SyncOperation.update,
      );
      expect(resolver.resolve(context).entity, same(remote));
    });

    test('ignores the local entity', () {
      final resolver = ServerWinsResolver<_TestEntity>();
      final context = ConflictContext<_TestEntity>(
        local: _TestEntity(id: '1', name: 'local', createdAt: DateTime(2023)),
        remote: _TestEntity(id: '1', name: 'remote', createdAt: DateTime(2024)),
        operation: SyncOperation.update,
      );
      final resolution = resolver.resolve(context);
      expect(resolution.entity.name, 'remote');
      expect(resolution.entity.createdAt, DateTime(2024));
    });

    test('works for insert operation', () {
      final resolver = ServerWinsResolver<_TestEntity>();
      final context = ConflictContext<_TestEntity>(
        local: _TestEntity(id: '1', name: 'local'),
        remote: _TestEntity(id: '1', name: 'remote'),
        operation: SyncOperation.insert,
      );
      expect(resolver.resolve(context).strategy, ConflictStrategy.acceptRemote);
    });

    test('works for update operation', () {
      final resolver = ServerWinsResolver<_TestEntity>();
      final context = ConflictContext<_TestEntity>(
        local: _TestEntity(id: '1', name: 'local'),
        remote: _TestEntity(id: '1', name: 'remote'),
        operation: SyncOperation.update,
      );
      expect(resolver.resolve(context).strategy, ConflictStrategy.acceptRemote);
    });

    test('works for delete operation', () {
      final resolver = ServerWinsResolver<_TestEntity>();
      final context = ConflictContext<_TestEntity>(
        local: _TestEntity(id: '1', name: 'local'),
        remote: _TestEntity(id: '1', name: 'remote'),
        operation: SyncOperation.delete,
      );
      expect(resolver.resolve(context).strategy, ConflictStrategy.acceptRemote);
    });
  });

  group('ClientWinsResolver', () {
    test('returns acceptLocal strategy', () {
      final resolver = ClientWinsResolver<_TestEntity>();
      final context = ConflictContext<_TestEntity>(
        local: _TestEntity(id: '1', name: 'local'),
        remote: _TestEntity(id: '1', name: 'remote'),
        operation: SyncOperation.update,
      );
      expect(resolver.resolve(context).strategy, ConflictStrategy.acceptLocal);
    });

    test('returns the local entity', () {
      final resolver = ClientWinsResolver<_TestEntity>();
      final local = _TestEntity(id: '1', name: 'local');
      final context = ConflictContext<_TestEntity>(
        local: local,
        remote: _TestEntity(id: '1', name: 'remote'),
        operation: SyncOperation.update,
      );
      expect(resolver.resolve(context).entity, same(local));
    });

    test('ignores the remote entity', () {
      final resolver = ClientWinsResolver<_TestEntity>();
      final context = ConflictContext<_TestEntity>(
        local: _TestEntity(id: '1', name: 'local', createdAt: DateTime(2023)),
        remote: _TestEntity(id: '1', name: 'remote', createdAt: DateTime(2024)),
        operation: SyncOperation.update,
      );
      final resolution = resolver.resolve(context);
      expect(resolution.entity.name, 'local');
      expect(resolution.entity.createdAt, DateTime(2023));
    });

    test('works for insert operation', () {
      final resolver = ClientWinsResolver<_TestEntity>();
      final context = ConflictContext<_TestEntity>(
        local: _TestEntity(id: '1', name: 'local'),
        remote: _TestEntity(id: '1', name: 'remote'),
        operation: SyncOperation.insert,
      );
      expect(resolver.resolve(context).strategy, ConflictStrategy.acceptLocal);
    });

    test('works for update operation', () {
      final resolver = ClientWinsResolver<_TestEntity>();
      final context = ConflictContext<_TestEntity>(
        local: _TestEntity(id: '1', name: 'local'),
        remote: _TestEntity(id: '1', name: 'remote'),
        operation: SyncOperation.update,
      );
      expect(resolver.resolve(context).strategy, ConflictStrategy.acceptLocal);
    });

    test('works for delete operation', () {
      final resolver = ClientWinsResolver<_TestEntity>();
      final context = ConflictContext<_TestEntity>(
        local: _TestEntity(id: '1', name: 'local'),
        remote: _TestEntity(id: '1', name: 'remote'),
        operation: SyncOperation.delete,
      );
      expect(resolver.resolve(context).strategy, ConflictStrategy.acceptLocal);
    });
  });
}

class _MergeResolver implements ConflictResolver<_TestEntity> {
  @override
  ConflictResolution<_TestEntity> resolve(ConflictContext<_TestEntity> context) {
    final merged = _TestEntity(
      id: context.local.id,
      name: '${context.local.name}-${context.remote.name}',
    );
    return ConflictResolution.merge(merged);
  }
}

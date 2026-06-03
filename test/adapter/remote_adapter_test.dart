// ignore_for_file: use_null_aware_elements

import 'package:test/test.dart';
import 'package:universal_sync/src/adapter/remote_adapter.dart';
import 'package:universal_sync/src/model/sync_queue_entry.dart';

Map<String, dynamic> _resultJson(
  String outcome, {
  String? entryId,
  int? serverSequence,
  Map<String, dynamic>? serverPayload,
  String? errorMessage,
}) {
  return {
    'entryId': entryId ?? 'e1',
    'outcome': outcome,
    if (serverSequence != null) 'serverSequence': serverSequence,
    if (serverPayload != null) 'serverPayload': serverPayload,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };
}

void main() {
  group('PushEntry', () {
    test('constructor stores fields', () {
      final entry = PushEntry(
        id: 'e1',
        entityType: 'todo',
        entityId: 't1',
        operation: SyncOperation.insert,
        payload: '{}',
        localSequence: 1,
      );
      expect(entry.id, 'e1');
      expect(entry.entityType, 'todo');
      expect(entry.entityId, 't1');
      expect(entry.operation, SyncOperation.insert);
      expect(entry.payload, '{}');
      expect(entry.localSequence, 1);
    });

    test('toJson produces correct map', () {
      final entry = PushEntry(
        id: 'e1',
        entityType: 'todo',
        entityId: 't1',
        operation: SyncOperation.insert,
        payload: '{"title":"hello"}',
        localSequence: 1,
      );
      final json = entry.toJson();
      expect(json['id'], 'e1');
      expect(json['entityType'], 'todo');
      expect(json['operation'], 'insert');
      expect(json['payload'], '{"title":"hello"}');
      expect(json['localSequence'], 1);
    });
  });

  group('PushRequest', () {
    test('toJson produces correct map', () {
      final entry = PushEntry(
        id: 'e1',
        entityType: 'todo',
        entityId: 't1',
        operation: SyncOperation.update,
        payload: '{}',
        localSequence: 2,
      );
      final request = PushRequest([entry]);
      final json = request.toJson();
      expect(json['entries'], isA<List>());
      expect((json['entries'] as List).length, 1);
    });
  });

  group('SyncEntryResult', () {
    test('accepted has outcome accepted and serverSequence', () {
      final result = SyncEntryResult.accepted(entryId: 'e1', serverSequence: 10);
      expect(result.outcome, SyncOutcome.accepted);
      expect(result.serverSequence, 10);
      expect(result.serverPayload, isNull);
      expect(result.errorMessage, isNull);
    });

    test('conflicted has outcome conflicted and serverPayload', () {
      final payload = {'title': 'server version'};
      final result = SyncEntryResult.conflicted(entryId: 'e1', serverPayload: payload);
      expect(result.outcome, SyncOutcome.conflicted);
      expect(result.serverPayload, payload);
      expect(result.serverSequence, isNull);
      expect(result.errorMessage, isNull);
    });

    test('rejected has outcome rejected and errorMessage', () {
      final result = SyncEntryResult.rejected(entryId: 'e1', errorMessage: 'bad data');
      expect(result.outcome, SyncOutcome.rejected);
      expect(result.errorMessage, 'bad data');
      expect(result.serverSequence, isNull);
      expect(result.serverPayload, isNull);
    });

    test('rejected defaults errorMessage to empty string', () {
      final result = SyncEntryResult.rejected(entryId: 'e1');
      expect(result.outcome, SyncOutcome.rejected);
      expect(result.errorMessage, '');
    });

    group('toJson / fromJson round-trip', () {
      test('accepted', () {
        final result = SyncEntryResult.accepted(entryId: 'e1', serverSequence: 5);
        final json = result.toJson();
        final parsed = SyncEntryResult.fromJson(json);
        expect(parsed.entryId, 'e1');
        expect(parsed.outcome, SyncOutcome.accepted);
        expect(parsed.serverSequence, 5);
      });

      test('conflicted', () {
        final payload = {'field': 'value'};
        final result = SyncEntryResult.conflicted(entryId: 'e2', serverPayload: payload);
        final json = result.toJson();
        final parsed = SyncEntryResult.fromJson(json);
        expect(parsed.entryId, 'e2');
        expect(parsed.outcome, SyncOutcome.conflicted);
        expect(parsed.serverPayload, payload);
      });

      test('rejected', () {
        final result = SyncEntryResult.rejected(entryId: 'e3', errorMessage: 'err');
        final json = result.toJson();
        final parsed = SyncEntryResult.fromJson(json);
        expect(parsed.entryId, 'e3');
        expect(parsed.outcome, SyncOutcome.rejected);
        expect(parsed.errorMessage, 'err');
      });
    });

    test('fromJson throws ArgumentError on unknown outcome', () {
      expect(
        () => SyncEntryResult.fromJson({'entryId': 'e1', 'outcome': 'unknown'}),
        throwsArgumentError,
      );
    });
  });

  group('PushResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'results': [
          _resultJson('accepted', entryId: 'e1', serverSequence: 1),
          _resultJson('rejected', entryId: 'e2', errorMessage: 'fail'),
        ],
      };
      final response = PushResponse.fromJson(json);
      expect(response.results.length, 2);
      expect(response.results[0].outcome, SyncOutcome.accepted);
      expect(response.results[1].outcome, SyncOutcome.rejected);
    });

    test('fromJson parses empty results array', () {
      final json = {'results': <Map<String, dynamic>>[]};
      final response = PushResponse.fromJson(json);
      expect(response.results, isEmpty);
    });

    test('fromJson parses mixed outcomes', () {
      final json = {
        'results': [
          _resultJson('accepted', entryId: 'e1', serverSequence: 1),
          _resultJson('rejected', entryId: 'e2', errorMessage: 'nope'),
          _resultJson('conflicted', entryId: 'e3', serverPayload: {'key': 'val'}),
        ],
      };
      final response = PushResponse.fromJson(json);
      expect(response.results.length, 3);
      expect(response.results[0].outcome, SyncOutcome.accepted);
      expect(response.results[1].outcome, SyncOutcome.rejected);
      expect(response.results[2].outcome, SyncOutcome.conflicted);
    });
  });

  group('PullRequest', () {
    test('stores fields', () {
      final request = PullRequest(entityType: 'todo', sinceSequence: 42);
      expect(request.entityType, 'todo');
      expect(request.sinceSequence, 42);
    });

    test('toJson produces correct map', () {
      final request = PullRequest(entityType: 'todo', sinceSequence: 42);
      final json = request.toJson();
      expect(json['entityType'], 'todo');
      expect(json['sinceSequence'], 42);
    });
  });

  group('RemoteOperation', () {
    test('fromJson parses correctly', () {
      final json = {
        'entityType': 'todo',
        'entityId': 't1',
        'operation': 'insert',
        'payload': {'title': 'new'},
        'serverSequence': 100,
      };
      final op = RemoteOperation.fromJson(json);
      expect(op.entityType, 'todo');
      expect(op.entityId, 't1');
      expect(op.operation, SyncOperation.insert);
      expect(op.payload, {'title': 'new'});
      expect(op.serverSequence, 100);
    });

    test('fromJson parses insert operation', () {
      final op = RemoteOperation.fromJson({
        'entityType': 'todo',
        'entityId': 't1',
        'operation': 'insert',
        'payload': {},
        'serverSequence': 1,
      });
      expect(op.operation, SyncOperation.insert);
    });

    test('fromJson parses update operation', () {
      final op = RemoteOperation.fromJson({
        'entityType': 'todo',
        'entityId': 't1',
        'operation': 'update',
        'payload': {},
        'serverSequence': 2,
      });
      expect(op.operation, SyncOperation.update);
    });

    test('fromJson parses delete operation', () {
      final op = RemoteOperation.fromJson({
        'entityType': 'todo',
        'entityId': 't1',
        'operation': 'delete',
        'payload': {},
        'serverSequence': 3,
      });
      expect(op.operation, SyncOperation.delete);
    });
  });

  group('PullResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'operations': [
          {
            'entityType': 'todo',
            'entityId': 't1',
            'operation': 'insert',
            'payload': {'title': 'hello'},
            'serverSequence': 10,
          },
          {
            'entityType': 'todo',
            'entityId': 't2',
            'operation': 'update',
            'payload': {'title': 'world'},
            'serverSequence': 11,
          },
        ],
        'latestSequence': 11,
      };
      final response = PullResponse.fromJson(json);
      expect(response.operations.length, 2);
      expect(response.latestSequence, 11);
      expect(response.operations[0].entityId, 't1');
      expect(response.operations[1].entityId, 't2');
    });

    test('fromJson parses empty operations array', () {
      final json = {'operations': <Map<String, dynamic>>[], 'latestSequence': 0};
      final response = PullResponse.fromJson(json);
      expect(response.operations, isEmpty);
      expect(response.latestSequence, 0);
    });

    test('fromJson parses latestSequence correctly', () {
      final json = {'operations': <Map<String, dynamic>>[], 'latestSequence': 99};
      final response = PullResponse.fromJson(json);
      expect(response.latestSequence, 99);
    });
  });
}

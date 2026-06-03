import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

void main() {
  group('PushResponse', () {
    test('constructor stores results', () {
      final r = SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1);
      final response = PushResponse([r]);
      expect(response.results, [r]);
    });

    test('accepts empty results', () {
      final response = PushResponse([]);
      expect(response.results, isEmpty);
    });

    test('fromJson restores PushResponse', () {
      final json = {
        'results': [
          {
            'entryId': 'e1',
            'outcome': 'accepted',
            'serverSequence': 1,
          },
        ],
      };
      final response = PushResponse.fromJson(json);
      expect(response.results, hasLength(1));
      expect(response.results.first.entryId, 'e1');
      expect(response.results.first.outcome, SyncOutcome.accepted);
    });
  });

  group('PullResponse', () {
    test('constructor stores fields', () {
      final response = PullResponse(
        operations: [],
        latestSequence: 5,
      );
      expect(response.operations, isEmpty);
      expect(response.latestSequence, 5);
    });
  });
}

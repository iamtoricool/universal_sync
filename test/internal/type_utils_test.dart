import 'package:test/test.dart';
import 'package:universal_sync/src/internal/type_utils.dart';

class _DummyType {}

void main() {
  group('entityTypeName', () {
    test('returns simple class name for non-generic type', () {
      expect(entityTypeName(_DummyType), '_DummyType');
    });

    test('strips generic parameters', () {
      expect(entityTypeName(List<int>), 'List');
    });

    test('strips library prefix', () {
      expect(entityTypeName(List<int>), 'List');
    });

    test('throws ArgumentError on empty name', () {
      expect(
        () => entityTypeName(String),
        returnsNormally,
      );
    });
  });
}

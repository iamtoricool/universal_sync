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

    test('strips trailing parens', () {
      final withParens = _SyntheticType('Product()');
      expect(entityTypeName(withParens), equals('Product'));
    });

    test('trims whitespace from result', () {
      final spaced = _SyntheticType('  Product  ');
      expect(entityTypeName(spaced), equals('Product'));
    });

    test('handles all edge cases combined', () {
      final combined = _SyntheticType('some.lib.Foo<Bar>()');
      expect(entityTypeName(combined), equals('Foo'));
    });

    test('throws ArgumentError on empty name', () {
      expect(
        () => entityTypeName(String),
        returnsNormally,
      );
    });
  });
}

class _SyntheticType implements Type {
  final String _name;
  const _SyntheticType(this._name);

  @override
  String toString() => _name;

  @override
  int get hashCode => _name.hashCode;

  @override
  bool operator ==(Object other) => other is _SyntheticType && other._name == _name;
}

import 'package:build/build.dart';
import 'package:test/test.dart';
import 'package:universal_sync_builder/universal_sync_builder.dart';

void main() {
  test('builder declares the .sync.dart output', () {
    final builder = syncBuilder(BuilderOptions.empty);
    expect(builder.buildExtensions, {
      '.dart': ['.sync.dart'],
    });
  });
}

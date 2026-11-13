import 'dart:io';

/// Fails when line coverage of non-generated sources is below the threshold.
void main(List<String> arguments) {
  final path = arguments.isNotEmpty ? arguments.first : 'coverage/lcov.info';
  final threshold = arguments.length > 1 ? double.parse(arguments[1]) : 95.0;

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: $path');
    exitCode = 1;
    return;
  }

  var total = 0;
  var hit = 0;
  final rows = <String>[];

  for (final record in file.readAsStringSync().split('end_of_record')) {
    final source = RegExp(r'^SF:(.+)$', multiLine: true).firstMatch(record);
    if (source == null) continue;
    final name = source.group(1)!;
    // Generated schema code is exercised indirectly and excluded by policy.
    if (name.contains('sync_tables')) continue;

    final lf =
        int.tryParse(
          RegExp(r'^LF:(\d+)$', multiLine: true).firstMatch(record)?.group(1) ?? '',
        ) ??
        0;
    final lh =
        int.tryParse(
          RegExp(r'^LH:(\d+)$', multiLine: true).firstMatch(record)?.group(1) ?? '',
        ) ??
        0;
    total += lf;
    hit += lh;
    final pct = lf == 0 ? 100.0 : 100 * lh / lf;
    rows.add('${pct.toStringAsFixed(1).padLeft(5)}%  $lh/$lf  $name');
  }

  rows.sort();
  for (final row in rows) {
    stdout.writeln(row);
  }

  final pct = total == 0 ? 0.0 : 100 * hit / total;
  stdout.writeln(
    '\nTOTAL ${pct.toStringAsFixed(1)}% ($hit/$total), threshold '
    '${threshold.toStringAsFixed(1)}%',
  );
  if (pct < threshold) {
    stderr.writeln('Coverage below threshold.');
    exitCode = 1;
  }
}

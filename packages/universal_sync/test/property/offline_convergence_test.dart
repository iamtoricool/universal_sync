import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

import '../support/rig.dart';
import '../support/test_db.dart';

void main() {
  for (var seed = 0; seed < 12; seed++) {
    test('offline op sequence $seed converges exactly', () async {
      final rig = await TestRig.create(
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          pullPageSize: 10,
        ),
      );
      addTearDown(rig.dispose);

      final random = Random(seed);
      final expected = <String, ({String title, bool done})>{};

      for (var step = 0; step < 40; step++) {
        final key = 't${random.nextInt(4)}';
        final operation = random.nextInt(4);
        final title = 'title-$step';
        final done = random.nextBool();

        switch (operation) {
          case 0:
          case 3:
            await rig.tasks.save(
              TasksCompanion.insert(
                id: key,
                title: title,
                done: Value(done),
                updatedAt: rig.clock.now(),
              ),
            );
            expected[key] = (title: title, done: done);
          case 1:
            if (!expected.containsKey(key)) continue;
            await rig.tasks.patch(
              key,
              TasksCompanion(title: Value(title), done: Value(done)),
            );
            expected[key] = (title: title, done: done);
          case 2:
            await rig.tasks.remove(key);
            expected.remove(key);
        }
      }

      final report = await rig.sync.drain();
      expect(report.failed, 0);
      expect((await rig.sync.diagnostics()).pending, 0);

      final local = {
        for (final row in await rig.tasks.query().get()) row.id: (title: row.title, done: row.done),
      };
      expect(local, expected);

      final remote = {
        for (final row in rig.server.rowsFor('tasks'))
          row['id'] as String: (
            title: row['title'] as String,
            done: row['done'] as bool,
          ),
      };
      expect(remote, expected);
    });
  }

  test('repeated write/drain cycles keep the queue bounded', () async {
    final rig = await TestRig.create();
    addTearDown(rig.dispose);

    for (var cycle = 0; cycle < 25; cycle++) {
      for (var i = 0; i < 5; i++) {
        await rig.tasks.save(
          TasksCompanion.insert(
            id: 't$i',
            title: 'cycle $cycle',
            updatedAt: rig.clock.now(),
          ),
        );
      }
      await rig.sync.drain();
      final diagnostics = await rig.sync.diagnostics();
      expect(diagnostics.pending, 0);
      expect(diagnostics.inflight, 0);
      expect(diagnostics.outboxBytes, 0);
    }

    expect(rig.server.rowsFor('tasks'), hasLength(5));
  });
}

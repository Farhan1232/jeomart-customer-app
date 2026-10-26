import 'dart:async';

import 'package:customer/utils/parallel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Session 36 - [Parallel.applyInOrder], which `getPaymentSettingsData()` now
/// runs its thirteen settings reads through.
///
/// The point of it is that only the network part changes: every read is on
/// the wire at once, and everything observable on the apply side - order, and
/// what a failure stops - is what thirteen consecutive awaits did.
void main() {
  test('every read is started before the first one is applied', () async {
    final List<Completer<int>> reads = List<Completer<int>>.generate(4, (_) => Completer<int>());
    final List<int> started = <int>[];

    final Future<void> run = Parallel.applyInOrder<int, int>(
      <int>[0, 1, 2, 3],
      (int i) {
        started.add(i);
        return reads[i].future;
      },
      (int i, int value) {},
    );

    await Future<void>.delayed(Duration.zero);
    expect(started, <int>[0, 1, 2, 3], reason: 'nothing has come back yet, and all four are in flight');

    for (final Completer<int> read in reads) {
      read.complete(0);
    }
    await run;
  });

  test('results are applied in list order, whatever order they arrive in', () async {
    final List<Completer<String>> reads = List<Completer<String>>.generate(3, (_) => Completer<String>());
    final List<String> applied = <String>[];

    final Future<void> run = Parallel.applyInOrder<int, String>(
      <int>[0, 1, 2],
      (int i) => reads[i].future,
      (int i, String value) async {
        await Future<void>.delayed(Duration.zero);
        applied.add('$i:$value');
      },
    );

    reads[2].complete('c');
    reads[1].complete('b');
    await Future<void>.delayed(Duration.zero);
    expect(applied, isEmpty, reason: 'item 0 has not arrived, so nothing after it may be applied');

    reads[0].complete('a');
    await run;
    expect(applied, <String>['0:a', '1:b', '2:c']);
  });

  test('a failure reaches the caller and stops every later apply, and nothing is left uncaught', () async {
    final List<int> applied = <int>[];

    await expectLater(
      Parallel.applyInOrder<int, int>(
        <int>[0, 1, 2, 3],
        (int i) async {
          if (i == 1 || i == 3) throw StateError('read $i failed');
          return i;
        },
        (int i, int value) => applied.add(i),
      ),
      throwsA(isA<StateError>().having((StateError e) => e.message, 'message', 'read 1 failed')),
    );

    // Let every started read settle: the failure at 3 is never awaited, and a
    // future that fails with no handler would fail this test as uncaught.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(applied, <int>[0]);
  });

  test('an apply that throws stops the ones after it, as an await chain did', () async {
    final List<int> applied = <int>[];

    await expectLater(
      Parallel.applyInOrder<int, int>(
        <int>[0, 1, 2],
        (int i) async => i,
        (int i, int value) {
          if (i == 1) throw FormatException('bad document $i');
          applied.add(i);
        },
      ),
      throwsA(isA<FormatException>()),
    );
    expect(applied, <int>[0]);
  });
}

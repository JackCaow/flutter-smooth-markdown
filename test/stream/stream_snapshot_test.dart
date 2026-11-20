import 'dart:math';

import 'package:flutter_smooth_markdown/src/parser/stream_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'published snapshots survive tail rollback, page boundaries and edits',
    () {
      final random = Random(435200);
      var snapshot = StreamSnapshot<int>.empty();
      var reference = <int>[];
      final saved = <({List<int> actual, List<int> expected})>[];
      for (var i = 0; i < 600; i++) {
        final retained = i % 17 == 0 ? 0 : random.nextInt(reference.length + 1);
        final tail = List.generate(
          random.nextInt(400),
          (_) => random.nextInt(10000),
        );
        snapshot = snapshot.replaceTail(retained, tail);
        reference = [...reference.take(retained), ...tail];
        expect(snapshot, reference);
        expect(snapshot.toList(), reference);
        saved.add((actual: snapshot, expected: reference));
        // Caller-owned mutable tail must not alter a published snapshot.
        tail.clear();
      }
      for (final entry in saved) {
        expect(entry.actual, entry.expected);
      }
      expect(() => snapshot[-1], throwsRangeError);
      expect(() => snapshot[snapshot.length], throwsRangeError);
      expect(
        () => snapshot.replaceTail(snapshot.length + 1, []),
        throwsRangeError,
      );
    },
  );

  test(
    'all List mutation entry points reject writes, including no-op writes',
    () {
      for (final list in [
        StreamSnapshot<int>.empty(),
        StreamSnapshot<int>.empty().replaceTail(0, [3, 1, 2]),
      ]) {
        expect(() => list.length = list.length, throwsUnsupportedError);
        expect(() => list.clear(), throwsUnsupportedError);
        expect(() => list.addAll([]), throwsUnsupportedError);
        expect(() => list.insertAll(0, []), throwsUnsupportedError);
        expect(() => list.removeWhere((_) => false), throwsUnsupportedError);
        expect(() => list.sort(), throwsUnsupportedError);
        expect(() => list.shuffle(), throwsUnsupportedError);
        expect(() => list.setRange(0, 0, []), throwsUnsupportedError);
        expect(() => list.fillRange(0, 0), throwsUnsupportedError);
        expect(() => list.replaceRange(0, 0, []), throwsUnsupportedError);
        expect(() => list.cast<num>().clear(), throwsUnsupportedError);
      }
    },
  );
}

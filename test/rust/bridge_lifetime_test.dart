import 'dart:convert';

import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/rust/platform.dart' as core;
import 'package:flutter_test/flutter_test.dart';

String json(List<MarkdownNode> nodes) =>
    jsonEncode(nodes.map((n) => n.toJson()).toList());

void main() {
  test(
    'scoped native buffers never escape through AST strings or child lists',
    () {
      const source =
          '# **中文🙂**\n\n![image *alt*](/image "title")\n\n'
          'A [link](/url "title") with **bold** and `code`.\n\n'
          '| A | B |\n| :- | -: |\n| x | y |\n\n```dart\nvalue🙂\n```';
      final batch = core.parseNative(source)!;
      final expected = json(batch);
      final stream = core.createNativeStream()!;
      final retained = stream.update(source);
      stream.dispose();
      // Reuse native allocator size classes after the result and session owners
      // have been freed. Saved Dart values must remain entirely independent.
      for (var i = 0; i < 300; i++) {
        core.parseNative('other **$i**\n\n```text\n${'x' * (i + 1)}\n```');
      }
      expect(json(batch), expected);
      expect(json(retained), expected);
    },
  );

  test(
    'flat native retention preserves split/empty groups across prefixes and edits',
    () {
      const source =
          'one\n\ntwo\n\n- [x] task\n- plain\n\nthree\n\nfour🙂\n\n'
          '[site][id]\n\n[id]: /target\n\nlast';
      final stream = core.createNativeStream()!;
      try {
        for (var end = 0; end <= source.length; end++) {
          final prefix = source.substring(0, end);
          expect(json(stream.update(prefix)), json(core.parseNative(prefix)!));
        }
        for (final text in [
          source,
          'replacement',
          'replacement\n\nsecond',
          '',
          source,
        ]) {
          expect(json(stream.update(text)), json(core.parseNative(text)!));
        }
      } finally {
        stream.dispose();
      }
    },
  );

  test(
    'paged publications keep earlier lists stable across rollback and disposal',
    () {
      final stream = core.createNativeStream()!;
      const section = '# H\n\ntext **bold** 中文🙂\n\n- one\n- two\n\n';
      final saved = <({List<MarkdownNode> nodes, String expected})>[];
      MarkdownNode? first;
      try {
        // Cross many page boundaries; some native groups produce multiple output
        // lists. Keep earlier snapshots while the parser mutates its tail.
        for (var i = 1; i <= 180; i++) {
          final source = section * i;
          final nodes = stream.update(source);
          expect(json(nodes), json(core.parseNative(source)!));
          if (i > 2) expect(nodes.first, same(first));
          first ??= nodes.first;
          if (i % 19 == 0) saved.add((nodes: nodes, expected: json(nodes)));
          expect(() => nodes.clear(), throwsUnsupportedError);
        }
        for (final source in ['', 'replacement', '$section\n[id]: /new']) {
          expect(json(stream.update(source)), json(core.parseNative(source)!));
        }
      } finally {
        stream.dispose();
      }
      for (final snapshot in saved) {
        expect(json(snapshot.nodes), snapshot.expected);
        expect(
          () => snapshot.nodes[0] = TextNode('changed'),
          throwsUnsupportedError,
        );
      }
    },
  );
}

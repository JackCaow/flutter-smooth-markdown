import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/html/html_inline_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HtmlInlineParser createParser() {
    return HtmlInlineParser(
      parseChildren: (source, depth) => [TextNode('$depth:$source')],
    );
  }

  group('HtmlInlineParser', () {
    test('returns null for an invalid tag', () {
      final result = createParser().tryParse('< b>', 0, 0);

      expect(result, isNull);
    });

    test('builds bold node and reports the paired tag span', () {
      final result = createParser().tryParse('<b>x</b>tail', 0, 0)!;

      expect(result.nodes, hasLength(1));
      final bold = result.nodes.single as BoldNode;
      expect((bold.children.single as TextNode).content, '1:x');
      expect(result.consumed, 8);
    });

    test('splices callback children for unknown tags', () {
      final result = createParser().tryParse('<video>x</video>', 0, 0)!;

      expect(result.nodes, hasLength(1));
      expect((result.nodes.single as TextNode).content, '1:x');
    });

    test('keeps callback children for an unsafe anchor', () {
      final result = createParser().tryParse(
        '<a href="javascript:alert(1)">x</a>',
        0,
        0,
      )!;

      expect(result.nodes.whereType<LinkNode>(), isEmpty);
      expect((result.nodes.single as TextNode).content, '1:x');
    });

    test('uses image alt text when the image source is unsafe', () {
      final result = createParser().tryParse(
        '<img src="javascript:x" alt="fallback">',
        0,
        0,
      )!;

      expect(result.nodes.whereType<ImageNode>(), isEmpty);
      expect((result.nodes.single as TextNode).content, 'fallback');
    });

    test('auto-closes an incomplete mark tag at the input end', () {
      const input = '<mark>partial';
      final result = createParser().tryParse(input, 0, 0)!;

      expect(result.consumed, input.length);
      final mark = result.nodes.single as HighlightNode;
      expect((mark.children.single as TextNode).content, '1:partial');
    });
  });
}

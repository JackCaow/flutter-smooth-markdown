import 'package:flutter_smooth_markdown/src/parser/ast/markdown_node.dart';
import 'package:flutter_smooth_markdown/src/parser/block_parser.dart';
import 'package:flutter_smooth_markdown/src/parser/inline_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Inline Math Parsing', () {
    late InlineParser parser;

    setUp(() {
      parser = InlineParser();
    });

    test('should parse simple inline math', () {
      final result = parser.parse(r'$E=mc^2$');
      expect(result.length, 1);
      expect(result[0], isA<InlineMathNode>());
      expect((result[0] as InlineMathNode).latex, r'E=mc^2');
    });

    test('should parse math with spaces', () {
      final result = parser.parse(r'$x + y = z$');
      expect(result.length, 1);
      expect(result[0], isA<InlineMathNode>());
      expect((result[0] as InlineMathNode).latex, 'x + y = z');
    });

    test('should parse math in paragraph text', () {
      final result =
          parser.parse(r'The formula $a^2 + b^2 = c^2$ is important');
      expect(result.length, 3);
      expect(result[0], isA<TextNode>());
      expect((result[0] as TextNode).content, 'The formula ');
      expect(result[1], isA<InlineMathNode>());
      expect((result[1] as InlineMathNode).latex, r'a^2 + b^2 = c^2');
      expect(result[2], isA<TextNode>());
      expect((result[2] as TextNode).content, ' is important');
    });

    test('should not parse empty math (two dollar signs)', () {
      final result = parser.parse(r'$$');
      // $$ is block math marker, inline parser skips it;
      // the result should not contain an InlineMathNode
      final hasMath = result.any((n) => n is InlineMathNode);
      expect(hasMath, false);
    });

    test('should not parse unclosed math as InlineMathNode', () {
      final result = parser.parse(r'$unclosed');
      // Without a closing $, inline math parsing fails
      final hasMath = result.any((n) => n is InlineMathNode);
      expect(hasMath, false);
      // Should remain as plain text
      expect(result.every((n) => n is TextNode), true);
    });

    test('should parse multiple inline math in same text', () {
      final result = parser.parse(r'Given $x=1$ and $y=2$ then $z=3$');
      final mathNodes = result.whereType<InlineMathNode>().toList();
      expect(mathNodes.length, 3);
      expect(mathNodes[0].latex, 'x=1');
      expect(mathNodes[1].latex, 'y=2');
      expect(mathNodes[2].latex, 'z=3');
    });
  });

  group('Block Math Parsing', () {
    late BlockParser parser;

    setUp(() {
      parser = BlockParser();
    });

    test('should parse simple block math', () {
      final result = parser.parse('\$\$\nx^2 + y^2 = z^2\n\$\$');
      expect(result.length, 1);
      expect(result[0], isA<BlockMathNode>());
      expect((result[0] as BlockMathNode).latex, 'x^2 + y^2 = z^2');
    });

    test(r'should parse single-line block math', () {
      final result = parser.parse('\$\$E = mc^2\$\$');
      expect(result.length, 1);
      expect(result[0], isA<BlockMathNode>());
      expect((result[0] as BlockMathNode).latex, 'E = mc^2');
    });

    test('should parse multi-line block math', () {
      const input = '\$\$\n'
          r'\sum_{i=1}^{n} x_i'
          '\n'
          '= x_1 + x_2 + \\cdots + x_n\n'
          '\$\$';
      final result = parser.parse(input);
      expect(result.length, 1);
      expect(result[0], isA<BlockMathNode>());

      final latex = (result[0] as BlockMathNode).latex;
      expect(latex, contains(r'\sum_{i=1}^{n} x_i'));
      expect(latex, contains('x_n'));
    });

    test('should parse block math after paragraph without blank line', () {
      final result = parser.parse('Intro\n\$\$\nE = mc^2\n\$\$');
      expect(result.length, 2);
      expect(result[0], isA<ParagraphNode>());
      final paragraph = result[0] as ParagraphNode;
      expect(paragraph.children, hasLength(1));
      expect(paragraph.children.single, isA<TextNode>());
      expect((paragraph.children.single as TextNode).content, 'Intro');
      expect(result[1], isA<BlockMathNode>());
      expect((result[1] as BlockMathNode).latex, 'E = mc^2');
    });

    test(r'should parse block math without closing $$', () {
      final result = parser.parse('\$\$\na + b = c');
      expect(result.length, 1);
      expect(result[0], isA<BlockMathNode>());
      expect((result[0] as BlockMathNode).latex, 'a + b = c');
    });

    test('should parse empty block math', () {
      final result = parser.parse('\$\$\n\$\$');
      expect(result.length, 1);
      expect(result[0], isA<BlockMathNode>());
      expect((result[0] as BlockMathNode).latex, isEmpty);
    });
  });
}

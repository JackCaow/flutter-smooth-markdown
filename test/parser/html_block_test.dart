import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/block_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockParser HTML support', () {
    late BlockParser parser;

    setUp(() {
      parser = BlockParser(enableHtml: true);
    });

    group('html blocks', () {
      test('parses center block with children and center alignment', () {
        final result = parser.parse('<center>\nhello\n</center>');
        expect(result, hasLength(1));
        final block = result[0] as HtmlBlockNode;
        expect(block.tag, 'center');
        expect(block.align, HtmlBlockAlignment.center);
        expect(block.children.first, isA<ParagraphNode>());
      });

      test('parses div with align attribute', () {
        final result = parser.parse('<div align="right">\ntext\n</div>');
        final block = result[0] as HtmlBlockNode;
        expect(block.tag, 'div');
        expect(block.align, HtmlBlockAlignment.right);
      });

      test('parses single line p block', () {
        final result = parser.parse('<p>text</p>');
        expect(result, hasLength(1));
        final block = result[0] as HtmlBlockNode;
        expect(block.tag, 'p');
        final paragraph = block.children.first as ParagraphNode;
        expect((paragraph.children.first as TextNode).content, 'text');
      });

      test('maps html blockquote to BlockquoteNode', () {
        final result = parser.parse('<blockquote>\nquote\n</blockquote>');
        expect(result.first, isA<BlockquoteNode>());
      });

      test('parses markdown content inside html block', () {
        final result = parser.parse('<div>\n# Title\n- item\n</div>');
        final block = result[0] as HtmlBlockNode;
        expect(block.children.whereType<HeaderNode>(), hasLength(1));
        expect(block.children.whereType<ListNode>(), hasLength(1));
      });

      test('nested same-tag divs close at matching depth', () {
        final result = parser.parse(
          '<div>\n<div>\ninner\n</div>\nouter\n</div>',
        );
        expect(result, hasLength(1));
        final outer = result[0] as HtmlBlockNode;
        expect(outer.children.whereType<HtmlBlockNode>(), hasLength(1));
      });

      test('consumes unclosed div to end of input', () {
        final result = parser.parse('<div>\nrest\nmore');
        expect(result, hasLength(1));
        final block = result[0] as HtmlBlockNode;
        expect(block.children, isNotEmpty);
      });

      test('keeps remainder after terminating close tag inside block', () {
        final result = parser.parse('<div>a</div><div>b</div>');
        expect(result, hasLength(1));
        final json = result[0].toJson().toString();
        expect(json, contains('a'));
        expect(json, contains('b'));
      });

      test('parses empty self-closed div line', () {
        final result = parser.parse('<div/>');
        expect(result, hasLength(1));
        expect((result[0] as HtmlBlockNode).children, isEmpty);
      });
    });

    group('html hr lines', () {
      test('treats standalone hr tag line as horizontal rule', () {
        final result = parser.parse('a\n\n<hr>\n\nb');
        expect(result, hasLength(3));
        expect(result[1], isA<HorizontalRuleNode>());
      });

      test('accepts self closing hr variants', () {
        expect(parser.parse('<hr/>').first, isA<HorizontalRuleNode>());
        expect(parser.parse('<hr />').first, isA<HorizontalRuleNode>());
      });
    });

    group('interaction with other blocks', () {
      test('paragraph ends when html block line begins', () {
        final result = parser.parse('text\n<div>\nx\n</div>');
        expect(result, hasLength(2));
        expect(result[0], isA<ParagraphNode>());
        expect(result[1], isA<HtmlBlockNode>());
      });

      test('details block still parses through dedicated path', () {
        final result = parser.parse(
          '<details>\n<summary>s</summary>\nbody\n</details>',
        );
        expect(result, hasLength(1));
        expect(result.first, isA<DetailsNode>());
      });

      test('mid-line block tag stays part of the paragraph', () {
        final result = parser.parse('before <div>x</div>');
        expect(result.first, isA<ParagraphNode>());
      });

      test('does not treat html block inside fenced code as block', () {
        final result = parser.parse('```\n<div>\n```');
        expect(result, hasLength(1));
        expect(result.first, isA<CodeBlockNode>());
      });
    });

    group('html disabled', () {
      test('leaves div line as paragraph when html disabled', () {
        final plain = BlockParser();
        final result = plain.parse('<div>\nx\n</div>');
        expect(result.whereType<HtmlBlockNode>(), isEmpty);
        expect(result.first, isA<ParagraphNode>());
      });

      test('leaves hr tag line as paragraph when html disabled', () {
        final plain = BlockParser();
        final result = plain.parse('<hr>');
        expect(result.first, isA<ParagraphNode>());
      });
    });
  });

  group('MarkdownParser HTML integration', () {
    test('processes inline markdown inside html block children', () {
      final parser = MarkdownParser(enableHtml: true);
      final result = parser.parse('<div>\n**bold** text\n</div>');
      final block = result[0] as HtmlBlockNode;
      final paragraph = block.children.first as ParagraphNode;
      expect(paragraph.children.whereType<BoldNode>(), hasLength(1));
    });

    test('processes inline html inside regular paragraph', () {
      final parser = MarkdownParser(enableHtml: true);
      final result = parser.parse('hello <u>world</u>');
      final paragraph = result[0] as ParagraphNode;
      expect(paragraph.children.whereType<UnderlineNode>(), hasLength(1));
    });

    test('keeps html literal when disabled at parser level', () {
      final parser = MarkdownParser();
      final result = parser.parse('hello <u>world</u>');
      final paragraph = result[0] as ParagraphNode;
      expect(paragraph.children.whereType<UnderlineNode>(), isEmpty);
    });

    test('parses inline html inside table cells', () {
      final parser = MarkdownParser(enableHtml: true);
      final result = parser.parse(
        '| a | b |\n| --- | --- |\n| <b>x</b> | y |',
      );
      final table = result[0] as TableNode;
      final firstCell = table.rows.first.cells.first;
      expect(firstCell.whereType<BoldNode>(), hasLength(1));
    });

    test('parses inline html inside header lines', () {
      final parser = MarkdownParser(enableHtml: true);
      final result = parser.parse('# Title <sup>2</sup>');
      final header = result[0] as HeaderNode;
      expect(
        header.children?.whereType<SuperscriptNode>() ?? const [],
        hasLength(1),
      );
    });
  });
}

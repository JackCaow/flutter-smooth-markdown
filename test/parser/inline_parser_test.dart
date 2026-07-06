import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/inline_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InlineParser Tests', () {
    late InlineParser parser;

    setUp(() {
      parser = InlineParser();
    });

    group('Plain Text', () {
      test('should parse plain text', () {
        final result = parser.parse('Hello World');
        expect(result.length, 1);
        expect(result[0], isA<TextNode>());
        expect((result[0] as TextNode).content, 'Hello World');
      });

      test('should parse hard breaks', () {
        final backslashBreak = parser.parse('Hello\\\nWorld');
        expect(backslashBreak, hasLength(3));
        expect(backslashBreak[0], isA<TextNode>());
        expect(backslashBreak[1], isA<HardBreakNode>());
        expect(backslashBreak[2], isA<TextNode>());

        final trailingSpaceBreak = parser.parse('Hello  \nWorld');
        expect(trailingSpaceBreak, hasLength(3));
        expect(trailingSpaceBreak[1], isA<HardBreakNode>());
      });

      test('should handle empty string', () {
        final result = parser.parse('');
        expect(result, isEmpty);
      });
    });

    group('Bold Parsing', () {
      test('should parse bold with **', () {
        final result = parser.parse('This is **bold** text');
        expect(result.length, 3);
        expect(result[0], isA<TextNode>());
        expect(result[1], isA<BoldNode>());
        expect(result[2], isA<TextNode>());

        final bold = result[1] as BoldNode;
        expect(bold.children.length, 1);
        expect((bold.children[0] as TextNode).content, 'bold');
      });

      test('should parse bold with __', () {
        final result = parser.parse('This is __bold__ text');
        expect(result.length, 3);
        expect(result[1], isA<BoldNode>());
      });

      test('should handle multiple bold sections', () {
        final result = parser.parse('**First** and **Second**');
        expect(result.length, 3);
        expect(result[0], isA<BoldNode>());
        expect(result[1], isA<TextNode>());
        expect(result[2], isA<BoldNode>());
      });

      test('should not parse incomplete bold', () {
        final result = parser.parse('**incomplete');
        expect(result.length, 1);
        expect(result[0], isA<TextNode>());
      });
    });

    group('Italic Parsing', () {
      test('should parse italic with *', () {
        final result = parser.parse('This is *italic* text');
        expect(result.length, 3);
        expect(result[1], isA<ItalicNode>());

        final italic = result[1] as ItalicNode;
        expect((italic.children[0] as TextNode).content, 'italic');
      });

      test('should parse italic with _', () {
        final result = parser.parse('This is _italic_ text');
        expect(result.length, 3);
        expect(result[1], isA<ItalicNode>());
      });

      test('should differentiate between italic and bold', () {
        final result = parser.parse('*italic* **bold**');
        expect(result.length, 3);
        expect(result[0], isA<ItalicNode>());
        expect(result[1], isA<TextNode>());
        expect(result[2], isA<BoldNode>());
      });
    });

    group('Inline Code Parsing', () {
      test('should parse inline code', () {
        final result = parser.parse('This is `code` text');
        expect(result.length, 3);
        expect(result[1], isA<InlineCodeNode>());

        final code = result[1] as InlineCodeNode;
        expect(code.code, 'code');
      });

      test('should handle code with spaces', () {
        final result = parser.parse('`const x = 10`');
        expect(result.length, 1);
        expect(result[0], isA<InlineCodeNode>());
        expect((result[0] as InlineCodeNode).code, 'const x = 10');
      });

      test('should not parse incomplete code', () {
        final result = parser.parse('`incomplete');
        expect(result.length, 1);
        expect(result[0], isA<TextNode>());
      });
    });

    group('Link Parsing', () {
      test('should parse simple link', () {
        final result = parser.parse('[Link](https://example.com)');
        expect(result.length, 1);
        expect(result[0], isA<LinkNode>());

        final link = result[0] as LinkNode;
        expect(link.url, 'https://example.com');
        expect(link.children.length, 1);
        expect((link.children[0] as TextNode).content, 'Link');
      });

      test('should parse link with title', () {
        final result = parser.parse('[Link](https://example.com "Title")');
        expect(result.length, 1);
        expect(result[0], isA<LinkNode>());

        final link = result[0] as LinkNode;
        expect(link.url, 'https://example.com');
        expect(link.title, 'Title');
      });

      test('should parse link in text', () {
        final result =
            parser.parse('Visit [this link](https://example.com) now');
        expect(result.length, 3);
        expect(result[0], isA<TextNode>());
        expect(result[1], isA<LinkNode>());
        expect(result[2], isA<TextNode>());
      });

      test('should not parse incomplete link', () {
        final result = parser.parse('[incomplete](');
        expect(result.length, 1);
        expect(result[0], isA<TextNode>());
      });
    });

    group('Image Parsing', () {
      test('should parse simple image', () {
        final result = parser.parse('![Alt](https://example.com/image.png)');
        expect(result.length, 1);
        expect(result[0], isA<ImageNode>());

        final image = result[0] as ImageNode;
        expect(image.url, 'https://example.com/image.png');
        expect(image.alt, 'Alt');
      });

      test('should parse image with title', () {
        final result =
            parser.parse('![Alt](https://example.com/image.png "Title")');
        expect(result.length, 1);
        expect(result[0], isA<ImageNode>());

        final image = result[0] as ImageNode;
        expect(image.url, 'https://example.com/image.png');
        expect(image.alt, 'Alt');
        expect(image.title, 'Title');
      });

      test('should parse image in text', () {
        final result = parser.parse('Here is ![image](url.png) in text');
        expect(result.length, 3);
        expect(result[0], isA<TextNode>());
        expect(result[1], isA<ImageNode>());
        expect(result[2], isA<TextNode>());
      });
    });

    group('Strikethrough Parsing', () {
      test('should parse strikethrough', () {
        final result = parser.parse('This is ~~deleted~~ text');
        expect(result.length, 3);
        expect(result[1], isA<StrikethroughNode>());

        final strike = result[1] as StrikethroughNode;
        expect((strike.children[0] as TextNode).content, 'deleted');
      });

      test('should handle multiple strikethrough', () {
        final result = parser.parse('~~First~~ and ~~Second~~');
        expect(result.length, 3);
        expect(result[0], isA<StrikethroughNode>());
        expect(result[2], isA<StrikethroughNode>());
      });
    });

    group('Nested Parsing', () {
      test('should parse bold within link', () {
        final result = parser.parse('[**bold link**](url)');
        expect(result.length, 1);
        expect(result[0], isA<LinkNode>());

        final link = result[0] as LinkNode;
        expect(link.children.length, 1);
        expect(link.children[0], isA<BoldNode>());
      });

      test('should parse italic within bold', () {
        final result = parser.parse('**bold *and italic* text**');
        expect(result.length, 1);
        expect(result[0], isA<BoldNode>());

        final bold = result[0] as BoldNode;
        expect(bold.children.length, 3);
        expect(bold.children[1], isA<ItalicNode>());
      });

      test('should parse code within link', () {
        final result = parser.parse('[`code`](url)');
        expect(result.length, 1);
        expect(result[0], isA<LinkNode>());

        final link = result[0] as LinkNode;
        expect(link.children[0], isA<InlineCodeNode>());
      });
    });

    group('Mixed Content', () {
      test('should parse complex mixed content', () {
        final result = parser.parse(
          'This is **bold**, *italic*, `code`, [link](url), and ~~strike~~.',
        );

        // Count the different node types
        final types = result.map((n) => n.runtimeType).toList();
        expect(types.contains(BoldNode), true);
        expect(types.contains(ItalicNode), true);
        expect(types.contains(InlineCodeNode), true);
        expect(types.contains(LinkNode), true);
        expect(types.contains(StrikethroughNode), true);
      });

      test('should merge consecutive text nodes', () {
        final result = parser.parse('Hello World');
        expect(result.length, 1);
        expect(result[0], isA<TextNode>());
      });
    });

    group('Edge Cases', () {
      test('should handle special characters in text', () {
        final result = parser.parse('Text with * and _ characters');
        expect(result.length, 1);
        expect(result[0], isA<TextNode>());
      });

      test('should handle empty bold', () {
        final result = parser.parse('****');
        expect(result.length, 1);
        expect(result[0], isA<TextNode>());
      });

      test('should handle mismatched markers', () {
        final result = parser.parse('**bold with *italic**');
        // Should parse as bold with * inside
        expect(result.length, 1);
        expect(result[0], isA<BoldNode>());
      });
    });
  });
}

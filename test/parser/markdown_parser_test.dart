import 'package:flutter_smooth_markdown/flutter_smooth_markdown_editor_experimental.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarkdownParser Tests', () {
    late MarkdownParser parser;

    setUp(() {
      parser = MarkdownParser();
    });

    group('Basic Parsing', () {
      test('should parse empty string', () {
        final result = parser.parse('');
        expect(result, isEmpty);
      });

      test('should parse plain text paragraph', () {
        final result = parser.parse('Hello World');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());
      });

      test('should parse header', () {
        final result = parser.parse('# Title');
        expect(result.length, 1);
        expect(result[0], isA<HeaderNode>());
        expect((result[0] as HeaderNode).level, 1);
      });
    });

    group('Code Fence Parsing', () {
      test('should preserve longer backtick fence through serialization', () {
        const markdown = '````dart title=main.dart\n'
            'before\n'
            '```\n'
            'after\n'
            '````';

        final result = parser.parse(markdown);
        expect(result, hasLength(1));
        final codeBlock = result.single as CodeBlockNode;
        expect(codeBlock.language, 'dart');
        expect(codeBlock.info, 'dart title=main.dart');
        expect(codeBlock.fence, '````');
        expect(codeBlock.code, 'before\n```\nafter');

        final codec = MarkdownDocumentCodec();
        expect(codec.serialize(codec.parse(markdown)), markdown);
      });

      test('should preserve longer tilde fence through serialization', () {
        const markdown = '~~~~dart title=main.dart\n'
            'before\n'
            '~~~\n'
            'after\n'
            '~~~~';

        final result = parser.parse(markdown);
        expect(result, hasLength(1));
        final codeBlock = result.single as CodeBlockNode;
        expect(codeBlock.language, 'dart');
        expect(codeBlock.info, 'dart title=main.dart');
        expect(codeBlock.fence, '~~~~');
        expect(codeBlock.code, 'before\n~~~\nafter');

        final codec = MarkdownDocumentCodec();
        expect(codec.serialize(codec.parse(markdown)), markdown);
      });
    });

    group('Inline Elements in Blocks', () {
      test('should parse bold in paragraph', () {
        final result = parser.parse('This is **bold** text');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());

        final para = result[0] as ParagraphNode;
        expect(para.children.length, 3);
        expect(para.children[0], isA<TextNode>());
        expect(para.children[1], isA<BoldNode>());
        expect(para.children[2], isA<TextNode>());
      });

      test('should parse italic in paragraph', () {
        final result = parser.parse('This is *italic* text');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());

        final para = result[0] as ParagraphNode;
        expect(para.children[1], isA<ItalicNode>());
      });

      test('should parse inline code in paragraph', () {
        final result = parser.parse('This is `code` text');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());

        final para = result[0] as ParagraphNode;
        expect(para.children[1], isA<InlineCodeNode>());
      });

      test('should parse hard break in paragraph', () {
        final result = parser.parse('First\\\nSecond');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());

        final para = result[0] as ParagraphNode;
        expect(para.children, hasLength(3));
        expect(para.children[0], isA<TextNode>());
        expect(para.children[1], isA<HardBreakNode>());
        expect(para.children[2], isA<TextNode>());
      });

      test('should parse link in paragraph', () {
        final result = parser.parse('Visit [link](https://example.com) now');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());

        final para = result[0] as ParagraphNode;
        expect(para.children[1], isA<LinkNode>());
      });

      test('should parse image in paragraph', () {
        final result = parser.parse('See ![image](url.png) here');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());

        final para = result[0] as ParagraphNode;
        expect(para.children[1], isA<ImageNode>());
      });
    });

    group('Inline Elements in Lists', () {
      test('should parse bold in list item', () {
        final result = parser.parse('- Item with **bold**');
        expect(result.length, 1);
        expect(result[0], isA<ListNode>());

        final list = result[0] as ListNode;
        final item = list.items[0];
        expect(item.children.length, 2);
        expect(item.children[0], isA<TextNode>());
        expect(item.children[1], isA<BoldNode>());
      });

      test('should parse link in list item', () {
        final result = parser.parse('- Check [this](url) out');
        expect(result.length, 1);
        expect(result[0], isA<ListNode>());

        final list = result[0] as ListNode;
        final item = list.items[0];
        expect(item.children.any((n) => n is LinkNode), true);
      });

      test('should parse mixed inline in list', () {
        const markdown = '''
- Item with **bold** and *italic*
- Item with `code` and [link](url)
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<ListNode>());

        final list = result[0] as ListNode;
        expect(list.items.length, 2);
      });
    });

    group('Inline Elements in Blockquotes', () {
      test('should parse inline elements in blockquote', () {
        final result = parser.parse('> This is **bold** in quote');
        expect(result.length, 1);
        expect(result[0], isA<BlockquoteNode>());

        final quote = result[0] as BlockquoteNode;
        expect(quote.children.length, 1);
        expect(quote.children[0], isA<ParagraphNode>());

        final para = quote.children[0] as ParagraphNode;
        expect(para.children.any((n) => n is BoldNode), true);
      });

      test('should parse nested elements in blockquote', () {
        const markdown = '''
> # Header
>
> Paragraph with *italic* and **bold**
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<BlockquoteNode>());

        final quote = result[0] as BlockquoteNode;
        expect(quote.children.length, 2);
        expect(quote.children[0], isA<HeaderNode>());
        expect(quote.children[1], isA<ParagraphNode>());
      });
    });

    group('Complex Documents', () {
      test('should parse mixed block and inline elements', () {
        const markdown = '''
# Title with **bold**

This is a paragraph with *italic*, `code`, and [link](url).

- List item **one**
- List item *two*

> Quote with **emphasis**

```dart
void main() {}
```

---

Final paragraph with ~~strikethrough~~.
''';
        final result = parser.parse(markdown);

        // Verify we have all the block types
        final types = result.map((n) => n.runtimeType).toSet();
        expect(types.contains(HeaderNode), true);
        expect(types.contains(ParagraphNode), true);
        expect(types.contains(ListNode), true);
        expect(types.contains(BlockquoteNode), true);
        expect(types.contains(CodeBlockNode), true);
        expect(types.contains(HorizontalRuleNode), true);
      });

      test('should handle nested inline elements', () {
        final result = parser.parse('This is **bold with *italic* inside**');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());

        final para = result[0] as ParagraphNode;
        final bold = para.children.firstWhere((n) => n is BoldNode) as BoldNode;
        expect(bold.children.any((n) => n is ItalicNode), true);
      });
    });

    group('Async Parsing', () {
      test('should parse asynchronously', () async {
        final result = await parser.parseAsync('# Async Test\n\nParagraph');
        expect(result.length, 2);
        expect(result[0], isA<HeaderNode>());
        expect(result[1], isA<ParagraphNode>());
      });
    });

    group('Partial Parsing', () {
      test('should parse blocks only', () {
        final result = parser.parseBlocksOnly('This is **bold**');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());

        // Should not have inline parsing
        final para = result[0] as ParagraphNode;
        expect(para.children.length, 1);
        expect(para.children[0], isA<TextNode>());
        expect((para.children[0] as TextNode).content, 'This is **bold**');
      });

      test('should parse inline only', () {
        final result = parser.parseInlineOnly('This is **bold** and *italic*');
        expect(result.length, 4);
        expect(result.any((n) => n is BoldNode), true);
        expect(result.any((n) => n is ItalicNode), true);
      });
    });

    group('Edge Cases', () {
      test('should handle only whitespace', () {
        final result = parser.parse('   \n  \n  ');
        expect(result, isEmpty);
      });

      test('should handle multiple empty lines', () {
        const markdown = '''
Paragraph one


Paragraph two
''';
        final result = parser.parse(markdown);
        expect(result.length, 2);
        expect(result[0], isA<ParagraphNode>());
        expect(result[1], isA<ParagraphNode>());
      });

      test('should handle complex nesting', () {
        final result = parser.parse('[**bold** and *italic*](url)');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());

        final para = result[0] as ParagraphNode;
        expect(para.children[0], isA<LinkNode>());
      });
    });
  });
}

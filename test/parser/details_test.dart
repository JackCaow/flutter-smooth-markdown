import 'package:flutter_smooth_markdown/src/parser/ast/markdown_node.dart';
import 'package:flutter_smooth_markdown/src/parser/block_parser.dart';
import 'package:flutter_smooth_markdown/src/parser/markdown_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Details Parsing Tests', () {
    late BlockParser parser;

    setUp(() {
      parser = BlockParser();
    });

    test('Parse basic details with summary', () {
      const markdown = '''
<details>
<summary>Click to expand</summary>
This is the hidden content
</details>''';

      final nodes = parser.parse(markdown);

      expect(nodes.length, equals(1));
      expect(nodes[0], isA<DetailsNode>());

      final details = nodes[0] as DetailsNode;
      expect(details.isOpen, isFalse);
      expect(details.summary.isNotEmpty, isTrue);
      expect(details.children.isNotEmpty, isTrue);
    });

    test('Parse details with open attribute', () {
      const markdown = '''
<details open>
<summary>Already expanded</summary>
Visible content
</details>''';

      final nodes = parser.parse(markdown);

      expect(nodes.length, equals(1));
      expect(nodes[0], isA<DetailsNode>());

      final details = nodes[0] as DetailsNode;
      expect(details.isOpen, isTrue);
    });

    test('Parse details with multiline content', () {
      const markdown = '''
<details>
<summary>Table of Contents</summary>

- Item 1
- Item 2
- Item 3

Some paragraph text.
</details>''';

      final nodes = parser.parse(markdown);

      expect(nodes.length, equals(1));
      expect(nodes[0], isA<DetailsNode>());

      final details = nodes[0] as DetailsNode;
      expect(details.children.length, greaterThan(1));
    });

    test('Parse details with summary on same line as tag', () {
      const markdown = '''
<details>
<summary>Title</summary>
Content here
</details>''';

      final nodes = parser.parse(markdown);

      expect(nodes.length, equals(1));
      expect(nodes[0], isA<DetailsNode>());

      final details = nodes[0] as DetailsNode;
      expect(details.summary.isNotEmpty, isTrue);
    });

    test('Parse details with code block inside', () {
      const markdown = '''
<details>
<summary>Code Example</summary>

```dart
void main() {
  print('Hello World');
}
```
</details>''';

      final nodes = parser.parse(markdown);

      expect(nodes.length, equals(1));
      expect(nodes[0], isA<DetailsNode>());

      final details = nodes[0] as DetailsNode;
      expect(details.children.any((node) => node is CodeBlockNode), isTrue);
    });

    test('Parse empty details block', () {
      const markdown = '''
<details>
<summary>Empty</summary>
</details>''';

      final nodes = parser.parse(markdown);

      expect(nodes.length, equals(1));
      expect(nodes[0], isA<DetailsNode>());

      final details = nodes[0] as DetailsNode;
      expect(details.children, isEmpty);
    });

    test('Parse multiple details blocks', () {
      const markdown = '''
<details>
<summary>First</summary>
Content 1
</details>

<details>
<summary>Second</summary>
Content 2
</details>''';

      final nodes = parser.parse(markdown);

      expect(nodes.length, equals(2));
      expect(nodes[0], isA<DetailsNode>());
      expect(nodes[1], isA<DetailsNode>());
    });
  });

  group('DetailsNode Tests', () {
    test('Create DetailsNode', () {
      const node = DetailsNode(
        summary: [TextNode('Summary')],
        children: [TextNode('Content')],
      );

      expect(node.type, equals('details'));
      expect(node.isOpen, isFalse);
      expect(node.summary.length, equals(1));
      expect(node.children.length, equals(1));
    });

    test('Create DetailsNode with open attribute', () {
      const node = DetailsNode(
        summary: [TextNode('Summary')],
        children: [TextNode('Content')],
        isOpen: true,
      );

      expect(node.isOpen, isTrue);
    });

    test('DetailsNode copyWith', () {
      const original = DetailsNode(
        summary: [TextNode('Summary')],
        children: [TextNode('Content')],
      );

      final copied = original.copyWith(isOpen: true);

      expect(copied.isOpen, isTrue);
      expect(copied.summary, equals(original.summary));
      expect(copied.children, equals(original.children));
    });

    test('DetailsNode toJson', () {
      const node = DetailsNode(
        summary: [TextNode('Summary')],
        children: [TextNode('Content')],
        isOpen: true,
      );

      final json = node.toJson();

      expect(json['type'], equals('details'));
      expect(json['isOpen'], isTrue);
      expect(json['summary'], isA<List<dynamic>>());
      expect(json['children'], isA<List<dynamic>>());
    });
  });

  group('Details inline processing', () {
    test('processes inline markdown inside details content', () {
      final parser = MarkdownParser();
      final nodes = parser.parse(
        '<details>\n<summary>s</summary>\n**bold** body\n</details>',
      );

      final details = nodes[0] as DetailsNode;
      final paragraph = details.children.first as ParagraphNode;
      expect(paragraph.children.whereType<BoldNode>(), hasLength(1));
    });

    test('processes nested blocks inside details content', () {
      final parser = MarkdownParser();
      final nodes = parser.parse(
        '<details>\n<summary>s</summary>\n> *quoted*\n</details>',
      );

      final details = nodes[0] as DetailsNode;
      final quote = details.children.first as BlockquoteNode;
      final paragraph = quote.children.first as ParagraphNode;
      expect(paragraph.children.whereType<ItalicNode>(), hasLength(1));
    });
  });
}

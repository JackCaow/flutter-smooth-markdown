import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarkdownNode Tests', () {
    group('TextNode', () {
      test('should create text node with content', () {
        const node = TextNode('Hello, World!');
        expect(node.content, 'Hello, World!');
        expect(node.type, 'text');
      });

      test('should convert to JSON correctly', () {
        const node = TextNode('Test');
        final json = node.toJson();
        expect(json['type'], 'text');
        expect(json['content'], 'Test');
      });

      test('should copy with new content', () {
        const node = TextNode('Original');
        final copy = node.copyWith(content: 'Modified');
        expect(copy.content, 'Modified');
        expect(node.content, 'Original');
      });
    });

    group('HeaderNode', () {
      test('should create header node with level and content', () {
        const node = HeaderNode(level: 1, content: 'Title');
        expect(node.level, 1);
        expect(node.content, 'Title');
        expect(node.type, 'header');
      });

      test('should validate header level', () {
        expect(
          () => HeaderNode(level: 0, content: 'Invalid'),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => HeaderNode(level: 7, content: 'Invalid'),
          throwsA(isA<AssertionError>()),
        );
      });

      test('should convert to JSON correctly', () {
        const node = HeaderNode(level: 2, content: 'Subtitle');
        final json = node.toJson();
        expect(json['type'], 'header');
        expect(json['level'], 2);
        expect(json['content'], 'Subtitle');
      });
    });

    group('CodeBlockNode', () {
      test('should create code block with language', () {
        const node = CodeBlockNode(
          code: 'print("Hello")',
          language: 'dart',
        );
        expect(node.code, 'print("Hello")');
        expect(node.language, 'dart');
        expect(node.fence, '```');
        expect(node.type, 'code_block');
      });

      test('should create code block without language', () {
        const node = CodeBlockNode(code: 'plain code');
        expect(node.code, 'plain code');
        expect(node.language, null);
        expect(node.fence, '```');
      });

      test('should preserve a tilde fence', () {
        const node = CodeBlockNode(
          code: 'print("Hello")',
          language: 'dart',
          fence: '~~~',
        );
        expect(node.fence, '~~~');
        expect(node.toJson()['fence'], '~~~');
      });

      test('should preserve a code fence info string', () {
        const node = CodeBlockNode(
          code: 'print("Hello")',
          language: 'dart',
          info: 'dart title=main.dart',
        );
        expect(node.language, 'dart');
        expect(node.info, 'dart title=main.dart');
        expect(node.toJson()['info'], 'dart title=main.dart');
      });
    });

    group('ListNode', () {
      test('should create unordered list', () {
        const node = ListNode(
          items: [
            ListItemNode(children: [TextNode('Item 1')]),
            ListItemNode(children: [TextNode('Item 2')]),
          ],
        );
        expect(node.ordered, false);
        expect(node.items.length, 2);
        expect(node.type, 'list');
      });

      test('should create ordered list', () {
        const node = ListNode(
          items: [
            ListItemNode(children: [TextNode('First')]),
            ListItemNode(children: [TextNode('Second')]),
          ],
          ordered: true,
          startIndex: 1,
        );
        expect(node.ordered, true);
        expect(node.startIndex, 1);
      });
    });

    group('LinkNode', () {
      test('should create link node', () {
        const node = LinkNode(
          url: 'https://example.com',
          children: [TextNode('Example')],
          title: 'Example Link',
        );
        expect(node.url, 'https://example.com');
        expect(node.title, 'Example Link');
        expect(node.type, 'link');
      });
    });

    group('ImageNode', () {
      test('should create image node', () {
        const node = ImageNode(
          url: 'https://example.com/image.png',
          alt: 'Example Image',
          title: 'Image Title',
        );
        expect(node.url, 'https://example.com/image.png');
        expect(node.alt, 'Example Image');
        expect(node.title, 'Image Title');
        expect(node.type, 'image');
      });
    });
  });
}

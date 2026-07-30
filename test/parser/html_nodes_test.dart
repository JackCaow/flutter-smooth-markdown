import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HTML AST Nodes', () {
    group('UnderlineNode', () {
      test('exposes children and underline type', () {
        const node = UnderlineNode([TextNode('under')]);
        expect(node.children, hasLength(1));
        expect(node.type, 'underline');
      });

      test('converts to JSON with children', () {
        const node = UnderlineNode([TextNode('under')]);
        final json = node.toJson();
        expect(json['type'], 'underline');
        expect(json['children'], hasLength(1));
      });

      test('copies with new children without mutating original', () {
        const node = UnderlineNode([TextNode('a')]);
        final copy = node.copyWith(children: const [TextNode('b')]);
        expect((copy.children.first as TextNode).content, 'b');
        expect((node.children.first as TextNode).content, 'a');
      });
    });

    group('HighlightNode', () {
      test('exposes children and highlight type', () {
        const node = HighlightNode([TextNode('marked')]);
        expect(node.type, 'highlight');
        expect(node.toJson()['type'], 'highlight');
      });
    });

    group('SubscriptNode', () {
      test('exposes children and subscript type', () {
        const node = SubscriptNode([TextNode('2')]);
        expect(node.type, 'subscript');
        expect(node.toJson()['children'], hasLength(1));
      });
    });

    group('SuperscriptNode', () {
      test('exposes children and superscript type', () {
        const node = SuperscriptNode([TextNode('2')]);
        expect(node.type, 'superscript');
        expect(node.copyWith().children, hasLength(1));
      });
    });

    group('KbdNode', () {
      test('exposes children and kbd type', () {
        const node = KbdNode([TextNode('Ctrl')]);
        expect(node.type, 'kbd');
        expect(node.toJson()['type'], 'kbd');
      });
    });

    group('StyledSpanNode', () {
      test('stores color, background color, and font size', () {
        const node = StyledSpanNode(
          children: [TextNode('styled')],
          color: 0xFFFF0000,
          backgroundColor: 0xFF00FF00,
          fontSize: 18,
        );
        expect(node.type, 'styled_span');
        expect(node.color, 0xFFFF0000);
        expect(node.backgroundColor, 0xFF00FF00);
        expect(node.fontSize, 18);
      });

      test('omits null style fields from JSON', () {
        const node = StyledSpanNode(children: [TextNode('plain')]);
        final json = node.toJson();
        expect(json.containsKey('color'), isFalse);
        expect(json.containsKey('backgroundColor'), isFalse);
        expect(json.containsKey('fontSize'), isFalse);
      });

      test('copies with new color preserving other fields', () {
        const node = StyledSpanNode(
          children: [TextNode('styled')],
          fontSize: 14,
        );
        final copy = node.copyWith(color: 0xFF0000FF);
        expect(copy.color, 0xFF0000FF);
        expect(copy.fontSize, 14);
        expect(node.color, isNull);
      });
    });

    group('HtmlBlockNode', () {
      test('stores tag, children, and alignment', () {
        const node = HtmlBlockNode(
          tag: 'center',
          children: [
            ParagraphNode([TextNode('centered')])
          ],
          align: HtmlBlockAlignment.center,
        );
        expect(node.type, 'html_block');
        expect(node.tag, 'center');
        expect(node.align, HtmlBlockAlignment.center);
      });

      test('converts to JSON with alignment name', () {
        const node = HtmlBlockNode(
          tag: 'div',
          children: [],
          align: HtmlBlockAlignment.right,
        );
        final json = node.toJson();
        expect(json['tag'], 'div');
        expect(json['align'], 'right');
      });

      test('omits alignment from JSON when null', () {
        const node = HtmlBlockNode(tag: 'p', children: []);
        expect(node.toJson().containsKey('align'), isFalse);
      });
    });

    group('ImageNode dimensions', () {
      test('stores optional width and height', () {
        const node = ImageNode(
          url: 'https://example.com/a.png',
          alt: 'alt',
          width: 200,
          height: 100,
        );
        expect(node.width, 200);
        expect(node.height, 100);
      });

      test('defaults width and height to null', () {
        const node = ImageNode(url: 'a.png', alt: 'alt');
        expect(node.width, isNull);
        expect(node.height, isNull);
        expect(node.toJson().containsKey('width'), isFalse);
      });

      test('includes dimensions in JSON when present', () {
        const node = ImageNode(url: 'a.png', alt: 'alt', width: 64);
        final json = node.toJson();
        expect(json['width'], 64);
        expect(json.containsKey('height'), isFalse);
      });

      test('copies with new dimensions', () {
        const node = ImageNode(url: 'a.png', alt: 'alt');
        final copy = node.copyWith(width: 32, height: 16);
        expect(copy.width, 32);
        expect(copy.height, 16);
        expect(copy.url, 'a.png');
      });
    });
  });
}

import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/inline_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InlineParser HTML support', () {
    late InlineParser parser;

    setUp(() {
      parser = InlineParser(enableHtml: true);
    });

    String plainText(List<MarkdownNode> nodes) =>
        nodes.whereType<TextNode>().map((n) => n.content).join();

    group('formatting tags', () {
      test('maps strong tag to BoldNode when html enabled', () {
        final result = parser.parse('<strong>hi</strong>');
        expect(result, hasLength(1));
        expect(result[0], isA<BoldNode>());
        final bold = result[0] as BoldNode;
        expect((bold.children.first as TextNode).content, 'hi');
      });

      test('maps b and i tags to bold and italic nodes', () {
        expect(parser.parse('<b>x</b>').first, isA<BoldNode>());
        expect(parser.parse('<i>x</i>').first, isA<ItalicNode>());
        expect(parser.parse('<em>x</em>').first, isA<ItalicNode>());
      });

      test('maps strike family tags to StrikethroughNode', () {
        expect(parser.parse('<s>x</s>').first, isA<StrikethroughNode>());
        expect(parser.parse('<del>x</del>').first, isA<StrikethroughNode>());
        expect(
            parser.parse('<strike>x</strike>').first, isA<StrikethroughNode>());
      });

      test('maps u and ins tags to UnderlineNode', () {
        expect(parser.parse('<u>x</u>').first, isA<UnderlineNode>());
        expect(parser.parse('<ins>x</ins>').first, isA<UnderlineNode>());
      });

      test('maps mark sub sup and kbd tags to dedicated nodes', () {
        expect(parser.parse('<mark>x</mark>').first, isA<HighlightNode>());
        expect(parser.parse('<sub>2</sub>').first, isA<SubscriptNode>());
        expect(parser.parse('<sup>2</sup>').first, isA<SuperscriptNode>());
        expect(parser.parse('<kbd>Ctrl</kbd>').first, isA<KbdNode>());
      });

      test('parses tag names case-insensitively', () {
        expect(parser.parse('<B>x</B>').first, isA<BoldNode>());
      });

      test('maps br tag to HardBreakNode', () {
        final result = parser.parse('a<br>b');
        expect(result, hasLength(3));
        expect(result[1], isA<HardBreakNode>());
        final selfClosed = parser.parse('a<br/>b');
        expect(selfClosed[1], isA<HardBreakNode>());
      });

      test('keeps code tag content verbatim without recursion', () {
        final result = parser.parse('<code>a<b **c**</code>');
        expect(result, hasLength(1));
        expect(result[0], isA<InlineCodeNode>());
        expect((result[0] as InlineCodeNode).code, 'a<b **c**');
      });
    });

    group('disabled and literal text', () {
      test('keeps angle bracket as literal text when html disabled', () {
        final plain = InlineParser();
        final result = plain.parse('<b>hi</b>');
        expect(result, hasLength(1));
        expect((result[0] as TextNode).content, '<b>hi</b>');
      });

      test('keeps invalid tags as literal text when html enabled', () {
        for (final input in ['a < b', '2<3', '<3 you', '< b>', 'end<']) {
          final result = parser.parse(input);
          expect(plainText(result), input, reason: 'input: $input');
        }
      });

      test('keeps angle bracket autolink style url as literal text', () {
        final result = parser.parse('<https://example.com>');
        expect(plainText(result), '<https://example.com>');
      });

      test('escaped angle bracket suppresses tag parsing', () {
        final result = parser.parse(r'\<b>x');
        expect(plainText(result), '<b>x');
        expect(result.whereType<BoldNode>(), isEmpty);
      });
    });

    group('unknown tags', () {
      test('strips unknown tag and keeps inner content', () {
        final result = parser.parse('<video>content</video>');
        expect(result, hasLength(1));
        expect((result[0] as TextNode).content, 'content');
      });

      test('strips unknown self-closed tag entirely', () {
        final result = parser.parse('a<foo/>b');
        expect(plainText(result), 'ab');
      });

      test('consumes stray closing tag silently', () {
        final result = parser.parse('</b>x');
        expect(plainText(result), 'x');
      });

      test('consumes inline hr tag silently', () {
        final result = parser.parse('a<hr>b');
        expect(plainText(result), 'ab');
      });

      test('parses markdown inside stripped unknown tag', () {
        final result = parser.parse('<section>**bold**</section>');
        expect(result.first, isA<BoldNode>());
      });
    });

    group('nesting', () {
      test('parses nested html tags', () {
        final result = parser.parse('<b><i>x</i></b>');
        final bold = result.first as BoldNode;
        expect(bold.children.first, isA<ItalicNode>());
      });

      test('matches same-name nested tags with a counter', () {
        final result = parser.parse('<u>a<u>b</u>c</u>');
        expect(result, hasLength(1));
        final outer = result.first as UnderlineNode;
        expect(outer.children.whereType<UnderlineNode>(), hasLength(1));
        expect(plainText(outer.children), 'ac');
      });

      test('parses html inside markdown emphasis', () {
        final result = parser.parse('**a <u>b</u>**');
        final bold = result.first as BoldNode;
        expect(bold.children.whereType<UnderlineNode>(), hasLength(1));
      });

      test('parses markdown inside html tag', () {
        final result = parser.parse('<b>a **c**</b>');
        final bold = result.first as BoldNode;
        expect(bold.children.whereType<BoldNode>(), hasLength(1));
      });

      test('falls back to plain text beyond max nesting depth', () {
        final open = List.filled(20, '<b>').join();
        final close = List.filled(20, '</b>').join();
        final result = parser.parse('${open}x$close');
        expect(result, isNotEmpty);
      });
    });

    group('unclosed tags', () {
      test('auto closes unclosed mark tag at end of text', () {
        final result = parser.parse('<mark>rest of text');
        expect(result, hasLength(1));
        final mark = result.first as HighlightNode;
        expect(plainText(mark.children), 'rest of text');
      });

      test('auto closes unclosed unknown tag keeping content', () {
        final result = parser.parse('<widget>partial');
        expect(plainText(result), 'partial');
      });
    });

    group('code span protection', () {
      test('does not parse tags inside inline code span', () {
        final result = parser.parse('`<b>`');
        expect(result, hasLength(1));
        expect((result[0] as InlineCodeNode).code, '<b>');
      });

      test('does not parse tags inside inline math', () {
        final result = parser.parse(r'$a<b$');
        expect(result.first, isA<InlineMathNode>());
      });
    });

    group('links and images', () {
      test('parses anchor tag into LinkNode with title', () {
        final result = parser.parse('<a href="https://x.com" title="t">go</a>');
        final link = result.first as LinkNode;
        expect(link.url, 'https://x.com');
        expect(link.title, 't');
        expect(plainText(link.children), 'go');
      });

      test('drops link with javascript href but keeps link text', () {
        final result = parser.parse('<a href="javascript:alert(1)">click</a>');
        expect(result.whereType<LinkNode>(), isEmpty);
        expect(plainText(result), 'click');
      });

      test('strips anchor without href keeping content', () {
        final result = parser.parse('<a name="x">y</a>');
        expect(result.whereType<LinkNode>(), isEmpty);
        expect(plainText(result), 'y');
      });

      test('parses img width and height attributes into ImageNode', () {
        final result = parser.parse(
          '<img src="https://x.com/a.png" alt="pic" width=64 height="32">',
        );
        final image = result.first as ImageNode;
        expect(image.url, 'https://x.com/a.png');
        expect(image.alt, 'pic');
        expect(image.width, 64);
        expect(image.height, 32);
      });

      test('emits alt text for img with unsafe src', () {
        final result = parser.parse('<img src="javascript:x" alt="my pic">');
        expect(result.whereType<ImageNode>(), isEmpty);
        expect(plainText(result), 'my pic');
      });

      test('ignores percent dimensions on img', () {
        final result = parser.parse(
          '<img src="https://x.com/a.png" alt="a" width="100%">',
        );
        final image = result.first as ImageNode;
        expect(image.width, isNull);
      });
    });

    group('styled spans', () {
      test('parses font color into StyledSpanNode', () {
        final result = parser.parse('<font color="red">r</font>');
        final span = result.first as StyledSpanNode;
        expect(span.color, 0xFFFF0000);
      });

      test('parses font size scale into pixels', () {
        final result = parser.parse('<font size="3">x</font>');
        final span = result.first as StyledSpanNode;
        expect(span.fontSize, 16);
      });

      test('parses span style declarations for safe properties', () {
        final result = parser.parse(
          '<span style="color:#00f; font-size:18px; '
          'background-color:yellow">x</span>',
        );
        final span = result.first as StyledSpanNode;
        expect(span.color, 0xFF0000FF);
        expect(span.fontSize, 18);
        expect(span.backgroundColor, 0xFFFFFF00);
      });

      test('ignores unsafe css properties silently', () {
        final result = parser.parse(
          '<span style="position:fixed; color:red">x</span>',
        );
        final span = result.first as StyledSpanNode;
        expect(span.color, 0xFFFF0000);
      });

      test('strips span without any usable style', () {
        final result = parser.parse('<span class="x">y</span>');
        expect(result.whereType<StyledSpanNode>(), isEmpty);
        expect(plainText(result), 'y');
      });
    });
  });
}

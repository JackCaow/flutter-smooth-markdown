import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('markdownToHtml URL export policy', () {
    test('keeps safe link hrefs', () {
      final html = markdownToHtml(
        '[http](http://example.com/path?x=1&y=2)\n'
        '[https](https://example.com)\n'
        '[mail](mailto:team@example.com)\n'
        '[phone](tel:+15551234567)\n'
        '[relative](../guide/page.md#top)',
      );

      expect(
        html,
        contains('href="http://example.com/path?x=1&amp;y=2"'),
      );
      expect(html, contains('href="https://example.com"'));
      expect(html, contains('href="mailto:team@example.com"'));
      expect(html, contains('href="tel:+15551234567"'));
      expect(html, contains('href="../guide/page.md#top"'));
    });

    test('drops dangerous link hrefs while keeping labels', () {
      final html = markdownToHtml(
        '[script](javascript:alert)\n'
        '[data](data:text/html,<svg>)\n'
        '[vb](vbscript:msgbox)\n'
        '[ftp](ftp://example.com/file)',
      );

      expect(RegExp(r'href=""').allMatches(html), hasLength(4));
      expect(html, contains('>script</a>'));
      expect(html, contains('>data</a>'));
      expect(html, isNot(contains('javascript:alert')));
      expect(html, isNot(contains('data:text/html')));
      expect(html, isNot(contains('vbscript:')));
      expect(html, isNot(contains('ftp://example.com/file')));
    });

    test('applies the same safe URL policy to image sources', () {
      final html = markdownToHtml(
        '![remote](https://example.com/image.png)\n\n'
        '![local](./images/pic.png)\n\n'
        '![script](javascript:alert)\n\n'
        'Inline ![data](data:image/svg+xml,<svg> "bad & <title>").',
      );

      expect(
        html,
        contains('<img src="https://example.com/image.png" alt="remote">'),
      );
      expect(html, contains('<img src="./images/pic.png" alt="local">'));
      expect(html, contains('<img src="" alt="script">'));
      expect(
        html,
        contains('<img src="" alt="data" title="bad &amp; &lt;title&gt;">'),
      );
      expect(html, isNot(contains('javascript:alert')));
      expect(html, isNot(contains('data:image/svg+xml')));
    });

    test('escapes link and image attributes', () {
      final html = markdownToHtml(
        '[A & B](https://example.com/search?q="one"&x=<tag> '
        '"Title & <ok>")\n\n'
        '![Alt "quote" & <tag>]'
        '(https://example.com/img.png?name="cat"&x=<1> "Image & <ok>")',
      );

      expect(
        html,
        contains(
          '<a target="_blank" rel="noopener noreferrer nofollow" class="underline cursor-pointer" href="https://example.com/search?q=&quot;one&quot;&amp;x=&lt;tag&gt;" title="Title &amp; &lt;ok&gt;">A &amp; B</a>',
        ),
      );
      expect(
        html,
        contains(
          '<img src="https://example.com/img.png?name=&quot;cat&quot;&amp;x=&lt;1&gt;" alt="Alt &quot;quote&quot; &amp; &lt;tag&gt;" title="Image &amp; &lt;ok&gt;">',
        ),
      );
    });
  });

  group('markdownToHtml Scratch TipTap fixture alignment', () {
    test('exports table alignment on cell paragraphs', () {
      final html = markdownToHtml(
        '| Left | Center | Right | Plain |\n'
        '| :--- | :---: | ---: | --- |\n'
        '| **L** | C | R | P |',
      );

      expect(
        html,
        '<table class="not-prose" style="min-width: 100px">\n'
        '<colgroup>\n'
        '<col style="min-width: 25px">\n'
        '<col style="min-width: 25px">\n'
        '<col style="min-width: 25px">\n'
        '<col style="min-width: 25px">\n'
        '</colgroup>\n'
        '<tbody>\n'
        '<tr>\n'
        '<th colspan="1" rowspan="1"><p style="text-align: left">Left</p></th>\n'
        '<th colspan="1" rowspan="1"><p style="text-align: center">Center</p></th>\n'
        '<th colspan="1" rowspan="1"><p style="text-align: right">Right</p></th>\n'
        '<th colspan="1" rowspan="1"><p>Plain</p></th>\n'
        '</tr>\n'
        '<tr>\n'
        '<td colspan="1" rowspan="1"><p style="text-align: left"><strong>L</strong></p></td>\n'
        '<td colspan="1" rowspan="1"><p style="text-align: center">C</p></td>\n'
        '<td colspan="1" rowspan="1"><p style="text-align: right">R</p></td>\n'
        '<td colspan="1" rowspan="1"><p>P</p></td>\n'
        '</tr>\n'
        '</tbody>\n'
        '</table>',
      );
    });

    test('keeps escaped inline delimiters literal', () {
      final html = markdownToHtml(
        r'\*literal\* and \_literal\_ and \~\~literal\~\~ with '
        r'\[label\](https://example.com), \`code\`, \\ slash, and **bold**.',
      );

      expect(
        html,
        r'<p>*literal* and _literal_ and ~~literal~~ with [label](https:&#47;&#47;example.com), `code`, \ slash, and <strong>bold</strong>.</p>',
      );
      expect(html, isNot(contains('<em>literal</em>')));
      expect(html, isNot(contains('<s>literal</s>')));
      expect(html, isNot(contains('href="https://example.com"')));
    });

    test('keeps protected html token-looking text literal', () {
      final html =
          markdownToHtml('{{SMHTML0}} and [link](https://example.com)');

      expect(
        html,
        '<p>{{SMHTML0}} and <a target="_blank" rel="noopener noreferrer nofollow" class="underline cursor-pointer" href="https://example.com">link</a></p>',
      );
    });

    test('only closes fenced code blocks on valid closing fences', () {
      final html = markdownToHtml(
        '````dart\n'
        '```not a closing fence\n'
        'print(1);\n'
        '```\n'
        'still code\n'
        '````\n'
        'after',
      );

      expect(
        html,
        '<pre><code class="language-dart">```not a closing fence\n'
        'print(1);\n'
        '```\n'
        'still code</code></pre>\n'
        '<p>after</p>',
      );
    });

    test('exports details blocks without allowing raw html injection', () {
      final html = markdownToHtml(
        '<details open>\n'
        '<summary>Show **more**</summary>\n\n'
        'Hidden <script>alert(1)</script>\n\n'
        '- Item\n'
        '</details>',
      );

      expect(
        html,
        '<details open="">\n'
        '<summary>Show <strong>more</strong></summary>\n'
        '<p>Hidden &lt;script&gt;alert(1)&lt;&#47;script&gt;</p>\n'
        '<ul>\n'
        '<li><p>Item</p></li>\n'
        '</ul>\n'
        '</details>',
      );
      expect(html, isNot(contains('<script>')));

      expect(
        markdownToHtml(
          '<details onclick="alert(1)">\n'
          '<summary>Unsafe</summary>\n'
          '</details>',
        ),
        '<p>&lt;details onclick=&quot;alert(1)&quot;&gt; '
        '&lt;summary&gt;Unsafe&lt;&#47;summary&gt; &lt;&#47;details&gt;</p>',
      );
    });
  });
}

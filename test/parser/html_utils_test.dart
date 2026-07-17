import 'package:flutter_smooth_markdown/src/parser/html/html_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lexHtmlTag', () {
    test('lexes simple open tag', () {
      final tag = lexHtmlTag('<b>', 0);
      expect(tag, isNotNull);
      expect(tag!.name, 'b');
      expect(tag.isClosing, isFalse);
      expect(tag.isSelfClosing, isFalse);
      expect(tag.attributes, isEmpty);
      expect(tag.end, 3);
    });

    test('lexes closing tag', () {
      final tag = lexHtmlTag('</div>', 0);
      expect(tag!.name, 'div');
      expect(tag.isClosing, isTrue);
      expect(tag.end, 6);
    });

    test('lexes self-closing tag without space', () {
      final tag = lexHtmlTag('<br/>', 0);
      expect(tag!.name, 'br');
      expect(tag.isSelfClosing, isTrue);
      expect(tag.end, 5);
    });

    test('lexes self-closing tag with space', () {
      final tag = lexHtmlTag('<hr />', 0);
      expect(tag!.name, 'hr');
      expect(tag.isSelfClosing, isTrue);
    });

    test('lowercases tag name', () {
      final tag = lexHtmlTag('<BR>', 0);
      expect(tag!.name, 'br');
    });

    test('lexes tag with mixed quoted and unquoted attributes', () {
      final tag = lexHtmlTag(
        '<img src="a.png" alt=\'x y\' width=200 loading>',
        0,
      );
      expect(tag!.name, 'img');
      expect(tag.attributes['src'], 'a.png');
      expect(tag.attributes['alt'], 'x y');
      expect(tag.attributes['width'], '200');
      expect(tag.attributes['loading'], '');
    });

    test('lowercases attribute names but preserves values', () {
      final tag = lexHtmlTag('<div ALIGN="Center">', 0);
      expect(tag!.attributes['align'], 'Center');
    });

    test('allows spaces around attribute equals sign', () {
      final tag = lexHtmlTag('<a href = "x">', 0);
      expect(tag!.attributes['href'], 'x');
    });

    test('keeps first value for duplicate attributes', () {
      final tag = lexHtmlTag('<a href="1" href="2">', 0);
      expect(tag!.attributes['href'], '1');
    });

    test('allows closing angle bracket inside quoted value', () {
      final tag = lexHtmlTag('<a title="a > b">', 0);
      expect(tag!.attributes['title'], 'a > b');
      expect(tag.end, 17);
    });

    test('lexes hyphenated custom tag name', () {
      final tag = lexHtmlTag('<my-widget>', 0);
      expect(tag!.name, 'my-widget');
    });

    test('lexes empty unquoted attribute value', () {
      final tag = lexHtmlTag('<img src=>', 0);
      expect(tag!.attributes['src'], '');
    });

    test('lexes at a non-zero start offset', () {
      final tag = lexHtmlTag('ab<i>', 2);
      expect(tag!.name, 'i');
      expect(tag.end, 5);
    });

    test('returns null for digit after angle bracket', () {
      expect(lexHtmlTag('<3 you', 0), isNull);
    });

    test('returns null for space after angle bracket', () {
      expect(lexHtmlTag('< b>', 0), isNull);
    });

    test('returns null for tag name starting with digit', () {
      expect(lexHtmlTag('<1a>', 0), isNull);
    });

    test('returns null for colon in tag name', () {
      expect(lexHtmlTag('<https://example.com>', 0), isNull);
    });

    test('returns null for attribute name starting with digit', () {
      expect(lexHtmlTag('<a 1x=2>', 0), isNull);
    });

    test('returns null when closing bracket is missing', () {
      expect(lexHtmlTag('<b never closed', 0), isNull);
    });

    test('gives up lexing beyond max tag length', () {
      final longTag = '<a title="${'x' * 600}">';
      expect(lexHtmlTag(longTag, 0), isNull);
    });
  });

  group('parseHtmlColor', () {
    test('parses shorthand hex color to argb int', () {
      expect(parseHtmlColor('#f00'), 0xFFFF0000);
    });

    test('parses six digit hex color', () {
      expect(parseHtmlColor('#00FF00'), 0xFF00FF00);
    });

    test('parses named color case-insensitively', () {
      expect(parseHtmlColor('red'), 0xFFFF0000);
      expect(parseHtmlColor('REd'), 0xFFFF0000);
    });

    test('returns null for unknown color name', () {
      expect(parseHtmlColor('notacolor'), isNull);
    });

    test('rejects eight digit hex color', () {
      expect(parseHtmlColor('#ff00ff00'), isNull);
    });

    test('rejects malformed hex color', () {
      expect(parseHtmlColor('#12'), isNull);
      expect(parseHtmlColor('#gggggg'), isNull);
      expect(parseHtmlColor(''), isNull);
    });
  });

  group('parseHtmlFontSize', () {
    test('parses pixel value', () {
      expect(parseHtmlFontSize('18px'), 18);
    });

    test('converts points to pixels', () {
      expect(parseHtmlFontSize('12pt'), 16);
    });

    test('parses bare number', () {
      expect(parseHtmlFontSize('14'), 14);
    });

    test('rejects relative units and keywords', () {
      expect(parseHtmlFontSize('1.2em'), isNull);
      expect(parseHtmlFontSize('80%'), isNull);
      expect(parseHtmlFontSize('large'), isNull);
    });

    test('rejects sizes outside the safe range', () {
      expect(parseHtmlFontSize('2px'), isNull);
      expect(parseHtmlFontSize('500px'), isNull);
    });
  });

  group('parseFontSizeAttr', () {
    test('maps legacy font size scale to pixels', () {
      expect(parseFontSizeAttr('1'), 10);
      expect(parseFontSizeAttr('3'), 16);
      expect(parseFontSizeAttr('7'), 48);
    });

    test('rejects out of range and relative values', () {
      expect(parseFontSizeAttr('0'), isNull);
      expect(parseFontSizeAttr('99'), isNull);
      expect(parseFontSizeAttr('+2'), isNull);
    });
  });

  group('parseInlineCssDeclarations', () {
    test('splits declarations and lowercases property names', () {
      final decls = parseInlineCssDeclarations(
        'Color: Red; font-size : 14px;',
      );
      expect(decls['color'], 'Red');
      expect(decls['font-size'], '14px');
    });

    test('skips malformed declarations', () {
      final decls = parseInlineCssDeclarations('no-colon; :bad; ok:1');
      expect(decls, {'ok': '1'});
    });

    test('keeps first value for duplicate properties', () {
      final decls = parseInlineCssDeclarations('color:red;color:blue');
      expect(decls['color'], 'red');
    });
  });

  group('parseHtmlDimension', () {
    test('parses bare and px suffixed numbers', () {
      expect(parseHtmlDimension('64'), 64);
      expect(parseHtmlDimension('64px'), 64);
      expect(parseHtmlDimension(' 32.5 '), 32.5);
    });

    test('rejects percentages zero and oversized values', () {
      expect(parseHtmlDimension('100%'), isNull);
      expect(parseHtmlDimension('0'), isNull);
      expect(parseHtmlDimension('-5'), isNull);
      expect(parseHtmlDimension('99999'), isNull);
    });
  });

  group('isSafeHtmlUrl', () {
    test('allows http and https urls', () {
      expect(isSafeHtmlUrl('https://example.com'), isTrue);
      expect(isSafeHtmlUrl('http://example.com/a?b=c'), isTrue);
    });

    test('allows mailto and tel schemes', () {
      expect(isSafeHtmlUrl('mailto:a@b.com'), isTrue);
      expect(isSafeHtmlUrl('tel:+12345'), isTrue);
    });

    test('allows relative and anchor urls', () {
      expect(isSafeHtmlUrl('assets/img.png'), isTrue);
      expect(isSafeHtmlUrl('/a/b'), isTrue);
      expect(isSafeHtmlUrl('#section'), isTrue);
    });

    test('allows protocol-relative urls', () {
      expect(isSafeHtmlUrl('//cdn.example.com/x.png'), isTrue);
    });

    test('treats colon after path separator as non-scheme', () {
      expect(isSafeHtmlUrl('a/b:c'), isTrue);
    });

    test('rejects javascript scheme in url safety check', () {
      expect(isSafeHtmlUrl('javascript:alert(1)'), isFalse);
      expect(isSafeHtmlUrl('JavaScript:alert(1)'), isFalse);
    });

    test('rejects javascript scheme hidden by whitespace', () {
      expect(isSafeHtmlUrl('  javascript:alert(1)'), isFalse);
      expect(isSafeHtmlUrl('java\tscript:alert(1)'), isFalse);
      expect(isSafeHtmlUrl('java\nscript:alert(1)'), isFalse);
    });

    test('rejects data file and vbscript schemes', () {
      expect(isSafeHtmlUrl('data:image/png;base64,AAAA'), isFalse);
      expect(isSafeHtmlUrl('file:///etc/passwd'), isFalse);
      expect(isSafeHtmlUrl('vbscript:x'), isFalse);
    });

    test('rejects empty url', () {
      expect(isSafeHtmlUrl(''), isFalse);
      expect(isSafeHtmlUrl('   '), isFalse);
    });
  });
}

import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/html/html_block_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HtmlBlockParser', () {
    late List<String> parsedSources;
    late HtmlBlockParser parser;

    setUp(() {
      parsedSources = <String>[];
      parser = HtmlBlockParser(
        parseChildren: (source) {
          parsedSources.add(source);
          return <MarkdownNode>[
            ParagraphNode(<MarkdownNode>[TextNode(source)]),
          ];
        },
      );
    });

    test('probes standalone hr without treating mid-line html as a block', () {
      expect(parser.probe('  <hr />  '), isA<HtmlHorizontalRuleMatch>());
      expect(parser.probe('before <div>x</div>'), isNull);
      expect(parser.probe('< div>'), isNull);
    });

    test('probe carries the lexed opening tag into block parsing', () {
      final match =
          parser.probe('<div align="right">') as HtmlContainerBlockMatch;

      expect(match.openTag.name, 'div');
      expect(match.openTag.attributes['align'], 'right');
      final result = parser.parseBlock(
        <String>['<div align="right">', 'text', '</div>'],
        0,
        match,
      );

      final node = result.node as HtmlBlockNode;
      expect(node.align, HtmlBlockAlignment.right);
      expect(result.linesConsumed, 3);
      expect(parsedSources, <String>['text']);
    });

    test('tracks same-name nesting across lines', () {
      final lines = <String>[
        '<div>',
        '<div>',
        'inner',
        '</div>',
        'outer',
        '</div>',
      ];
      final match = parser.probe(lines.first) as HtmlContainerBlockMatch;

      final result = parser.parseBlock(lines, 0, match);

      expect(result.linesConsumed, lines.length);
      expect(parsedSources.single, contains('<div>'));
      expect(parsedSources.single, contains('outer'));
    });

    test('keeps content after the terminating close tag', () {
      const line = '<div>a</div><div>b</div>';
      final match = parser.probe(line) as HtmlContainerBlockMatch;

      parser.parseBlock(<String>[line], 0, match);

      expect(parsedSources.single, 'a\n<div>b</div>');
    });

    test('consumes an incomplete block through input end', () {
      final lines = <String>['<div>', 'rest', 'more'];
      final match = parser.probe(lines.first) as HtmlContainerBlockMatch;

      final result = parser.parseBlock(lines, 0, match);

      expect(result.linesConsumed, lines.length);
      expect(parsedSources.single, 'rest\nmore');
    });

    test('maps blockquote to the existing markdown node', () {
      final lines = <String>['<blockquote>', 'quote', '</blockquote>'];
      final match = parser.probe(lines.first) as HtmlContainerBlockMatch;

      final result = parser.parseBlock(lines, 0, match);

      expect(result.node, isA<BlockquoteNode>());
    });
  });
}

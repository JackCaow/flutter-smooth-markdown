import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final plugins = ParserPluginRegistry()
    ..register(const MarkdownCitationPlugin());
  test('numbered citations preserve ordinary Markdown grammar and escaping', () {
    final parser = MarkdownParser(plugins: plugins);
    final nodes = parser.parseInlineOnly(
      r'[1] [2](https://example.org) `code [3]` \[4] [^5] ![6](img) [7][label] [more][8] [0]',
    );
    expect(nodes.whereType<MarkdownCitationNode>().map((n) => n.number), [1]);
    expect(nodes.whereType<LinkNode>().single.url, 'https://example.org');
    expect(nodes.whereType<FootnoteReferenceNode>().single.label, '5');
    expect(nodes.whereType<InlineCodeNode>().single.code, 'code [3]');
    expect(
      MarkdownParser().parseInlineOnly('[1]').whereType<MarkdownCitationNode>(),
      isEmpty,
    );
  });

  testWidgets(
    'split citation resolves arriving metadata and taps its own source',
    (tester) async {
      final stream = StreamController<String>();
      addTearDown(stream.close);
      MarkdownSource? tapped;
      const source = MarkdownSource(
        title: 'Original document',
        excerpt: 'Evidence here',
      );
      var sources = <int, MarkdownSource>{};
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MarkdownCitationScope(
                  sources: sources,
                  onSourceTap: (v) => tapped = v,
                  child: CustomScrollView(
                    slivers: [
                      StreamMarkdown.sliver(
                        stream: stream.stream,
                        plugins: plugins,
                        useEnhancedComponents: true,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      stream.add('Sample [');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(Tooltip), findsNothing);
      stream.add('1] and [2].');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('[1]'), findsOneWidget);
      update(() => sources = {1: source});
      await tester.pump();
      expect(find.byTooltip('Original document'), findsOneWidget);
      expect(find.text('[2]'), findsOneWidget);
      await tester.tap(find.byTooltip('Original document'));
      expect(tapped, same(source));
      await tester.pumpWidget(const SizedBox());
    },
  );
}

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/markdown_parser.dart'
    show DartStreamParser;
import 'package:flutter_test/flutter_test.dart';

class _CountingEmojis extends MapView<String, String> {
  _CountingEmojis() : super(const {});

  int reads = 0;

  @override
  String? operator [](Object? key) => key == 'live' ? 'read-${++reads}' : null;
}

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

  test('mixed citation registries evaluate host emoji lookups only once', () {
    final emoji = _CountingEmojis();
    final mixed = ParserPluginRegistry()
      ..register(const MarkdownCitationPlugin())
      ..register(EmojiPlugin(customEmojis: emoji));
    final nodes = MarkdownParser(
      plugins: mixed,
    ).parse('Read [1] :live:.\n\n[1]: /manual');
    final result = (nodes.first as ParagraphNode).children
        .whereType<EmojiNode>()
        .single;
    expect(result.emoji, 'read-1');
    expect(emoji.reads, 1);
  });

  test('enabling citations preserves resolved links and real definitions', () {
    const input =
        'See [guide][doc], [1], and [2].\n\n'
        '> [doc]: /guide "Guide"\n> [1]: /one\n\n'
        '```\n[2]: /code-only\n```';
    final backend = MarkdownCore.isNative
        ? MarkdownParserBackend.rust
        : MarkdownParserBackend.legacyDart;
    final result = MarkdownParser(
      plugins: plugins,
      backend: backend,
    ).parse(input);
    final children = result.whereType<ParagraphNode>().first.children;
    final links = children.whereType<LinkNode>().toList();
    final control = MarkdownParser(backend: backend)
        .parse(input)
        .whereType<ParagraphNode>()
        .first
        .children
        .whereType<LinkNode>();
    expect(links.map((n) => n.url), control.map((n) => n.url));
    if (MarkdownCore.isNative) {
      expect(links.map((n) => n.url), ['/guide', '/one']);
      expect(links.first.title, 'Guide');
      expect(children.whereType<MarkdownCitationNode>().map((n) => n.number), [
        2,
      ]);
    } else {
      // The legacy grammar leaves reference-style links as source text.
      expect(children.whereType<MarkdownCitationNode>().last.number, 2);
    }
  });

  test(
    'citation updates reuse stable blocks until a reference can resolve them',
    () {
      final session = DartStreamParser(
        plugins: plugins,
        referenceBackend: MarkdownParserBackend.automatic,
      );
      addTearDown(session.dispose);
      const initial = 'First [1].\n\nSecond.\n\nThird.\n\nFourth.';
      final before = session.update(initial);
      final appended = session.update('$initial More.');
      expect(session.lastRetainedBlocks, greaterThan(0));
      expect(appended.first, same(before.first));
      expect(session.lastParsedUnits, lessThan(initial.length));
      const withDefinition = '$initial More.\n\n[1]: /one';
      final defined = session.update(withDefinition);
      expect(session.lastRetainedBlocks, 0);
      expect(session.update(withDefinition), same(defined));
      final replaced = session.update('New [2].');
      expect(
        (replaced.single as ParagraphNode).children
            .whereType<MarkdownCitationNode>()
            .single
            .number,
        2,
      );
    },
  );

  testWidgets('a late reference definition resolves an earlier stream link', (
    t,
  ) async {
    final stream = StreamController<String>();
    addTearDown(stream.close);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownCitationScope(
            sources: const {1: MarkdownSource(title: 'citation')},
            onSourceTap: (_) {},
            child: CustomScrollView(
              slivers: [
                StreamMarkdown.sliver(stream: stream.stream, plugins: plugins),
              ],
            ),
          ),
        ),
      ),
    );
    stream.add('See [guide][doc] and [1].\n\n[doc]');
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('citation'), findsOneWidget);
    stream.add(': /guide\n\n[1]: /one');
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(SliverList), findsOneWidget);
    if (MarkdownCore.isNative) {
      expect(find.byTooltip('citation'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.link == true &&
              w.properties.label == '/guide',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.link == true &&
              w.properties.label == '/one',
        ),
        findsOneWidget,
      );
    } else {
      expect(find.byTooltip('citation'), findsOneWidget);
    }
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('stream stops using a replaced citation registry', (t) async {
    final stream = StreamController<String>();
    addTearDown(stream.close);
    final old = ParserPluginRegistry()
      ..register(const MarkdownCitationPlugin());
    var active = old;
    late StateSetter update;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return MarkdownCitationScope(
                sources: const {1: MarkdownSource(title: 'source')},
                onSourceTap: (_) {},
                child: StreamMarkdown(stream: stream.stream, plugins: active),
              );
            },
          ),
        ),
      ),
    );
    stream.add('First [1].');
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('source'), findsOneWidget);
    update(() => active = plugins);
    await t.pump();
    old.unregisterInline('citation');
    stream.add('\n\nSecond [1].');
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(t.takeException(), isNull);
    expect(find.byTooltip('source'), findsNWidgets(2));
    await t.pumpWidget(const SizedBox());
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

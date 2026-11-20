import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/parser_compatibility.dart'
    show backendForSourceLength;
import 'package:flutter_smooth_markdown/src/rust/core_types.dart'
    show maxNativeSourceUnits;
import 'package:flutter_test/flutter_test.dart';

String paragraphs(String label, int count) => [
  for (var i = 0; i < count; i++) '$label item $i, an ordinary paragraph.',
].join('\n\n');

Finder rich(String content) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText() == content,
);

Widget viewport(
  Widget sliver, {
  ScrollController? scroll,
  bool reverse = false,
}) => MaterialApp(
  home: CustomScrollView(
    controller: scroll,
    reverse: reverse,
    slivers: [sliver],
  ),
);

int? blockCount(WidgetTester tester) => tester
    .widgetList<SliverList>(find.byType(SliverList))
    .firstOrNull
    ?.delegate
    .estimatedChildCount;

Future<void> waitForBlocks(WidgetTester tester, int count) async {
  for (var i = 0; i < 200 && blockCount(tester) != count; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(blockCount(tester), count);
}

class _DocumentHook extends BlockParserPlugin {
  int calls = 0;
  @override
  String get id => 'whole-document';
  @override
  String get name => 'Whole document';
  @override
  bool canParse(String line, List<String> lines, int index) =>
      line == ':::inspect';
  @override
  BlockParseResult parse(List<String> lines, int index) {
    calls++;
    return BlockParseResult(
      linesConsumed: 1,
      node: ParagraphNode([TextNode('Final line: ${lines.last}')]),
    );
  }
}

void main() {
  for (final backend in [
    MarkdownParserBackend.legacyDart,
    MarkdownParserBackend.rust,
  ]) {
    testWidgets('first viewport and complete scrollable AST for $backend', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final text = paragraphs('document', 1400);
      await tester.pumpWidget(
        viewport(
          SmoothMarkdown.sliver(
            data: text,
            config: MarkdownConfig(parserBackend: backend),
            enableCache: false,
          ),
          scroll: scroll,
        ),
      );
      expect(rich('document item 0, an ordinary paragraph.'), findsOneWidget);
      expect(blockCount(tester), inExclusiveRange(0, 1400));
      await waitForBlocks(tester, 1400);
      expect(find.byType(RichText).evaluate().length, lessThan(100));
      expect(rich('document item 1399, an ordinary paragraph.'), findsNothing);
      for (var i = 0; i < 3; i++) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
      }
      expect(
        rich('document item 1399, an ordinary paragraph.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a stale background result cannot overwrite a replacement', (
    tester,
  ) async {
    const config = MarkdownConfig(
      parserBackend: MarkdownParserBackend.legacyDart,
    );
    for (final (label, count) in [
      ('first', 1600),
      ('second', 1500),
      ('third', 1300),
    ]) {
      await tester.pumpWidget(
        viewport(
          SmoothMarkdown.sliver(
            data: paragraphs(label, count),
            config: config,
            enableCache: false,
          ),
        ),
      );
    }
    await waitForBlocks(tester, 1300);
    expect(rich('third item 0, an ordinary paragraph.'), findsOneWidget);
    expect(rich('first item 0, an ordinary paragraph.'), findsNothing);
  });

  testWidgets(
    'definitions resolve against the full document before first display',
    (tester) async {
      final text =
          '[one][late]\n\n${paragraphs('middle', 1500)}\n\n[late]: /resolved';
      const backend = MarkdownParserBackend.rust;
      final expected = MarkdownParser(backend: backend).parse(text).length;
      String? opened;
      await tester.pumpWidget(
        viewport(
          SmoothMarkdown.sliver(
            data: text,
            config: const MarkdownConfig(parserBackend: backend),
            onTapLink: (url) => opened = url,
            enableCache: false,
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await waitForBlocks(tester, expected);
      await tester.tap(find.text('one', findRichText: true).first);
      expect(opened, '/resolved');
    },
  );

  testWidgets('a registry edited in place can activate a full-document hook', (
    tester,
  ) async {
    final text = ':::inspect\n\n${paragraphs('middle', 1250)}\n\nlast';
    final hooks = ParserPluginRegistry();
    final plugin = _DocumentHook();
    Widget app() => viewport(
      SmoothMarkdown.sliver(
        data: text,
        plugins: hooks,
        config: const MarkdownConfig(
          parserBackend: MarkdownParserBackend.legacyDart,
        ),
      ),
    );
    await tester.pumpWidget(app());
    expect(rich(':::inspect'), findsOneWidget);
    hooks.registerBlock(plugin);
    await tester.pumpWidget(app());
    expect(plugin.calls, 1);
    expect(rich('Final line: last'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(rich('Final line: last'), findsOneWidget);
  });

  testWidgets('large box reuses its tree, then applies changed styling', (
    tester,
  ) async {
    final text = 'First\n\n${'body text ' * 4100}';
    final style = MarkdownStyleSheet.light();
    Widget app(MarkdownStyleSheet sheet) => MaterialApp(
      home: SingleChildScrollView(
        child: SmoothMarkdown(
          data: text,
          styleSheet: sheet,
          config: const MarkdownConfig(
            parserBackend: MarkdownParserBackend.legacyDart,
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(style));
    final old = tester.widget<RichText>(rich('First'));
    await tester.pumpWidget(app(style));
    expect(tester.widget<RichText>(rich('First')), same(old));
    await tester.pumpWidget(
      app(style.copyWith(textStyle: const TextStyle(color: Colors.red))),
    );
    expect(tester.widget<RichText>(rich('First')), isNot(same(old)));
  });

  testWidgets('ragged tables keep the full parser interpretation', (
    tester,
  ) async {
    final text = '| left | right |\n| --- |\n\n${paragraphs('body', 1500)}';
    final expected = MarkdownParser().parse(text).length;
    await tester.pumpWidget(
      viewport(SmoothMarkdown.sliver(data: text, enableCache: false)),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await waitForBlocks(tester, expected);
    final table = tester.widget<Table>(find.byType(Table));
    expect(table.children.single.children.length, 2);
    expect(find.text('right', findRichText: true), findsWidgets);
  });

  testWidgets('oversized automatic documents render in box and worker sliver', (
    tester,
  ) async {
    const title = 'Oversized document';
    const head = '# $title\n\n';
    final source = head + (' ' * (maxNativeSourceUnits + 1 - head.length));
    expect(source.length, 8388609);
    expect(
      backendForSourceLength(
        MarkdownParserBackend.automatic,
        maxNativeSourceUnits,
      ),
      MarkdownParserBackend.automatic,
    );
    if (MarkdownCore.isNative) {
      expect(
        () => MarkdownParser(backend: MarkdownParserBackend.rust).parse(source),
        throwsA(isA<MarkdownCoreException>()),
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: SmoothMarkdown(data: source, enableCache: false),
        ),
      ),
    );
    expect(rich(title), findsOneWidget);
    await tester.pumpWidget(
      viewport(SmoothMarkdown.sliver(data: source, enableCache: false)),
    );
    await waitForBlocks(tester, 1);
    expect(rich(title), findsOneWidget);
  });

  testWidgets('selection and reverse scrolling keep complete reading order', (
    tester,
  ) async {
    final text = paragraphs('select', 120);
    await tester.pumpWidget(
      viewport(SmoothMarkdown.sliver(data: text, selectable: true)),
    );
    expect(find.byType(SmoothSelectionRegion), findsOneWidget);
    expect(rich('select item 119, an ordinary paragraph.'), findsOneWidget);
    await tester.pumpWidget(
      viewport(SmoothMarkdown.sliver(data: text), reverse: true),
    );
    expect(
      tester.getTopLeft(rich('select item 0, an ordinary paragraph.')).dy,
      lessThan(
        tester.getTopLeft(rich('select item 119, an ordinary paragraph.')).dy,
      ),
    );
  });

  testWidgets('custom code builders run when their static blocks enter view', (
    tester,
  ) async {
    final text = "${paragraphs('normal', 100)}\n\n```dart\nvalue\n```";
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var calls = 0;
    await tester.pumpWidget(
      viewport(
        SmoothMarkdown.sliver(
          data: text,
          codeBuilder: (code, _) {
            calls++;
            return Text('custom: $code');
          },
        ),
        scroll: scroll,
      ),
    );
    expect(calls, 0);
    for (var i = 0; i < 3; i++) {
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
    }
    expect(calls, greaterThan(0));
    expect(find.textContaining('custom: value'), findsOneWidget);
  });
}

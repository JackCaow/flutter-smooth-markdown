import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = MarkdownConfig(parserBackend: MarkdownParserBackend.legacyDart);

Future<void> _ready(
  WidgetTester tester,
  MarkdownReaderController reader,
) async {
  for (var i = 0; i < 300 && !reader.isIndexComplete; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(reader.isIndexComplete, isTrue);
}

Widget _page(
  MarkdownReaderController c,
  String source, {
  bool box = false,
  BuilderRegistry? registry,
}) => MaterialApp(
  home: Scaffold(
    body: box
        ? SingleChildScrollView(
            child: SmoothMarkdown(
              data: source,
              readerController: c,
              config: _config,
            ),
          )
        : CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 45)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                sliver: SmoothMarkdown.sliver(
                  data: source,
                  readerController: c,
                  config: _config,
                  builderRegistry: registry,
                ),
              ),
            ],
          ),
  ),
);

class _CountingHeading extends MarkdownWidgetBuilder {
  int built = 0;
  @override
  bool canBuild(MarkdownNode node) => node is HeaderNode;
  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet sheet,
    MarkdownRenderContext context,
  ) {
    built++;
    return Text((node as HeaderNode).content);
  }
}

void main() {
  testWidgets(
    'heading anchors avoid collisions; search uses readable inline and table text',
    (tester) async {
      final c = MarkdownReaderController();
      await tester.pumpWidget(
        _page(
          c,
          '# **Hello** world\n\n# Hello world\n\n# Hello world-1\n\n# 中文 标题\n\nA **mixed** case\n\n| Item | Value |\n| --- | --- |\n| apple | Mixed Case |',
          box: true,
        ),
      );
      expect(c.headings.map((h) => h.anchor), [
        'hello-world',
        'hello-world-1',
        'hello-world-1-1',
        '中文-标题',
      ]);
      expect(c.headings.map((h) => h.occurrence), [1, 2, 1, 1]);
      expect(
        await c.jumpToAnchor('#%E4%B8%AD%E6%96%87-%E6%A0%87%E9%A2%98'),
        isTrue,
      );
      expect(await c.jumpToAnchor('#no-such-section'), isFalse);
      c.search('mixed case');
      expect(c.matches.map((m) => m.blockIndex), [4, 5]);
      expect(await c.nextMatch(), isTrue);
      expect(c.activeMatchIndex, 1);
      // The forced Dart backend reparses this box on an unrelated parent build.
      // The selected occurrence in the identical document must survive it.
      final current = tester.widget<SmoothMarkdown>(
        find.byType(SmoothMarkdown),
      );
      await tester.pumpWidget(_page(c, current.data, box: true));
      expect(c.activeMatchIndex, 1);
      expect(await c.previousMatch(), isTrue);
      expect(c.activeMatchIndex, 0);
      c.search('mixed case', caseSensitive: true);
      expect(c.matches.length, 1);
      c.search('');
      expect(c.matches, isEmpty);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'toggling selection keeps one reader controller and its active match',
    (tester) async {
      final reader = MarkdownReaderController();
      Widget page(bool selectable) => MaterialApp(
        home: CustomScrollView(
          slivers: [
            SmoothMarkdown.sliver(
              data: '# One\n\nsame and same',
              config: _config,
              readerController: reader,
              selectable: selectable,
            ),
          ],
        ),
      );
      await tester.pumpWidget(page(false));
      reader.search('same');
      expect(await reader.jumpToMatch(1), isTrue);

      for (final selectable in [true, false]) {
        await tester.pumpWidget(page(selectable));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(reader.headings.single.anchor, 'one');
        expect(reader.activeMatchIndex, 1);
        expect(await reader.jumpToAnchor('one'), isTrue);
      }
      await tester.pumpWidget(const SizedBox());
      expect(reader.headings, isEmpty);
      reader.dispose();
    },
  );

  testWidgets(
    'search reveals the occurrence inside its collapsed disclosure only',
    (tester) async {
      final reader = MarkdownReaderController();
      const source =
          '<details>\n<summary>Summary A</summary>\nshared phrase Alpha\n</details>'
          '\n\n<details>\n<summary>Summary B</summary>\nshared phrase Bravo\n</details>';
      await tester.pumpWidget(_page(reader, source, box: true));
      reader.search('Summary B');
      expect(await reader.jumpToMatch(0), isTrue);
      expect(find.textContaining('Bravo', findRichText: true), findsNothing);

      reader.search('shared phrase');
      expect(reader.matches, hasLength(2));
      final jump = reader.jumpToMatch(1);
      await tester.pumpAndSettle();
      expect(await jump, isTrue);
      expect(
        find.textContaining('Bravo', findRichText: true).hitTestable(),
        findsWidgets,
      );
      expect(find.textContaining('Alpha', findRichText: true), findsNothing);
      await tester.pumpWidget(const SizedBox());
      reader.dispose();
    },
  );

  testWidgets('search scrolls long code lines horizontally to the active hit', (
    tester,
  ) async {
    final reader = MarkdownReaderController();
    await tester.pumpWidget(
      _page(reader, '~~~\nneedle ${'x' * 300} needle\n~~~', box: true),
    );
    final horizontal = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .singleWhere(
          (s) =>
              axisDirectionToAxis(s.position.axisDirection) == Axis.horizontal,
        )
        .position;
    expect(horizontal.maxScrollExtent, greaterThan(800));
    reader.search('needle');
    expect(reader.matches, hasLength(2));
    expect(await reader.jumpToMatch(1), isTrue);
    await tester.pumpAndSettle();
    expect(horizontal.pixels, greaterThan(800));
    expect(await reader.jumpToMatch(0), isTrue);
    await tester.pumpAndSettle();
    expect(horizontal.pixels, lessThan(10));
    await tester.pumpWidget(const SizedBox());
    reader.dispose();
  });

  testWidgets(
    '435k document seeks directly to a far unmounted heading and search hit',
    (tester) async {
      final c = MarkdownReaderController();
      final sections = List.generate(
        1600,
        (i) =>
            '# Section $i\n\n${'ordinary content ' * 7}\n\n${'text ' * 15}find item $i!\n\nshort body\n\nlast block\n\n',
      );
      final source = sections.join().padRight(435200);
      expect(source.length, greaterThanOrEqualTo(435200));
      final counter = _CountingHeading();
      final builders = BuilderRegistry()..register('header', counter);
      await tester.pumpWidget(_page(c, source, registry: builders));
      await _ready(tester, c);
      final visible = find.byType(RichText);
      expect(visible.evaluate().length, lessThan(100));
      expect(find.text('Section 1570', findRichText: true), findsNothing);
      final jump = c.jumpToAnchor('#section-1570');
      await tester.pumpAndSettle();
      expect(await jump, isTrue);
      expect(find.text('Section 1570', findRichText: true), findsOneWidget);
      expect(c.activeHeading?.anchor, 'section-1570');
      expect(visible.evaluate().length, lessThan(100));
      c.search('find item 42!');
      expect(c.matches.length, 1);
      final search = c.jumpToMatch(0);
      await tester.pumpAndSettle();
      expect(await search, isTrue);
      final hit = find
          .textContaining('find item 42!', findRichText: true)
          .first;
      final screen = tester.getRect(find.byType(Viewport));
      expect(tester.getRect(hit).overlaps(screen), isTrue);
      expect(c.activeHeading?.anchor, 'section-42');
      // A regular offset jump would build all 1,570 intervening headings.
      expect(counter.built, lessThan(60));
      expect(visible.evaluate().length, lessThan(100));
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'selecting a later occurrence in one tall paragraph reveals the glyphs',
    (tester) async {
      final c = MarkdownReaderController();
      final source = 'target ${'long sentence ' * 1000} target';
      await tester.pumpWidget(_page(c, source, box: true));
      c.search('target');
      expect(c.matches.length, 2);
      expect(await c.jumpToMatch(1), isTrue);
      await tester.pump();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(scroll.pixels, greaterThan(1000));
      expect(await c.jumpToMatch(0), isTrue);
      await tester.pump();
      expect(scroll.pixels, lessThan(30));
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'reverse scroll reports the section at the physical top and reveals matches',
    (tester) async {
      final reader = MarkdownReaderController();
      final source = List.generate(
        100,
        (i) => '# Section $i\n\nparagraph $i!\n\n',
      ).join();
      await tester.pumpWidget(
        MaterialApp(
          home: CustomScrollView(
            reverse: true,
            slivers: [
              SmoothMarkdown.sliver(
                data: source,
                config: _config,
                readerController: reader,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(Viewport));
      // The existing reverse sliver path renders a top-to-bottom box. At offset
      // zero the end of that box fills the viewport.
      expect(reader.activeHeading!.blockIndex, greaterThan(150));
      expect(await reader.jumpToAnchor('#section-21'), isTrue);
      await tester.pumpAndSettle();
      final heading = tester.getRect(
        find.text('Section 21', findRichText: true).first,
      );
      expect(heading.top, closeTo(viewport.top, 35));
      expect(reader.activeHeading?.anchor, 'section-21');
      reader.search('paragraph 78!');
      expect(await reader.jumpToMatch(0), isTrue);
      await tester.pumpAndSettle();
      final paragraph = tester.getRect(
        find.text('paragraph 78!', findRichText: true).first,
      );
      expect(paragraph.overlaps(viewport), isTrue);
      expect(reader.activeHeading?.anchor, 'section-78');
      await tester.pumpWidget(const SizedBox());
      reader.dispose();
    },
  );

  testWidgets('a fragment tapped in the preview waits for the full index', (
    tester,
  ) async {
    final reader = MarkdownReaderController();
    final external = <String>[];
    final doc =
        '[Go to end](#final-section)\n\n${'filler paragraph\n\n' * 5000}# Final section\n\n${'footer block\n\n' * 40}';
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SmoothMarkdown.sliver(
              data: doc,
              readerController: reader,
              config: _config,
              enableCache: false,
              onTapLink: external.add,
            ),
          ],
        ),
      ),
    );
    expect(reader.isIndexComplete, isFalse);
    await tester.tap(find.text('Go to end', findRichText: true));
    await _ready(tester, reader);
    await tester.pumpAndSettle();
    expect(reader.activeHeading?.anchor, 'final-section');
    expect(
      find.text('Final section', findRichText: true).hitTestable(),
      findsWidgets,
    );
    expect(external, isEmpty);
    await tester.pumpWidget(const SizedBox());
    reader.dispose();
  });
}

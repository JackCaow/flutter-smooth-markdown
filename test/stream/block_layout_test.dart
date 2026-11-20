import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

Finder rich(String text) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText() == text,
);

Future<void> publish(
  WidgetTester tester,
  StreamController<String> stream,
  String text,
) async {
  stream.add(text);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 70));
}

void main() {
  for (final backend in [
    MarkdownParserBackend.legacyDart,
    MarkdownParserBackend.rust,
  ]) {
    testWidgets(
      'reverse sliver scrolling keeps Markdown reading order $backend',
      (tester) async {
        final controller = StreamController<String>();
        addTearDown(controller.close);
        await tester.pumpWidget(
          MaterialApp(
            home: CustomScrollView(
              reverse: true,
              slivers: [
                StreamMarkdown.sliver(
                  stream: controller.stream,
                  config: MarkdownConfig(parserBackend: backend),
                ),
              ],
            ),
          ),
        );
        await publish(
          tester,
          controller,
          [for (var i = 0; i < 100; i++) 'reverse $i'].join('\n\n'),
        );
        expect(
          tester.getTopLeft(rich('reverse 0')).dy,
          lessThan(tester.getTopLeft(rich('reverse 99')).dy),
        );
        expect(tester.getTopLeft(rich('reverse 99')).dy, lessThan(600));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'mixed page boundaries preserve table/code/list geometry $backend',
      (tester) async {
        final controller = StreamController<String>();
        addTearDown(controller.close);
        final config = MarkdownConfig(parserBackend: backend);
        final text =
            '${[for (var i = 0; i < 30; i++) 'before $i'].join('\n\n')}\n\n'
            '```dart\nint x = 1;\n```\n\n## after blocks\n\n'
            '| A | B |\n| :- | -: |\n| one | two |\n\n- item one\n- item two\n\n'
            '> quoted\n\n${[for (var i = 0; i < 40; i++) 'after $i'].join('\n\n')}';
        Widget app(Widget child) => MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 280,
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        );
        const key = ValueKey('mixed');
        await tester.pumpWidget(
          app(
            StreamMarkdown(
              key: key,
              stream: controller.stream,
              useEnhancedComponents: true,
              config: config,
            ),
          ),
        );
        await publish(tester, controller, text);
        await tester.pumpAndSettle();
        final height = tester.getSize(find.byKey(key)).height;
        final anchor = tester.getTopLeft(rich('after 0'));
        await tester.pumpWidget(
          app(
            SmoothMarkdown(
              key: key,
              data: text,
              useEnhancedComponents: true,
              config: config,
              enableCache: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(key)).height, closeTo(height, .001));
        expect(tester.getTopLeft(rich('after 0')), anchor);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'paged geometry, node identity and resize match flat rendering $backend',
      (tester) async {
        final controller = StreamController<String>();
        addTearDown(controller.close);
        final config = MarkdownConfig(parserBackend: backend);
        final text = [
          for (var i = 0; i < 140; i++) 'paragraph $i with **bold**',
        ].join('\n\n');
        Widget app(Widget child, {double width = 650}) => MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        );
        const key = ValueKey('document');
        await tester.pumpWidget(
          app(
            StreamMarkdown(key: key, stream: controller.stream, config: config),
          ),
        );
        await publish(tester, controller, text);
        final height = tester.getSize(find.byKey(key)).height;
        final positions = [
          for (final i in [0, 31, 32, 63, 64, 139])
            tester.getTopLeft(rich('paragraph $i with bold')),
        ];
        final first = tester.widget(rich('paragraph 0 with bold'));
        final page = tester.widget(find.byKey(const ValueKey(0)));
        await publish(tester, controller, '\n\nnew tail');
        expect(tester.widget(rich('paragraph 0 with bold')), same(first));
        expect(tester.widget(find.byKey(const ValueKey(0))), same(page));
        await tester.pumpWidget(
          app(
            StreamMarkdown(key: key, stream: controller.stream, config: config),
            width: 180,
          ),
        );
        final narrowHeight = tester.getSize(find.byKey(key)).height;
        expect(tester.getSize(find.byKey(key)).width, 180);
        await tester.pumpWidget(
          app(
            SmoothMarkdown(
              key: key,
              data: '$text\n\nnew tail',
              config: config,
              enableCache: false,
            ),
            width: 180,
          ),
        );
        expect(
          tester.getSize(find.byKey(key)).height,
          closeTo(narrowHeight, .001),
        );
        await tester.pumpWidget(
          app(
            SmoothMarkdown(
              key: key,
              data: text,
              config: config,
              enableCache: false,
            ),
          ),
        );
        expect(tester.getSize(find.byKey(key)).height, closeTo(height, .001));
        for (var n = 0; n < positions.length; n++) {
          final i = [0, 31, 32, 63, 64, 139][n];
          expect(
            tester.getTopLeft(rich('paragraph $i with bold')),
            positions[n],
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'sliver mounts individual viewport blocks and preserves scroll position $backend',
      (tester) async {
        final controller = StreamController<String>();
        addTearDown(controller.close);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                controller: scroll,
                slivers: [
                  StreamMarkdown.sliver(
                    stream: controller.stream,
                    config: MarkdownConfig(parserBackend: backend),
                  ),
                ],
              ),
            ),
          ),
        );
        await publish(
          tester,
          controller,
          [for (var i = 0; i < 500; i++) 'row $i'].join('\n\n'),
        );
        expect(rich('row 0'), findsOneWidget);
        expect(rich('row 499'), findsNothing);
        final list = tester.widget<SliverList>(find.byType(SliverList));
        expect(list.delegate.estimatedChildCount, 500);
        final first = tester.renderObject(rich('row 0'));
        expect(find.byType(RichText).evaluate().length, lessThan(32));
        await tester.scrollUntilVisible(rich('row 499'), 1000, maxScrolls: 40);
        await tester.pumpAndSettle();
        expect(rich('row 499'), findsOneWidget);
        expect(rich('row 0'), findsNothing);
        expect(first.attached, isFalse);
        final offset = scroll.offset;
        await publish(tester, controller, '\n\nnew tail');
        expect(scroll.offset, closeTo(offset, .001));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('sliver selection keeps the complete selection tree', (
    tester,
  ) async {
    final controller = StreamController<String>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            StreamMarkdown.sliver(stream: controller.stream, selectable: true),
          ],
        ),
      ),
    );
    await publish(
      tester,
      controller,
      [for (var i = 0; i < 180; i++) 'select $i'].join('\n\n'),
    );
    expect(rich('select 179'), findsOneWidget);
    expect(find.byType(SmoothSelectionRegion), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sliver loading, errors, custom builders and stream replacement stay compatible',
    (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);
      var calls = 0;
      Widget app(Stream<String> stream) => MaterialApp(
        home: CustomScrollView(
          slivers: [
            StreamMarkdown.sliver(
              stream: stream,
              loadingWidget: const Text('loading'),
              errorBuilder: (_) => const Text('error'),
              codeBuilder: (_, _) {
                calls++;
                return const Text('custom');
              },
            ),
          ],
        ),
      );
      await tester.pumpWidget(app(controller.stream));
      expect(find.text('loading'), findsOneWidget);
      await publish(
        tester,
        controller,
        '```dart\nx\n```\n\none\n\ntwo\n\ntail',
      );
      final previous = calls;
      await publish(tester, controller, ' more');
      expect(calls, greaterThan(previous));
      controller.addError(StateError('test'));
      await tester.pump();
      await tester.pump();
      expect(find.text('error'), findsOneWidget);
      final replacement = StreamController<String>();
      addTearDown(replacement.close);
      await tester.pumpWidget(app(replacement.stream));
      expect(find.text('loading'), findsOneWidget);
      await publish(tester, replacement, 'replacement');
      expect(rich('replacement'), findsOneWidget);
      expect(find.text('custom'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

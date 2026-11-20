import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _publish(
  WidgetTester tester,
  StreamController<String> stream,
  String chunk,
) async {
  stream.add(chunk);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 70));
}

Widget _app(
  Stream<String> stream,
  MarkdownParserBackend backend, {
  ParserPluginRegistry? plugins,
  bool html = false,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: StreamMarkdown(
        stream: stream,
        config: MarkdownConfig(parserBackend: backend, enableHtml: html),
        plugins: plugins,
        useEnhancedComponents: true,
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'automatic stream keeps content when it crosses the native input limit',
    (tester) async {
      final stream = StreamController<String>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        _app(stream.stream, MarkdownParserBackend.automatic),
      );
      await _publish(tester, stream, '# First\n\n');
      expect(find.text('First', findRichText: true), findsOneWidget);
      await _publish(tester, stream, ' ' * (8 * 1024 * 1024));
      await _publish(tester, stream, '\n\n# Last');
      expect(find.text('First', findRichText: true), findsOneWidget);
      expect(find.text('Last', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final backend in [
    MarkdownParserBackend.legacyDart,
    MarkdownParserBackend.rust,
  ]) {
    testWidgets(
      '$backend renders ragged delimiters and resumes on completion',
      (tester) async {
        final stream = StreamController<String>();
        addTearDown(stream.close);
        await tester.pumpWidget(_app(stream.stream, backend));
        final batch = find.byType(SmoothMarkdown);
        final table = find.byType(Table);

        await _publish(tester, stream, 'intro\n\n| left | right |\n| ');
        expect(batch, findsNothing);
        await _publish(tester, stream, '--- |');
        expect(batch, findsOneWidget);
        expect(tester.widget<Table>(table).children.single.children.length, 2);
        await _publish(tester, stream, ' :---: |');
        expect(batch, findsNothing);
        await _publish(tester, stream, '\n| first | second |');
        expect(tester.widget<Table>(table).children.length, 2);
        expect(find.text('second', findRichText: true), findsOneWidget);

        await _publish(tester, stream, '\n\n| new | table |\n| --- |\n');
        expect(batch, findsOneWidget);
        await _publish(tester, stream, '\nafter');
        expect(batch, findsOneWidget);
        expect(find.text('after', findRichText: true), findsOneWidget);
        final fresh = StreamController<String>();
        addTearDown(fresh.close);
        await tester.pumpWidget(_app(fresh.stream, backend));
        await _publish(tester, fresh, 'new document');
        expect(batch, findsNothing);
        expect(table, findsNothing);
        expect(find.text('new document', findRichText: true), findsOneWidget);
      },
    );

    testWidgets('$backend invokes a plugin when its split marker completes', (
      tester,
    ) async {
      final stream = StreamController<String>();
      addTearDown(stream.close);
      final plugins = ParserPluginRegistry()..register(const ThinkingPlugin());
      await tester.pumpWidget(_app(stream.stream, backend, plugins: plugins));
      final batch = find.byType(SmoothMarkdown);
      await _publish(tester, stream, 'intro\n\n<|Th');
      await _publish(tester, stream, 'In');
      expect(batch, findsNothing);
      await _publish(tester, stream, 'K');
      expect(batch, findsOneWidget);
      await _publish(tester, stream, 'ing|>\nreason\n<|/thinking|>');
      final thinking = find.text('Thinking...');
      expect(thinking, findsOneWidget);
      await tester.tap(thinking);
      await tester.pumpAndSettle();
      expect(find.text('reason', findRichText: true), findsOneWidget);

      plugins.clear();
      await _publish(tester, stream, '\n\nplain');
      expect(batch, findsNothing);
      expect(find.text('Thinking'), findsNothing);
      plugins.register(const ThinkingPlugin());
      await tester.pumpWidget(_app(stream.stream, backend, plugins: plugins));
      expect(batch, findsOneWidget);
      expect(thinking, findsOneWidget);
    });

    testWidgets(
      '$backend handles a shorter visible prefix after HTML changes',
      (tester) async {
        final stream = StreamController<String>();
        addTearDown(stream.close);
        await tester.pumpWidget(_app(stream.stream, backend));
        // Disclosures unconditionally take the original batch parser.
        await _publish(tester, stream, 'intro\n\n<DETAILS');
        expect(find.byType(SmoothMarkdown), findsOneWidget);
        await tester.pumpWidget(_app(stream.stream, backend, html: true));
        await _publish(
          tester,
          stream,
          ' open',
        ); // The incomplete tag is withheld.
        await tester.pumpWidget(_app(stream.stream, backend));
        expect(find.byType(SmoothMarkdown), findsNothing);
        await _publish(tester, stream, '>body</details>');
        expect(find.byType(SmoothMarkdown), findsOneWidget);
      },
    );
  }
}

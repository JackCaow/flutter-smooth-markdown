import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

Finder rich(String value) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText() == value,
);
Future<void> publish(
  WidgetTester tester,
  StreamController<String> controller,
  String text,
) async {
  controller.add(text);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 70));
}

void main() {
  testWidgets(
    'Dart streaming retains completed widgets and invalidates style/plugin transitions',
    (tester) async {
      final stream = StreamController<String>();
      addTearDown(stream.close);
      final plugins = ParserPluginRegistry()..register(const ThinkingPlugin());
      Widget app(MarkdownStyleSheet style) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreamMarkdown(
              stream: stream.stream,
              config: const MarkdownConfig(
                parserBackend: MarkdownParserBackend.legacyDart,
              ),
              styleSheet: style,
              plugins: plugins,
              useEnhancedComponents: true,
            ),
          ),
        ),
      );
      final style = MarkdownStyleSheet.light();
      await tester.pumpWidget(app(style));
      await publish(
        tester,
        stream,
        'first\n\nsecond\n\nthird\n\nfourth\n\ntail',
      );
      final first = tester.widget(rich('first'));
      await publish(tester, stream, ' more');
      expect(identical(first, tester.widget(rich('first'))), isTrue);
      await tester.pumpWidget(app(MarkdownStyleSheet.dark()));
      final restyled = tester.widget(rich('first'));
      expect(identical(first, restyled), isFalse);
      await publish(tester, stream, '\n\n<think>\nreason\n</think>');
      expect(identical(restyled, tester.widget(rich('first'))), isFalse);
      expect(find.textContaining('Unknown node type'), findsNothing);
    },
  );

  testWidgets(
    'Dart custom builders and unknown parser plugins still run each publication',
    (tester) async {
      for (final observePlugins in [false, true]) {
        final stream = StreamController<String>();
        addTearDown(stream.close);
        var builds = 0;
        var pluginCalls = 0;
        final plugins = observePlugins
            ? (ParserPluginRegistry()..register(_Observer(() => pluginCalls++)))
            : null;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StreamMarkdown(
                stream: stream.stream,
                plugins: plugins,
                config: const MarkdownConfig(
                  parserBackend: MarkdownParserBackend.legacyDart,
                ),
                codeBuilder: (code, language) => Text('build ${++builds}'),
              ),
            ),
          ),
        );
        await publish(
          tester,
          stream,
          '```dart\nx\n```\n\n@first\n\nsecond\n\nthird\n\ntail',
        );
        final previousBuilds = builds, previousCalls = pluginCalls;
        await publish(tester, stream, ' more');
        expect(builds, greaterThan(previousBuilds));
        if (observePlugins) {
          expect(pluginCalls, greaterThan(previousCalls));
        }
        expect(find.text('build $builds'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'switching backends reparses the same buffer and replacing streams clears sessions',
    (tester) async {
      final stream = StreamController<String>();
      addTearDown(stream.close);
      Widget app(Stream<String> input, MarkdownParserBackend backend) =>
          MaterialApp(
            home: Scaffold(
              body: StreamMarkdown(
                stream: input,
                config: MarkdownConfig(parserBackend: backend),
              ),
            ),
          );
      await tester.pumpWidget(app(stream.stream, MarkdownParserBackend.rust));
      await publish(
        tester,
        stream,
        '[site][ref]\n\nsecond\n\nthird\n\nfourth\n\n[ref]: /target\n',
      );
      expect(rich('site'), findsOneWidget);
      await tester.pumpWidget(
        app(stream.stream, MarkdownParserBackend.legacyDart),
      );
      // Preserve the existing Dart reference behavior, rather than inheriting a
      // cached native AST when only the backend configuration changes.
      expect(rich('[site][ref]'), findsOneWidget);
      await tester.pumpWidget(app(stream.stream, MarkdownParserBackend.rust));
      expect(rich('site'), findsOneWidget);
      final replacement = StreamController<String>();
      addTearDown(replacement.close);
      await tester.pumpWidget(
        app(replacement.stream, MarkdownParserBackend.legacyDart),
      );
      await publish(tester, replacement, 'replacement');
      expect(rich('replacement'), findsOneWidget);
      expect(rich('second'), findsNothing);
    },
  );
}

class _Observer extends InlineParserPlugin {
  const _Observer(this.observe);
  final void Function() observe;
  @override
  String get id => 'observer';
  @override
  String get name => 'Observer';
  @override
  String get triggerCharacter => '@';
  @override
  bool canParse(String text, int index) {
    observe();
    return false;
  }

  @override
  InlineParseResult? parse(String text, int startIndex) => null;
}

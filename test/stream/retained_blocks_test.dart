import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

Finder rich(String value) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText() == value,
);
Future<void> publish(
  WidgetTester tester,
  StreamController<String> controller,
  String value,
) async {
  controller.add(value);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 70));
}

void main() {
  testWidgets(
    'AI registry retains committed widgets and invalidates on host/theme changes',
    (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);
      final plugins = ParserPluginRegistry()
        ..register(const ThinkingPlugin())
        ..register(const ArtifactPlugin())
        ..register(const ToolCallPlugin());
      Widget app(MarkdownStyleSheet style) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreamMarkdown(
              stream: controller.stream,
              plugins: plugins,
              styleSheet: style,
              useEnhancedComponents: true,
            ),
          ),
        ),
      );
      final style = MarkdownStyleSheet.light();
      await tester.pumpWidget(app(style));
      await publish(
        tester,
        controller,
        'first\n\nsecond\n\nthird\n\nfourth\n\ntail',
      );
      final before = tester.widget(rich('first'));
      await publish(tester, controller, ' more');
      expect(identical(tester.widget(rich('first')), before), isTrue);
      await tester.pumpWidget(app(MarkdownStyleSheet.dark()));
      expect(identical(tester.widget(rich('first')), before), isFalse);
      final afterStyle = tester.widget(rich('first'));
      await publish(tester, controller, '\n\n<think>\nreason\n</think>');
      expect(identical(tester.widget(rich('first')), afterStyle), isFalse);
      expect(find.textContaining('Unknown node type'), findsNothing);
    },
  );
  testWidgets(
    'custom code builders retain their per-publication callback behavior',
    (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
            codeBuilder: (code, language) {
              calls++;
              return Text('custom $calls');
            },
          ),
        ),
      );
      await publish(
        tester,
        controller,
        '```dart\nvalue\n```\n\nsecond\n\nthird\n\nfourth\n\ntail',
      );
      final previous = calls;
      await publish(tester, controller, ' more');
      expect(calls, greaterThan(previous));
      expect(find.text('custom $calls'), findsOneWidget);
    },
  );
  testWidgets(
    'reference invalidation replaces old link targets and stream replacement clears nodes',
    (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);
      String? tapped;
      Widget app(Stream<String> stream) => MaterialApp(
        home: StreamMarkdown(
          stream: stream,
          onTapLink: (value) => tapped = value,
        ),
      );
      await tester.pumpWidget(app(controller.stream));
      await publish(
        tester,
        controller,
        '[site][ref]\n\nsecond\n\nthird\n\nfourth\n\ntail',
      );
      await publish(tester, controller, '\n\n[ref]: /target\n');
      // Link semantics confirm the committed paragraph was reparsed for the definition.
      expect(rich('site'), findsOneWidget);
      await tester.tap(rich('site'));
      await tester.pump();
      expect(tapped, '/target');
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == '[site][ref]',
        ),
        findsNothing,
      );
      final replacement = StreamController<String>();
      addTearDown(replacement.close);
      await tester.pumpWidget(app(replacement.stream));
      await publish(tester, replacement, 'replacement');
      expect(rich('replacement'), findsOneWidget);
      expect(rich('second'), findsNothing);
      expect(tapped, '/target');
    },
  );
}

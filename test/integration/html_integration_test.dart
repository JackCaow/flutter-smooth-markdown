import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder findRichTextContaining(String text) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(text),
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('SmoothMarkdown HTML integration', () {
    testWidgets('renders html only when config enables it', (tester) async {
      const data = 'a <mark>lit</mark> b';

      await tester.pumpWidget(wrap(const SmoothMarkdown(
        data: data,
        enableCache: false,
        useRepaintBoundary: false,
      )));
      expect(findRichTextContaining('<mark>lit</mark>'), findsOneWidget);

      await tester.pumpWidget(wrap(const SmoothMarkdown(
        data: data,
        config: MarkdownConfig(enableHtml: true),
        enableCache: false,
        useRepaintBoundary: false,
      )));
      expect(findRichTextContaining('<mark>'), findsNothing);
      expect(findRichTextContaining('lit'), findsOneWidget);
    });

    testWidgets('parse cache does not leak results across enableHtml configs',
        (tester) async {
      // Unique data so earlier tests cannot have warmed this cache entry.
      const data = 'cache probe <u>value</u> end';

      // Populate the cache with HTML disabled first.
      await tester.pumpWidget(wrap(const SmoothMarkdown(
        data: data,
        useRepaintBoundary: false,
      )));
      expect(findRichTextContaining('<u>value</u>'), findsOneWidget);

      // Same data with HTML enabled must NOT reuse the cached AST.
      await tester.pumpWidget(wrap(const SmoothMarkdown(
        data: data,
        config: MarkdownConfig(enableHtml: true),
        useRepaintBoundary: false,
      )));
      expect(findRichTextContaining('<u>value</u>'), findsNothing);
      expect(findRichTextContaining('value'), findsOneWidget);

      // And back again: the disabled variant still renders literally.
      await tester.pumpWidget(wrap(const SmoothMarkdown(
        data: data,
        useRepaintBoundary: false,
      )));
      expect(findRichTextContaining('<u>value</u>'), findsOneWidget);
    });

    testWidgets('renders full html feature mix end to end', (tester) async {
      const data = 'Text <b>b</b> <u>u</u> <sub>2</sub><sup>3</sup> '
          '<kbd>Ctrl</kbd> <font color="red">r</font><br>next\n\n'
          '<center>\n\n**centered md**\n\n</center>\n\n'
          '<blockquote>\nquoted\n</blockquote>\n\n<hr>\n\ndone';

      await tester.pumpWidget(wrap(const SmoothMarkdown(
        data: data,
        config: MarkdownConfig(enableHtml: true),
        enableCache: false,
        useRepaintBoundary: false,
      )));

      expect(findRichTextContaining('centered md'), findsOneWidget);
      expect(findRichTextContaining('quoted'), findsOneWidget);
      expect(findRichTextContaining('Unknown node type'), findsNothing);
      expect(find.textContaining('Unknown node type'), findsNothing);
    });

    testWidgets('selectable mode renders html content without exceptions',
        (tester) async {
      const data = '<div align="center">\n<b>bold</b> and <mark>mark</mark>\n'
          '</div>\n\n<hr>\n\n<kbd>K</kbd>';

      await tester.pumpWidget(wrap(const SmoothMarkdown(
        data: data,
        config: MarkdownConfig(enableHtml: true),
        selectable: true,
        enableCache: false,
        useRepaintBoundary: false,
      )));

      expect(tester.takeException(), isNull);
      expect(findRichTextContaining('bold'), findsWidgets);
    });
  });

  group('StreamMarkdown HTML integration', () {
    testWidgets('stream markdown renders unclosed bold during streaming',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(wrap(StreamMarkdown(
        stream: controller.stream,
        config: const MarkdownConfig(enableHtml: true),
      )));

      // First chunk leaves the tag unclosed mid-stream.
      controller.add('start <b>partial');
      await tester.pump(const Duration(milliseconds: 100));
      expect(findRichTextContaining('partial'), findsOneWidget);
      expect(findRichTextContaining('<b>'), findsNothing);

      // Closing chunk arrives and the same content stays rendered.
      controller.add(' words</b> tail');
      await tester.pump(const Duration(milliseconds: 100));
      expect(findRichTextContaining('partial words'), findsOneWidget);
      expect(findRichTextContaining('tail'), findsOneWidget);
    });

    testWidgets('stream markdown grows an unclosed div block', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(wrap(StreamMarkdown(
        stream: controller.stream,
        config: const MarkdownConfig(enableHtml: true),
      )));

      controller.add('<div>\nfirst line');
      await tester.pump(const Duration(milliseconds: 100));
      expect(findRichTextContaining('first line'), findsOneWidget);

      controller.add('\nsecond line\n</div>');
      await tester.pump(const Duration(milliseconds: 100));
      expect(findRichTextContaining('second line'), findsOneWidget);
    });

    testWidgets('withholds a partial html tag until it completes',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(wrap(StreamMarkdown(
        stream: controller.stream,
        config: const MarkdownConfig(enableHtml: true),
      )));

      // First chunk ends mid-tag: `<font colo` has no closing `>`.
      controller.add('lead <font colo');
      await tester.pump(const Duration(milliseconds: 100));
      // The leading text renders, but the partial tag is withheld rather
      // than flashing as the literal text "<font".
      expect(findRichTextContaining('lead'), findsOneWidget);
      expect(findRichTextContaining('<font'), findsNothing);

      // Completing the tag renders the styled content with no literal tag.
      controller.add('r="red">red</font>');
      await tester.pump(const Duration(milliseconds: 100));
      expect(findRichTextContaining('red'), findsOneWidget);
      expect(findRichTextContaining('<font'), findsNothing);
    });
  });
}

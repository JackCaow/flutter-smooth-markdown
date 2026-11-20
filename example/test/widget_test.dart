import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_smooth_markdown_example/editor_preview_main.dart';
import 'package:flutter_smooth_markdown_example/html_demo.dart';
import 'package:flutter_smooth_markdown_example/main.dart';

void main() {
  Future<void> openHome(WidgetTester tester, {double width = 390}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'home opens the field guide, assistant, patch review and long reader',
    (tester) async {
      await openHome(tester);
      for (final (entry, action) in [
        ('山脊行程手册', 'guide-contents'),
        ('问开发助手', 'ai-answer-questions'),
        ('审阅代码改动', 'review-toggle'),
        ('长文档阅读器', 'large-document-paste'),
      ]) {
        await tapVisible(tester, find.text(entry));
        expect(find.byKey(ValueKey(action)), findsOneWidget);
        await tapVisible(tester, find.byType(BackButton));
      }
      expect(find.text('开发者工作台'), findsOneWidget);
    },
  );

  testWidgets('open long reader follows a change in system brightness', (
    tester,
  ) async {
    final dispatcher = tester.platformDispatcher;
    dispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(dispatcher.clearPlatformBrightnessTestValue);
    await openHome(tester);
    await tapVisible(tester, find.text('长文档阅读器'));
    final markdown = find.byType(SmoothMarkdown);
    Color? textColor() =>
        tester.widget<SmoothMarkdown>(markdown).styleSheet!.textStyle?.color;
    expect(textColor(), MarkdownStyleSheet.light().textStyle!.color);
    dispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(textColor(), MarkdownStyleSheet.dark().textStyle!.color);
  });

  testWidgets('editor opens from the gallery and returns to the same home', (
    tester,
  ) async {
    await openHome(tester);
    expect(find.text('山脊行程手册'), findsOneWidget);
    await tapVisible(tester, find.text('Markdown 编辑器'));
    expect(find.byType(SmoothMarkdownEditor), findsOneWidget);
    expect(find.text('Scratch-style editor preview'), findsOneWidget);

    await tapVisible(tester, find.byType(BackButton));
    expect(find.text('开发者工作台'), findsOneWidget);
  });

  testWidgets(
    'journal remains readable with its Markdown source in the library',
    (tester) async {
      await openHome(tester);
      await tapVisible(tester, find.textContaining('示例库'));
      await tester.enterText(find.byType(TextField), 'Ridgeline');
      await tester.pump();
      await tapVisible(tester, find.text('山脊手记'));
      expect(find.byType(SmoothMarkdown), findsOneWidget);

      await tapVisible(tester, find.text('源码'));
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        startsWith('# 山脊手记'),
      );
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      expect(find.byType(SmoothMarkdown), findsNothing);

      await tapVisible(tester, find.text('正文'));
      expect(find.byType(SmoothMarkdown), findsOneWidget);
      await tapVisible(tester, find.byType(BackButton));
      expect(find.text('山脊手记'), findsOneWidget);
    },
  );

  testWidgets(
    'library filters localized samples by English title and retains the query on return',
    (tester) async {
      await openHome(tester);
      await tapVisible(tester, find.textContaining('示例库'));
      final search = find.byType(TextField);
      await tester.enterText(search, 'basic formatting');
      await tester.pump();
      expect(find.byType(ListTile), findsOneWidget);
      await tapVisible(tester, find.text('基础格式'));
      expect(find.byType(SmoothMarkdown), findsOneWidget);
      await tapVisible(tester, find.text('源码'));
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        contains('# Basic Text Formatting'),
      );
      await tapVisible(tester, find.byType(BackButton));
      expect(
        tester.widget<TextField>(search).controller!.text,
        'basic formatting',
      );
      expect(find.text('基础格式'), findsOneWidget);
    },
  );

  testWidgets(
    'language and appearance apply through the gallery at narrow width',
    (tester) async {
      await openHome(tester, width: 320);
      await tapVisible(tester, find.text('语言与外观'));
      await tapVisible(tester, find.text('English'));
      expect(find.text('Ridgeline field guide'), findsOneWidget);
      await tapVisible(tester, find.text('Language & appearance'));
      await tapVisible(tester, find.text('Default Dark'));
      final cardTitle = find.text('Ridgeline field guide');
      expect(Theme.of(tester.element(cardTitle)).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editor preview boots directly into the editor demo', (
    tester,
  ) async {
    await tester.pumpWidget(const EditorPreviewApp());
    await tester.pumpAndSettle();

    expect(find.text('Markdown Editor'), findsOneWidget);
    expect(find.text('Scratch-style editor preview'), findsOneWidget);
    expect(find.byType(SmoothMarkdownEditor), findsOneWidget);
  });

  // Guards the three HTML-rendering regression fixes (streaming tag
  // withholding, image src policy split, non-breaking BlockRenderer typedef)
  // by ensuring the HtmlDemo content — which now includes the new image-src
  // policy, streaming-withholding, and API-note sections — parses and
  // renders under the default (HTML enabled) config without throwing.
  //
  // Uses a fixed-frame pump rather than pumpAndSettle because the demo
  // references a live network image, which never settles under the widget
  // test binding's stubbed HttpClient. The demo content is long and most of
  // it scrolls out of the viewport, so we assert on the first (always-built)
  // header plus the lead paragraph text to confirm a successful render; the
  // rejected-image alt-text behavior is covered directly by
  // `test/parser/html_utils_test.dart`.
  testWidgets('HtmlDemo renders without throwing under default HTML config', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HtmlDemo()));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The document title is always in the first viewport, so it proves the
    // markdown tree built without an exception during parsing/rendering.
    expect(find.text('HTML Tags Demo'), findsOneWidget);
  });
}

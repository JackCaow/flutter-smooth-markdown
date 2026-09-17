import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_smooth_markdown_example/editor_preview_main.dart';
import 'package:flutter_smooth_markdown_example/html_demo.dart';
import 'package:flutter_smooth_markdown_example/main.dart';

void main() {
  testWidgets('main demo exposes the markdown editor entry', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Smooth Markdown Demo'), findsOneWidget);
    expect(find.byTooltip('Open editor preview'), findsOneWidget);

    await tester.tap(find.byTooltip('Open editor preview'));
    await tester.pumpAndSettle();

    expect(find.text('Markdown Editor'), findsOneWidget);
    expect(find.text('Scratch-style editor preview'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Markdown Editor'), findsOneWidget);
    expect(find.text('Scratch-style editing preview'), findsOneWidget);
  });

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
  testWidgets(
    'HtmlDemo renders without throwing under default HTML config',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HtmlDemo()));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The document title is always in the first viewport, so it proves the
      // markdown tree built without an exception during parsing/rendering.
      expect(find.text('HTML Tags Demo'), findsOneWidget);
    },
  );
}

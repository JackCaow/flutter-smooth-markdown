import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_smooth_markdown_example/editor_preview_main.dart';
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
}

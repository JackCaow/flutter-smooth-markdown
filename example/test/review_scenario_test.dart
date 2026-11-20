import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown_example/review_scenario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps reviewed files when the same local review is reopened', (
    tester,
  ) async {
    final bucket = PageStorageBucket();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                child: const Text('Open review'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PageStorage(
                      bucket: bucket,
                      child: const ReviewScenario(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark reviewed'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    expect(find.text('1/2 reviewed'), findsOneWidget);
    expect(find.text('Undo review'), findsOneWidget);
  });

  testWidgets(
    'reviews either file first, keeps marks and can undo completion',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: ReviewScenario()));

      String patch() =>
          tester.widget<MarkdownDiffView>(find.byType(MarkdownDiffView)).patch;
      expect(patch(), contains('-    if (chunk.trim().isEmpty) return;'));
      expect(patch(), contains('+    if (chunk.isEmpty) return;'));

      await tester.tap(find.text('answer_buffer_test.dart'));
      await tester.pumpAndSettle();
      expect(patch(), contains(r"+    buffer.append('\n\n');"));
      await tester.tap(find.text('Mark reviewed'));
      await tester.pumpAndSettle();
      expect(find.text('1/2 reviewed'), findsOneWidget);

      await tester.tap(find.text('answer_buffer.dart'));
      await tester.pumpAndSettle();
      expect(find.text('Mark reviewed'), findsOneWidget);
      await tester.tap(find.text('Mark reviewed'));
      await tester.pumpAndSettle();
      expect(find.text('Review complete · 2/2'), findsOneWidget);
      await tester.tap(find.text('answer_buffer_test.dart'));
      await tester.pumpAndSettle();
      expect(find.text('Undo review'), findsOneWidget);
      await tester.tap(find.text('Undo review'));
      await tester.pumpAndSettle();
      expect(find.text('1/2 reviewed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('replays whitespace-only chunks before and after the fix', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const ReviewScenario(),
      ),
    );
    final before = find.text('修改前');
    final after = find.text('修改后');
    await tester.ensureVisible(after);
    await tester.pumpAndSettle();
    String output() =>
        tester.widget<SmoothMarkdown>(find.byType(SmoothMarkdown)).data;
    expect(output(), 'OneTwo');
    await tester.tap(after);
    await tester.pumpAndSettle();
    expect(output(), 'One\n\nTwo');
    await tester.tap(before);
    await tester.pumpAndSettle();
    expect(output(), 'OneTwo');
    expect(find.text('已审阅 0/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

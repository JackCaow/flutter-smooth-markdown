import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown_example/code_diff_demo.dart';
import 'package:flutter_smooth_markdown_example/streaming_demo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'language switches the source, unified diff and Markdown at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: CodeDiffDemo()));
      expect(
        tester.widget<MarkdownCodeView>(find.byType(MarkdownCodeView)).language,
        'dart',
      );
      await tester.tap(find.text('Dart'));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.text('Rust')));
      await tester.pumpAndSettle();
      final source = tester.widget<MarkdownCodeView>(
        find.byType(MarkdownCodeView),
      );
      expect(source.code, contains('pub struct Guest'));
      await tester.tap(find.byTooltip('Hide line numbers'));
      await tester.pump();
      expect(
        tester
            .widget<MarkdownCodeView>(find.byType(MarkdownCodeView))
            .showLineNumbers,
        isFalse,
      );
      await tester.tap(find.text('Diff'));
      await tester.pumpAndSettle();
      final diff = tester.widget<MarkdownDiffView>(
        find.byType(MarkdownDiffView),
      );
      expect(diff.patch, contains('+++ b/greeting.rs'));
      expect(
        diff.patch,
        contains('+        format!("Welcome, {}! 👋", self.name)'),
      );
      expect(diff.showLineNumbers, isFalse);
      await tester.tap(find.text('Markdown'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View source'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkdownCodeView>(find.byType(MarkdownCodeView)).code,
        contains('```diff rust'),
      );
      await tester.tap(find.byTooltip('Dark mode'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Light mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Chinese stream pauses, resumes, completes, replays and resets without stale chunks',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: [Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: StreamingMarkdownDemo(),
        ),
      );
      await tester.tap(find.text('开始播放'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 440));
      await tester.tap(find.text('暂停'));
      await tester.pump();
      final progress = tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value;
      expect(progress, greaterThan(0));
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        progress,
      );
      await tester.tap(find.text('继续播放'));
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();
      expect(find.text('重新播放'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );
      await tester.tap(find.text('重新播放'));
      await tester.pump();
      await tester.tap(find.byTooltip('重置'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('开始播放'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

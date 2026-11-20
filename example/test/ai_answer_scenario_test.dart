import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smooth_markdown_example/ai_answer_scenario.dart';
import 'package:flutter_smooth_markdown_example/ai_chat_demo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final playback = find.byKey(const ValueKey('ai-answer-playback'));
  final copy = find.byKey(const ValueKey('ai-answer-copy'));

  testWidgets(
    'sample answer pauses, resumes and copies the Markdown in order',
    (tester) async {
      String? clipboard;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: [Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: AiAnswerScenario(),
        ),
      );
      await tester.pump();
      await tester.tap(playback);
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('继续'), findsOneWidget);
      expect(tester.widget<IconButton>(copy).onPressed, isNull);
      expect(
        find.textContaining('Raster P95 为 4 ms', findRichText: true),
        findsNothing,
      );
      await tester.tap(playback);
      await tester.pump(const Duration(seconds: 12));
      await tester.pump();
      expect(find.text('重播'), findsOneWidget);
      await tester.tap(copy);
      await tester.pump();
      expect(clipboard, startsWith('**先看 UI 线程。** 60 Hz'));
      expect(clipboard, endsWith('还需要一帧的时间线来确认。'));
      await tester.tap(playback);
      await tester.pump();
      expect(find.text('暂停'), findsOneWidget);
      expect(tester.widget<IconButton>(copy).onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching from a partial reply starts only the new question', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const AiAnswerScenario()),
    );
    await tester.pump(const Duration(milliseconds: 550));
    await tester.tap(find.byKey(const ValueKey('ai-answer-questions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-answer-prompt-1')));
    await tester.pumpAndSettle();
    expect(find.text('How do I verify the improvement?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(find.text('Replay'), findsOneWidget);
    final snippet = find.textContaining(
      'Replay the same input',
      findRichText: true,
      skipOffstage: false,
    );
    // Following the answer brings its final block into view. Scroll back to
    // read the opening, which may have been released by the sliver.
    await tester.scrollUntilVisible(
      snippet,
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Start with the UI thread', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('Replay the same input', findRichText: true),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('a numbered citation opens the source used by the sample', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AiAnswerScenario()));
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    final citation = find.byTooltip('Long-document scroll profile');
    await tester.scrollUntilVisible(
      citation,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(citation);
    await tester.pumpAndSettle();
    expect(
      find.text('60 Hz sample. UI P95 was 24 ms and Raster P95 was 4 ms.'),
      findsOneWidget,
    );
  });
  testWidgets('custom questions open chat and keep the offline answer paused', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AiAnswerScenario()));
    await tester.tap(find.byKey(const ValueKey('ai-answer-questions')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connect DeepSeek'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-answer-custom')));
    await tester.pumpAndSettle();
    expect(find.byType(AIChatDemo), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Resume'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

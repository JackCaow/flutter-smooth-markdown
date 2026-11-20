import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown_example/field_guide_scenario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  testWidgets('live links, section selection and retained packing checklist', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 730);
    addTearDown(tester.view.reset);
    final bucket = PageStorageBucket();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PageStorage(
                    bucket: bucket,
                    child: const FieldGuideScenario(),
                  ),
                ),
              ),
              child: const Text('打开手册'),
            ),
          ),
        ),
      ),
    );
    await tap(tester, find.text('打开手册'));
    expect(find.text('周六，去看山'), findsOneWidget);
    expect(find.byType(SmoothMarkdown), findsOneWidget);
    await tap(tester, find.text('集合与返程', findRichText: true));
    expect(key('guide-markdown-1'), findsOneWidget);
    await tap(tester, key('guide-contents'));
    await tap(tester, key('guide-section-2'));
    await tap(tester, key('guide-item-0'));
    expect(tester.widget<CheckboxListTile>(key('guide-item-0')).value, isTrue);
    expect(find.text('已装入 1 / 5'), findsOneWidget);

    String? copied;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = call.arguments['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tap(tester, key('guide-copy'));
    expect(copied, contains('- [x] 离线行程与车票\n- [ ] 水壶和午餐'));

    await tap(tester, key('guide-contents'));
    await tap(tester, key('guide-section-3'));
    expect(key('guide-markdown-3'), findsOneWidget);
    expect(key('guide-item-0'), findsNothing);
    await tap(tester, find.byType(BackButton));
    await tap(tester, find.text('打开手册'));
    await tap(tester, key('guide-packing'));
    expect(tester.widget<CheckboxListTile>(key('guide-item-0')).value, isTrue);
    await tap(tester, key('guide-item-0'));
    expect(find.text('已装入 0 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English guide opens on a narrow dark screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const FieldGuideScenario()),
    );
    await tester.pumpAndSettle();
    await tap(tester, key('guide-contents'));
    await tap(tester, key('guide-section-2'));
    expect(find.text('Packing list'), findsOneWidget);
    expect(find.text('0 / 5 packed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

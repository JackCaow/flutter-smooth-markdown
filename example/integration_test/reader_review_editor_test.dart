// From example/, run on a connected test phone:
// flutter test integration_test/reader_review_editor_test.dart -d <device-id>
// Add --dart-define=SMOOTH_TEST_CLIPBOARD=true to replace the phone's clipboard
// with the HTML and PNG fixtures and exercise the system Paste action.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown_example/large_document_sample.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_clipboard/super_clipboard.dart' as clip;

const _interval = Duration(milliseconds: 50);

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final clock = Stopwatch()..start();
  while (!ready() && clock.elapsed < const Duration(seconds: 15)) {
    await tester.pump(_interval);
  }
  expect(ready(), isTrue);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final evidence = <String, dynamic>{};

  if (Platform.isIOS && const bool.fromEnvironment('SMOOTH_TEST_CLIPBOARD')) {
    // On a physical iPhone, opening the native editing menu can activate
    // platform accessibility for the first time and retain its engine handle.
    // Start with accessibility enabled so each widget test can still detect
    // handles leaked by its widgets against a stable platform baseline.
    setUpAll(() => binding.platformDispatcher.semanticsEnabledTestValue = true);
    tearDownAll(binding.platformDispatcher.clearSemanticsEnabledTestValue);
  }

  testWidgets('native reader reveals remote headings and search matches', (
    tester,
  ) async {
    final reader = MarkdownReaderController();
    final source = buildLargeDocumentSample();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SmoothMarkdown.sliver(data: source, readerController: reader),
            ],
          ),
        ),
      ),
    );
    await _until(tester, () => reader.isIndexComplete);
    expect(source.length, 435200);
    expect(reader.headings, hasLength(1600));
    final heading = reader.headings[1570];
    final jump = reader.jumpToAnchor(heading.anchor);
    await tester.pumpAndSettle();
    expect(await jump, isTrue);
    expect(reader.activeHeading?.blockIndex, heading.blockIndex);
    expect(
      find.text('Shared Markdown', findRichText: true).hitTestable(),
      findsWidgets,
    );
    reader.search('Alpha');
    expect(reader.matches, hasLength(1600));
    final result = reader.jumpToMatch(42);
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(reader.activeMatchIndex, 42);
    expect(reader.activeHeading?.blockIndex, reader.headings[42].blockIndex);
    expect(find.text('Alpha', findRichText: true).hitTestable(), findsWidgets);
    evidence['reader'] = {
      'sourceUnits': source.length,
      'headings': reader.headings.length,
      'anchor': heading.anchor,
      'searchIndex': reader.activeMatchIndex,
      'searchCount': reader.matches.length,
    };
    await tester.pumpWidget(const SizedBox());
    reader.dispose();
  });

  testWidgets('reverse conversation retains physical location while paused', (
    tester,
  ) async {
    final scroll = MarkdownChatScrollController();
    double newestHeight = 60;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ListView.builder(
                controller: scroll,
                reverse: true,
                itemCount: 80,
                itemBuilder: (_, i) => SizedBox(
                  height: i == 0 ? newestHeight : 60,
                  child: Text('message $i'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(130);
    await tester.pumpAndSettle();
    expect(scroll.following.value, isFalse);
    final history = find.text('message 4').hitTestable();
    final before = tester.getTopLeft(history).dy;
    update(() => newestHeight += 120);
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(history).dy;
    expect(after, closeTo(before, .5));
    scroll.jumpToLatest();
    await tester.pumpAndSettle();
    expect(scroll.following.value, isTrue);
    expect(scroll.offset, scroll.position.minScrollExtent);
    evidence['chat'] = {
      'beforeY': before,
      'afterY': after,
      'latestOffset': scroll.offset,
    };
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });

  testWidgets(
    'reader keeps navigation through selection and reveals hidden hits',
    (tester) async {
      final reader = MarkdownReaderController();
      final line = 'start ${'x' * 300} farRightNeedle';
      final source =
          '# Report\n\n<details>\n<summary>Summary</summary>\n'
          'hiddenNeedle\n</details>\n\n~~~\n$line\n~~~';
      Widget page(bool selectable) => MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SmoothMarkdown.sliver(
                data: source,
                readerController: reader,
                selectable: selectable,
                useEnhancedComponents: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(page(false));
      await tester.pumpWidget(page(true));
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      expect(reader.headings.single.title, 'Report');
      for (final query in ['hiddenNeedle', 'farRightNeedle']) {
        reader.search(query);
        expect(reader.matches, hasLength(1));
        final revealed = reader.jumpToMatch(0);
        await tester.pumpAndSettle();
        expect(await revealed, isTrue);
        if (query == 'hiddenNeedle') {
          expect(
            find.textContaining(query, findRichText: true).hitTestable(),
            findsWidgets,
          );
        } else {
          final scroll = tester
              .stateList<ScrollableState>(find.byType(Scrollable))
              .singleWhere(
                (s) =>
                    axisDirectionToAxis(s.position.axisDirection) ==
                    Axis.horizontal,
              );
          expect(scroll.position.pixels, greaterThan(0));
          evidence['codeSearchOffset'] = scroll.position.pixels;
        }
      }
      await tester.pumpWidget(const SizedBox());
      reader.dispose();
    },
  );

  testWidgets('split source marker resolves a late source', (tester) async {
    final stream = StreamController<String>();
    addTearDown(stream.close);
    const source = MarkdownSource(
      title: 'Device source',
      excerpt: 'Test evidence',
    );
    final originalRegistry = ParserPluginRegistry()
      ..register(const MarkdownCitationPlugin());
    var plugins = originalRegistry;
    var sources = <int, MarkdownSource>{};
    MarkdownSource? tapped;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MarkdownCitationScope(
                sources: sources,
                onSourceTap: (s) => tapped = s,
                child: CustomScrollView(
                  slivers: [
                    StreamMarkdown.sliver(
                      stream: stream.stream,
                      plugins: plugins,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    stream.add('Test [');
    await tester.pump(const Duration(milliseconds: 150));
    stream.add('1]');
    await _until(tester, () => find.text('[1]').evaluate().isNotEmpty);
    expect(find.byTooltip(source.title), findsNothing);
    update(() => sources = {1: source});
    await tester.pump();
    await tester.tap(find.byTooltip(source.title));
    expect(tapped, same(source));
    update(
      () =>
          plugins = ParserPluginRegistry()
            ..register(const MarkdownCitationPlugin()),
    );
    await tester.pump();
    originalRegistry.unregisterInline('citation');
    stream.add('\n\nRead [guide][doc] and [1].\n\n[doc]: /manual');
    await _until(
      tester,
      () => find.byTooltip(source.title).evaluate().length == 2,
    );
    final nodes = MarkdownParser(
      plugins: plugins,
      backend: MarkdownParserBackend.rust,
    ).parse('Read [guide][doc].\n\n[doc]: /manual');
    expect(
      nodes
          .whereType<ParagraphNode>()
          .expand((p) => p.children)
          .whereType<LinkNode>()
          .map((link) => link.url),
      ['/manual'],
    );
    evidence['source'] = tapped!.title;
    await tester.pumpWidget(const SizedBox());
  });

  for (final layout in MarkdownDiffLayout.values) {
    testWidgets('4000-line ${layout.name} diff releases viewport rows', (
      tester,
    ) async {
      final scroll = ScrollController();
      final patch = [
        '@@ -1,4000 +1,4000 @@',
        for (var i = 1; i <= 4000; i++) ' source line $i',
      ].join('\n');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: scroll,
              slivers: [
                MarkdownDiffView.sliver(
                  patch: patch,
                  layout: layout,
                  language: 'text',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final visible = find.textContaining('source line ', findRichText: true);
      final firstCount = visible.evaluate().length;
      expect(firstCount, inInclusiveRange(1, 200));
      expect(find.text('source line 1', findRichText: true), findsWidgets);
      expect(find.text('source line 3999', findRichText: true), findsNothing);
      final lastRow = find
          .text('source line 3999', findRichText: true)
          .hitTestable();
      var seeks = 0;
      while (lastRow.evaluate().isEmpty && seeks < 8) {
        // A narrow viewport can wrap the final rows and change the sliver's
        // estimated extent as they are first laid out.
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        seeks++;
      }
      expect(find.text('source line 1', findRichText: true), findsNothing);
      expect(
        find.text('source line 3999', findRichText: true).hitTestable(),
        findsWidgets,
      );
      final lastCount = visible.evaluate().length;
      expect(lastCount, inInclusiveRange(1, 200));
      evidence[layout.name] = {
        'firstCount': firstCount,
        'lastCount': lastCount,
        'rows': 4000,
        'seeks': seeks,
      };
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
    });
  }

  testWidgets('split diff aligns a replacement with a missing newline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              MarkdownDiffView.sliver(
                patch:
                    '@@ -1 +1 @@\n-old value\n\\ No newline at end of file\n+new value',
                language: 'text',
                layout: MarkdownDiffLayout.sideBySide,
              ),
            ],
          ),
        ),
      ),
    );
    final left = tester.getTopLeft(find.text('old value', findRichText: true));
    final right = tester.getTopLeft(find.text('new value', findRichText: true));
    expect(left.dy, right.dy);
    expect(left.dx, lessThan(right.dx));
    evidence['eofReplacementY'] = left.dy;
  });

  testWidgets('source editor replaces and undoes changes', (tester) async {
    final editor = MarkdownEditorController(text: 'North north North');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmoothMarkdownEditor(
            controller: editor,
            initialMode: MarkdownEditorMode.source,
          ),
        ),
      ),
    );
    expect(
      editor.replaceNextMatch('North', 'West', caseSensitive: true),
      isNotNull,
    );
    expect(editor.text, 'West north North');
    expect(editor.replaceAllMatches('north', 'East'), 2);
    expect(editor.text, 'West East East');
    expect(editor.undo(), isTrue);
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'West north North',
    );
    evidence['editor'] = editor.text;
    await tester.pumpWidget(const SizedBox());
    editor.dispose();
  });

  testWidgets(
    'host clipboard HTML and PNG enter the editor through Paste',
    (tester) async {
      final system = clip.SystemClipboard.instance!;
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/kV8AAAAASUVORK5CYII=',
      );
      MarkdownClipboardImage? pasted;
      final editor = MarkdownEditorController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmoothMarkdownEditor(
              controller: editor,
              initialMode: MarkdownEditorMode.source,
              onPasteImage: (value) {
                pasted = value;
                return 'assets/device.png';
              },
            ),
          ),
        ),
      );
      final field = find.byKey(const ValueKey('smooth_markdown_editor_source'));
      await tester.tap(field);
      await tester.pumpAndSettle();
      Future<void> paste(clip.DataWriterItem fixture) async {
        await system.write([fixture]);
        await tester.longPress(field);
        final menuItem = find.text('Paste').hitTestable();
        await _until(tester, () => menuItem.evaluate().isNotEmpty);
        await tester.tap(menuItem.first);
      }

      await paste(
        clip.DataWriterItem()
          ..add(clip.Formats.htmlText('<p><b>native fixture</b></p>'))
          ..add(clip.Formats.plainText('plain alternative')),
      );
      await _until(tester, () => editor.text == '**native fixture**');
      final html = editor.text;
      // Start a new insertion so a genuine long-press on the phone need
      // not programmatically select a specific word.
      editor.text = '';
      await tester.pumpAndSettle();
      await paste(clip.DataWriterItem()..add(clip.Formats.png(png)));
      await _until(tester, () => editor.text == '![Image](assets/device.png)');
      expect(pasted!.mimeType, 'image/png');
      expect(pasted!.bytes, orderedEquals(png));
      expect(editor.undo(), isTrue);
      expect(editor.text, isEmpty);
      evidence['clipboard'] = {
        'html': html,
        'imageBytes': png.length,
        'mimeType': pasted!.mimeType,
        'action': 'long-press Paste menu',
      };
      final code = MarkdownEditorController(text: '```dart\nseed\n```');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmoothMarkdownEditor(
              key: const ValueKey('code-editor'),
              controller: code,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Edit code'));
      await tester.pumpAndSettle();
      final codeField = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      await system.write([
        clip.DataWriterItem()
          ..add(clip.Formats.htmlText('<pre><code>a * b</code></pre>'))
          ..add(clip.Formats.plainText('a * b')),
      ]);
      await tester.longPress(codeField);
      final pasteCode = find.text('Paste').hitTestable();
      await _until(tester, () => pasteCode.evaluate().isNotEmpty);
      await tester.tap(pasteCode.first);
      await _until(tester, () => code.text.contains('a * b'));
      final literal = code.document.blocks
          .whereType<MarkdownCodeBlock>()
          .single
          .code;
      expect(literal, contains('a * b'));
      expect(literal, isNot(contains('```')));
      evidence['codePaste'] = literal;
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
      code.dispose();
    },
    skip:
        !(Platform.isAndroid || Platform.isIOS) ||
        !const bool.fromEnvironment('SMOOTH_TEST_CLIPBOARD'),
  );
  tearDownAll(() {
    binding.reportData = {'deviceFeatureChecks': evidence};
    debugPrint('DEVICE_FEATURE_CHECKS ${jsonEncode(evidence)}');
  });
}

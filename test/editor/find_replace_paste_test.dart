import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/editor/markdown_editor_clipboard.dart'
    show clipboardContentToMarkdown, htmlToPastedMarkdown;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'replace next uses literal matches on original UTF-16 offsets and wraps',
    () {
      final controller = MarkdownEditorController(text: 'İ *A* *a*');
      addTearDown(controller.dispose);
      controller.textController.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 9,
      );
      expect(
        controller.replaceNextMatch('*a*', r'$1'),
        const TextRange(start: 6, end: 8),
      );
      expect(controller.text, r'İ *A* $1');
      expect(
        controller.replaceNextMatch('*a*', 'x', caseSensitive: true),
        isNull,
      );
      expect(
        controller.replaceNextMatch('*a*', 'x'),
        const TextRange(start: 2, end: 3),
      );
      expect(controller.text, r'İ x $1');
      expect(controller.undo(), isTrue);
      expect(controller.text, r'İ *A* $1');
      expect(controller.redo(), isTrue);
      expect(controller.text, r'İ x $1');
    },
  );

  test('replace all handles more than 500 matches as one undoable edit', () {
    final text = List.filled(550, 'a.A').join('|');
    final controller = MarkdownEditorController(text: text);
    addTearDown(controller.dispose);
    controller.textController.selection = TextSelection(
      baseOffset: text.length,
      extentOffset: 1,
    );
    expect(controller.findMatches('a'), hasLength(500));
    expect(controller.replaceAllMatches('a', r'$&', caseSensitive: true), 550);
    expect(controller.text, List.filled(550, r'$&.A').join('|'));
    expect(
      controller.selection,
      TextSelection(baseOffset: text.length + 550, extentOffset: 2),
    );
    expect(controller.undo(), isTrue);
    expect(controller.text, text);
    expect(controller.canUndo, isFalse);
    expect(controller.redo(), isTrue);
    expect(controller.replaceAllMatches('', 'x'), 0);
    expect(controller.replaceAllMatches('.', ''), 550);
  });

  test('clipboard HTML retains formatting, nested lists and tables', () {
    final result = htmlToPastedMarkdown(
      '<h2>Title</h2>\n<p><b>Bold</b> and <i>italic</i>, '
      '<span style="font-weight: 700">CSS</span> <a href="https://example.org/a%20b">site</a></p>'
      '<ol start="3"><li>one<ul><li>sub</li></ul></li></ol>'
      '<table><tr><th>K</th><th>V</th></tr><tr><td>|</td><td><code>1</code></td></tr></table>'
      '<pre>x```y</pre><script>ignored</script>',
    );
    expect(
      result,
      '## Title\n\n**Bold** and *italic*, **CSS** [site](https://example.org/a%20b)\n\n'
      '3. one\n   - sub\n\n| K | V |\n| --- | --- |\n| \\| | `1` |\n\n````\nx```y\n````',
    );
    expect(
      htmlToPastedMarkdown('<a href="javascript:void(0)">label</a>'),
      'label',
    );
  });

  test(
    'clipboard preserves literal plain Markdown and host image URLs',
    () async {
      const raw = '  # A\r\n\n*hi*  ';
      expect(
        await clipboardContentToMarkdown(
          const MarkdownClipboardContent(plainText: raw),
        ),
        raw,
      );
      final image = MarkdownClipboardImage(
        Uint8List.fromList([1, 2]),
        mimeType: 'image/png',
      );
      final content = MarkdownClipboardContent(image: image);
      expect(
        await clipboardContentToMarkdown(
          content,
          onPasteImage: (pasted) {
            expect(pasted, same(image));
            return 'assets/a (1).png';
          },
        ),
        '![Image](assets/a%20%281%29.png)',
      );
      expect(
        await clipboardContentToMarkdown(content, onPasteImage: (_) => null),
        isNull,
      );
    },
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));
  final source = find.byKey(const ValueKey('smooth_markdown_editor_source'));
  Future<void> hotkey(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  test(
    'explicit HTML line breaks and whitespace around marks survive paste',
    () {
      expect(
        htmlToPastedMarkdown('<p><b> bold </b>x<br>line</p>'),
        '**bold** x  \nline',
      );
    },
  );

  test(
    'clipboard paragraphs keep literal Markdown block prefixes and math',
    () {
      for (final value in [
        '# Heading',
        '- item',
        '1. item',
        '> quote',
        r'$math$',
      ]) {
        final markdown = htmlToPastedMarkdown('<p>$value</p>');
        final paragraph =
            MarkdownParser().parse(markdown).single as ParagraphNode;
        expect(
          paragraph.children.map((n) => (n as TextNode).content).join(),
          value,
        );
      }
    },
  );

  testWidgets('keyboard replace respects case, selection and undo', (
    tester,
  ) async {
    final controller = MarkdownEditorController(text: 'Cat cat Cat');
    await tester.pumpWidget(
      wrap(
        SmoothMarkdownEditor(
          controller: controller,
          initialMode: MarkdownEditorMode.source,
          height: 320,
        ),
      ),
    );
    await tester.tap(source);
    await hotkey(tester, LogicalKeyboardKey.keyH);
    final query = find.widgetWithText(TextField, 'Find in Markdown source...');
    await tester.enterText(query, 'Cat');
    await tester.enterText(
      find.widgetWithText(TextField, 'Replace with...'),
      'Dog',
    );
    await tester.tap(find.byTooltip('Match case'));
    await tester.pump();
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.byTooltip('Replace match'));
    await tester.pump();
    expect(controller.text, 'Dog cat Cat');
    await tester.tap(find.byTooltip('Replace all'));
    await tester.pump();
    expect(controller.text, 'Dog cat Dog');
    expect(controller.undo(), isTrue);
    expect(controller.text, 'Dog cat Cat');
  });

  testWidgets(
    'plain Flutter clipboard remains usable without a native adapter',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') return {'text': '*plain*'};
          if (call.method == 'Clipboard.hasStrings') return {'value': true};
          return null;
        });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final controller = MarkdownEditorController(text: '');
      await tester.pumpWidget(
        wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            initialMode: MarkdownEditorMode.source,
          ),
        ),
      );
      await tester.tap(source);
      await hotkey(tester, LogicalKeyboardKey.keyV);
      expect(controller.text, '*plain*');
    },
  );

  testWidgets('native paste shortcut converts HTML at the source selection', (
    tester,
  ) async {
    final controller = MarkdownEditorController(text: 'left old right');
    await tester.pumpWidget(
      wrap(
        SmoothMarkdownEditor(
          controller: controller,
          height: 320,
          initialMode: MarkdownEditorMode.source,
          readClipboard: () async => const MarkdownClipboardContent(
            html: '<b>new</b>',
            plainText: 'new',
          ),
        ),
      ),
    );
    await tester.tap(source);
    controller.textController.selection = const TextSelection(
      baseOffset: 5,
      extentOffset: 8,
    );
    await hotkey(tester, LogicalKeyboardKey.keyV);
    expect(controller.text, 'left **new** right');
    expect(controller.selection, const TextSelection.collapsed(offset: 12));
    expect(controller.undo(), isTrue);
    expect(controller.text, 'left old right');
  });

  testWidgets('image paste menu embeds a bitmap renderable by the reader', (
    tester,
  ) async {
    final controller = MarkdownEditorController(text: 'old');
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/kV8AAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      wrap(
        SmoothMarkdownEditor(
          controller: controller,
          height: 320,
          initialMode: MarkdownEditorMode.source,
          readClipboard: () async => MarkdownClipboardContent(
            image: MarkdownClipboardImage(bytes, mimeType: 'image/png'),
          ),
        ),
      ),
    );
    await tester.longPressAt(tester.getTopLeft(source) + const Offset(20, 25));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(
      controller.text,
      '![Image](data:image/png;base64,${base64Encode(bytes)})',
    );
    await tester.pumpWidget(wrap(SmoothMarkdown(data: controller.text)));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsOneWidget,
    );
  });

  testWidgets('async image paste preserves intervening edits', (tester) async {
    final controller = MarkdownEditorController(text: 'first');
    final save = Completer<String?>();
    await tester.pumpWidget(
      wrap(
        SmoothMarkdownEditor(
          controller: controller,
          height: 320,
          initialMode: MarkdownEditorMode.source,
          readClipboard: () async => MarkdownClipboardContent(
            image: MarkdownClipboardImage(Uint8List(1), mimeType: 'image/png'),
          ),
          onPasteImage: (_) => save.future,
        ),
      ),
    );
    await tester.tap(source);
    await hotkey(tester, LogicalKeyboardKey.keyV);
    await tester.enterText(source, 'second');
    save.complete('asset.png');
    await tester.pump();
    expect(controller.text, 'second');
  });

  testWidgets(
    'pasting into an existing marked paragraph preserves both styles',
    (tester) async {
      final controller = MarkdownEditorController(text: '**Old** plain');
      await tester.pumpWidget(
        wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            readClipboard: () async =>
                const MarkdownClipboardContent(html: '<i>new</i>'),
          ),
        ),
      );
      await tester.tap(find.textContaining('Old', findRichText: true).first);
      await tester.pumpAndSettle();
      final field = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      field.controller.selection = TextSelection.collapsed(
        offset: field.controller.text.length,
      );
      await hotkey(tester, LogicalKeyboardKey.keyV);
      expect(controller.text, contains('**Old** plain*new*'));
      expect(controller.document.blocks.first.plainText, 'Old plainnew');
    },
  );

  testWidgets('leaving the editor while reading prevents a stale upload', (
    tester,
  ) async {
    final reader = Completer<MarkdownClipboardContent?>();
    var saved = 0;
    await tester.pumpWidget(
      wrap(
        SmoothMarkdownEditor(
          height: 320,
          initialMode: MarkdownEditorMode.source,
          readClipboard: () => reader.future,
          onPasteImage: (_) {
            saved++;
            return 'photo.png';
          },
        ),
      ),
    );
    await tester.tap(source);
    await hotkey(tester, LogicalKeyboardKey.keyV);
    await tester.pumpWidget(wrap(const SizedBox()));
    reader.complete(
      MarkdownClipboardContent(
        image: MarkdownClipboardImage(Uint8List(1), mimeType: 'image/png'),
      ),
    );
    await tester.pump();
    expect(saved, 0);
  });

  testWidgets('table paste retains marks in other cell text', (tester) async {
    final controller = MarkdownEditorController(
      text: '| A |\n| --- |\n| **first** next |',
    );
    await tester.pumpWidget(
      wrap(
        SmoothMarkdownEditor(
          controller: controller,
          height: 320,
          readClipboard: () async =>
              const MarkdownClipboardContent(html: '<em>new</em>'),
        ),
      ),
    );
    final table = controller.document.blocks.first as MarkdownTableBlock;
    await tester.tap(
      find.byKey(
        ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
      ),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    field.controller.selection = const TextSelection(
      baseOffset: 6,
      extentOffset: 10,
    );
    await hotkey(tester, LogicalKeyboardKey.keyV);
    expect(controller.text, contains('| **first** *new* |'));
  });

  testWidgets('formatted editor accepts multi-block clipboard markup', (
    tester,
  ) async {
    final controller = MarkdownEditorController(text: 'Old');
    await tester.pumpWidget(
      wrap(
        SmoothMarkdownEditor(
          controller: controller,
          height: 320,
          readClipboard: () async => const MarkdownClipboardContent(
            html: '<h2>Title</h2><p><b>body</b></p>',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Old', findRichText: true).first);
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    field.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: field.controller.text.length,
    );
    await hotkey(tester, LogicalKeyboardKey.keyV);
    expect(controller.text, contains('## Title\n\n**body**'));
  });
}

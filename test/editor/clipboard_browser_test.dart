@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testWidgets(
    'browser paste event converts offered HTML for the focused editor',
    (tester) async {
      final a = MarkdownEditorController(text: 'first');
      final b = MarkdownEditorController(text: 'old');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SmoothMarkdownEditor(
                  controller: a,
                  initialMode: MarkdownEditorMode.source,
                  height: 150,
                ),
                SmoothMarkdownEditor(
                  controller: b,
                  initialMode: MarkdownEditorMode.source,
                  height: 150,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_source')).last,
      );
      b.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      final data = web.DataTransfer();
      data.items.add('<h2>From browser</h2>'.toJS, 'text/html');
      data.items.add('From browser'.toJS, 'text/plain');
      await pasteEvent(tester, data, b);
      expect(a.text, 'first');
      expect(b.text, '## From browser');
    },
  );
  testWidgets('browser clipboard file supplies its image bytes to the host', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/kV8AAAAASUVORK5CYII=',
    );
    final editor = MarkdownEditorController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmoothMarkdownEditor(
            controller: editor,
            initialMode: MarkdownEditorMode.source,
            height: 280,
            onPasteImage: (image) {
              expect(image.bytes, bytes);
              expect(image.mimeType, 'image/png');
              return 'assets/paste.png';
            },
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('smooth_markdown_editor_source')),
    );
    final file = web.File(
      [bytes.toJS].toJS,
      'clipboard.png',
      web.FilePropertyBag(type: 'image/png'),
    );
    final data = web.DataTransfer();
    data.items.add(file);
    await pasteEvent(tester, data, editor);
    expect(editor.text, '![Image](assets/paste.png)');
  });
}

Future<void> pasteEvent(
  WidgetTester tester,
  web.DataTransfer data,
  MarkdownEditorController editor,
) async {
  final before = editor.text;
  final event = web.ClipboardEvent(
    'paste',
    web.ClipboardEventInit(
      clipboardData: data,
      cancelable: true,
      bubbles: true,
    ),
  );
  await tester.runAsync(() async {
    web.window.dispatchEvent(event);
    for (var attempt = 0; attempt < 30 && editor.text == before; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });
  await tester.pump();
  expect(event.defaultPrevented, isTrue);
}

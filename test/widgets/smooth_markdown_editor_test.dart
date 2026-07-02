import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown_editor_experimental.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _richTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is RichText) {
        return widget.text.toPlainText().contains(text);
      }
      return false;
    },
    description: 'RichText containing "$text"',
  );
}

Color? _richTextColorContaining(WidgetTester tester, String text) {
  for (final element in _richTextContaining(text).evaluate()) {
    final widget = element.widget;
    if (widget is RichText) {
      final color = _spanColorContaining(widget.text, text);
      if (color != null) return color;
    }
  }
  return null;
}

Color? _spanColorContaining(InlineSpan span, String text) {
  if (span is TextSpan) {
    if ((span.text?.contains(text) ?? false) && span.style?.color != null) {
      return span.style!.color;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      final color = _spanColorContaining(child, text);
      if (color != null) return color;
    }
    if (span.toPlainText().contains(text)) {
      return span.style?.color;
    }
  }
  return null;
}

Finder _highlightedRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is! RichText) return false;
      return _hasHighlightedSpan(widget.text, text);
    },
    description: 'Highlighted RichText containing "$text"',
  );
}

bool _hasHighlightedSpan(InlineSpan span, String text) {
  if (span is TextSpan) {
    final highlighted =
        span.text == text && span.style?.backgroundColor != null;
    if (highlighted) return true;
    return span.children?.any((child) => _hasHighlightedSpan(child, text)) ??
        false;
  }
  return false;
}

bool _hasBoldSpan(InlineSpan span, String text) {
  if (span is TextSpan) {
    final bold = span.text == text &&
        (span.style?.fontWeight == FontWeight.bold ||
            span.style?.fontWeight == FontWeight.w700);
    if (bold) return true;
    return span.children?.any((child) => _hasBoldSpan(child, text)) ?? false;
  }
  return false;
}

bool _hasUnderlineSpan(InlineSpan span, String text) {
  if (span is TextSpan) {
    final underlined = span.text == text &&
        (span.style?.decoration?.contains(TextDecoration.underline) ?? false);
    if (underlined) return true;
    return span.children?.any((child) => _hasUnderlineSpan(child, text)) ??
        false;
  }
  return false;
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 900,
          child: child,
        ),
      ),
    ),
  );
}

Widget _wrapWithWidth(Widget child, {required double width}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: child,
        ),
      ),
    ),
  );
}

Widget _wrapDark(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 900,
          child: child,
        ),
      ),
    ),
  );
}

Future<void> _sendControlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool alt = false,
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (alt) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  }
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }

  try {
    await tester.sendKeyEvent(key);
  } finally {
    if (shift) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    }
    if (alt) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }
}

Future<void> _shiftTap(WidgetTester tester, Finder finder) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  try {
    await tester.tap(finder);
  } finally {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
}

Future<void> _tapToolbarIcon(WidgetTester tester, IconData icon) async {
  final iconFinder = find.byIcon(icon);
  final toolbarScrollable = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable &&
        axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
    description: 'horizontal editor toolbar',
  );

  for (var i = 0; i < 30 && iconFinder.evaluate().isEmpty; i++) {
    await tester.drag(toolbarScrollable.first, const Offset(-160, 0));
    await tester.pump();
  }
  if (iconFinder.evaluate().isEmpty) {
    for (var i = 0; i < 30 && iconFinder.evaluate().isEmpty; i++) {
      await tester.drag(toolbarScrollable.first, const Offset(160, 0));
      await tester.pump();
    }
  }
  expect(iconFinder, findsWidgets);

  await tester.ensureVisible(iconFinder.first);
  await tester.pump();
  await tester.tap(iconFinder.first);
}

List<MarkdownBlock> _scratchContentBlocks(MarkdownDocument document) {
  return [
    for (var i = 0; i < document.blocks.length; i++)
      if (!_isScratchTrailingParagraph(document, i)) document.blocks[i],
  ];
}

bool _isScratchTrailingParagraph(MarkdownDocument document, int index) {
  final block = document.blocks[index];
  return document.blocks.length > 1 &&
      index == document.blocks.length - 1 &&
      block is MarkdownParagraphBlock &&
      block.plainText.isEmpty;
}

MarkdownBlock _singleScratchContentBlock(
  MarkdownEditorController controller,
) {
  return _scratchContentBlocks(controller.document).single;
}

MarkdownBlock _lastScratchContentBlock(
  MarkdownEditorController controller,
) {
  return _scratchContentBlocks(controller.document).last;
}

Future<TextEditingController> _enterComposingText(
  WidgetTester tester,
  Finder finder,
  String text, {
  required TextRange composing,
}) async {
  final field = tester.widget<TextField>(finder);
  final controller = field.controller!
    ..value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: composing,
    );
  await tester.pump();
  return controller;
}

void main() {
  group('MarkdownEditorController', () {
    test('wraps selected text with bold markers', () {
      final controller = MarkdownEditorController(text: 'Hello');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      controller.applyCommand(MarkdownEditorCommand.bold);

      expect(controller.text, '**Hello**');
      expect(controller.selection.textInside(controller.text), 'Hello');
    });

    test('tracks saved source and selected markdown for host integrations', () {
      final controller = MarkdownEditorController(text: 'Hello world');
      addTearDown(controller.dispose);

      expect(controller.savedText, 'Hello world');
      expect(controller.isDirty, isFalse);

      controller.textController.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 11,
      );
      expect(controller.selectedText, 'world');
      expect(controller.getSelectionMarkdown(), 'world');

      controller.insertMarkdown('Scratch');
      expect(controller.text, 'Hello Scratch');
      expect(controller.isDirty, isTrue);

      controller.markSaved();
      expect(controller.savedText, 'Hello Scratch');
      expect(controller.isDirty, isFalse);
    });

    test('allows hosts to disable source undo history', () {
      final controller = MarkdownEditorController(historyLimit: 0);
      addTearDown(controller.dispose);

      controller
        ..text = 'first'
        ..text = 'second';

      expect(controller.canUndo, isFalse);
      expect(controller.undo(), isFalse);
      expect(controller.text, 'second');
    });

    test('exposes table row and column editing through controller', () {
      final controller = MarkdownEditorController();
      addTearDown(controller.dispose);
      controller.document = const MarkdownDocument(
        blocks: [
          MarkdownTableBlock(
            id: 'table',
            headers: [
              [MarkdownText('A')],
              [MarkdownText('B')],
            ],
            rows: [
              [
                [MarkdownText('1')],
                [MarkdownText('2')],
              ],
            ],
            alignments: [null, null],
          ),
        ],
      );

      expect(
        controller.replaceTableCellText(
          tableId: 'table',
          rowIndex: 0,
          columnIndex: 1,
          text: 'updated',
        ),
        isTrue,
      );
      expect(controller.insertTableColumnAfter('table', 1), isTrue);
      expect(controller.insertTableRowAfter('table', 0), isTrue);
      expect(
        controller.setTableColumnAlignment(
          tableId: 'table',
          columnIndex: 1,
          alignment: MarkdownTableAlignment.center,
        ),
        isTrue,
      );

      var table = controller.document.blockById('table') as MarkdownTableBlock;
      expect(table.columnCount, 3);
      expect(table.rows, hasLength(2));
      expect(table.rows.first[1].single.plainText, 'updated');
      expect(table.alignments[1], MarkdownTableAlignment.center);

      expect(controller.deleteTableColumn('table', 2), isTrue);
      expect(controller.deleteTableRow('table', 1), isTrue);
      table = controller.document.blockById('table') as MarkdownTableBlock;
      expect(table.columnCount, 2);
      expect(table.rows, hasLength(1));
    });

    test('prefixes selected lines as an ordered list', () {
      final controller = MarkdownEditorController(text: 'one\ntwo');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 7,
      );
      controller.applyCommand(MarkdownEditorCommand.orderedList);

      expect(controller.text, '1. one\n2. two');
    });

    test('supports TipTap heading level six command', () {
      final controller = MarkdownEditorController(text: 'Deep heading');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection.collapsed(
        offset: 12,
      );
      controller.applyCommand(MarkdownEditorCommand.heading6);

      expect(controller.text, '###### Deep heading');
    });

    test('selects the next search match', () {
      final controller = MarkdownEditorController(text: 'alpha beta alpha');
      addTearDown(controller.dispose);

      final match = controller.selectNextMatch('alpha');

      expect(match, const TextRange(start: 0, end: 5));
      expect(controller.selection.textInside(controller.text), 'alpha');
    });

    test('limits search matches like Scratch', () {
      final controller = MarkdownEditorController(
        text: List.filled(650, 'alpha').join(' '),
      );
      addTearDown(controller.dispose);

      final matches = controller.findMatches('alpha');

      expect(matches, hasLength(500));
      expect(matches.first, const TextRange(start: 0, end: 5));
      expect(matches.last.start, 499 * 'alpha '.length);
    });

    test('converts block markers back to paragraph text', () {
      final controller = MarkdownEditorController(text: '## Heading');
      addTearDown(controller.dispose);

      controller.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 10,
      );
      controller.applyCommand(MarkdownEditorCommand.paragraph);

      expect(controller.text, 'Heading');
    });

    test('keeps semantic document synchronized from source edits', () {
      final controller = MarkdownEditorController(text: '# Title');
      addTearDown(controller.dispose);

      expect(
        _singleScratchContentBlock(controller),
        isA<MarkdownHeadingBlock>(),
      );
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');

      controller.text = '- [x] Done';

      final block = _singleScratchContentBlock(controller);
      expect(block, isA<MarkdownListBlock>());
      final list = block as MarkdownListBlock;
      expect(list.kind, MarkdownListKind.task);
      expect(list.items.single.checked, isTrue);
      expect(list.items.single.plainText, 'Done');
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
    });

    test('defers source history while composing until commit', () {
      final controller = MarkdownEditorController();
      addTearDown(controller.dispose);

      controller.textController.value = const TextEditingValue(
        text: '# 标题',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 2, end: 4),
      );

      expect(controller.text, '# 标题');
      expect(
        controller.textController.value.composing,
        const TextRange(start: 2, end: 4),
      );
      expect(controller.canUndo, isFalse);

      controller.textController.value = const TextEditingValue(
        text: '# 标题',
        selection: TextSelection.collapsed(offset: 4),
      );

      expect(controller.canUndo, isTrue);
      expect(
          _singleScratchContentBlock(controller), isA<MarkdownHeadingBlock>());

      expect(controller.undo(), isTrue);
      expect(controller.text, '');
    });

    test('coalesces source typing in one event loop into one undo step',
        () async {
      final controller = MarkdownEditorController();
      addTearDown(controller.dispose);

      void typeSource(String text) {
        controller.textController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }

      typeSource('a');
      typeSource('ab');
      typeSource('abc');
      await Future<void>.delayed(Duration.zero);

      expect(controller.canUndo, isTrue);
      expect(controller.undo(), isTrue);
      expect(controller.text, '');
      expect(controller.undo(), isFalse);

      typeSource('a');
      await Future<void>.delayed(Duration.zero);
      typeSource('ab');
      await Future<void>.delayed(Duration.zero);

      expect(controller.undo(), isTrue);
      expect(controller.text, 'a');
      expect(controller.undo(), isTrue);
      expect(controller.text, '');
    });

    test('adds Scratch trailing paragraphs after source-parsed block tails',
        () {
      final controller = MarkdownEditorController(text: '');
      addTearDown(controller.dispose);

      expect(_singleScratchContentBlock(controller),
          isA<MarkdownParagraphBlock>());
      expect(_singleScratchContentBlock(controller).plainText, '');
      expect(controller.text, '');

      controller.text = '![Alt](image.png)';

      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blocks.first, isA<MarkdownImageBlock>());
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
      expect(controller.text, '![Alt](image.png)');

      controller.text = '# Title';

      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blocks.first, isA<MarkdownHeadingBlock>());
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
      expect(controller.text, '# Title');

      controller.text = '- Item';

      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blocks.first, isA<MarkdownListBlock>());
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
      expect(controller.text, '- Item');

      controller.text = '---';

      expect(controller.document.blocks, hasLength(2));
      expect(
        controller.document.blocks.first,
        isA<MarkdownHorizontalRuleBlock>(),
      );
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
      expect(controller.text, '---');

      controller.text = r'$$'
          '\n'
          r'x^2'
          '\n'
          r'$$';

      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blocks.first, isA<MarkdownBlockMathBlock>());
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
      expect(
        controller.text,
        r'$$'
        '\n'
        r'x^2'
        '\n'
        r'$$',
      );

      controller.text = 'Plain paragraph';

      expect(controller.document.blocks, hasLength(1));
      expect(_singleScratchContentBlock(controller),
          isA<MarkdownParagraphBlock>());
      expect(controller.text, 'Plain paragraph');
    });

    test('parses semantic document with supplied parser plugins', () {
      final plugins = ParserPluginRegistry()
        ..register(const AdmonitionPlugin());
      final controller = MarkdownEditorController(
        text: '::: note Heads up\nBody\n:::',
        plugins: plugins,
      );
      addTearDown(controller.dispose);

      final block = _singleScratchContentBlock(controller);
      expect(block, isA<MarkdownRawBlock>());
      expect(block.toMarkdown(), '::: note Heads up\nBody\n:::');
    });

    test('serializes semantic document transactions back to source', () {
      final controller = MarkdownEditorController(text: 'Body');
      addTearDown(controller.dispose);

      final blockId = _singleScratchContentBlock(controller).id;
      controller.applyBlockCommand(blockId, MarkdownEditorCommand.heading2);

      expect(controller.text, '## Body');
      expect(
        _singleScratchContentBlock(controller),
        isA<MarkdownHeadingBlock>(),
      );
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
    });

    test('serializes inline document transactions back to source', () {
      final controller = MarkdownEditorController(text: 'hello world');
      addTearDown(controller.dispose);

      final blockId = _singleScratchContentBlock(controller).id;
      controller.applyInlineCommand(
        blockId,
        const TextRange(start: 6, end: 11),
        MarkdownEditorCommand.bold,
      );

      expect(controller.text, 'hello **world**');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, contains(isA<MarkdownStrong>()));
    });

    test('serializes cross-block inline document selections back to source',
        () {
      final controller = MarkdownEditorController(text: 'Alpha\n\nBeta');
      addTearDown(controller.dispose);

      final changed = controller.applyInlineCommandToDocumentSelection(
        MarkdownDocumentSelection(
          anchor: MarkdownDocumentPosition(
            blockId: controller.document.blocks[0].id,
            offset: 0,
          ),
          focus: MarkdownDocumentPosition(
            blockId: controller.document.blocks[1].id,
            offset: 4,
          ),
        ),
        MarkdownEditorCommand.bold,
      );

      expect(changed, isTrue);
      expect(controller.text, '**Alpha**\n\n**Beta**');
    });

    test('replaces cross-block document selections and syncs source', () {
      final controller = MarkdownEditorController(text: 'BeforeX\n\nYAfter');
      addTearDown(controller.dispose);

      final result = controller.replaceDocumentSelectionWithMarkdown(
        MarkdownDocumentSelection(
          anchor: MarkdownDocumentPosition(
            blockId: controller.document.blocks[0].id,
            offset: 6,
          ),
          focus: MarkdownDocumentPosition(
            blockId: controller.document.blocks[1].id,
            offset: 1,
          ),
        ),
        '# Inserted\n\nBody',
      );

      expect(result, isNotNull);
      expect(
        controller.text,
        'Before\n\n'
        '# Inserted\n\n'
        'Body\n\n'
        'After',
      );
      expect(
        controller.selection,
        TextSelection.collapsed(offset: controller.text.indexOf('After')),
      );
    });

    test('retags replacement block ids before inserting parsed markdown', () {
      final controller = MarkdownEditorController(
        text: '- Existing\n\nBeta\n\nGamma',
      );
      addTearDown(controller.dispose);

      final beta = controller.document.blocks[1];
      final result = controller.replaceDocumentSelectionWithMarkdown(
        MarkdownDocumentSelection(
          anchor: MarkdownDocumentPosition(
            blockId: beta.id,
            offset: 0,
          ),
          focus: MarkdownDocumentPosition(
            blockId: beta.id,
            offset: beta.plainText.length,
          ),
        ),
        '- Inserted',
      );

      expect(result, isNotNull);
      final blockIds = <String>[];
      final listItemIds = <String>[];

      void collectIds(List<MarkdownBlock> blocks) {
        for (final block in blocks) {
          blockIds.add(block.id);
          if (block is MarkdownBlockquoteBlock) {
            collectIds(block.blocks);
          } else if (block is MarkdownListBlock) {
            for (final item in block.items) {
              listItemIds.add(item.id);
              collectIds(item.blocks);
            }
          }
        }
      }

      collectIds(controller.document.blocks);

      expect(blockIds.toSet().length, blockIds.length);
      expect(listItemIds.toSet().length, listItemIds.length);
      expect(controller.document.blockById(result!.activeBlockId), isNotNull);
      expect(
        controller.documentEditor.replaceTextBlockText(
          result.activeBlockId,
          'Changed',
        ),
        isTrue,
      );
      expect(controller.text, '- Existing\n\n- Changed\n\nGamma');
    });

    test('inserts imported markdown as a separated block', () {
      final controller = MarkdownEditorController(text: 'Intro');
      addTearDown(controller.dispose);

      controller.textController.selection =
          const TextSelection.collapsed(offset: 5);
      controller.insertMarkdownBlock('# Imported\n\nBody');

      expect(
        controller.text,
        'Intro\n\n'
        '# Imported\n\n'
        'Body',
      );
      expect(controller.document.blocks[1], isA<MarkdownHeadingBlock>());
      expect(controller.document.blocks[2].plainText, 'Body');
    });

    test('inserts custom table dimensions in source editing', () {
      final controller = MarkdownEditorController(text: 'Intro');
      addTearDown(controller.dispose);

      controller.textController.selection =
          const TextSelection.collapsed(offset: 5);
      controller.insertTable(rows: 4, columns: 2);

      expect(
        controller.text,
        'Intro\n\n'
        '| Column | Column |\n'
        '| --- | --- |\n'
        '| Cell | Cell |\n'
        '| Cell | Cell |\n'
        '| Cell | Cell |',
      );
      final table = _lastScratchContentBlock(controller) as MarkdownTableBlock;
      expect(table.columnCount, 2);
      expect(table.rows, hasLength(3));
    });

    test('converts markdown to plain text for export', () {
      expect(
        markdownToPlainText(
          '# Title\n\n'
          '- [link](https://example.com)\n'
          '- [[Daily|today]]\n\n'
          '- [x] Done\n'
          '- [ ] Todo\n\n'
          '```dart\n'
          '**code stays markdown**\n'
          '```',
        ),
        'Title\n\n'
        'link\n'
        '[[Daily|today]]\n\n'
        'Done\n'
        'Todo\n\n'
        '**code stays markdown**',
      );
    });

    test('keeps intraword underscores in plain text export', () {
      expect(
        markdownToPlainText(
          'Keep snake_case and foo__bar__baz.\n'
          'Strip _italic_ and __strong__.',
        ),
        'Keep snake_case and foo__bar__baz.\n'
        'Strip italic and strong.',
      );
    });

    test('converts markdown to html for export', () {
      final html = markdownToHtml(
        '# Title\n\n'
        'See **bold**, ~~strike~~, [link](https://example.com "Example"), '
        '[bad](javascript:alert), [[Daily|today]], and [[Inbox]].\n\n'
        '```dart\n'
        'void main() {}\n'
        '```',
      );

      expect(html, contains('<h1>Title</h1>'));
      expect(html, contains('<strong>bold</strong>'));
      expect(html, contains('<s>strike</s>'));
      expect(html, isNot(contains('<del>strike</del>')));
      expect(
        html,
        contains(
          '<a target="_blank" rel="noopener noreferrer nofollow" class="underline cursor-pointer" href="https://example.com" title="Example">link</a>',
        ),
      );
      expect(
        html,
        contains(
          '<a target="_blank" rel="noopener noreferrer nofollow" class="underline cursor-pointer" href="">bad</a>',
        ),
      );
      expect(
        html,
        contains(
          '<span data-wikilink="" data-note-title="Daily|today">Daily|today</span>',
        ),
      );
      expect(
        html,
        contains(
          '<span data-wikilink="" data-note-title="Inbox">Inbox</span>',
        ),
      );
      expect(html, contains('<code class="language-dart">void main() {}'));
    });

    test('exports standalone images as Scratch TipTap image blocks', () {
      final html = markdownToHtml(
        '![Alt text](https://example.com/image.png "Image title")\n\n'
        'Paragraph with ![inline](https://example.com/inline.png).',
      );

      expect(
        html,
        startsWith(
          '<img src="https://example.com/image.png" alt="Alt text" title="Image title">',
        ),
      );
      expect(
        html,
        isNot(
          startsWith(
            '<p><img src="https://example.com/image.png"',
          ),
        ),
      );
      expect(
        html,
        contains(
          '<p>Paragraph with <img src="https://example.com/inline.png" alt="inline">.</p>',
        ),
      );
    });

    test('keeps code and image attributes from recursive inline parsing', () {
      final html = markdownToHtml(
        '`**not bold** and \$not math\$`\n\n'
        '![**Alt**](https://example.com/image.png "A **title**")\n\n'
        '[**bold** and `code`](https://example.com)',
      );

      expect(
        html,
        contains('<p><code>**not bold** and \$not math\$</code></p>'),
      );
      expect(
        html,
        contains(
          '<img src="https://example.com/image.png" alt="**Alt**" title="A **title**">',
        ),
      );
      expect(
        html,
        contains(
          '<a target="_blank" rel="noopener noreferrer nofollow" class="underline cursor-pointer" href="https://example.com"><strong>bold</strong> and <code>code</code></a>',
        ),
      );
    });

    test('exports hard breaks as Scratch TipTap br nodes', () {
      final html = markdownToHtml(
        'First  \n'
        'Second\n'
        'Third\\\n'
        'Fourth',
      );

      expect(
        html,
        '<p>First<br>Second Third<br>Fourth</p>',
      );
    });

    test('exports horizontal rules as Scratch TipTap hr nodes', () {
      final html = markdownToHtml('Before\n\n---\n\nAfter');

      expect(html, '<p>Before</p>\n<hr>\n<p>After</p>');
      expect(html, isNot(contains('<hr />')));
    });

    test('exports blockquotes with Scratch TipTap nested block html', () {
      final html = markdownToHtml(
        '> First paragraph\n'
        '>\n'
        '> - Child\n'
        '> - Sibling\n'
        '>\n'
        '> ---',
      );

      expect(
        html,
        '<blockquote><p>First paragraph</p>\n'
        '<ul>\n'
        '<li><p>Child</p></li>\n'
        '<li><p>Sibling</p></li>\n'
        '</ul>\n'
        '<hr></blockquote>',
      );
      expect(html, isNot(contains('- Child')));
    });

    test('keeps intraword underscores in html export', () {
      final html = markdownToHtml(
        'Keep snake_case and foo__bar__baz.\n'
        'Strip _italic_ and __strong__.',
      );

      expect(
        html,
        contains('Keep snake_case and foo__bar__baz. Strip'),
      );
      expect(html, contains('<em>italic</em>'));
      expect(html, contains('<strong>strong</strong>'));
    });

    test('exports leading frontmatter as a Scratch frontmatter block', () {
      final html = markdownToHtml(
        '---\n'
        'title: Daily\n'
        'tags:\n'
        '  - work\n'
        '---\n\n'
        '# Body',
      );

      expect(
        html,
        startsWith(
          '<pre data-frontmatter="" class="frontmatter"><code>'
          'title: Daily\n'
          'tags:\n'
          '  - work'
          '</code></pre>',
        ),
      );
      expect(html, contains('<h1>Body</h1>'));
      expect(html, isNot(contains('<hr />')));
    });

    test('exports math with Scratch TipTap html wrappers', () {
      final html = markdownToHtml(
        r'$$E = mc^2$$'
        '\n\n'
        r'$$'
        '\n'
        r'a^2 + b^2 = c^2'
        '\n'
        r'$$'
        '\n\n'
        r'Inline $x + y$',
      );

      expect(
        html,
        contains(
          '<div data-latex="E = mc^2" data-type="block-math"></div>',
        ),
      );
      expect(
        html,
        contains(
          '<div data-latex="a^2 + b^2 = c^2" data-type="block-math"></div>',
        ),
      );
      expect(
        html,
        contains(
          '<span data-latex="x + y" data-type="inline-math"></span>',
        ),
      );
      expect(html, isNot(contains('math-display')));
      expect(html, isNot(contains('math-inline')));
    });

    test('exports lists with Scratch TipTap html wrappers', () {
      final html = markdownToHtml(
        '- [x] Done\n'
        '- [ ] Todo\n\n'
        '3. Three\n'
        '4. Four',
      );

      expect(html, contains('<ul data-type="taskList">'));
      expect(
        html,
        contains(
          '<li data-checked="true" data-type="taskItem"><label><input type="checkbox" checked="checked"><span></span></label><div><p>Done</p></div></li>',
        ),
      );
      expect(
        html,
        contains(
          '<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label><div><p>Todo</p></div></li>',
        ),
      );
      expect(html, contains('<ol start="3">'));
      expect(html, contains('<li><p>Three</p></li>'));
      expect(html, contains('<li><p>Four</p></li>'));
    });

    test('exports nested lists with Scratch TipTap html nesting', () {
      final html = markdownToHtml(
        '- Parent\n'
        '  - Child\n'
        '- Next\n\n'
        '- [ ] Root\n'
        '  - [x] Nested',
      );

      expect(html, contains('<li><p>Parent</p><ul>'));
      expect(html, contains('<li><p>Child</p></li>'));
      expect(html, contains('</ul>\n</li>\n<li><p>Next</p></li>'));
      expect(
        html,
        contains(
          '<li data-checked="false" data-type="taskItem"><label><input type="checkbox"><span></span></label><div><p>Root</p><ul data-type="taskList">',
        ),
      );
      expect(
        html,
        contains(
          '<li data-checked="true" data-type="taskItem"><label><input type="checkbox" checked="checked"><span></span></label><div><p>Nested</p></div></li>',
        ),
      );
    });

    test('converts escaped table cell pipes to html for export', () {
      final html = markdownToHtml(
        '| Name \\| Value | Description |\n'
        '| --- | --- |\n'
        '| A \\| B and **C \\| D** | [[Daily\\|today]] |',
      );

      expect(
        html,
        contains('<table class="not-prose" style="min-width: 50px">'),
      );
      expect(html, contains('<colgroup>'));
      expect(
        html,
        contains(
          '<th colspan="1" rowspan="1"><p>Name | Value</p></th>',
        ),
      );
      expect(
        html,
        contains(
          '<td colspan="1" rowspan="1"><p>A | B and <strong>C | D</strong></p></td>',
        ),
      );
      expect(
        html,
        contains(
          '<td colspan="1" rowspan="1"><p><span data-wikilink="" data-note-title="Daily|today">Daily|today</span></p></td>',
        ),
      );
      expect(RegExp(r'<t[hd]\b').allMatches(html), hasLength(4));
    });

    test('normalizes ragged tables to Scratch-style rectangular html', () {
      final html = markdownToHtml(
        '| A | B |\n'
        '| --- | --- | --- |\n'
        '| 1 |\n'
        '| 2 | 3 | 4 |',
      );

      expect(
        html,
        contains('<table class="not-prose" style="min-width: 50px">'),
      );
      expect(
        html,
        contains('<td colspan="1" rowspan="1"><p></p></td>'),
      );
      expect(
        html,
        contains('<td colspan="1" rowspan="1"><p>3</p></td>'),
      );
      expect(
          html, isNot(contains('<td colspan="1" rowspan="1"><p>4</p></td>')));
      expect(RegExp(r'<t[hd]\b').allMatches(html), hasLength(6));
    });
  });

  group('SmoothMarkdownEditor', () {
    testWidgets('defaults to formatted block editing', (tester) async {
      final controller = MarkdownEditorController(text: '# Title\n\nBody');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 240,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('smooth_markdown_editor_source')),
          findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        findsOneWidget,
      );
      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      expect(activeField.controller?.text, 'Title');

      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'Edited',
      );
      await tester.pump();

      expect(controller.text, '# Edited\n\nBody');
    });

    testWidgets('formatted preview defaults to dark theme colors',
        (tester) async {
      final controller = MarkdownEditorController(text: '# Title\n\nBody');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapDark(
          SmoothMarkdownEditor(
            controller: controller,
            height: 240,
          ),
        ),
      );

      final bodyColor = _richTextColorContaining(tester, 'Body');
      final headingColor = _richTextColorContaining(tester, 'Title');

      expect(bodyColor, isNotNull);
      expect(headingColor, isNotNull);
      expect(bodyColor!.computeLuminance(), greaterThan(0.5));
      expect(headingColor!.computeLuminance(), greaterThan(0.5));
    });

    testWidgets('uses editor theme parameter for core editor chrome',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '```dart\nvoid main() {}\n```',
      );
      addTearDown(controller.dispose);

      const toolbarColor = Color(0xFF101820);
      const activeColor = Color(0xFF223344);
      const headerColor = Color(0xFF334455);
      const borderColor = Color(0xFF445566);
      const sourceColor = Color(0xFF556677);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            editorTheme: const MarkdownEditorThemeData(
              toolbarColor: toolbarColor,
              toolbarActiveBackgroundColor: activeColor,
              blockHeaderColor: headerColor,
              blockBorderColor: borderColor,
              sourceTextStyle: TextStyle(color: sourceColor),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Material && widget.color == toolbarColor,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Material && widget.color == headerColor,
        ),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate((widget) {
          final decoration = widget is DecoratedBox ? widget.decoration : null;
          return decoration is BoxDecoration && decoration.color == activeColor;
        }),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate((widget) {
          final decoration = widget is DecoratedBox ? widget.decoration : null;
          final border = decoration is BoxDecoration ? decoration.border : null;
          return border is Border &&
              border.top.color == borderColor &&
              border.right.color == borderColor &&
              border.bottom.color == borderColor &&
              border.left.color == borderColor;
        }),
        findsWidgets,
      );

      await tester.tap(find.byTooltip('Source'));
      await tester.pump();

      final sourceField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_source')),
      );
      expect(sourceField.style?.color, sourceColor);
    });

    testWidgets('uses editor theme from ThemeData extensions', (tester) async {
      final controller = MarkdownEditorController(
        text: '```dart\nprint("theme");\n```',
      );
      addTearDown(controller.dispose);

      const toolbarColor = Color(0xFF203040);
      const headerColor = Color(0xFF304050);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[
              MarkdownEditorThemeData(
                toolbarColor: toolbarColor,
                blockHeaderColor: headerColor,
              ),
            ],
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 900,
                child: SmoothMarkdownEditor(
                  controller: controller,
                  height: 320,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) => widget is Material && widget.color == toolbarColor,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Material && widget.color == headerColor,
        ),
        findsWidgets,
      );
    });

    testWidgets('notifies host callbacks for text mode and focus changes',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Draft');
      final textChanges = <String>[];
      final modeChanges = <MarkdownEditorMode>[];
      final focusModeChanges = <bool>[];
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            initialMode: MarkdownEditorMode.source,
            height: 240,
            onChanged: textChanges.add,
            onModeChanged: modeChanges.add,
            onFocusModeChanged: focusModeChanges.add,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_source')),
        'Draft updated',
      );
      await tester.pump();

      expect(textChanges, contains('Draft updated'));

      await tester.tap(find.byTooltip('Preview'));
      await tester.pump();
      await tester.tap(find.byTooltip('Formatted'));
      await tester.pump();

      expect(
        modeChanges,
        <MarkdownEditorMode>[
          MarkdownEditorMode.preview,
          MarkdownEditorMode.formatted,
        ],
      );

      await _tapToolbarIcon(tester, Icons.fullscreen);
      await tester.pump();

      expect(focusModeChanges, <bool>[true]);
    });

    testWidgets('formatted pane lazily renders long documents', (tester) async {
      final markdown = List.generate(
        200,
        (index) => 'Paragraph ${index.toString().padLeft(3, '0')}',
      ).join('\n\n');
      final controller = MarkdownEditorController(text: markdown);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 240,
          ),
        ),
      );

      expect(_richTextContaining('Paragraph 000'), findsOneWidget);
      expect(_richTextContaining('Paragraph 199'), findsNothing);

      final formattedScrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey('smooth_markdown_editor_formatted_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      final position =
          tester.state<ScrollableState>(formattedScrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(_richTextContaining('Paragraph 199'), findsOneWidget);
    });

    testWidgets('maps formatted inline mark cursors back to source',
        (tester) async {
      final scenarios = <({
        String name,
        String markdown,
        String plainText,
        int formattedOffset,
        int sourceOffset,
      })>[
        (
          name: 'bold',
          markdown: 'Say **bold** now',
          plainText: 'Say bold now',
          formattedOffset: 6,
          sourceOffset: 8,
        ),
        (
          name: 'link',
          markdown: 'Open [site](https://example.com) today',
          plainText: 'Open site today',
          formattedOffset: 7,
          sourceOffset: 8,
        ),
        (
          name: 'inline code',
          markdown: 'Use `code` here',
          plainText: 'Use code here',
          formattedOffset: 6,
          sourceOffset: 7,
        ),
      ];

      for (final scenario in scenarios) {
        final controller = MarkdownEditorController(text: scenario.markdown);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            SmoothMarkdownEditor(
              key: ValueKey('formatted_to_source_${scenario.name}'),
              controller: controller,
              height: 240,
            ),
          ),
        );

        await tester.tap(
          find.byKey(
            const ValueKey('smooth_markdown_editor_formatted_block_0'),
          ),
        );
        await tester.pump();

        final activeField = tester.widget<TextField>(
          find.byKey(
            const ValueKey('smooth_markdown_editor_formatted_active_0'),
          ),
        );
        expect(activeField.controller!.text, scenario.plainText);
        activeField.controller!.selection =
            TextSelection.collapsed(offset: scenario.formattedOffset);
        await tester.pump();

        await tester.tap(find.byTooltip('Source'));
        await tester.pump();
        await tester.pump();

        final sourceField = tester.widget<TextField>(
          find.byKey(const ValueKey('smooth_markdown_editor_source')),
        );
        expect(
          sourceField.controller!.selection.extentOffset,
          scenario.sourceOffset,
          reason: scenario.name,
        );
      }
    });

    testWidgets('maps source inline mark cursors into formatted text',
        (tester) async {
      final scenarios = <({
        String name,
        String markdown,
        String plainText,
        int formattedOffset,
        int sourceOffset,
      })>[
        (
          name: 'bold',
          markdown: 'Say **bold** now',
          plainText: 'Say bold now',
          formattedOffset: 6,
          sourceOffset: 8,
        ),
        (
          name: 'link',
          markdown: 'Open [site](https://example.com) today',
          plainText: 'Open site today',
          formattedOffset: 7,
          sourceOffset: 8,
        ),
        (
          name: 'inline code',
          markdown: 'Use `code` here',
          plainText: 'Use code here',
          formattedOffset: 6,
          sourceOffset: 7,
        ),
      ];

      for (final scenario in scenarios) {
        final controller = MarkdownEditorController(text: scenario.markdown);
        controller.textController.selection =
            TextSelection.collapsed(offset: scenario.sourceOffset);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            SmoothMarkdownEditor(
              key: ValueKey('source_to_formatted_${scenario.name}'),
              controller: controller,
              initialMode: MarkdownEditorMode.source,
              height: 240,
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('smooth_markdown_editor_source')),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Formatted'));
        await tester.pump();
        await tester.pump();

        final activeField = tester.widget<TextField>(
          find.byKey(
            const ValueKey('smooth_markdown_editor_formatted_active_0'),
          ),
        );
        expect(activeField.controller!.text, scenario.plainText);
        expect(
          activeField.controller!.selection.extentOffset,
          scenario.formattedOffset,
          reason: scenario.name,
        );
      }
    });

    testWidgets('formatted mode rerenders semantic document transactions',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Body');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 240,
          ),
        ),
      );

      final blockId = _singleScratchContentBlock(controller).id;
      controller.applyBlockCommand(blockId, MarkdownEditorCommand.heading2);
      await tester.pump();

      expect(controller.text, '## Body');
      expect(_richTextContaining('Body'), findsWidgets);
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
        findsOneWidget,
      );
    });

    testWidgets('formatted edits undo and redo through toolbar',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Body');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 240,
          ),
        ),
      );

      var undoButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('smooth_markdown_editor_undo')),
      );
      var redoButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('smooth_markdown_editor_redo')),
      );
      expect(undoButton.onPressed, isNull);
      expect(redoButton.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Edited',
      );
      await tester.pump();

      expect(controller.text, 'Edited');
      undoButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('smooth_markdown_editor_undo')),
      );
      redoButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('smooth_markdown_editor_redo')),
      );
      expect(undoButton.onPressed, isNotNull);
      expect(redoButton.onPressed, isNull);

      await tester
          .tap(find.byKey(const ValueKey('smooth_markdown_editor_undo')));
      await tester.pump();

      expect(controller.text, 'Body');
      expect(
        _singleScratchContentBlock(controller).plainText,
        'Body',
      );
      var activeField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
      );
      expect(activeField.controller!.text, 'Body');

      undoButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('smooth_markdown_editor_undo')),
      );
      redoButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('smooth_markdown_editor_redo')),
      );
      expect(undoButton.onPressed, isNull);
      expect(redoButton.onPressed, isNotNull);

      await tester
          .tap(find.byKey(const ValueKey('smooth_markdown_editor_redo')));
      await tester.pump();

      expect(controller.text, 'Edited');
      expect(
        _singleScratchContentBlock(controller).plainText,
        'Edited',
      );
      activeField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
      );
      expect(activeField.controller!.text, 'Edited');
    });

    testWidgets('source edits undo and redo through toolbar', (tester) async {
      final controller = MarkdownEditorController(text: 'Body');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            initialMode: MarkdownEditorMode.source,
            height: 240,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_source')),
        'Body edited',
      );
      await tester.pump();

      expect(controller.text, 'Body edited');

      await tester
          .tap(find.byKey(const ValueKey('smooth_markdown_editor_undo')));
      await tester.pump();

      expect(controller.text, 'Body');
      var sourceField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_source')),
      );
      expect(sourceField.controller!.text, 'Body');
      expect(_singleScratchContentBlock(controller).plainText, 'Body');

      await tester
          .tap(find.byKey(const ValueKey('smooth_markdown_editor_redo')));
      await tester.pump();

      expect(controller.text, 'Body edited');
      sourceField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_source')),
      );
      expect(sourceField.controller!.text, 'Body edited');
      expect(_singleScratchContentBlock(controller).plainText, 'Body edited');
    });

    testWidgets('keyboard shortcuts trigger undo and redo', (tester) async {
      final controller = MarkdownEditorController(text: 'Shortcut body');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 240,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Shortcut edited',
      );
      await tester.pump();

      expect(controller.text, 'Shortcut edited');

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyZ);
      await tester.pump();

      expect(controller.text, 'Shortcut body');
      var activeField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
      );
      expect(activeField.controller!.text, 'Shortcut body');

      await _sendControlShortcut(
        tester,
        LogicalKeyboardKey.keyZ,
        shift: true,
      );
      await tester.pump();

      expect(controller.text, 'Shortcut edited');

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyZ);
      await tester.pump();
      await _sendControlShortcut(tester, LogicalKeyboardKey.keyY);
      await tester.pump();

      expect(controller.text, 'Shortcut edited');
      activeField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
      );
      expect(activeField.controller!.text, 'Shortcut edited');
    });

    testWidgets('capabilities hide disabled toolbar and slash commands',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Body');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 240,
            toolbarCommands: const [
              MarkdownEditorCommand.bold,
              MarkdownEditorCommand.image,
              MarkdownEditorCommand.table,
            ],
            capabilities: const MarkdownEditorCapabilities(
              disabledCommands: {
                MarkdownEditorCommand.image,
                MarkdownEditorCommand.table,
              },
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_command_bold')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_command_image')),
        findsNothing,
      );
      expect(
        find.byKey(
            const ValueKey('smooth_markdown_editor_table_picker_button')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        '/table',
      );
      await tester.pump();

      expect(find.text('Table'), findsNothing);
    });

    testWidgets('supports controlled mode and host toolbar slots',
        (tester) async {
      var mode = MarkdownEditorMode.source;
      var modeChanges = 0;

      await tester.pumpWidget(
        _wrapWithWidth(
          StatefulBuilder(
            builder: (context, setState) {
              return SmoothMarkdownEditor(
                data: 'Body',
                mode: mode,
                height: 240,
                toolbarLeading: const [
                  SizedBox(
                    key: ValueKey('host_toolbar_leading'),
                    width: 12,
                  ),
                ],
                toolbarTrailing: const [
                  SizedBox(
                    key: ValueKey('host_toolbar_trailing'),
                    width: 12,
                  ),
                ],
                onModeChanged: (nextMode) {
                  modeChanges++;
                  setState(() => mode = nextMode);
                },
              );
            },
          ),
          width: 1600,
        ),
      );

      expect(
          find.byKey(const ValueKey('host_toolbar_leading')), findsOneWidget);
      expect(find.byKey(const ValueKey('smooth_markdown_editor_source')),
          findsOneWidget);

      await tester.tap(find.byTooltip('Preview'));
      await tester.pump();

      expect(mode, MarkdownEditorMode.preview);
      expect(modeChanges, 1);
      expect(find.byKey(const ValueKey('smooth_markdown_editor_source')),
          findsNothing);

      final toolbarScrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
        description: 'horizontal editor toolbar',
      );
      for (var i = 0;
          i < 20 &&
              find
                  .byKey(const ValueKey('host_toolbar_trailing'))
                  .evaluate()
                  .isEmpty;
          i++) {
        await tester.drag(toolbarScrollable.first, const Offset(-220, 0));
        await tester.pump();
      }
      expect(
        find.byKey(const ValueKey('host_toolbar_trailing')),
        findsOneWidget,
      );
    });

    testWidgets('disabled command shortcuts are ignored', (tester) async {
      final controller = MarkdownEditorController(text: 'Bold me');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 240,
            capabilities: const MarkdownEditorCapabilities(
              disabledCommands: {MarkdownEditorCommand.bold},
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      controller.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 4,
      );
      await _sendControlShortcut(tester, LogicalKeyboardKey.keyB);
      await tester.pump();

      expect(controller.text, 'Bold me');
    });

    testWidgets('formatted code block language selector uses document model',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '```dart\nvoid main() {}\n```',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final dropdownFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_code_language_0'),
      );
      final dropdown = tester.widget<DropdownButton<String>>(dropdownFinder);
      expect(
        dropdown.items!.map((item) => item.value).toList(),
        [
          '',
          'javascript',
          'typescript',
          'python',
          'rust',
          'json',
          'sql',
          'css',
          'html',
          'bash',
          'markdown',
          'yaml',
          'go',
          'java',
          'cpp',
          'c',
          'swift',
          'ruby',
          'php',
          'diff',
          'dockerfile',
          'mermaid',
        ],
      );
      dropdown.onChanged?.call('mermaid');
      await tester.pump();

      expect(
          _singleScratchContentBlock(controller), isA<MarkdownMermaidBlock>());
      expect(controller.text, '```mermaid\nvoid main() {}\n```');
    });

    testWidgets('formatted custom block delegates preview and editing to host',
        (tester) async {
      final controller = MarkdownEditorController();
      addTearDown(controller.dispose);
      controller.document = const MarkdownDocument(
        blocks: [
          MarkdownRawBlock(
            id: 'custom',
            markdown: ':::callout\nOriginal\n:::',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            customBlockBuilder: (context, block) {
              return Column(
                key: const ValueKey('host_custom_block_preview'),
                children: [
                  Text('Host ${block.blockType}: ${block.markdown}'),
                  TextButton(
                    key: const ValueKey('host_custom_block_edit'),
                    onPressed: block.edit,
                    child: const Text('Edit custom'),
                  ),
                ],
              );
            },
            customBlockEditorBuilder: (context, block) {
              return TextButton(
                key: const ValueKey('host_custom_block_save'),
                onPressed: () => block.replaceMarkdown('## Edited'),
                child: const Text('Save custom'),
              );
            },
          ),
        ),
      );

      expect(find.byKey(const ValueKey('host_custom_block_preview')),
          findsWidgets);
      expect(find.textContaining('Host raw'), findsWidgets);

      await tester
          .tap(find.byKey(const ValueKey('host_custom_block_edit')).first);
      await tester.pump();

      expect(
          find.byKey(const ValueKey('host_custom_block_save')), findsWidgets);

      await tester
          .tap(find.byKey(const ValueKey('host_custom_block_save')).first);
      await tester.pump();

      expect(controller.text, '## Edited');
      expect(
          _singleScratchContentBlock(controller), isA<MarkdownHeadingBlock>());
    });

    testWidgets('formatted code block edits code through document model',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '```dart\nprint("old");\n```',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edit code'));
      await tester.pump();

      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      expect(activeFinder, findsOneWidget);
      expect(
        tester.widget<TextField>(activeFinder).controller!.text,
        'print("old");',
      );

      await tester.enterText(activeFinder, 'print("new");');
      await tester.pump();

      expect(_singleScratchContentBlock(controller), isA<MarkdownCodeBlock>());
      expect(controller.text, '```dart\nprint("new");\n```');
    });

    testWidgets('formatted code block keeps source selection inside code',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '```dart\nprint("old");\n```',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edit code'));
      await tester.pump();

      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      await tester.showKeyboard(activeFinder);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'print("new");',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      await tester.pump();

      expect(controller.text, '```dart\nprint("new");\n```');
      expect(
        controller.textController.selection,
        const TextSelection.collapsed(offset: 19),
      );
    });

    testWidgets('formatted code block indents code with Tab', (tester) async {
      final controller = MarkdownEditorController(
        text: '```dart\nprint("hi");\n```',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edit code'));
      await tester.pump();

      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      await tester.showKeyboard(activeFinder);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'print("hi");',
          selection: TextSelection.collapsed(offset: 0),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(controller.text, '```dart\n  print("hi");\n```');
      expect(
        tester.widget<TextField>(activeFinder).controller!.selection,
        const TextSelection.collapsed(offset: 2),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(controller.text, '```dart\nprint("hi");\n```');
      expect(
        tester.widget<TextField>(activeFinder).controller!.selection,
        const TextSelection.collapsed(offset: 0),
      );
    });

    testWidgets('formatted Mermaid block edits source through document model',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '```mermaid\ngraph TD\n  A --> B\n```',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edit code'));
      await tester.pump();

      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      expect(activeFinder, findsOneWidget);
      expect(
        tester.widget<TextField>(activeFinder).controller!.text,
        'graph TD\n  A --> B',
      );

      await tester.enterText(activeFinder, 'graph LR\n  A --> C');
      await tester.pump();

      expect(
          _singleScratchContentBlock(controller), isA<MarkdownMermaidBlock>());
      expect(controller.text, '```mermaid\ngraph LR\n  A --> C\n```');
    });

    testWidgets('formatted language selector preserves tilde for Mermaid',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '~~~dart\nvoid main() {}\n~~~',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final dropdownFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_code_language_0'),
      );
      final dropdown = tester.widget<DropdownButton<String>>(dropdownFinder);
      dropdown.onChanged?.call('mermaid');
      await tester.pump();

      expect(
          _singleScratchContentBlock(controller), isA<MarkdownMermaidBlock>());
      expect(
        (_singleScratchContentBlock(controller) as MarkdownMermaidBlock).fence,
        '~~~',
      );
      expect(controller.text, '~~~mermaid\nvoid main() {}\n~~~');

      final mermaidDropdown =
          tester.widget<DropdownButton<String>>(dropdownFinder);
      mermaidDropdown.onChanged?.call('python');
      await tester.pump();

      expect(_singleScratchContentBlock(controller), isA<MarkdownCodeBlock>());
      expect(
        (_singleScratchContentBlock(controller) as MarkdownCodeBlock).fence,
        '~~~',
      );
      expect(controller.text, '~~~python\nvoid main() {}\n~~~');
    });

    testWidgets('formatted frontmatter editor updates markdown',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '---\n'
            'title: Old\n'
            '---\n'
            '\n'
            'Body',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      expect(controller.document.blocks.first, isA<MarkdownFrontmatterBlock>());
      expect(
        find.byKey(
          const ValueKey('smooth_markdown_editor_frontmatter_block_0'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_frontmatter_source_0'),
        ),
        'title: New',
      );
      await tester.pump();

      expect(
        controller.text,
        '---\n'
        'title: New\n'
        '---\n'
        '\n'
        'Body',
      );
    });

    testWidgets('toolbar exposes Scratch heading levels', (tester) async {
      final controller = MarkdownEditorController(text: 'Heading target');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Headings'));
      await tester.pumpAndSettle();

      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('Heading 2'), findsOneWidget);
      expect(find.text('Heading 3'), findsOneWidget);
      expect(find.text('Heading 4'), findsOneWidget);
      expect(find.text('Heading 5'), findsOneWidget);
      expect(find.text('Heading 6'), findsOneWidget);
    });

    testWidgets('formatted heading shortcut uses document model',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Shortcut heading');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await _sendControlShortcut(
        tester,
        LogicalKeyboardKey.digit3,
        alt: true,
      );
      await tester.pump();

      expect(controller.text, '### Shortcut heading');
      final block =
          _singleScratchContentBlock(controller) as MarkdownHeadingBlock;
      expect(block.level, 3);
    });

    testWidgets('formatted heading shortcut supports TipTap h6 keymap',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Deep shortcut');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await _sendControlShortcut(
        tester,
        LogicalKeyboardKey.digit6,
        alt: true,
      );
      await tester.pump();

      expect(controller.text, '###### Deep shortcut');
      final block =
          _singleScratchContentBlock(controller) as MarkdownHeadingBlock;
      expect(block.level, 6);
    });

    testWidgets('formatted inline code shortcut uses document marks',
        (tester) async {
      final controller = MarkdownEditorController(text: 'mark code');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 9,
      );
      await tester.pump();

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyE);
      await tester.pump();

      expect(controller.text, 'mark `code`');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, contains(isA<MarkdownInlineCode>()));
    });

    testWidgets('formatted Scratch strikethrough shortcut uses Shift S',
        (tester) async {
      final controller = MarkdownEditorController(text: 'mark strike');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 11,
      );
      await tester.pump();

      await _sendControlShortcut(
        tester,
        LogicalKeyboardKey.keyS,
        shift: true,
      );
      await tester.pump();

      expect(controller.text, 'mark ~~strike~~');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, contains(isA<MarkdownStrikethrough>()));
    });

    testWidgets('formatted Scratch print shortcut delegates PDF export',
        (tester) async {
      final controller = MarkdownEditorController(text: '# Print me');
      addTearDown(controller.dispose);
      String? exportedMarkdown;
      String? exportedHtml;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            onExportPdf: (markdown, html) {
              exportedMarkdown = markdown;
              exportedHtml = html;
            },
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await _sendControlShortcut(
        tester,
        LogicalKeyboardKey.keyP,
        shift: true,
      );
      await tester.pump();

      expect(exportedMarkdown, '# Print me');
      expect(exportedHtml, contains('<h1>Print me</h1>'));
    });

    testWidgets('Scratch print shortcut falls back to copying HTML',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = MarkdownEditorController(text: '# Print me');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await _sendControlShortcut(
        tester,
        LogicalKeyboardKey.keyP,
        shift: true,
      );
      await tester.pump();

      expect(clipboardText, contains('<h1>Print me</h1>'));
    });

    testWidgets('plain P shortcut is left for Scratch command palette',
        (tester) async {
      final controller = MarkdownEditorController(text: '# Command palette');
      addTearDown(controller.dispose);
      var exportCount = 0;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            onExportPdf: (_, __) {
              exportCount += 1;
            },
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyP);
      await tester.pump();

      expect(exportCount, 0);
    });

    testWidgets('copy menu labels match Scratch export actions',
        (tester) async {
      final controller = MarkdownEditorController(text: '# Export me');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();

      expect(find.byTooltip('Export (Ctrl+Shift+C)'), findsOneWidget);

      await tester.tap(find.byTooltip('Export (Ctrl+Shift+C)'));
      await tester.pump();

      expect(find.text('Copy Markdown'), findsOneWidget);
      expect(find.text('Copy Plain Text'), findsOneWidget);
      expect(find.text('Copy HTML'), findsOneWidget);
      expect(find.text('Print as PDF'), findsOneWidget);
      expect(find.text('Export Markdown'), findsOneWidget);
      expect(find.text('Import Markdown'), findsNothing);
      expect(find.text('Export PDF'), findsNothing);
    });

    testWidgets('export markdown menu delegates to host callback',
        (tester) async {
      final controller = MarkdownEditorController(text: '# Export me');
      addTearDown(controller.dispose);
      String? exportedMarkdown;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            onExportMarkdown: (markdown) {
              exportedMarkdown = markdown;
            },
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await tester.tap(find.byTooltip('Export (Ctrl+Shift+C)'));
      await tester.pump();

      await tester.tap(find.text('Export Markdown'));
      await tester.pump();

      expect(exportedMarkdown, '# Export me');
    });

    testWidgets('export markdown falls back to clipboard', (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = MarkdownEditorController(text: '# Export me');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await tester.tap(find.byTooltip('Export (Ctrl+Shift+C)'));
      await tester.pump();

      await tester.tap(find.text('Export Markdown'));
      await tester.pump();

      expect(clipboardText, '# Export me');
    });

    testWidgets('import menu inserts host provided markdown', (tester) async {
      final controller = MarkdownEditorController(text: 'Intro');
      addTearDown(controller.dispose);
      var importCalls = 0;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            onImportMarkdown: () {
              importCalls += 1;
              return '# Imported\n\nBody';
            },
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await tester.tap(find.byTooltip('Export (Ctrl+Shift+C)'));
      await tester.pump();
      await tester.tap(find.text('Import Markdown'));
      await tester.pump();

      expect(importCalls, 1);
      expect(
        controller.text,
        'Intro\n\n'
        '# Imported\n\n'
        'Body',
      );
      expect(controller.document.blocks[1], isA<MarkdownHeadingBlock>());
      expect(controller.document.blocks[2].plainText, 'Body');
    });

    testWidgets('disabled editor does not run import menu callback',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Intro');
      addTearDown(controller.dispose);
      var importCalls = 0;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            enabled: false,
            height: 320,
            onImportMarkdown: () {
              importCalls += 1;
              return '# Imported';
            },
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await tester.tap(find.byTooltip('Export (Ctrl+Shift+C)'));
      await tester.pump();

      expect(find.text('Import Markdown'), findsOneWidget);

      await tester.tap(find.text('Import Markdown'));
      await tester.pump();

      expect(importCalls, 0);
      expect(controller.text, 'Intro');
    });

    testWidgets('formatted inline toolbar commands use document marks',
        (tester) async {
      final controller = MarkdownEditorController(text: 'hello world');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 11,
      );
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.format_bold);
      await tester.pump();

      expect(controller.text, 'hello **world**');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, contains(isA<MarkdownStrong>()));

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == 'hello world',
        description: 'active EditableText for hello world',
      );
      final editable = tester.widget<EditableText>(editableFinder);
      final span = editable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: editable.style,
        withComposing: false,
      );
      expect(_hasBoldSpan(span, 'world'), isTrue);

      activeField.controller!.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 11,
      );
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.link);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_link_url_input')),
        'https://example.com',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(controller.text, 'hello [**world**](https://example.com)');
      final linkedBlock =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(linkedBlock.children, contains(isA<MarkdownLink>()));

      final linkedEditable = tester.widget<EditableText>(editableFinder);
      final linkedSpan = linkedEditable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: linkedEditable.style,
        withComposing: false,
      );
      expect(_hasBoldSpan(linkedSpan, 'world'), isTrue);
      expect(_hasUnderlineSpan(linkedSpan, 'world'), isTrue);
    });

    testWidgets('formatted shift-click copies top-level document selection',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = MarkdownEditorController(text: '**Alpha**\n\nBeta');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_11')),
      );
      await tester.pump();

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(clipboardText, '**Alpha**\n\nBeta');
    });

    testWidgets('formatted drag selects top-level document blocks',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = MarkdownEditorController(text: '**Alpha**\n\nBeta');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final source = find
          .byKey(const ValueKey('smooth_markdown_editor_formatted_block_0'));
      final target = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_block_11'),
      );
      await tester.dragFrom(
        tester.getCenter(source),
        tester.getCenter(target) - tester.getCenter(source),
      );
      await tester.pump();

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(clipboardText, '**Alpha**\n\nBeta');
    });

    testWidgets('formatted drag range auto-scrolls near viewport edges',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final markdown = List.generate(
        18,
        (index) => 'Block $index',
      ).join('\n\n');
      final controller = MarkdownEditorController(text: markdown);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 180,
          ),
        ),
      );

      final source = find
          .byKey(const ValueKey('smooth_markdown_editor_formatted_block_0'));
      final start = tester.getCenter(source);
      final editorBottom = tester
          .getBottomLeft(
            find.byType(SmoothMarkdownEditor),
          )
          .dy;
      final scrollable = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        description: 'formatted vertical scrollable',
      );
      final scrollState = tester.state<ScrollableState>(scrollable.first);
      expect(scrollState.position.maxScrollExtent, greaterThan(0));

      final gesture = await tester.startGesture(start);
      await tester.pump();
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(Offset(start.dx, editorBottom - 8));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final target = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_block_160'),
      );
      expect(tester.getTopLeft(target).dy, lessThan(editorBottom));
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(scrollState.position.pixels, greaterThan(10));
      await _sendControlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(clipboardText, markdown);
    });

    testWidgets('formatted shift-click copies blockquote child selection',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller =
          MarkdownEditorController(text: '> **Alpha**\n>\n> Beta');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_blockquote_child_0_0'),
        ),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(
          const ValueKey('smooth_markdown_editor_blockquote_child_0_1'),
        ),
      );
      await tester.pump();

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(
        clipboardText,
        '> **Alpha**\n'
        '>\n'
        '> Beta',
      );
    });

    testWidgets('formatted drag selects blockquote child blocks',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller =
          MarkdownEditorController(text: '> **Alpha**\n>\n> Beta');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final source = find.byKey(
        const ValueKey('smooth_markdown_editor_blockquote_child_0_0'),
      );
      final target = find.byKey(
        const ValueKey('smooth_markdown_editor_blockquote_child_0_1'),
      );
      await tester.dragFrom(
        tester.getCenter(source),
        tester.getCenter(target) - tester.getCenter(source),
      );
      await tester.pump();

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(
        clipboardText,
        '> **Alpha**\n'
        '>\n'
        '> Beta',
      );
    });

    testWidgets('formatted document selection toolbar bolds selected blocks',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Alpha\n\nBeta');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_7')),
      );
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.format_bold);
      await tester.pump();

      expect(controller.text, '**Alpha**\n\n**Beta**');
    });

    testWidgets('formatted blockquote child selection toolbar bolds children',
        (tester) async {
      final controller = MarkdownEditorController(text: '> Alpha\n>\n> Beta');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_blockquote_child_0_0'),
        ),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(
          const ValueKey('smooth_markdown_editor_blockquote_child_0_1'),
        ),
      );
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.format_bold);
      await tester.pump();

      expect(
        controller.text,
        '> **Alpha**\n'
        '>\n'
        '> **Beta**',
      );
    });

    testWidgets('formatted document selection toolbar groups selected blocks',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Alpha\n\nBeta');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_7')),
      );
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.format_list_bulleted);
      await tester.pump();

      expect(controller.text, '- Alpha\n- Beta');
    });

    testWidgets('formatted document selection delete removes selected blocks',
        (tester) async {
      final controller =
          MarkdownEditorController(text: 'Alpha\n\nBeta\n\nGamma');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_7')),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(controller.text, 'Gamma');

      await tester
          .tap(find.byKey(const ValueKey('smooth_markdown_editor_undo')));
      await tester.pump();

      expect(controller.text, 'Alpha\n\nBeta\n\nGamma');
    });

    testWidgets('formatted document selection ignores unsupported block ranges',
        (tester) async {
      final controller = MarkdownEditorController(
        text: 'Alpha\n\n'
            '| A |\n'
            '| --- |\n'
            '| cell |\n\n'
            'Omega',
      );
      addTearDown(controller.dispose);
      final omegaStart = controller.text.indexOf('Omega');

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(
          ValueKey('smooth_markdown_editor_formatted_block_$omegaStart'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(
          ValueKey('smooth_markdown_editor_formatted_active_$omegaStart'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('toolbar reflects active inline marks like Scratch',
        (tester) async {
      final controller =
          MarkdownEditorController(text: 'Say **bold** and plain');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection =
          const TextSelection.collapsed(offset: 6);
      await tester.pump();

      final boldButtonFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_command_bold'),
      );
      var boldButton = tester.widget<IconButton>(boldButtonFinder);
      expect(boldButton.color, isNotNull);

      activeField.controller!.selection =
          const TextSelection.collapsed(offset: 15);
      await tester.pump();

      boldButton = tester.widget<IconButton>(boldButtonFinder);
      expect(boldButton.color, isNull);
    });

    testWidgets('formatted collapsed inline command stores marks for typing',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Say ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      final activeField = tester.widget<TextField>(activeFinder);
      activeField.controller!.selection =
          const TextSelection.collapsed(offset: 4);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.format_bold);
      await tester.pump();

      final boldButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('smooth_markdown_editor_command_bold')),
      );
      expect(boldButton.color, isNotNull);

      await tester.enterText(activeFinder, 'Say bold');
      await tester.pump();

      expect(controller.text, 'Say **bold**');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, contains(isA<MarkdownStrong>()));
      expect(
        controller.selection.extentOffset,
        controller.text.length,
      );
    });

    testWidgets('formatted stored marks can disable inherited marks',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Say **bold**');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      final activeField = tester.widget<TextField>(activeFinder);
      activeField.controller!.selection =
          const TextSelection.collapsed(offset: 5);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.format_bold);
      await tester.pump();

      final boldButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('smooth_markdown_editor_command_bold')),
      );
      expect(boldButton.color, isNull);

      await tester.enterText(activeFinder, 'Say bXold');
      await tester.pump();

      expect(controller.text, 'Say **b**X**old**');
    });

    testWidgets('toolbar reflects active list blocks like Scratch',
        (tester) async {
      final controller = MarkdownEditorController(text: '- item');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_list_item_0_0')),
      );
      await tester.pump();

      final listButton = tester.widget<IconButton>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_command_unorderedList'),
        ),
      );
      expect(listButton.color, isNotNull);
    });

    testWidgets('formatted link command edits and removes existing links',
        (tester) async {
      final controller =
          MarkdownEditorController(text: 'Open [site](https://old.example)');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection =
          const TextSelection.collapsed(offset: 6);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.link);
      await tester.pump();

      final urlField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_link_url_input')),
      );
      expect(urlField.controller!.text, 'https://old.example');

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_link_url_input')),
        'new.example',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(controller.text, 'Open [site](https://new.example)');

      final editedField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      editedField.controller!.selection =
          const TextSelection.collapsed(offset: 6);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.link);
      await tester.pump();
      await tester.tap(find.text('Remove link'));
      await tester.pump();

      expect(controller.text, 'Open site');
      final unlinkedBlock =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(unlinkedBlock.children, isNot(contains(isA<MarkdownLink>())));
    });

    testWidgets('formatted link command clears URL to remove existing link',
        (tester) async {
      final controller =
          MarkdownEditorController(text: 'Open [site](https://old.example)');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection =
          const TextSelection.collapsed(offset: 6);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.link);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_link_url_input')),
        '',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(controller.text, 'Open site');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, isNot(contains(isA<MarkdownLink>())));
    });

    testWidgets('formatted link command inserts a link at a collapsed cursor',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection =
          const TextSelection.collapsed(offset: 5);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.link);
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_link_text_input')),
        'Docs',
      );
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_link_url_input')),
        'docs.example',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(controller.text, 'Open [Docs](https://docs.example)');
    });

    testWidgets('formatted link dialog submits from text field with Enter',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection =
          const TextSelection.collapsed(offset: 5);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.link);
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_link_url_input')),
        'docs.example',
      );
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_link_text_input')),
        'Docs',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(find.text('Edit Link'), findsNothing);
      expect(controller.text, 'Open [Docs](https://docs.example)');
    });

    testWidgets('formatted link dialog closes with Escape without changes',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open docs');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection =
          const TextSelection(baseOffset: 5, extentOffset: 9);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.link);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_link_url_input')),
        'docs.example',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.text('Edit Link'), findsNothing);
      expect(controller.text, 'Open docs');
    });

    testWidgets(
        'formatted image command inserts edits and deletes image blocks',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Intro');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection =
          const TextSelection.collapsed(offset: 5);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.image_outlined);
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_image_url_input')),
        'assets/diagram.png',
      );
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_image_alt_input')),
        'Diagram',
      );
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_image_title_input')),
        'Initial title',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(
        controller.text,
        'Intro\n\n![Diagram](assets/diagram.png "Initial title")',
      );
      expect(controller.document.blocks, hasLength(3));
      final insertedImage = controller.document.blocks[1] as MarkdownImageBlock;
      expect(insertedImage.title, 'Initial title');
      expect(controller.document.blocks[2].plainText, '');
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_image_block_7')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is EditableText && widget.controller.text == '',
          description: 'active empty paragraph after image command',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_image_edit_7')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_image_url_input')),
        'assets/updated.png',
      );
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_image_alt_input')),
        'Updated',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(
                const ValueKey('smooth_markdown_editor_image_title_input'),
              ),
            )
            .controller!
            .text,
        'Initial title',
      );
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_image_title_input')),
        'Updated title',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(
        controller.text,
        'Intro\n\n![Updated](assets/updated.png "Updated title")',
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_image_edit_7')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_image_title_input')),
        '',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(
        controller.text,
        'Intro\n\n![Updated](assets/updated.png)',
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_image_delete_7')),
      );
      await tester.pump();

      expect(controller.text, 'Intro');
    });

    testWidgets('formatted image command fills an empty document like TipTap',
        (tester) async {
      final controller = MarkdownEditorController();
      addTearDown(controller.dispose);
      var pickerCalls = 0;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
            onPickImage: () {
              pickerCalls++;
              return const MarkdownEditorImageSelection(
                url: 'assets/empty.png',
                alt: 'Empty',
                title: 'Picked',
              );
            },
          ),
        ),
      );

      await _tapToolbarIcon(tester, Icons.image_outlined);
      await tester.pump();

      expect(pickerCalls, 1);
      expect(find.text('Edit Image'), findsNothing);
      expect(
        controller.text,
        '![Empty](assets/empty.png "Picked")',
      );
      expect(controller.document.blocks, hasLength(2));
      final image = controller.document.blocks[0] as MarkdownImageBlock;
      final after = controller.document.blocks[1] as MarkdownParagraphBlock;
      expect(image.url, 'assets/empty.png');
      expect(image.alt, 'Empty');
      expect(image.title, 'Picked');
      expect(after.plainText, '');
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_image_block_0')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is EditableText && widget.controller.text == '',
          description: 'active empty paragraph after empty image command',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted image command can use a host image picker',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Intro');
      addTearDown(controller.dispose);
      var pickerCalls = 0;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
            onPickImage: () {
              pickerCalls++;
              return const MarkdownEditorImageSelection(
                url: 'assets/local.png',
                title: 'Local asset',
              );
            },
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.image_outlined);
      await tester.pump();

      expect(pickerCalls, 1);
      expect(find.text('Edit Image'), findsNothing);
      expect(
        controller.text,
        '![Intro](assets/local.png "Local asset")',
      );
      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blocks[0], isA<MarkdownImageBlock>());
      expect(controller.document.blocks[1].plainText, '');
      expect(
        find.byWidgetPredicate(
          (widget) => widget is EditableText && widget.controller.text == '',
          description: 'active empty paragraph after replacing text image',
        ),
        findsOneWidget,
      );
    });

    testWidgets('image picker reports picking and inserted states',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Intro');
      addTearDown(controller.dispose);
      final events = <MarkdownEditorImagePickEvent>[];

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
            onPickImage: () async {
              return const MarkdownEditorImageSelection(
                url: 'assets/state.png',
                alt: 'State',
              );
            },
            onImagePickEvent: events.add,
          ),
        ),
      );

      await _tapToolbarIcon(tester, Icons.image_outlined);
      await tester.pump();

      expect(
        events.map((event) => event.status),
        [
          MarkdownEditorImagePickStatus.picking,
          MarkdownEditorImagePickStatus.inserted,
        ],
      );
      expect(events.last.selection?.url, 'assets/state.png');
      expect(controller.text, 'Intro\n\n![State](assets/state.png)');
    });

    testWidgets('image picker reports cancellation and failures',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Intro');
      addTearDown(controller.dispose);
      final events = <MarkdownEditorImagePickEvent>[];
      var fail = false;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
            onPickImage: () {
              if (fail) throw StateError('upload failed');
              return null;
            },
            onImagePickEvent: events.add,
          ),
        ),
      );

      await _tapToolbarIcon(tester, Icons.image_outlined);
      await tester.pump();

      expect(
        events.map((event) => event.status),
        [
          MarkdownEditorImagePickStatus.picking,
          MarkdownEditorImagePickStatus.cancelled,
        ],
      );

      fail = true;
      await _tapToolbarIcon(tester, Icons.image_outlined);
      await tester.pump();

      expect(events[2].status, MarkdownEditorImagePickStatus.picking);
      expect(events[3].status, MarkdownEditorImagePickStatus.failed);
      expect(events[3].error, isA<StateError>());
      expect(controller.text, 'Intro');
    });

    testWidgets('formatted image command exits a selected list item',
        (tester) async {
      final controller = MarkdownEditorController(text: '- Intro');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
            onPickImage: () {
              return const MarkdownEditorImageSelection(
                url: 'assets/list.png',
              );
            },
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_list_item_0_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.image_outlined);
      await tester.pump();

      expect(
        controller.text,
        '-\n'
        '  \n'
        '  ![Intro](assets/list.png)',
      );
      expect(_scratchContentBlocks(controller.document), hasLength(2));
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
      final list = controller.document.blocks.first as MarkdownListBlock;
      expect(list.items.single.blocks, hasLength(2));
      expect(list.items.single.blocks.first.plainText, '');
      expect(list.items.single.blocks[1], isA<MarkdownImageBlock>());
      expect(
        find.byWidgetPredicate(
          (widget) => widget is EditableText && widget.controller.text == '',
          description: 'active empty paragraph after list image command',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted full markdown image becomes a Scratch-style block',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        '![Diagram](assets/diagram(1).png "Architecture")',
      );
      await tester.pump();

      expect(
        controller.text,
        '![Diagram](assets/diagram(1).png "Architecture")',
      );
      expect(controller.document.blocks, hasLength(3));
      final before = controller.document.blocks[0] as MarkdownParagraphBlock;
      final image = controller.document.blocks[1] as MarkdownImageBlock;
      final after = controller.document.blocks[2] as MarkdownParagraphBlock;
      expect(before.plainText, '');
      expect(image.url, 'assets/diagram(1).png');
      expect(image.alt, 'Diagram');
      expect(image.title, 'Architecture');
      expect(after.plainText, '');
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_image_block_0')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is EditableText && widget.controller.text == '',
          description: 'active empty paragraph after full image input',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted paragraph image input becomes a Scratch block',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open ![Diagram](image.png)',
      );
      await tester.pump();

      expect(controller.document.blocks, hasLength(3));
      final before = controller.document.blocks[0] as MarkdownParagraphBlock;
      final image = controller.document.blocks[1] as MarkdownImageBlock;
      final after = controller.document.blocks[2] as MarkdownParagraphBlock;
      expect(before.plainText, 'Open ');
      expect(image.url, 'image.png');
      expect(image.alt, 'Diagram');
      expect(image.title, isNull);
      expect(after.plainText, '');
      expect(controller.text, 'Open \n\n![Diagram](image.png)');
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_image_block_7')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is EditableText && widget.controller.text == '',
          description: 'active empty paragraph after typed image block',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted list item markdown image becomes a nested block',
        (tester) async {
      final controller = MarkdownEditorController(text: '- placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_list_item_0_0')),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        '![Diagram](assets/list(1).png "Nested")',
      );
      await tester.pump();

      expect(
        controller.text,
        '-\n'
        '  \n'
        '  ![Diagram](assets/list(1).png "Nested")',
      );
      expect(_scratchContentBlocks(controller.document), hasLength(2));
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
      final list = controller.document.blocks.first as MarkdownListBlock;
      final image = list.items.single.blocks[1] as MarkdownImageBlock;
      expect(image.url, 'assets/list(1).png');
      expect(image.alt, 'Diagram');
      expect(image.title, 'Nested');
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_image_block_0')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_image_delete_0')),
      );
      await tester.pump();

      expect(controller.text, '-');
      final emptiedList = controller.document.blocks.first as MarkdownListBlock;
      expect(emptiedList.items.single.blocks, hasLength(1));
      expect(emptiedList.items.single.blocks.single.plainText, '');
    });

    testWidgets('formatted blockquote markdown image becomes a nested block',
        (tester) async {
      final controller = MarkdownEditorController(text: '> placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_blockquote_child_0_0'),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        '![Diagram](assets/quote(1).png "Quoted")',
      );
      await tester.pump();

      expect(
        controller.text,
        '>\n'
        '>\n'
        '> ![Diagram](assets/quote(1).png "Quoted")',
      );
      final quote = controller.document.blocks.first as MarkdownBlockquoteBlock;
      expect(_scratchContentBlocks(controller.document), hasLength(2));
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
      final image = quote.blocks[1] as MarkdownImageBlock;
      expect(image.url, 'assets/quote(1).png');
      expect(image.alt, 'Diagram');
      expect(image.title, 'Quoted');
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_image_block_0')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_image_delete_0')),
      );
      await tester.pump();

      expect(controller.text, '>');
      final emptiedQuote =
          controller.document.blocks.first as MarkdownBlockquoteBlock;
      expect(emptiedQuote.blocks, hasLength(1));
      expect(emptiedQuote.blocks.single.plainText, '');
    });

    testWidgets('formatted text edits preserve existing inline marks',
        (tester) async {
      final controller = MarkdownEditorController(text: 'hello **world**');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'hello worXld',
      );
      await tester.pump();

      expect(controller.text, 'hello **worXld**');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, contains(isA<MarkdownStrong>()));

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == 'hello worXld',
        description: 'active EditableText for edited bold text',
      );
      final editable = tester.widget<EditableText>(editableFinder);
      final span = editable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: editable.style,
        withComposing: false,
      );
      expect(_hasBoldSpan(span, 'worXld'), isTrue);
    });

    testWidgets('formatted typed inline markdown becomes semantic nodes',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open [site](https://example.com)',
      );
      await tester.pump();

      expect(controller.text, 'Open [site](https://example.com)');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, contains(isA<MarkdownLink>()));
      final link = block.children.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == 'Open site',
        description: 'active EditableText for typed semantic link',
      );
      final editable = tester.widget<EditableText>(editableFinder);
      final span = editable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: editable.style,
        withComposing: false,
      );
      expect(_hasUnderlineSpan(span, 'site'), isTrue);

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open site and [[Daily|today]]',
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open site and Daily|today with \$x^2\$',
      );
      await tester.pump();

      expect(
        controller.text,
        'Open [site](https://example.com) and [[Daily|today]] '
        'with \$x^2\$',
      );
      final richBlock =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(richBlock.children, contains(isA<MarkdownLink>()));
      expect(richBlock.children, contains(isA<MarkdownWikilink>()));
      expect(richBlock.children, contains(isA<MarkdownInlineMath>()));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText &&
              widget.controller.text == 'Open site and Daily|today with x^2',
          description: 'active EditableText for typed semantic inline nodes',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted wikilink input rule respects disabled wikilinks',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            enableWikilinks: false,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open [[Alpha Note]]',
      );
      await tester.pump();

      expect(controller.text, r'Open \[\[Alpha Note\]\]');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, isNot(contains(isA<MarkdownWikilink>())));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText &&
              widget.controller.text == 'Open [[Alpha Note]]',
          description: 'active field with disabled wikilink input rule',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted typed markdown link normalizes bare URLs',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open [site](example.com)',
      );
      await tester.pump();

      expect(controller.text, 'Open [site](https://example.com)');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      final link = block.children.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');
    });

    testWidgets('formatted typed markdown link rejects unsafe schemes',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open [bad](javascript:alert)',
      );
      await tester.pump();

      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children.whereType<MarkdownLink>(), isEmpty);
      expect(block.plainText, 'Open [bad](javascript:alert)');
      expect(controller.text, r'Open \[bad\](javascript:alert)');
    });

    testWidgets('formatted typed bare URL autolinks with Scratch protocol',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open example.com ',
      );
      await tester.pump();

      expect(
        controller.text,
        'Open [example.com](https://example.com)',
      );
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      final link = block.children.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');
      expect(link.plainText, 'example.com');
      expect(block.plainText, 'Open example.com ');
    });

    testWidgets('formatted typed wrapped bare URL autolinks like Scratch',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open (example.com) ',
      );
      await tester.pump();

      expect(
        controller.text,
        'Open ([example.com](https://example.com))',
      );
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      final link = block.children.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');
      expect(block.plainText, 'Open (example.com) ');
    });

    testWidgets('formatted typed bare email autolinks like Scratch',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open team@example.com ',
      );
      await tester.pump();

      expect(
        controller.text,
        'Open [team@example.com](mailto:team@example.com)',
      );
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      final link = block.children.whereType<MarkdownLink>().single;
      expect(link.url, 'mailto:team@example.com');
      expect(link.plainText, 'team@example.com');
    });

    testWidgets('formatted bare URL paste uses Scratch default protocol',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open site');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 9,
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open example.com',
      );
      await tester.pump();

      expect(controller.text, 'Open [site](https://example.com)');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      final link = block.children.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');
      expect(link.plainText, 'site');
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText && widget.controller.text == 'Open site',
          description: 'active EditableText after URL paste link-on-paste',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted bare URL paste at cursor inserts link like Scratch',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open example.com',
      );
      await tester.pump();

      expect(controller.text, 'Open [example.com](https://example.com)');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      final link = block.children.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');
      expect(link.plainText, 'example.com');
    });

    testWidgets('formatted bare email paste uses TipTap mailto href',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open site');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 9,
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
        'Open team@example.com',
      );
      await tester.pump();

      expect(controller.text, 'Open [site](mailto:team@example.com)');
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      final link = block.children.whereType<MarkdownLink>().single;
      expect(link.url, 'mailto:team@example.com');
      expect(link.plainText, 'site');
    });

    testWidgets('formatted typed inline markdown marks become semantic',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Say ');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeFinder = find
          .byKey(const ValueKey('smooth_markdown_editor_formatted_active_0'));
      await tester.enterText(activeFinder, 'Say **bold**');
      await tester.pump();

      expect(controller.text, 'Say **bold**');
      var block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, contains(isA<MarkdownStrong>()));

      await tester.enterText(activeFinder, 'Say bold and `code`');
      await tester.pump();

      expect(controller.text, 'Say **bold** and `code`');
      block = _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, contains(isA<MarkdownStrong>()));
      expect(block.children, contains(isA<MarkdownInlineCode>()));

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText &&
            widget.controller.text == 'Say bold and code',
        description: 'active EditableText for typed inline marks',
      );
      final editable = tester.widget<EditableText>(editableFinder);
      final span = editable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: editable.style,
        withComposing: false,
      );
      expect(_hasBoldSpan(span, 'bold'), isTrue);
    });

    testWidgets('formatted task list toggles checkbox through document model',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '- [ ] first\n- [x] second',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final list = _singleScratchContentBlock(controller) as MarkdownListBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_task_checkbox_${list.id}_0'),
        ),
      );
      await tester.pump();

      expect(controller.text, '- [x] first\n- [x] second');
      final updated =
          _singleScratchContentBlock(controller) as MarkdownListBlock;
      expect(updated.items.first.checked, isTrue);
    });

    testWidgets('formatted list item edits only item text via document model',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '- [ ] first\n- [x] second',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_list_item_0_1')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      expect(activeField.controller?.text, 'second');

      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'done',
      );
      await tester.pump();

      expect(controller.text, '- [ ] first\n- [x] done');
      final updated =
          _singleScratchContentBlock(controller) as MarkdownListBlock;
      expect(updated.items.last.plainText, 'done');
      expect(updated.items.last.checked, isTrue);
    });

    testWidgets('formatted nested list range copy preserves list markdown',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = MarkdownEditorController(
        text: '- Outer\n  - Alpha\n  - Beta\n  - Gamma',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 360,
          ),
        ),
      );

      final outer = _singleScratchContentBlock(controller) as MarkdownListBlock;
      final nested = outer.items.single.blocks.last as MarkdownListBlock;
      final nestedKeyPrefix = '0_${nested.id}';

      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_list_item_${nestedKeyPrefix}_0'),
        ),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(
          ValueKey('smooth_markdown_editor_list_item_${nestedKeyPrefix}_1'),
        ),
      );
      await tester.pump();

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(
        clipboardText,
        '- Alpha\n'
        '- Beta',
      );
    });

    testWidgets('formatted nested list drag selects item range',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = MarkdownEditorController(
        text: '- Outer\n  - Alpha\n  - Beta\n  - Gamma',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 360,
          ),
        ),
      );

      final outer = _singleScratchContentBlock(controller) as MarkdownListBlock;
      final nested = outer.items.single.blocks.last as MarkdownListBlock;
      final nestedKeyPrefix = '0_${nested.id}';
      final source = find.byKey(
        ValueKey('smooth_markdown_editor_list_item_${nestedKeyPrefix}_0'),
      );
      final target = find.byKey(
        ValueKey('smooth_markdown_editor_list_item_${nestedKeyPrefix}_1'),
      );

      await tester.dragFrom(
        tester.getCenter(source),
        tester.getCenter(target) - tester.getCenter(source),
      );
      await tester.pump();

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(
        clipboardText,
        '- Alpha\n'
        '- Beta',
      );
    });

    testWidgets('formatted nested list range toolbar bolds selected items',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '- Outer\n  - Alpha\n  - Beta\n  - Gamma',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 360,
          ),
        ),
      );

      final outer = _singleScratchContentBlock(controller) as MarkdownListBlock;
      final nested = outer.items.single.blocks.last as MarkdownListBlock;
      final nestedKeyPrefix = '0_${nested.id}';

      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_list_item_${nestedKeyPrefix}_0'),
        ),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(
          ValueKey('smooth_markdown_editor_list_item_${nestedKeyPrefix}_1'),
        ),
      );
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.format_bold);
      await tester.pump();

      expect(
        controller.text,
        '- Outer\n'
        '  - **Alpha**\n'
        '  - **Beta**\n'
        '  - Gamma',
      );
    });

    testWidgets('formatted nested list range delete removes selected items',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '- Outer\n  - Alpha\n  - Beta\n  - Gamma',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 360,
          ),
        ),
      );

      final outer = _singleScratchContentBlock(controller) as MarkdownListBlock;
      final nested = outer.items.single.blocks.last as MarkdownListBlock;
      final nestedKeyPrefix = '0_${nested.id}';

      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_list_item_${nestedKeyPrefix}_0'),
        ),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(
          ValueKey('smooth_markdown_editor_list_item_${nestedKeyPrefix}_1'),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(controller.text, '- Outer\n  - Gamma');
    });

    testWidgets('formatted Tab indents a list item and keeps it editable',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '- parent\n- child',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_list_item_0_1')),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(controller.text, '- parent\n  - child');
      final list = _singleScratchContentBlock(controller) as MarkdownListBlock;
      expect(list.items, hasLength(1));
      expect(list.items.single.blocks.last, isA<MarkdownListBlock>());

      final activeField = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == 'child',
        description: 'active nested list item field',
      );
      expect(activeField, findsOneWidget);

      await tester.enterText(activeField, 'renamed');
      await tester.pump();

      expect(controller.text, '- parent\n  - renamed');
    });

    testWidgets('formatted Shift+Tab outdents a nested list item',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '- parent\n  - child',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final list = _singleScratchContentBlock(controller) as MarkdownListBlock;
      final nested = list.items.single.blocks.last as MarkdownListBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_list_item_0_${nested.id}_0'),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(controller.text, '- parent\n- child');
      final updated =
          _singleScratchContentBlock(controller) as MarkdownListBlock;
      expect(updated.items, hasLength(2));
    });

    testWidgets('formatted shortcut and toolbar move active blocks',
        (tester) async {
      final controller = MarkdownEditorController(
        text: 'One\n\nTwo\n\nThree',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_5')),
      );
      await tester.pump();

      var activeField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_5')),
      );
      activeField.controller!.selection = const TextSelection.collapsed(
        offset: 2,
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(controller.text, 'Two\n\nOne\n\nThree');
      activeField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
      );
      expect(activeField.controller!.text, 'Two');
      expect(activeField.controller!.selection.extentOffset, 2);

      final moveUpButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('smooth_markdown_editor_move_block_up')),
      );
      final moveDownButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('smooth_markdown_editor_move_block_down')),
      );
      expect(moveUpButton.onPressed, isNull);
      expect(moveDownButton.onPressed, isNotNull);

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_move_block_down')),
      );
      await tester.pump();

      expect(controller.text, 'One\n\nTwo\n\nThree');
      activeField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_5')),
      );
      expect(activeField.controller!.text, 'Two');
      expect(activeField.controller!.selection.extentOffset, 2);
    });

    testWidgets('formatted drag handle reorders top-level blocks',
        (tester) async {
      final controller = MarkdownEditorController(
        text: 'One\n\nTwo\n\nThree',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final handle = find.byKey(
        const ValueKey('smooth_markdown_editor_drag_handle_0'),
      );
      final target = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_drop_10'),
      );
      expect(handle, findsOneWidget);
      expect(target, findsOneWidget);

      await tester.timedDragFrom(
        tester.getCenter(handle),
        tester.getCenter(target) - tester.getCenter(handle),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      expect(controller.text, 'Two\n\nThree\n\nOne');

      expect(controller.undo(), isTrue);
      await tester.pump();
      expect(controller.text, 'One\n\nTwo\n\nThree');
    });

    testWidgets('formatted Enter splits a paragraph block', (tester) async {
      final controller = MarkdownEditorController(text: 'HelloWorld');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection.collapsed(
        offset: 5,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.document.blocks, hasLength(2));
      expect(controller.text, 'Hello\n\nWorld');
      final editableFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == 'World',
        description: 'active split paragraph TextField',
      );
      expect(editableFinder, findsOneWidget);
    });

    testWidgets('formatted multiline text edits create hard breaks',
        (tester) async {
      final controller = MarkdownEditorController(text: 'FirstSecond');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'First\nSecond',
      );
      await tester.pump();

      final paragraph =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(paragraph.children[1], isA<MarkdownHardBreak>());
      expect(controller.text, 'First  \nSecond');
    });

    testWidgets('formatted Enter inserts and exits task list items',
        (tester) async {
      final controller = MarkdownEditorController(text: '- [x] second');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_list_item_0_0')),
      );
      await tester.pump();

      var activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection.collapsed(
        offset: 6,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.text, '- [x] second\n- [ ]');
      final list = _singleScratchContentBlock(controller) as MarkdownListBlock;
      expect(list.items, hasLength(2));
      expect(list.items.last.checked, isFalse);

      activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      expect(activeField.controller?.text, '');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(_scratchContentBlocks(controller.document), hasLength(2));
      expect(controller.document.blocks.first, isA<MarkdownListBlock>());
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.text, '- [x] second');
    });

    testWidgets('formatted Enter splits nested list items', (tester) async {
      final controller = MarkdownEditorController(
        text: '- parent\n  - childnext',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final list = _singleScratchContentBlock(controller) as MarkdownListBlock;
      final nested = list.items.single.blocks.last as MarkdownListBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_list_item_0_${nested.id}_0'),
        ),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection.collapsed(
        offset: 5,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.text, '- parent\n  - child\n  - next');
      expect(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.controller?.text == 'next',
          description: 'active nested split item field',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted Backspace merges paragraph blocks', (tester) async {
      final controller = MarkdownEditorController(text: 'Hello\n\nWorld');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_7')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_7'),
        ),
      );
      activeField.controller!.selection = const TextSelection.collapsed(
        offset: 0,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(controller.document.blocks, hasLength(1));
      expect(controller.text, 'HelloWorld');
      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == 'HelloWorld',
        description: 'merged paragraph TextField',
      );
      expect(editableFinder, findsOneWidget);
    });

    testWidgets('formatted Backspace merges and exits task list items',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '- [x] first\n- [ ] second',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_list_item_0_1')),
      );
      await tester.pump();

      var activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection.collapsed(
        offset: 0,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(controller.text, '- [x] firstsecond');
      final list = _singleScratchContentBlock(controller) as MarkdownListBlock;
      expect(list.items, hasLength(1));

      activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection.collapsed(
        offset: 0,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(_singleScratchContentBlock(controller),
          isA<MarkdownParagraphBlock>());
      expect(controller.text, 'firstsecond');
    });

    testWidgets('formatted Backspace merges and outdents nested list items',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '- parent\n  - child\n  - next',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final list = _singleScratchContentBlock(controller) as MarkdownListBlock;
      final nested = list.items.single.blocks.last as MarkdownListBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_list_item_0_${nested.id}_1'),
        ),
      );
      await tester.pump();

      var activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection.collapsed(
        offset: 0,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(controller.text, '- parent\n  - childnext');

      activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      activeField.controller!.selection = const TextSelection.collapsed(
        offset: 0,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(controller.text, '- parent\n- childnext');
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.controller?.text == 'childnext',
          description: 'active outdented nested item field',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted input rule converts heading prefix', (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '### ',
      );
      await tester.pump();

      final block = _singleScratchContentBlock(controller);
      expect(block, isA<MarkdownHeadingBlock>());
      expect((block as MarkdownHeadingBlock).level, 3);
      expect(controller.text, '###');

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      expect(activeField.controller?.text, '');
    });

    testWidgets('formatted heading markdown waits for composing commit',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      final activeController = await _enterComposingText(
        tester,
        activeFinder,
        '# 标题',
        composing: const TextRange(start: 2, end: 4),
      );

      expect(activeController.text, '# 标题');
      expect(_singleScratchContentBlock(controller),
          isA<MarkdownParagraphBlock>());
      expect(
          find.byKey(
              const ValueKey('smooth_markdown_editor_formatted_active_0')),
          findsOneWidget);

      activeController.value = const TextEditingValue(
        text: '# 标题',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();

      final block = _singleScratchContentBlock(controller);
      expect(block, isA<MarkdownHeadingBlock>());
      expect((block as MarkdownHeadingBlock).level, 1);
      expect(block.plainText, '标题');
      expect(controller.text, '# 标题');
    });

    testWidgets('formatted image input waits for composing commit',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      const markdown = '![alt](x.png)';
      const markdownLength = 13;
      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      final activeController = await _enterComposingText(
        tester,
        activeFinder,
        markdown,
        composing: const TextRange(start: 0, end: markdownLength),
      );

      expect(activeController.text, markdown);
      expect(_singleScratchContentBlock(controller),
          isA<MarkdownParagraphBlock>());
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_image_block_0')),
        findsNothing,
      );

      activeController.value = const TextEditingValue(
        text: markdown,
        selection: TextSelection.collapsed(offset: markdownLength),
      );
      await tester.pump();

      expect(controller.text, markdown);
      expect(controller.document.blocks, hasLength(3));
      expect(controller.document.blocks[1], isA<MarkdownImageBlock>());
      final image = controller.document.blocks[1] as MarkdownImageBlock;
      expect(image.url, 'x.png');
      expect(image.alt, 'alt');
    });

    testWidgets('formatted markdown paste waits for composing commit',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      const markdown = '# Pasted\n\n- [x] Task';
      const markdownLength = 20;
      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      final activeController = await _enterComposingText(
        tester,
        activeFinder,
        markdown,
        composing: const TextRange(start: 0, end: markdownLength),
      );

      expect(activeController.text, markdown);
      expect(_scratchContentBlocks(controller.document), hasLength(1));
      expect(_singleScratchContentBlock(controller),
          isA<MarkdownParagraphBlock>());

      activeController.value = const TextEditingValue(
        text: markdown,
        selection: TextSelection.collapsed(offset: markdownLength),
      );
      await tester.pump();

      final blocks = _scratchContentBlocks(controller.document);
      expect(blocks, hasLength(2));
      expect(blocks[0], isA<MarkdownHeadingBlock>());
      expect(blocks[1], isA<MarkdownListBlock>());
      expect(controller.text, markdown);
    });

    for (final marker in ['- ', '* ', '+ ', '  * ']) {
      testWidgets(
          'formatted input rule converts Scratch bullet marker "$marker"',
          (tester) async {
        final controller = MarkdownEditorController(text: 'placeholder');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            SmoothMarkdownEditor(
              controller: controller,
              height: 320,
            ),
          ),
        );

        await tester.tap(
          find.byKey(
              const ValueKey('smooth_markdown_editor_formatted_block_0')),
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(
            const ValueKey('smooth_markdown_editor_formatted_active_0'),
          ),
          marker,
        );
        await tester.pump();

        final block = _singleScratchContentBlock(controller);
        expect(block, isA<MarkdownListBlock>());
        final list = block as MarkdownListBlock;
        expect(list.kind, MarkdownListKind.bullet);
        expect(controller.text, '-');

        final activeField = tester.widget<TextField>(
          find.byKey(
            const ValueKey('smooth_markdown_editor_formatted_active_0'),
          ),
        );
        expect(activeField.controller?.text, '');
      });
    }

    testWidgets('formatted input rule joins continuous ordered list input',
        (tester) async {
      final controller = MarkdownEditorController()
        ..document = const MarkdownDocument(
          blocks: [
            MarkdownListBlock(
              id: 'list',
              kind: MarkdownListKind.ordered,
              items: [
                MarkdownListItem(
                  id: 'item-1',
                  blocks: [
                    MarkdownParagraphBlock(
                      id: 'item-1-p',
                      children: [MarkdownText('one')],
                    ),
                  ],
                ),
              ],
            ),
            MarkdownParagraphBlock(
              id: 'p',
              children: [MarkdownText('placeholder')],
            ),
          ],
        );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_8')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_8'),
        ),
        '2. ',
      );
      await tester.pump();

      expect(_scratchContentBlocks(controller.document), hasLength(1));
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
      final list = _singleScratchContentBlock(controller) as MarkdownListBlock;
      expect(list.kind, MarkdownListKind.ordered);
      expect(list.items, hasLength(2));
      expect(controller.text, '1. one\n2.');

      expect(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.controller?.text == '',
          description: 'active joined ordered list item field',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted input rule converts task marker inside list item',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '- ',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '[x] ',
      );
      await tester.pump();

      final block = _singleScratchContentBlock(controller);
      expect(block, isA<MarkdownListBlock>());
      final list = block as MarkdownListBlock;
      expect(list.kind, MarkdownListKind.task);
      expect(list.items.single.checked, isTrue);
      expect(controller.text, '- [x]');

      final activeField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      expect(activeField.controller?.text, '');
    });

    testWidgets('formatted input rule converts and edits a task item',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '- [x] ',
      );
      await tester.pump();

      final block = _singleScratchContentBlock(controller);
      expect(block, isA<MarkdownListBlock>());
      final list = block as MarkdownListBlock;
      expect(list.kind, MarkdownListKind.task);
      expect(list.items.single.checked, isTrue);
      expect(controller.text, '- [x]');

      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'done',
      );
      await tester.pump();

      expect(controller.text, '- [x] done');
      final updated =
          _singleScratchContentBlock(controller) as MarkdownListBlock;
      expect(updated.items.single.plainText, 'done');
    });

    for (final marker in ['> ', '  > ']) {
      testWidgets(
          'formatted input rule converts and edits a blockquote from "$marker"',
          (tester) async {
        final controller = MarkdownEditorController(text: 'placeholder');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            SmoothMarkdownEditor(
              controller: controller,
              height: 320,
            ),
          ),
        );

        await tester.tap(
          find.byKey(
              const ValueKey('smooth_markdown_editor_formatted_block_0')),
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(
            const ValueKey('smooth_markdown_editor_formatted_active_0'),
          ),
          marker,
        );
        await tester.pump();

        expect(
          _singleScratchContentBlock(controller),
          isA<MarkdownBlockquoteBlock>(),
        );
        expect(controller.text, '>');

        await tester.enterText(
          find.byKey(
            const ValueKey('smooth_markdown_editor_formatted_active_0'),
          ),
          'quote',
        );
        await tester.pump();

        expect(controller.text, '> quote');
      });
    }

    testWidgets('formatted input rule converts horizontal rule',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '---',
      );
      await tester.pump();

      expect(controller.document.blocks, hasLength(2));
      expect(
          controller.document.blocks.first, isA<MarkdownHorizontalRuleBlock>());
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.text, '---');
      expect(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.controller?.text == '',
          description: 'active paragraph after horizontal rule',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted input rule converts single-line block math',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        r'$$E = mc^2$$',
      );
      await tester.pump();

      final block =
          _singleScratchContentBlock(controller) as MarkdownBlockMathBlock;
      expect(block.latex, 'E = mc^2');
      expect(controller.text, r'$$' '\nE = mc^2\n' r'$$');
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_0')),
        findsOneWidget,
      );
      expect(find.textContaining('Unknown node type'), findsNothing);
    });

    testWidgets('formatted input rule keeps empty block math delimiter plain',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        r'$$',
      );
      await tester.pump();

      expect(_singleScratchContentBlock(controller),
          isA<MarkdownParagraphBlock>());
      expect(controller.text, r'$$');
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_0')),
        findsNothing,
      );
    });

    testWidgets('formatted input rule converts mermaid fence', (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '```mermaid ',
      );
      await tester.pump();

      expect(
          _singleScratchContentBlock(controller), isA<MarkdownMermaidBlock>());
      expect(controller.text, '```mermaid\n\n```');
      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      expect(
        activeFinder,
        findsOneWidget,
      );
      expect(tester.widget<TextField>(activeFinder).controller!.text, '');

      await tester.enterText(activeFinder, 'graph TD\n  A --> B');
      await tester.pump();

      expect(controller.text, '```mermaid\ngraph TD\n  A --> B\n```');
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_mermaid_source_0')),
        findsNothing,
      );
    });

    testWidgets('formatted input rule preserves tilde mermaid fence',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '~~~mermaid ',
      );
      await tester.pump();

      expect(
          _singleScratchContentBlock(controller), isA<MarkdownMermaidBlock>());
      expect(
        (_singleScratchContentBlock(controller) as MarkdownMermaidBlock).fence,
        '~~~',
      );
      expect(controller.text, '~~~mermaid\n\n~~~');
      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      expect(
        activeFinder,
        findsOneWidget,
      );
      expect(tester.widget<TextField>(activeFinder).controller!.text, '');

      await tester.enterText(activeFinder, 'graph LR\n  A --> C');
      await tester.pump();

      expect(controller.text, '~~~mermaid\ngraph LR\n  A --> C\n~~~');
    });

    testWidgets('formatted input rule keeps extended code fence info as text',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '```dart title=main.dart ',
      );
      await tester.pump();

      expect(_singleScratchContentBlock(controller),
          isA<MarkdownParagraphBlock>());
      expect(
        _singleScratchContentBlock(controller).plainText,
        '```dart title=main.dart ',
      );
    });

    testWidgets('formatted code block copy shows Scratch copied feedback',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller =
          MarkdownEditorController(text: '```dart\nprint("hi");\n```');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      expect(find.byTooltip('Copy code'), findsOneWidget);

      await tester.tap(find.byTooltip('Copy code'));
      await tester.pump();

      expect(clipboardText, 'print("hi");');
      expect(find.byTooltip('Copied'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();

      expect(find.byTooltip('Copy code'), findsOneWidget);
      expect(find.byTooltip('Copied'), findsNothing);
    });

    testWidgets('formatted code block copy ignores clipboard failures',
        (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard-denied');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller =
          MarkdownEditorController(text: '```dart\nprint("hi");\n```');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Copy code'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Copied'), findsNothing);
      expect(find.byTooltip('Copy code'), findsOneWidget);
    });

    testWidgets('formatted selection copy serializes inline markdown',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = MarkdownEditorController(
        text: 'Open [site](https://example.com) and **bold** text',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_active_0')),
      );
      activeField.controller!.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 18,
      );

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(clipboardText, '[site](https://example.com) and **bold**');
    });

    testWidgets(
        'formatted input rule keeps extended Mermaid fence info as text',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '```mermaid theme=dark ',
      );
      await tester.pump();

      expect(_singleScratchContentBlock(controller),
          isA<MarkdownParagraphBlock>());
      expect(
        _singleScratchContentBlock(controller).plainText,
        '```mermaid theme=dark ',
      );
    });

    testWidgets('formatted markdown paste parses semantic blocks',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder\n\nTail');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '# Pasted\n\n'
        '- [x] Task\n\n'
        '```dart\n'
        'void main() {}\n'
        '```',
      );
      await tester.pump();

      expect(controller.document.blocks[0], isA<MarkdownHeadingBlock>());
      expect(controller.document.blocks[1], isA<MarkdownListBlock>());
      expect(controller.document.blocks[2], isA<MarkdownCodeBlock>());
      expect(controller.document.blocks[3].plainText, 'Tail');
      expect(
        controller.text,
        '# Pasted\n\n'
        '- [x] Task\n\n'
        '```dart\n'
        'void main() {}\n'
        '```\n\n'
        'Tail',
      );
      expect(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        findsNothing,
      );
      expect(_richTextContaining('Pasted'), findsWidgets);
      expect(_richTextContaining('Task'), findsWidgets);
    });

    testWidgets('formatted markdown paste normalizes ragged tables',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder\n\nTail');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '| A | B |\n'
        '| --- | --- | --- |\n'
        '| 1 |\n'
        '| 2 | 3 | 4 |',
      );
      await tester.pump();

      final table = controller.document.blocks.first as MarkdownTableBlock;
      expect(table.columnCount, 2);
      expect(table.rows[0], hasLength(2));
      expect(table.rows[0][1].single.plainText, '');
      expect(table.rows[1], hasLength(2));
      expect(table.rows[1][1].single.plainText, '3');
      expect(
        controller.text,
        '| A | B |\n'
        '| --- | --- |\n'
        '| 1 |  |\n'
        '| 2 | 3 |\n\n'
        'Tail',
      );
      expect(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted markdown paste parses nested blockquote blocks',
        (tester) async {
      final controller =
          MarkdownEditorController(text: '> placeholder\n\nTail');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
          ),
        ),
      );

      await tester.tap(
        find.byKey(
            const ValueKey('smooth_markdown_editor_blockquote_child_0_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '# Pasted\n\n'
        '- [x] Task',
      );
      await tester.pump();

      final blockquote =
          controller.document.blocks.first as MarkdownBlockquoteBlock;
      expect(blockquote.blocks[0], isA<MarkdownHeadingBlock>());
      expect(blockquote.blocks[1], isA<MarkdownListBlock>());
      expect(
        controller.text,
        '> # Pasted\n'
        '>\n'
        '> - [x] Task\n\n'
        'Tail',
      );
      expect(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        findsNothing,
      );
      expect(_richTextContaining('Pasted'), findsWidgets);
      expect(_richTextContaining('Task'), findsWidgets);
    });

    testWidgets('formatted markdown paste parses nested list item blocks',
        (tester) async {
      final controller =
          MarkdownEditorController(text: '- placeholder\n- Tail');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 420,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_list_item_0_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'Pasted\n\n'
        '- [x] Task',
      );
      await tester.pump();

      final list = controller.document.blocks.first as MarkdownListBlock;
      expect(list.items.first.blocks[0], isA<MarkdownParagraphBlock>());
      expect(list.items.first.blocks[1], isA<MarkdownListBlock>());
      expect(
        controller.text,
        '- Pasted\n'
        '  - [x] Task\n'
        '- Tail',
      );
      expect(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        findsNothing,
      );
      expect(_richTextContaining('Pasted'), findsWidgets);
      expect(_richTextContaining('Task'), findsWidgets);
    });

    testWidgets('formatted single-line heading paste parses a block',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '# Pasted',
      );
      await tester.pump();

      expect(
          _singleScratchContentBlock(controller), isA<MarkdownHeadingBlock>());
      final block =
          _singleScratchContentBlock(controller) as MarkdownHeadingBlock;
      expect(block.level, 1);
      expect(block.plainText, 'Pasted');
      expect(controller.text, '# Pasted');
    });

    testWidgets('formatted block paste preserves text around the cursor',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Before after');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 360,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'Before # Pastedafter',
      );
      await tester.pump();

      expect(controller.document.blocks, hasLength(3));
      expect(controller.document.blocks[0].plainText, 'Before ');
      expect(controller.document.blocks[1], isA<MarkdownHeadingBlock>());
      expect(controller.document.blocks[2].plainText, 'after');
      expect(
        controller.text,
        'Before \n\n'
        '# Pasted\n\n'
        'after',
      );
      expect(_richTextContaining('Before'), findsWidgets);
      expect(_richTextContaining('Pasted'), findsWidgets);
      expect(_richTextContaining('after'), findsWidgets);
    });

    testWidgets('formatted single-line markdown paste parses inline nodes',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'Open [site](example.com) and **bold**',
      );
      await tester.pump();

      expect(
        controller.text,
        'Open [site](https://example.com) and **bold**',
      );
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, contains(isA<MarkdownLink>()));
      expect(block.children, contains(isA<MarkdownStrong>()));

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText &&
            widget.controller.text == 'Open site and bold',
        description: 'active field with parsed inline paste',
      );
      final editable = tester.widget<EditableText>(editableFinder);
      final span = editable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: editable.style,
        withComposing: false,
      );
      expect(_hasUnderlineSpan(span, 'site'), isTrue);
      expect(_hasBoldSpan(span, 'bold'), isTrue);
    });

    testWidgets('formatted inline markdown paste preserves surrounding text',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Open now');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'Open [site](example.com) now',
      );
      await tester.pump();

      expect(controller.document.blocks, hasLength(1));
      expect(
        controller.text,
        'Open [site](https://example.com) now',
      );
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      final link = block.children.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText &&
              widget.controller.text == 'Open site now',
          description: 'active field preserving text around inline paste',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted wikilink-only paste stays plain like Scratch',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'Open [[Alpha Note]] and text',
      );
      await tester.pump();

      expect(
        controller.text,
        r'Open \[\[Alpha Note\]\] and text',
      );
      final block =
          _singleScratchContentBlock(controller) as MarkdownParagraphBlock;
      expect(block.children, isNot(contains(isA<MarkdownWikilink>())));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText &&
              widget.controller.text == 'Open [[Alpha Note]] and text',
          description: 'active field with plain wikilink-looking paste',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted ordered-list paren paste stays plain like Scratch',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '1) not a Scratch ordered paste\n2) still text',
      );
      await tester.pump();

      expect(_singleScratchContentBlock(controller),
          isA<MarkdownParagraphBlock>());
      expect(
        controller.text,
        '1) not a Scratch ordered paste  \n'
        '2) still text',
      );
    });

    testWidgets('formatted tilde fence paste stays plain like Scratch',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '~~~dart\nvoid main() {}\n~~~',
      );
      await tester.pump();

      expect(_singleScratchContentBlock(controller),
          isA<MarkdownParagraphBlock>());
      expect(
        controller.text,
        '~~~dart  \n'
        'void main() {}  \n'
        '~~~',
      );
    });

    testWidgets('formatted table cell edits through document model',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| 1 | 2 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_1'),
        ),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_1',
          ),
        ),
      );
      expect(activeField.controller?.text, '2');

      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_1',
          ),
        ),
        'updated',
      );
      await tester.pump();

      expect(
        controller.text,
        '| A | B |\n'
        '| --- | --- |\n'
        '| 1 | updated |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updatedTable.rows.single[1].single.plainText, 'updated');
    });

    testWidgets('formatted table cell edits escape pipe characters',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| 1 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'A | B',
      );
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| A \\| B |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updatedTable.rows.single, hasLength(1));
      expect(updatedTable.rows.single.single.single.plainText, 'A | B');
    });

    testWidgets('formatted table cell Tab moves to the next cell',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| one | two |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final activeFinder = find.byKey(
        ValueKey(
          'smooth_markdown_editor_table_cell_active_${table.id}_row_0_1',
        ),
      );
      expect(activeFinder, findsOneWidget);
      final activeField = tester.widget<TextField>(activeFinder);
      expect(activeField.controller?.text, 'two');
    });

    testWidgets('formatted table cell Shift Tab moves to the previous cell',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| one | two |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_1'),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      final activeFinder = find.byKey(
        ValueKey(
          'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
        ),
      );
      expect(activeFinder, findsOneWidget);
      final activeField = tester.widget<TextField>(activeFinder);
      expect(activeField.controller?.text, 'one');
    });

    testWidgets('formatted table cell Enter moves to the next row',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| one | two |\n'
            '| three | four |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_1'),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        controller.text,
        '| A | B |\n'
        '| --- | --- |\n'
        '| one | two |\n'
        '| three | four |',
      );
      final activeFinder = find.byKey(
        ValueKey(
          'smooth_markdown_editor_table_cell_active_${table.id}_row_1_1',
        ),
      );
      expect(activeFinder, findsOneWidget);
      final activeField = tester.widget<TextField>(activeFinder);
      expect(activeField.controller?.text, 'four');
    });

    testWidgets('formatted table cell Tab at the end creates a new row',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| one | two |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_1'),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        controller.text,
        '| A | B |\n'
        '| --- | --- |\n'
        '| one | two |\n'
        '|  |  |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updatedTable.rows, hasLength(2));
      expect(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_1_0',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted table cell Enter at the end creates a new row',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| one | two |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_1'),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        controller.text,
        '| A | B |\n'
        '| --- | --- |\n'
        '| one | two |\n'
        '|  |  |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updatedTable.rows, hasLength(2));
      expect(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_1_1',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted table cell edits preserve inline marks',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| hello **world** |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'hello worXld',
      );
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| hello **worXld** |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      final cell = updatedTable.rows.single.single;
      expect(cell, contains(isA<MarkdownStrong>()));

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == 'hello worXld',
        description: 'active EditableText for edited table bold text',
      );
      final editable = tester.widget<EditableText>(editableFinder);
      final span = editable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: editable.style,
        withComposing: false,
      );
      expect(_hasBoldSpan(span, 'worXld'), isTrue);
    });

    testWidgets('formatted table cell toolbar commands use document model',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| hello world |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
      );
      activeField.controller!.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 11,
      );
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.format_bold);
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| hello **world** |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updatedTable.rows.single.single, contains(isA<MarkdownStrong>()));

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == 'hello world',
        description: 'active EditableText for bold table cell text',
      );
      final editable = tester.widget<EditableText>(editableFinder);
      final span = editable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: editable.style,
        withComposing: false,
      );
      expect(_hasBoldSpan(span, 'world'), isTrue);

      activeField.controller!.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 11,
      );
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.link);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_link_url_input')),
        'https://example.com',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| hello [**world**](https://example.com) |',
      );

      final linkedEditable = tester.widget<EditableText>(editableFinder);
      final linkedSpan = linkedEditable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: linkedEditable.style,
        withComposing: false,
      );
      expect(_hasBoldSpan(linkedSpan, 'world'), isTrue);
      expect(_hasUnderlineSpan(linkedSpan, 'world'), isTrue);

      activeField.controller!.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 11,
      );
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.link);
      await tester.pump();
      await tester.tap(find.text('Remove link'));
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| hello **world** |',
      );
      final unlinkedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      final unlinkedCell = unlinkedTable.rows.single.single;
      expect(unlinkedCell, contains(isA<MarkdownStrong>()));
      expect(unlinkedCell, isNot(contains(isA<MarkdownLink>())));
    });

    testWidgets('formatted table cell collapsed command stores marks',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| hello |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      final activeFinder = find.byKey(
        ValueKey(
          'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
        ),
      );
      final activeField = tester.widget<TextField>(activeFinder);
      activeField.controller!.selection =
          const TextSelection.collapsed(offset: 5);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.format_italic);
      await tester.pump();

      final italicButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('smooth_markdown_editor_command_italic')),
      );
      expect(italicButton.color, isNotNull);

      await tester.enterText(activeFinder, 'hellocell');
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| hello*cell* |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(
          updatedTable.rows.single.single, contains(isA<MarkdownEmphasis>()));
    });

    testWidgets('formatted table cell link clears URL to remove existing link',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| Open [site](https://old.example) |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
      );
      activeField.controller!.selection =
          const TextSelection.collapsed(offset: 6);
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.link);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_link_url_input')),
        '',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| Open site |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updatedTable.rows.single.single,
          isNot(contains(isA<MarkdownLink>())));
    });

    testWidgets('formatted table cell typed inline markdown becomes semantic',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| Open |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'Open [site](https://example.com)',
      );
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| Open [site](https://example.com) |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updatedTable.rows.single.single, contains(isA<MarkdownLink>()));
      final link =
          updatedTable.rows.single.single.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == 'Open site',
        description: 'active table cell EditableText for typed semantic link',
      );
      final editable = tester.widget<EditableText>(editableFinder);
      final span = editable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: editable.style,
        withComposing: false,
      );
      expect(_hasUnderlineSpan(span, 'site'), isTrue);

      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'Open site and [[Daily|today]]',
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'Open site and Daily|today with \$x^2\$',
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'Open site and Daily|today with x^2 and ![diagram](image.png)',
      );
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| Open [site](https://example.com) and [[Daily\\|today]] '
        'with \$x^2\$ and ![diagram](image.png) |',
      );
      final richTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      final richCell = richTable.rows.single.single;
      expect(richCell, contains(isA<MarkdownLink>()));
      expect(richCell, contains(isA<MarkdownWikilink>()));
      expect(richCell, contains(isA<MarkdownInlineMath>()));
      expect(richCell, contains(isA<MarkdownImage>()));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText &&
              widget.controller.text ==
                  'Open site and Daily|today with x^2 and diagram',
          description:
              'active table cell EditableText for typed semantic inline nodes',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'formatted table cell selection copy serializes inline markdown',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| Open [site](https://example.com) and **bold** text |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
      );
      activeField.controller!.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 18,
      );

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(clipboardText, '[site](https://example.com) and **bold**');
    });

    testWidgets('formatted table shift click selects a rectangular cell range',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B | C |\n'
            '| --- | --- | --- |\n'
            '| 1 | 2 | 3 |\n'
            '| 4 | 5 | 6 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      await _shiftTap(
        tester,
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_1_1'),
        ),
      );
      await tester.pump();

      for (final key in [
        'smooth_markdown_editor_table_cell_selected_${table.id}_row_0_0',
        'smooth_markdown_editor_table_cell_selected_${table.id}_row_0_1',
        'smooth_markdown_editor_table_cell_selected_${table.id}_row_1_0',
        'smooth_markdown_editor_table_cell_selected_${table.id}_row_1_1',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      expect(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_selected_${table.id}_row_0_2',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'formatted table long-press drag selects a rectangular cell range',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B | C |\n'
            '| --- | --- | --- |\n'
            '| 1 | 2 | 3 |\n'
            '| 4 | 5 | 6 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      final source = find.byKey(
        ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
      );
      final target = find.byKey(
        ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_1_1'),
      );

      final gesture = await tester.startGesture(tester.getCenter(source));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      for (final key in [
        'smooth_markdown_editor_table_cell_selected_${table.id}_row_0_0',
        'smooth_markdown_editor_table_cell_selected_${table.id}_row_0_1',
        'smooth_markdown_editor_table_cell_selected_${table.id}_row_1_0',
        'smooth_markdown_editor_table_cell_selected_${table.id}_row_1_1',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      expect(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_selected_${table.id}_row_0_2',
          ),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'formatted table range copy serializes TSV with inline markdown',
        (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = MarkdownEditorController(
        text: '| A | B | C |\n'
            '| --- | --- | --- |\n'
            '| 1 | **2** | 3 |\n'
            '| 4 | 5 | 6 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_1'),
        ),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_1_2'),
        ),
      );
      await tester.pump();

      await _sendControlShortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(clipboardText, '**2**\t3\n5\t6');
    });

    testWidgets('formatted table range delete clears selected cells',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B | C |\n'
            '| --- | --- | --- |\n'
            '| 1 | 2 | 3 |\n'
            '| 4 | 5 | 6 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_1_1'),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      final updated =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(
        updated.rows[0][0].map((node) => node.plainText).join(),
        isEmpty,
      );
      expect(
        updated.rows[0][1].map((node) => node.plainText).join(),
        isEmpty,
      );
      expect(updated.rows[0][2].map((node) => node.plainText).join(), '3');
      expect(
        updated.rows[1][0].map((node) => node.plainText).join(),
        isEmpty,
      );
      expect(
        updated.rows[1][1].map((node) => node.plainText).join(),
        isEmpty,
      );
      expect(updated.rows[1][2].map((node) => node.plainText).join(), '6');
      expect(updated.headers.map((cell) => cell.single.plainText),
          ['A', 'B', 'C']);
    });

    testWidgets('formatted table range toolbar command bolds selected cells',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B | C |\n'
            '| --- | --- | --- |\n'
            '| 1 | 2 | 3 |\n'
            '| 4 | 5 | 6 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_1_1'),
        ),
      );
      await tester.pump();

      await _tapToolbarIcon(tester, Icons.format_bold);
      await tester.pump();

      final updated =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updated.rows[0][0], contains(isA<MarkdownStrong>()));
      expect(updated.rows[0][1], contains(isA<MarkdownStrong>()));
      expect(updated.rows[0][2], isNot(contains(isA<MarkdownStrong>())));
      expect(updated.rows[1][0], contains(isA<MarkdownStrong>()));
      expect(updated.rows[1][1], contains(isA<MarkdownStrong>()));
      expect(updated.rows[1][2], isNot(contains(isA<MarkdownStrong>())));
    });

    testWidgets('formatted table normal tap clears range selection',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B | C |\n'
            '| --- | --- | --- |\n'
            '| 1 | 2 | 3 |\n'
            '| 4 | 5 | 6 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();
      await _shiftTap(
        tester,
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_1_1'),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_selected_${table.id}_row_0_0',
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_2'),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_selected_${table.id}_row_0_0',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_2',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted table cell single-line markdown paste parses inline',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| placeholder |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'Open [site](example.com) and **bold**',
      );
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| Open [site](https://example.com) and **bold** |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      final children = updatedTable.rows.single.single;
      expect(children, contains(isA<MarkdownLink>()));
      expect(children, contains(isA<MarkdownStrong>()));

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText &&
            widget.controller.text == 'Open site and bold',
        description: 'active table cell with parsed inline paste',
      );
      final editable = tester.widget<EditableText>(editableFinder);
      final span = editable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: editable.style,
        withComposing: false,
      );
      expect(_hasUnderlineSpan(span, 'site'), isTrue);
      expect(_hasBoldSpan(span, 'bold'), isTrue);
    });

    testWidgets('formatted table cell wikilink-only paste stays plain',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| placeholder |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'Open [[Alpha Note]] and text',
      );
      await tester.pump();

      expect(
        controller.text,
        r'| A |'
        '\n'
        r'| --- |'
        '\n'
        r'| Open \[\[Alpha Note\]\] and text |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(
        updatedTable.rows.single.single,
        isNot(contains(isA<MarkdownWikilink>())),
      );
    });

    testWidgets('formatted table cell markdown link normalizes bare URLs',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| Open |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'Open [site](example.com)',
      );
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| Open [site](https://example.com) |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      final link =
          updatedTable.rows.single.single.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');
    });

    testWidgets('formatted table cell markdown link rejects unsafe schemes',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| Open |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'Open [bad](javascript:alert)',
      );
      await tester.pump();

      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      final cell = updatedTable.rows.single.single;
      expect(cell.whereType<MarkdownLink>(), isEmpty);
      expect(
        cell.map((node) => node.plainText).join(),
        'Open [bad](javascript:alert)',
      );
      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        r'| Open \[bad\](javascript:alert) |',
      );
    });

    testWidgets(
        'formatted table cell typed bare URL autolinks with Scratch protocol',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| Open |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'Open example.com ',
      );
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| Open [example.com](https://example.com)  |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      final link =
          updatedTable.rows.single.single.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');
      expect(link.plainText, 'example.com');
    });

    testWidgets(
        'formatted table cell bare URL paste uses Scratch default protocol',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| Open site |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      final activeField = tester.widget<TextField>(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
      );
      activeField.controller!.selection = const TextSelection(
        baseOffset: 5,
        extentOffset: 9,
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'Open example.com',
      );
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| Open [site](https://example.com) |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      final link =
          updatedTable.rows.single.single.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');
      expect(link.plainText, 'site');
    });

    testWidgets('formatted table cell bare URL paste at cursor inserts link',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| Open |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
          ),
        ),
        'Open example.com',
      );
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| Open [example.com](https://example.com) |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      final link =
          updatedTable.rows.single.single.whereType<MarkdownLink>().single;
      expect(link.url, 'https://example.com');
      expect(link.plainText, 'example.com');
    });

    testWidgets('formatted table cell typed markdown marks become semantic',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A |\n'
            '| --- |\n'
            '| Say |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      final activeFinder = find.byKey(
        ValueKey(
          'smooth_markdown_editor_table_cell_active_${table.id}_row_0_0',
        ),
      );
      await tester.enterText(activeFinder, 'Say **bold**');
      await tester.pump();

      expect(
        controller.text,
        '| A |\n'
        '| --- |\n'
        '| Say **bold** |',
      );
      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updatedTable.rows.single.single, contains(isA<MarkdownStrong>()));

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == 'Say bold',
        description: 'active table cell EditableText for typed inline mark',
      );
      final editable = tester.widget<EditableText>(editableFinder);
      final span = editable.controller.buildTextSpan(
        context: tester.element(editableFinder),
        style: editable.style,
        withComposing: false,
      );
      expect(_hasBoldSpan(span, 'bold'), isTrue);
    });

    testWidgets('toolbar table picker inserts selected dimensions',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Intro');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      await tester.drag(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is ListView &&
                  widget.scrollDirection == Axis.horizontal,
              description: 'horizontal toolbar list',
            )
            .first,
        const Offset(-720, 0),
      );
      await tester.pump();

      final pickerButton = find
          .byKey(const ValueKey('smooth_markdown_editor_table_picker_button'));
      await tester.ensureVisible(pickerButton);
      await tester.pump();
      await tester.tap(pickerButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_table_picker')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_table_picker_cell_4_2'),
        ),
      );
      await tester.pumpAndSettle();

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(table.columnCount, 2);
      expect(table.rows, hasLength(3));
      expect(
        controller.text,
        '| Column | Column |\n'
        '| --- | --- |\n'
        '| Cell | Cell |\n'
        '| Cell | Cell |\n'
        '| Cell | Cell |',
      );
    });

    testWidgets('formatted table context menu follows Scratch column rules',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| 1 | 2 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Column Before'), findsNothing);
      expect(find.text('Add Column After'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_1'),
        ),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Column Before'), findsOneWidget);
      await tester.tap(find.text('Add Column Before'));
      await tester.pumpAndSettle();

      expect(
        controller.text,
        '| A |  | B |\n'
        '| --- | --- | --- |\n'
        '| 1 |  | 2 |',
      );
    });

    testWidgets('formatted table context menu aligns columns', (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| 1 | 2 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_1'),
        ),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Align Center'));
      await tester.pumpAndSettle();

      expect(
        controller.text,
        '| A | B |\n'
        '| --- | :---: |\n'
        '| 1 | 2 |',
      );
      var updated =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updated.alignments, [null, MarkdownTableAlignment.center]);

      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_1'),
        ),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Default Alignment'));
      await tester.pumpAndSettle();

      expect(
        controller.text,
        '| A | B |\n'
        '| --- | --- |\n'
        '| 1 | 2 |',
      );
      updated = _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updated.alignments, [null, null]);
    });

    testWidgets('formatted table context menu follows Scratch row rules',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| 1 | 2 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_header_0'),
        ),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Row Above'), findsNothing);
      expect(find.text('Add Row Below'), findsOneWidget);

      await tester.tap(find.text('Add Row Below'));
      await tester.pumpAndSettle();

      expect(
        controller.text,
        '| A | B |\n'
        '| --- | --- |\n'
        '|  |  |\n'
        '| 1 | 2 |',
      );
    });

    testWidgets('formatted table context menu can delete the header row',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| 1 | 2 |\n'
            '| 3 | 4 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_header_0'),
        ),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Row'));
      await tester.pumpAndSettle();

      expect(
        controller.text,
        '| 1 | 2 |\n'
        '| --- | --- |\n'
        '| 3 | 4 |',
      );
    });

    testWidgets('formatted table toolbar inserts row and column',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| 1 | 2 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_table_add_column_0'),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_table_add_row_0'),
        ),
      );
      await tester.pump();

      final updatedTable =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(updatedTable.columnCount, 3);
      expect(updatedTable.rows, hasLength(2));
      expect(
        controller.text,
        '| A |  | B |\n'
        '| --- | --- | --- |\n'
        '| 1 |  | 2 |\n'
        '|  |  |  |',
      );
    });

    testWidgets('formatted table toolbar and body scroll on narrow viewports',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B | C | D |\n'
            '| --- | --- | --- | --- |\n'
            '| 1 | 2 | 3 | 4 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapWithWidth(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
          width: 320,
        ),
      );

      expect(tester.takeException(), isNull);

      final toolbarScroll = find.byKey(
        const ValueKey('smooth_markdown_editor_table_toolbar_scroll_0'),
      );
      final bodyScroll = find.byKey(
        const ValueKey('smooth_markdown_editor_table_body_scroll_0'),
      );

      expect(toolbarScroll, findsOneWidget);
      expect(bodyScroll, findsOneWidget);

      final bodyScrollable = find.descendant(
        of: bodyScroll,
        matching: find.byType(Scrollable),
      );
      final bodyPosition =
          tester.state<ScrollableState>(bodyScrollable).position;
      expect(bodyPosition.pixels, 0);

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      final firstCell = find.byKey(
        ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
      );
      await tester.drag(firstCell, const Offset(-160, 0));
      await tester.pump();

      expect(bodyPosition.pixels, greaterThan(0));
      expect(
        find.byKey(
          ValueKey(
            'smooth_markdown_editor_table_cell_selected_${table.id}_row_0_0',
          ),
        ),
        findsNothing,
      );

      await tester.drag(toolbarScroll, const Offset(-240, 0));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('formatted table toolbar toggles header row and column',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | --- |\n'
            '| 1 | 2 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      var table = _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(table.headerRow, isTrue);
      expect(table.headerColumn, isFalse);

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_table_toggle_header_row_0'),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_table_toggle_header_column_0'),
        ),
      );
      await tester.pump();

      table = _singleScratchContentBlock(controller) as MarkdownTableBlock;
      expect(table.headerRow, isFalse);
      expect(table.headerColumn, isTrue);
      expect(
        controller.text,
        '| A | B |\n'
        '| --- | --- |\n'
        '| 1 | 2 |',
      );
    });

    testWidgets('formatted table toolbar inserts before active cell',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '| A | B |\n'
            '| --- | ---: |\n'
            '| 1 | 2 |',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table =
          _singleScratchContentBlock(controller) as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_1'),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_table_add_column_before_0'),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_table_add_row_above_0'),
        ),
      );
      await tester.pump();

      expect(
        controller.text,
        '| A |  | B |\n'
        '| --- | --- | ---: |\n'
        '|  |  |  |\n'
        '| 1 |  | 2 |',
      );
    });

    testWidgets('formatted table toolbar deletes the table block',
        (tester) async {
      final controller = MarkdownEditorController(
        text: 'Before\n\n'
            '| A |\n'
            '| --- |\n'
            '| 1 |\n\n'
            'After',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final table = controller.document.blocks[1] as MarkdownTableBlock;
      await tester.tap(
        find.byKey(
          ValueKey('smooth_markdown_editor_table_cell_${table.id}_row_0_0'),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_table_delete_8')),
      );
      await tester.pump();

      expect(controller.text, 'Before\n\nAfter');
      expect(controller.document.blocks, hasLength(2));
      expect(controller.document.blockById(table.id), isNull);
    });

    testWidgets('renders source and preview in split mode', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothMarkdownEditor(
            data: '# Title\n\nBody',
            initialMode: MarkdownEditorMode.split,
            height: 320,
          ),
        ),
      );

      expect(find.byKey(const ValueKey('smooth_markdown_editor_source')),
          findsOneWidget);
      expect(_richTextContaining('Title'), findsWidgets);
      expect(_richTextContaining('Body'), findsWidgets);
    });

    testWidgets('split mode updates preview from source edits', (tester) async {
      final controller = MarkdownEditorController(text: '# Title\n\nBody');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            initialMode: MarkdownEditorMode.split,
            height: 320,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_source')),
        '# Updated\n\nNext body',
      );
      await tester.pump();

      expect(controller.text, '# Updated\n\nNext body');
      expect(_richTextContaining('Updated'), findsWidgets);
      expect(_richTextContaining('Next body'), findsWidgets);
    });

    testWidgets('formatted to source anchors stale cursor to visible block',
        (tester) async {
      final controller = MarkdownEditorController(text: '# Title\n\nBody');
      addTearDown(controller.dispose);
      controller.textController.selection =
          TextSelection.collapsed(offset: controller.text.length);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Source'));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_source')),
        findsOneWidget,
      );
      expect(controller.selection.extentOffset, 0);
    });

    testWidgets('source mode returns to formatted block at the source cursor',
        (tester) async {
      final controller = MarkdownEditorController(text: 'Alpha\n\nBeta target');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            initialMode: MarkdownEditorMode.source,
            height: 320,
          ),
        ),
      );

      controller.textController.selection =
          const TextSelection.collapsed(offset: 10);
      await tester.pump();
      await tester.tap(find.byTooltip('Formatted'));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_7'),
        ),
        findsOneWidget,
      );

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == 'Beta target',
        description: 'active Beta target field',
      );
      expect(editableFinder, findsOneWidget);
      final editable = tester.widget<EditableText>(editableFinder);
      expect(editable.controller.selection.extentOffset, 3);
    });

    testWidgets('source mode returns to a lazily built formatted block',
        (tester) async {
      final markdown = List.generate(
        120,
        (index) => 'Paragraph ${index.toString().padLeft(3, '0')}',
      ).join('\n\n');
      final controller = MarkdownEditorController(text: markdown);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            initialMode: MarkdownEditorMode.source,
            height: 240,
          ),
        ),
      );

      controller.textController.selection =
          TextSelection.collapsed(offset: controller.text.length);
      final sourceScrollable = find.descendant(
        of: find.byKey(const ValueKey('smooth_markdown_editor_source')),
        matching: find.byType(Scrollable),
      );
      final sourcePosition =
          tester.state<ScrollableState>(sourceScrollable).position;
      sourcePosition.jumpTo(sourcePosition.maxScrollExtent);
      await tester.pump();

      await tester.tap(find.byTooltip('Formatted'));
      await tester.pumpAndSettle();

      final formattedScrollable = find
          .descendant(
            of: find.byKey(
              const ValueKey('smooth_markdown_editor_formatted_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      final formattedPosition =
          tester.state<ScrollableState>(formattedScrollable).position;
      final tailEditableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == 'Paragraph 119',
        description: 'active lazily built tail paragraph',
      );

      expect(formattedPosition.pixels, greaterThan(0));
      expect(tailEditableFinder, findsOneWidget);
    });

    testWidgets('source mode returns to formatted nested list item',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '- one\n  - nested\n- two',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            initialMode: MarkdownEditorMode.source,
            height: 320,
          ),
        ),
      );

      final nestedCursor = controller.text.indexOf('nested') + 2;
      controller.textController.selection =
          TextSelection.collapsed(offset: nestedCursor);
      await tester.pump();
      await tester.tap(find.byTooltip('Formatted'));
      await tester.pump();
      await tester.pump();

      final editableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText && widget.controller.text == 'nested',
        description: 'active nested list item field',
      );
      expect(editableFinder, findsOneWidget);
      final editable = tester.widget<EditableText>(editableFinder);
      expect(editable.controller.selection.extentOffset, 2);
    });

    testWidgets('find opens the matching block in formatted mode',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothMarkdownEditor(
            data: 'Alpha\n\nBeta target',
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'target');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_7'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('find highlights rendered matches', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothMarkdownEditor(
            data: 'Alpha target',
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'target');
      await tester.pump();

      expect(find.text('1/1'), findsOneWidget);
      expect(_highlightedRichTextContaining('target'), findsOneWidget);
    });

    testWidgets('formatted find ignores hidden markdown source text',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothMarkdownEditor(
            data: 'Open [site](https://target.example)\n\nVisible target',
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'target');
      await tester.pump();

      expect(find.text('1/1'), findsOneWidget);
      expect(_highlightedRichTextContaining('target'), findsOneWidget);
    });

    testWidgets('formatted find skips non-highlightable block bodies',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothMarkdownEditor(
            data: '```dart\n'
                'hidden target\n'
                '```\n\n'
                '```mermaid\n'
                'graph target\n'
                '```\n\n'
                r'$$'
                '\n'
                'target\n'
                r'$$'
                '\n\n'
                'Visible target',
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'target');
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_scroll')),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();

      expect(find.text('1/1'), findsOneWidget);
      expect(_richTextContaining('Visible target'), findsOneWidget);
    });

    testWidgets('formatted find maps after plugin blocks with blank lines',
        (tester) async {
      final plugins = ParserPluginRegistry()
        ..register(const AdmonitionPlugin());

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            data: '::: note Heads up\n'
                'line 1\n'
                '\n'
                'line 2\n'
                ':::\n\n'
                'After target',
            plugins: plugins,
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'target');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText &&
              widget.controller.text == 'After target' &&
              widget.controller.selection.textInside(widget.controller.text) ==
                  'target',
          description: 'active paragraph after plugin block search match',
        ),
        findsOneWidget,
      );
    });

    testWidgets('source find still searches raw markdown source',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothMarkdownEditor(
            data: 'Open [site](https://target.example)\n\nVisible target',
            initialMode: MarkdownEditorMode.source,
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'target');
      await tester.pump();

      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('formatted find opens nested list item matches',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothMarkdownEditor(
            data: '- Alpha\n- Beta target',
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'target');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is EditableText &&
              widget.controller.text == 'Beta target' &&
              widget.controller.selection.textInside(widget.controller.text) ==
                  'target',
          description: 'active list item search match',
        ),
        findsOneWidget,
      );
    });

    testWidgets('find navigates next and previous matches', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothMarkdownEditor(
            data: 'target one\n\ntarget two',
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'target');
      await tester.pump();

      expect(find.text('1/2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();
      expect(find.text('2/2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pump();
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('find supports Scratch keyboard navigation', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothMarkdownEditor(
            data: 'target one\n\ntarget two',
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'target');
      await tester.pump();

      expect(find.text('1/2'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('2/2'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('find closes with Escape like Scratch', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothMarkdownEditor(
            data: 'Alpha target',
            height: 320,
          ),
        ),
      );

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.search);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'target');
      await tester.pump();

      expect(find.byTooltip('Close find'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byTooltip('Close find'), findsNothing);
      expect(find.text('1/1'), findsNothing);
    });

    testWidgets('formatted code block language selector updates markdown',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '```dart\nvoid main() {}\n```',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final dropdownFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_code_language_0'),
      );
      expect(dropdownFinder, findsOneWidget);

      final dropdown = tester.widget<DropdownButton<String>>(dropdownFinder);
      dropdown.onChanged?.call('python');
      await tester.pump();

      expect(controller.text, '```python\nvoid main() {}\n```');
    });

    testWidgets('formatted code block language selector reads code info token',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '```dart title=main.dart\nvoid main() {}\n```',
      );
      addTearDown(controller.dispose);

      expect(_singleScratchContentBlock(controller), isA<MarkdownCodeBlock>());
      expect(
        (_singleScratchContentBlock(controller) as MarkdownCodeBlock).info,
        'dart title=main.dart',
      );

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final dropdownFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_code_language_0'),
      );
      expect(dropdownFinder, findsOneWidget);
      final dropdown = tester.widget<DropdownButton<String>>(dropdownFinder);
      expect(dropdown.value, '');
      expect(controller.text, '```dart title=main.dart\nvoid main() {}\n```');
    });

    testWidgets('formatted code block language selector preserves tilde fence',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '~~~dart\nvoid main() {}\n~~~',
      );
      addTearDown(controller.dispose);

      expect(_singleScratchContentBlock(controller), isA<MarkdownCodeBlock>());
      expect(
        (_singleScratchContentBlock(controller) as MarkdownCodeBlock).fence,
        '~~~',
      );

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final dropdownFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_code_language_0'),
      );
      expect(dropdownFinder, findsOneWidget);

      final dropdown = tester.widget<DropdownButton<String>>(dropdownFinder);
      dropdown.onChanged?.call('python');
      await tester.pump();

      expect(controller.text, '~~~python\nvoid main() {}\n~~~');
    });

    testWidgets('formatted mermaid block previews and toggles source',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '```mermaid\ngraph TD\n  A --> B\n```',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 360,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MermaidDiagram), findsOneWidget);
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_mermaid_source_0')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_mermaid_toggle_0')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_mermaid_source_0')),
        findsOneWidget,
      );
      expect(find.textContaining('graph TD'), findsOneWidget);
    });

    testWidgets('formatted block math editor updates latex', (tester) async {
      final controller = MarkdownEditorController(
        text: r'$$' '\nE = mc^2\n' r'$$',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_0')),
        findsOneWidget,
      );
      expect(find.textContaining('Unknown node type'), findsNothing);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_input')),
        r'a^2 + b^2 = c^2',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(controller.text, r'$$' '\na^2 + b^2 = c^2\n' r'$$');
    });

    testWidgets('formatted block math defaults to dark theme colors',
        (tester) async {
      final controller = MarkdownEditorController(
        text: r'$$' '\nE = mc^2\n' r'$$',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrapDark(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final math = tester.widget<Math>(find.byType(Math));
      final color = math.options?.color;

      expect(color, isNotNull);
      expect(color!.computeLuminance(), greaterThan(0.5));
    });

    testWidgets('formatted block math editor submits with Control Enter',
        (tester) async {
      final controller = MarkdownEditorController(
        text: r'$$' '\nE = mc^2\n' r'$$',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_input')),
      );
      expect(
        input.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 8),
      );

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_input')),
        r'a^2 + b^2 = c^2',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('Edit Block Math'), findsNothing);
      expect(controller.text, r'$$' '\na^2 + b^2 = c^2\n' r'$$');
    });

    testWidgets('formatted block math opens editor with keyboard',
        (tester) async {
      final controller = MarkdownEditorController(
        text: r'$$' '\nE = mc^2\n' r'$$',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      final blockFinder =
          find.byKey(const ValueKey('smooth_markdown_editor_block_math_0'));
      expect(blockFinder, findsOneWidget);
      final blockInkWellFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_block_math_action_0'),
      );
      expect(blockInkWellFinder, findsOneWidget);

      Focus.of(tester.element(blockInkWellFinder)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Edit Block Math'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      Focus.of(tester.element(blockInkWellFinder)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(find.text('Edit Block Math'), findsOneWidget);
    });

    testWidgets('formatted block math opens editor from block tap',
        (tester) async {
      final controller = MarkdownEditorController(
        text: r'$$' '\nE = mc^2\n' r'$$',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_block_math_action_0'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Block Math'), findsOneWidget);
    });

    testWidgets('formatted block math editor closes with Escape unchanged',
        (tester) async {
      final controller = MarkdownEditorController(
        text: r'$$' '\nE = mc^2\n' r'$$',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_input')),
        r'a^2 + b^2 = c^2',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Edit Block Math'), findsNothing);
      expect(controller.text, r'$$' '\nE = mc^2\n' r'$$');
    });

    testWidgets('formatted block math command waits for dialog submit',
        (tester) async {
      final controller = MarkdownEditorController(text: 'latex source');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      final textField = tester.widget<TextField>(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
      );
      textField.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 12,
      );
      await tester.pump();
      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.functions);
      await tester.pumpAndSettle();

      expect(find.text('Edit Block Math'), findsOneWidget);
      expect(controller.text, 'latex source');

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_input')),
        r'a^2 + b^2 = c^2',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(controller.text, r'$$' '\na^2 + b^2 = c^2\n' r'$$');
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_0')),
        findsOneWidget,
      );
    });

    testWidgets('formatted block math command cancel keeps text',
        (tester) async {
      final controller = MarkdownEditorController(text: 'keep me');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.functions);
      await tester.pumpAndSettle();

      expect(find.text('Edit Block Math'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.text, 'keep me');
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_0')),
        findsNothing,
      );
    });

    testWidgets('formatted slash block math cancel avoids default formula',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/math',
      );
      await tester.pump();

      expect(find.text('Block Math'), findsOneWidget);

      await tester.tap(find.text('Block Math'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.text, isNot(contains('E = mc^2')));
      expect(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_0')),
        findsNothing,
      );
    });

    testWidgets('formatted block math command exits a nested list after submit',
        (tester) async {
      final controller = MarkdownEditorController(text: '- latex\n\nTail');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 360,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_list_item_0_0')),
      );
      await tester.pump();

      final activeFieldFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      final activeField = tester.widget<TextField>(activeFieldFinder);
      activeField.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pump();

      await tester.drag(find.byType(ListView).first, const Offset(-700, 0));
      await tester.pump();
      await _tapToolbarIcon(tester, Icons.functions);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_block_math_input')),
        r'x^2',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(controller.document.blocks, hasLength(3));
      final list = controller.document.blocks[0] as MarkdownListBlock;
      expect(list.items.single.blocks[0], isA<MarkdownBlockMathBlock>());
      expect(list.items.single.blocks[1], isA<MarkdownParagraphBlock>());
      expect(list.items.single.blocks[1].plainText, '');
      expect(controller.document.blocks[1], isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks[1].plainText, '');
      expect(controller.document.blocks[2].plainText, 'Tail');
      expect(controller.text, contains(r'$$'));
      expect(controller.text, contains('x^2'));
    });

    testWidgets('focus mode hides the toolbar', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SmoothMarkdownEditor(
            data: 'Focused',
            initialFocusMode: true,
            height: 240,
          ),
        ),
      );

      expect(find.byIcon(Icons.format_bold), findsNothing);
      expect(_richTextContaining('Focused'), findsWidgets);
    });

    testWidgets('source mode keeps slash commands as raw Markdown text',
        (tester) async {
      final controller = MarkdownEditorController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            initialMode: MarkdownEditorMode.source,
            height: 240,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_source')),
        '/hea',
      );
      await tester.pump();

      expect(find.text('Heading 1'), findsNothing);
      expect(controller.text, '/hea');
    });

    testWidgets('source mode keeps wikilinks as raw Markdown text',
        (tester) async {
      final controller = MarkdownEditorController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            initialMode: MarkdownEditorMode.source,
            wikilinkSuggestions: const ['Alpha Note'],
            height: 240,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('smooth_markdown_editor_source')),
        'See [[Al',
      );
      await tester.pump();

      expect(find.text('Alpha Note'), findsNothing);
      expect(controller.text, 'See [[Al');
    });

    testWidgets('formatted slash command inserts markdown structure',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/hea',
      );
      await tester.pump();

      expect(find.text('Heading 1'), findsOneWidget);

      await tester.tap(find.text('Heading 1'));
      await tester.pump();

      expect(
          _singleScratchContentBlock(controller), isA<MarkdownHeadingBlock>());
      expect(controller.text, '#');
    });

    testWidgets('formatted slash command opens inside list item text',
        (tester) async {
      final controller = MarkdownEditorController(text: '- placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_list_item_0_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/hea',
      );
      await tester.pump();

      expect(find.text('Heading 1'), findsOneWidget);

      await tester.tap(find.text('Heading 1'));
      await tester.pump();

      final list = _singleScratchContentBlock(controller) as MarkdownListBlock;
      expect(list.items.single.blocks.single, isA<MarkdownHeadingBlock>());
      expect(controller.text, startsWith('- #'));
    });

    testWidgets('formatted slash command opens inside blockquote text',
        (tester) async {
      final controller = MarkdownEditorController(text: '> placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_blockquote_child_0_0'),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/hea',
      );
      await tester.pump();

      expect(find.text('Heading 1'), findsOneWidget);

      await tester.tap(find.text('Heading 1'));
      await tester.pump();

      final blockquote =
          _singleScratchContentBlock(controller) as MarkdownBlockquoteBlock;
      expect(blockquote.blocks.single, isA<MarkdownHeadingBlock>());
      expect(controller.text, startsWith('> #'));
    });

    testWidgets('slash command matches Scratch aliases', (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      await tester.enterText(activeField, '/img');
      await tester.pump();

      expect(find.text('Image'), findsOneWidget);

      await tester.enterText(activeField, '/[[');
      await tester.pump();

      expect(find.text('Wikilink'), findsOneWidget);

      await tester.enterText(activeField, '/subtitle');
      await tester.pump();

      expect(find.text('Heading 2'), findsOneWidget);

      await tester.enterText(activeField, '/pre');
      await tester.pump();

      expect(find.text('Code Block'), findsOneWidget);

      await tester.enterText(activeField, '/title');
      await tester.pump();

      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('Heading 2'), findsOneWidget);
      expect(find.text('Heading 3'), findsNothing);

      await tester.enterText(activeField, '/latex');
      await tester.pump();

      expect(find.text('Block Math'), findsNothing);

      await tester.enterText(activeField, '/media');
      await tester.pump();

      expect(find.text('Image'), findsNothing);
    });

    testWidgets('slash command exposes deep heading levels', (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/h6',
      );
      await tester.pump();

      expect(find.text('Heading 6'), findsOneWidget);

      await tester.tap(find.text('Heading 6'));
      await tester.pump();

      final block =
          _singleScratchContentBlock(controller) as MarkdownHeadingBlock;
      expect(block.level, 6);
      expect(controller.text, '######');
    });

    testWidgets('slash command supports host provided markdown commands',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            customSlashCommands: const [
              MarkdownEditorSlashCommand(
                title: 'Callout',
                searchText: 'admonition note',
                icon: Icons.info_outline,
                markdown: '> Custom callout',
              ),
            ],
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();

      final activeField = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      await tester.enterText(activeField, '/admonition');
      await tester.pump();

      expect(find.text('Callout'), findsOneWidget);

      await tester.tap(find.text('Callout'));
      await tester.pump();

      expect(controller.text, '> Custom callout');
      expect(controller.document.blocks.first, isA<MarkdownBlockquoteBlock>());
    });

    testWidgets('formatted custom slash command inserts inside list items',
        (tester) async {
      final controller = MarkdownEditorController(text: '- placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            customSlashCommands: const [
              MarkdownEditorSlashCommand(
                title: 'Callout',
                searchText: 'admonition note',
                icon: Icons.info_outline,
                markdown: '> Custom callout',
              ),
            ],
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey('smooth_markdown_editor_list_item_0_0'),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/admonition',
      );
      await tester.pump();

      await tester.tap(find.text('Callout'));
      await tester.pump();

      final list = controller.document.blocks.first as MarkdownListBlock;
      expect(list.items.single.blocks.single, isA<MarkdownBlockquoteBlock>());
      expect(controller.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(controller.document.blocks.last.plainText, '');
    });

    testWidgets('slash command dynamic callback receives the query',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);
      String? seenQuery;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            customSlashCommands: [
              MarkdownEditorSlashCommand(
                title: 'Snippet',
                searchText: 'dynamic template',
                icon: Icons.auto_fix_high,
                onSelected: (query) {
                  seenQuery = query;
                  return '## Generated';
                },
              ),
            ],
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/snip',
      );
      await tester.pump();
      await tester.tap(find.text('Snippet'));
      await tester.pump();

      expect(seenQuery, 'snip');
      expect(controller.text, '## Generated');
      expect(controller.document.blocks.first, isA<MarkdownHeadingBlock>());
    });

    testWidgets('async slash command ignores stale trigger ranges',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            customSlashCommands: [
              MarkdownEditorSlashCommand(
                title: 'Delayed Snippet',
                searchText: 'delayed snippet',
                icon: Icons.hourglass_empty,
                onSelected: (query) async {
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                  return '## Generated';
                },
              ),
            ],
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/delay',
      );
      await tester.pump();

      expect(find.text('Delayed Snippet'), findsOneWidget);

      await tester.tap(find.text('Delayed Snippet'));
      await tester.pump(const Duration(milliseconds: 5));

      controller.text = 'Manual edit while callback waits';
      await tester.pump(const Duration(milliseconds: 20));

      expect(controller.text, 'Manual edit while callback waits');
      expect(controller.document.blocks.single.plainText,
          'Manual edit while callback waits');
    });

    testWidgets('slash command callback exceptions keep editor state',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
            customSlashCommands: [
              MarkdownEditorSlashCommand(
                title: 'Exploding Snippet',
                searchText: 'explode error',
                icon: Icons.error_outline,
                onSelected: (query) {
                  throw StateError('slash failed');
                },
              ),
            ],
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/explode',
      );
      await tester.pump();

      await tester.tap(find.text('Exploding Snippet'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(controller.text, '/explode');
    });

    testWidgets('slash command keyboard wraps across the full Scratch list',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 240,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/',
      );
      await tester.pump();

      expect(find.text('Text'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.text, '[[');
    });

    testWidgets('slash command keyboard order matches Scratch', (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 240,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/',
      );
      await tester.pump();

      for (var i = 0; i < 14; i += 1) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(_singleScratchContentBlock(controller),
          isA<MarkdownHorizontalRuleBlock>());
      expect(controller.text, '---');
    });

    testWidgets('slash command supports keyboard selection', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/hea',
      );
      await tester.pump();

      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('Heading 2'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey('smooth_markdown_editor_slash_command_1')),
        ),
        matchesSemantics(
          label: 'Heading 2',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
          _singleScratchContentBlock(controller), isA<MarkdownHeadingBlock>());
      expect(
        (_singleScratchContentBlock(controller) as MarkdownHeadingBlock).level,
        2,
      );
      expect(controller.text, '##');
    });

    testWidgets('slash command escape closes suggestions', (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/hea',
      );
      await tester.pump();

      expect(find.text('Heading 1'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.text('Heading 1'), findsNothing);
      expect(controller.text, '/hea');
    });

    testWidgets('slash command stays hidden inside source code fences',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '```dart\n/hea\n```',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            initialMode: MarkdownEditorMode.source,
            height: 240,
          ),
        ),
      );

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.indexOf('/hea') + 4,
      );
      await tester.pump();

      expect(find.text('Heading 1'), findsNothing);
    });

    testWidgets('slash command stays hidden inside source frontmatter',
        (tester) async {
      final controller = MarkdownEditorController(
        text: '---\n/hea\n---\n\nBody',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            initialMode: MarkdownEditorMode.source,
            height: 240,
          ),
        ),
      );

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.indexOf('/hea') + 4,
      );
      await tester.pump();

      expect(find.text('Heading 1'), findsNothing);
    });

    testWidgets('wikilink autocomplete stays hidden inside inline code',
        (tester) async {
      final controller = MarkdownEditorController(
        text: 'Use `[[Al',
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            initialMode: MarkdownEditorMode.source,
            wikilinkSuggestions: const ['Alpha Note'],
            height: 240,
          ),
        ),
      );

      controller.textController.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      await tester.pump();

      expect(find.text('Alpha Note'), findsNothing);
    });

    testWidgets('formatted wikilink autocomplete shows Scratch empty state',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            wikilinkSuggestions: const ['Alpha Note'],
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'See [[Zed',
      );
      await tester.pump();

      expect(find.text('No matching notes'), findsOneWidget);
      expect(find.text('Alpha Note'), findsNothing);
      expect(
        tester.getSemantics(
          find.byKey(
            const ValueKey('smooth_markdown_editor_wikilink_empty_state'),
          ),
        ),
        matchesSemantics(
          label: 'No matching notes',
          isLiveRegion: true,
        ),
      );
      semantics.dispose();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.text, 'See [[Zed');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.text('No matching notes'), findsNothing);
    });

    testWidgets('formatted wikilink autocomplete requires Scratch prefix',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            wikilinkSuggestions: const ['Alpha Note'],
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'Word[[Al',
      );
      await tester.pump();

      expect(find.text('Alpha Note'), findsNothing);
      expect(find.text('No matching notes'), findsNothing);

      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'Word [[Al',
      );
      await tester.pump();

      expect(find.text('Alpha Note'), findsOneWidget);
    });

    testWidgets('formatted wikilink autocomplete limits suggestions to ten',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            wikilinkSuggestions: const [
              'Note 01',
              'Note 02',
              'Note 03',
              'Note 04',
              'Note 05',
              'Note 06',
              'Note 07',
              'Note 08',
              'Note 09',
              'Note 10',
              'Note 11',
            ],
            height: 240,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'See [[Note',
      );
      await tester.pump();

      expect(find.text('Note 01'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.text, 'See [[Note 10]]');
    });

    testWidgets('formatted wikilink autocomplete supports keyboard selection',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            wikilinkSuggestions: const ['Alpha Note', 'Beta Note'],
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'See [[',
      );
      await tester.pump();

      expect(find.text('Alpha Note'), findsOneWidget);
      expect(find.text('Beta Note'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester.getSemantics(
          find.byKey(
            const ValueKey('smooth_markdown_editor_wikilink_suggestion_1'),
          ),
        ),
        matchesSemantics(
          label: 'Beta Note',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.text, 'See [[Beta Note]]');
    });

    testWidgets('formatted slash command uses the semantic document model',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        '/hea',
      );
      await tester.pump();

      expect(find.text('Heading 1'), findsOneWidget);

      await tester.tap(find.text('Heading 1'));
      await tester.pump();

      expect(
          _singleScratchContentBlock(controller), isA<MarkdownHeadingBlock>());
      expect(controller.text, '#');
      expect(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.controller?.text == '',
          description: 'active empty heading field',
        ),
        findsOneWidget,
      );
    });

    testWidgets('formatted wikilink autocomplete replaces the active token',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            wikilinkSuggestions: const ['Alpha Note', 'Beta Note'],
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('smooth_markdown_editor_formatted_active_0'),
        ),
        'See [[Al',
      );
      await tester.pump();

      expect(find.text('Alpha Note'), findsOneWidget);

      await tester.tap(find.text('Alpha Note'));
      await tester.pump();
      await tester.pump();

      expect(controller.text, 'See [[Alpha Note]]');

      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      final activeField = tester.widget<TextField>(activeFinder);
      expect(activeField.controller?.text, 'See Alpha Note');
      expect(
        activeField.controller?.selection,
        const TextSelection.collapsed(offset: 14),
      );
      expect(activeField.focusNode?.hasFocus, isTrue);

      await tester.enterText(
        activeFinder,
        '${activeField.controller!.text}!',
      );
      await tester.pump();

      expect(controller.text, 'See [[Alpha Note]]!');
      expect(
        tester.widget<TextField>(activeFinder).controller?.text,
        'See Alpha Note!',
      );
    });

    testWidgets('formatted slash wikilink suggestion keeps active field fresh',
        (tester) async {
      final controller = MarkdownEditorController(text: 'placeholder');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            controller: controller,
            wikilinkSuggestions: const ['Alpha Note'],
            height: 320,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('smooth_markdown_editor_formatted_block_0')),
      );
      await tester.pump();
      final activeFinder = find.byKey(
        const ValueKey('smooth_markdown_editor_formatted_active_0'),
      );
      await tester.enterText(activeFinder, '/wiki');
      await tester.pump();

      expect(find.text('Wikilink'), findsOneWidget);

      await tester.tap(find.text('Wikilink'));
      await tester.pump();
      await tester.pump();

      var activeField = tester.widget<TextField>(activeFinder);
      expect(controller.text, '[[');
      expect(activeField.controller?.text, '[[');
      expect(
        activeField.controller?.selection,
        const TextSelection.collapsed(offset: 2),
      );
      expect(activeField.focusNode?.hasFocus, isTrue);
      expect(find.text('Alpha Note'), findsOneWidget);

      await tester.tap(find.text('Alpha Note'));
      await tester.pump();
      await tester.pump();

      activeField = tester.widget<TextField>(activeFinder);
      expect(controller.text, '[[Alpha Note]]');
      expect(activeField.controller?.text, 'Alpha Note');
      expect(
        activeField.controller?.selection,
        const TextSelection.collapsed(offset: 10),
      );
      expect(activeField.focusNode?.hasFocus, isTrue);

      await tester.enterText(
        activeFinder,
        '${activeField.controller!.text}!',
      );
      await tester.pump();

      expect(controller.text, '[[Alpha Note]]!');
      expect(
        tester.widget<TextField>(activeFinder).controller?.text,
        'Alpha Note!',
      );
    });

    testWidgets('preview renders wikilinks as tappable inline nodes',
        (tester) async {
      String? tapped;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            data: 'Open [[Alpha Note]]',
            initialMode: MarkdownEditorMode.preview,
            onTapWikilink: (target) => tapped = target,
            height: 240,
          ),
        ),
      );

      expect(find.text('Alpha Note'), findsOneWidget);

      await tester.tap(find.text('Alpha Note'));
      await tester.pump();

      expect(tapped, 'Alpha Note');
    });

    testWidgets('external editor links require Scratch modifier click',
        (tester) async {
      String? tapped;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            data: 'Open [site](https://example.com)',
            initialMode: MarkdownEditorMode.preview,
            onTapLink: (url) => tapped = url,
            height: 240,
          ),
        ),
      );

      final link = _richTextContaining('site');
      expect(link, findsOneWidget);

      await tester.tap(link);
      await tester.pump();
      expect(tapped, isNull);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      try {
        await tester.tap(link);
        await tester.pump();
      } finally {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }

      expect(tapped, 'https://example.com');
    });

    testWidgets('external editor links normalize bare hrefs like Scratch',
        (tester) async {
      String? tapped;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            data: 'Open [site](example.com)',
            initialMode: MarkdownEditorMode.preview,
            onTapLink: (url) => tapped = url,
            height: 240,
          ),
        ),
      );

      final link = _richTextContaining('site');
      expect(link, findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      try {
        await tester.tap(link);
        await tester.pump();
      } finally {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }

      expect(tapped, 'https://example.com');
    });

    testWidgets('external editor links reject unsafe schemes like Scratch',
        (tester) async {
      String? tapped;

      await tester.pumpWidget(
        _wrap(
          SmoothMarkdownEditor(
            data: 'Open [bad](javascript:alert(1))',
            initialMode: MarkdownEditorMode.preview,
            onTapLink: (url) => tapped = url,
            height: 240,
          ),
        ),
      );

      final link = _richTextContaining('bad');
      expect(link, findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      try {
        await tester.tap(link);
        await tester.pump();
      } finally {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }

      expect(tapped, isNull);
    });
  });
}

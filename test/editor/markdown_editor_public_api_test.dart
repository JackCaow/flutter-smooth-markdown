import 'package:flutter/widgets.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown_editor.dart'
    as editor_api;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Markdown editor public API', () {
    test('exports controller, semantic document, selection, and editor APIs',
        () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'paragraph',
            children: [MarkdownText('Hello')],
          ),
          MarkdownTableBlock(
            id: 'table',
            headers: [
              [MarkdownText('A')],
            ],
            rows: [],
            alignments: [null],
          ),
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-text',
                    children: [MarkdownText('Item')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final controller = MarkdownEditorController();
      addTearDown(controller.dispose);
      controller.document = document;

      expect(controller.document.toMarkdown(), document.toMarkdown());
      expect(controller.documentEditor.document.toMarkdown(),
          document.toMarkdown());
      expect(
          editor.copySelectionAsMarkdown(
            const MarkdownDocumentSelection(
              anchor: MarkdownDocumentPosition(blockId: 'paragraph', offset: 0),
              focus: MarkdownDocumentPosition(blockId: 'paragraph', offset: 5),
            ),
          ),
          'Hello');
      expect(
        controller.copyTableSelectionAsTsv(
          const MarkdownTableCellSelection(
            tableId: 'table',
            anchor: MarkdownTableCellPosition(rowIndex: 0, columnIndex: 0),
            focus: MarkdownTableCellPosition(rowIndex: 0, columnIndex: 0),
          ),
        ),
        'A',
      );
      expect(
        controller.copyListItemSelectionAsMarkdown(
          const MarkdownListItemSelection(
            listId: 'list',
            anchorItemId: 'item',
            focusItemId: 'item',
          ),
        ),
        '- Item',
      );

      final result = MarkdownSelectionTransactionResult(
        document: controller.document,
        activeBlockId: 'paragraph',
        selectionOffset: 0,
      );
      expect(result.activeBlockId, 'paragraph');
      expect(TextRange.empty.isCollapsed, isTrue);
    });

    test('offers a stable editor-only import surface', () {
      final controller = editor_api.MarkdownEditorController(text: 'Body');
      addTearDown(controller.dispose);

      expect(controller.text, 'Body');
      expect(
        const editor_api.MarkdownEditorCapabilities()
            .supports(editor_api.MarkdownEditorCommand.bold),
        isTrue,
      );
      expect(editor_api.MarkdownEditorMode.formatted.name, 'formatted');

      const theme = editor_api.MarkdownEditorThemeData(
        toolbarColor: Color(0xFF102030),
      );
      expect(theme.toolbarColor, const Color(0xFF102030));
    });
  });
}

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../parser/parser_plugin.dart';
import 'document/markdown_document.dart';
import 'document/markdown_document_codec.dart';
import 'document/markdown_document_editor.dart';
import 'markdown_editor_command.dart';

export 'markdown_editor_command.dart';

/// Controller for Markdown source editing.
///
/// The controller wraps a [TextEditingController], keeps a synchronized
/// [MarkdownDocumentEditor], and adds Markdown-aware editing commands used by
/// SmoothMarkdownEditor.
class MarkdownEditorController extends ChangeNotifier {
  /// Creates a Markdown editor controller.
  MarkdownEditorController({
    String text = '',
    TextEditingController? textController,
    ParserPluginRegistry? plugins,
  })  : textController = textController ?? TextEditingController(text: text),
        _ownsTextController = textController == null {
    _codec = MarkdownDocumentCodec(plugins: plugins);
    _lastParsedText = this.textController.text;
    documentEditor = MarkdownDocumentEditor(
      _parseEditableDocument(_lastParsedText),
    );
    _lastHistoryValue = this.textController.value;
    documentEditor.addListener(_handleDocumentChanged);
    this.textController.addListener(_handleTextControllerChanged);
  }

  static const int _defaultHistoryLimit = 100;

  /// The underlying text editing controller.
  final TextEditingController textController;

  late final MarkdownDocumentCodec _codec;

  /// Semantic editable document state synchronized with [textController].
  late final MarkdownDocumentEditor documentEditor;

  final bool _ownsTextController;

  late String _lastParsedText;
  late TextEditingValue _lastHistoryValue;

  final List<TextEditingValue> _undoStack = <TextEditingValue>[];
  final List<TextEditingValue> _redoStack = <TextEditingValue>[];
  final int _historyLimit = _defaultHistoryLimit;

  bool _syncingSourceFromDocument = false;
  bool _syncingDocumentFromSource = false;
  bool _normalizingScratchTrailingParagraph = false;
  bool _applyingHistory = false;
  var _sourceTransactionDepth = 0;
  var _sourceTransactionChanged = false;
  TextEditingValue? _sourceTransactionBefore;
  var _sourceHistoryBatchOpen = false;
  var _sourceHistoryBatchToken = 0;

  /// Current Markdown source text.
  String get text => textController.text;

  set text(String value) {
    if (value == textController.text) return;
    textController.value = _editingValueForSourceMutation(
      textController.value,
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  /// Current semantic Markdown document.
  MarkdownDocument get document => documentEditor.document;

  /// Whether an undo step is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether a redo step is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Replaces the semantic document and updates [text].
  set document(MarkdownDocument value) {
    documentEditor.document = value;
  }

  /// Clears source undo and redo history.
  void clearHistory() {
    _closeSourceHistoryBatch();
    _undoStack.clear();
    _redoStack.clear();
    documentEditor.clearHistory();
    _lastHistoryValue = textController.value;
  }

  /// Runs several source edits as one undoable transaction.
  T runTransaction<T>(T Function() transaction) {
    final outermost = _sourceTransactionDepth == 0;
    if (outermost) {
      _closeSourceHistoryBatch();
      _sourceTransactionBefore = _lastHistoryValue;
      _sourceTransactionChanged = false;
    }

    _sourceTransactionDepth++;
    try {
      return transaction();
    } finally {
      _sourceTransactionDepth--;
      if (outermost) {
        final before = _sourceTransactionBefore;
        final changed = _sourceTransactionChanged;
        _sourceTransactionBefore = null;
        _sourceTransactionChanged = false;

        if (changed && before != null && before.text != textController.text) {
          _pushUndo(before);
          _redoStack.clear();
        }
        _lastHistoryValue = textController.value;
      }
    }
  }

  /// Restores the previous source snapshot.
  bool undo() {
    if (!canUndo) return false;

    _closeSourceHistoryBatch();
    final previous = _undoStack.removeLast();
    _redoStack.add(textController.value);
    _applyHistoryValue(previous);
    return true;
  }

  /// Reapplies the most recently undone source snapshot.
  bool redo() {
    if (!canRedo) return false;

    _closeSourceHistoryBatch();
    final next = _redoStack.removeLast();
    _pushUndo(textController.value);
    _applyHistoryValue(next);
    return true;
  }

  /// Applies a semantic block command to [blockId].
  void applyBlockCommand(String blockId, MarkdownEditorCommand command) {
    documentEditor.applyBlockCommand(blockId, command);
  }

  /// Whether the top-level block containing [blockId] can move up or down.
  bool canMoveBlock(
    String blockId, {
    required bool upward,
  }) {
    return documentEditor.canMoveBlock(blockId: blockId, upward: upward);
  }

  /// Whether the top-level block containing [blockId] can move to [targetIndex].
  bool canMoveBlockToIndex(
    String blockId, {
    required int targetIndex,
  }) {
    return documentEditor.canMoveBlockToIndex(
      blockId: blockId,
      targetIndex: targetIndex,
    );
  }

  /// Moves the top-level block containing [blockId] up or down.
  MarkdownSelectionTransactionResult? moveBlock(
    String blockId, {
    required bool upward,
    int selectionOffset = 0,
  }) {
    final result = documentEditor.moveBlock(
      blockId: blockId,
      upward: upward,
      selectionOffset: selectionOffset,
    );
    _syncSourceSelectionFromDocumentResult(result);
    return result;
  }

  /// Moves the top-level block containing [blockId] to [targetIndex].
  MarkdownSelectionTransactionResult? moveBlockToIndex(
    String blockId, {
    required int targetIndex,
    int selectionOffset = 0,
  }) {
    final result = documentEditor.moveBlockToIndex(
      blockId: blockId,
      targetIndex: targetIndex,
      selectionOffset: selectionOffset,
    );
    _syncSourceSelectionFromDocumentResult(result);
    return result;
  }

  /// Applies a semantic inline command to [range] inside [blockId].
  void applyInlineCommand(
    String blockId,
    TextRange range,
    MarkdownEditorCommand command, {
    String? argument,
  }) {
    documentEditor.applyInlineCommand(
      blockId,
      range,
      command,
      argument: argument,
    );
  }

  /// Serializes a semantic document selection as Markdown.
  String? copyDocumentSelectionAsMarkdown(
    MarkdownDocumentSelection selection,
  ) {
    return documentEditor.copySelectionAsMarkdown(selection);
  }

  /// Deletes a semantic document selection.
  MarkdownSelectionTransactionResult? deleteDocumentSelection(
    MarkdownDocumentSelection selection,
  ) {
    final result = documentEditor.deleteSelection(selection);
    _syncSourceSelectionFromDocumentResult(result);
    return result;
  }

  /// Replaces a semantic document selection with parsed Markdown.
  MarkdownSelectionTransactionResult? replaceDocumentSelectionWithMarkdown(
    MarkdownDocumentSelection selection,
    String markdown,
  ) {
    final parsed = _codec.parse(markdown);
    final result = documentEditor.replaceSelectionWithBlocks(
      selection,
      parsed.blocks,
    );
    _syncSourceSelectionFromDocumentResult(result);
    return result;
  }

  /// Applies an inline command to a semantic document selection.
  bool applyInlineCommandToDocumentSelection(
    MarkdownDocumentSelection selection,
    MarkdownEditorCommand command, {
    String? argument,
  }) {
    return documentEditor.applyInlineCommandToSelection(
      selection,
      command,
      argument: argument,
    );
  }

  /// Serializes a semantic table cell selection as TSV.
  String? copyTableSelectionAsTsv(MarkdownTableCellSelection selection) {
    return documentEditor.copyTableSelectionAsTsv(selection);
  }

  /// Clears a semantic table cell selection without deleting rows or columns.
  bool clearTableSelection(MarkdownTableCellSelection selection) {
    return documentEditor.clearTableSelection(selection);
  }

  /// Applies a basic inline command to a semantic table cell selection.
  bool applyInlineCommandToTableSelection(
    MarkdownTableCellSelection selection,
    MarkdownEditorCommand command, {
    String? argument,
  }) {
    return documentEditor.applyInlineCommandToTableSelection(
      selection,
      command,
      argument: argument,
    );
  }

  /// Applies a block command to a semantic document selection.
  bool applyBlockCommandToDocumentSelection(
    MarkdownDocumentSelection selection,
    MarkdownEditorCommand command,
  ) {
    return documentEditor.applyBlockCommandToSelection(selection, command);
  }

  /// Replaces a block with parsed Markdown blocks.
  MarkdownDocument? replaceBlockWithMarkdown(
    String blockId,
    String markdown,
  ) {
    final parsed = _codec.parse(markdown);
    if (parsed.blocks.isEmpty) return null;
    return documentEditor.replaceBlockWithBlocks(blockId, parsed.blocks);
  }

  /// Current text selection.
  TextSelection get selection => textController.selection;

  /// Replaces the current selection with [replacement].
  void replaceSelection(
    String replacement, {
    int? selectionStart,
    int? selectionEnd,
  }) {
    final value = textController.value;
    final range = _normalizedSelection(value);
    replaceRange(
      range,
      replacement,
      selection: _selectionForReplacement(
        range.start,
        replacement.length,
        selectionStart,
        selectionEnd,
      ),
    );
  }

  /// Replaces an arbitrary source [range] with [replacement].
  void replaceRange(
    TextRange range,
    String replacement, {
    TextSelection? selection,
  }) {
    final value = textController.value;
    final start = range.start.clamp(0, value.text.length);
    final end = range.end.clamp(start, value.text.length);
    final nextText = value.text.replaceRange(start, end, replacement);

    textController.value = _editingValueForSourceMutation(
      value,
      text: nextText,
      selection: selection ??
          TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  /// Inserts [markdown] at the current selection.
  void insertMarkdown(String markdown) {
    replaceSelection(markdown);
  }

  /// Inserts [markdown] as a separated block at the current selection.
  void insertMarkdownBlock(String markdown) {
    final block = markdown.trim();
    if (block.isEmpty) return;
    _insertSeparatedBlock(block);
  }

  /// Inserts a table at the current source selection.
  ///
  /// [rows] is the total row count, including the header row. This mirrors
  /// Scratch/TipTap table insertion semantics.
  void insertTable({
    int rows = 3,
    int columns = 3,
  }) {
    _insertSeparatedBlock(
      MarkdownDocumentEditor.tableBlock(
        id: 'inserted-table',
        rows: rows,
        columns: columns,
      ).toMarkdown(),
    );
  }

  /// Applies a Markdown editing [command].
  ///
  /// [argument] is command-specific: link and image use it as the URL, code
  /// block uses it as the language, and other commands ignore it.
  void applyCommand(MarkdownEditorCommand command, {String? argument}) {
    switch (command) {
      case MarkdownEditorCommand.paragraph:
        _setSelectedLinesToParagraph();
      case MarkdownEditorCommand.bold:
        _wrapSelection('**', '**', placeholder: 'bold');
      case MarkdownEditorCommand.italic:
        _wrapSelection('*', '*', placeholder: 'italic');
      case MarkdownEditorCommand.strikethrough:
        _wrapSelection('~~', '~~', placeholder: 'strikethrough');
      case MarkdownEditorCommand.inlineCode:
        _wrapSelection('`', '`', placeholder: 'code');
      case MarkdownEditorCommand.heading1:
        _prefixSelectedLines('# ', stripHeading: true);
      case MarkdownEditorCommand.heading2:
        _prefixSelectedLines('## ', stripHeading: true);
      case MarkdownEditorCommand.heading3:
        _prefixSelectedLines('### ', stripHeading: true);
      case MarkdownEditorCommand.heading4:
        _prefixSelectedLines('#### ', stripHeading: true);
      case MarkdownEditorCommand.heading5:
        _prefixSelectedLines('##### ', stripHeading: true);
      case MarkdownEditorCommand.heading6:
        _prefixSelectedLines('###### ', stripHeading: true);
      case MarkdownEditorCommand.unorderedList:
        _prefixSelectedLines('- ');
      case MarkdownEditorCommand.orderedList:
        _prefixSelectedLines('', ordered: true);
      case MarkdownEditorCommand.taskList:
        _prefixSelectedLines('- [ ] ');
      case MarkdownEditorCommand.blockquote:
        _prefixSelectedLines('> ');
      case MarkdownEditorCommand.codeBlock:
        _wrapBlock(
          argument == null || argument.isEmpty ? '```' : '```$argument',
          '```',
          placeholder: 'code',
        );
      case MarkdownEditorCommand.link:
        final url = argument == null || argument.isEmpty
            ? 'https://example.com'
            : argument;
        _wrapSelection('[', ']($url)', placeholder: 'link');
      case MarkdownEditorCommand.image:
        final url =
            argument == null || argument.isEmpty ? 'image-url' : argument;
        _insertImage(url);
      case MarkdownEditorCommand.table:
        insertTable();
      case MarkdownEditorCommand.blockMath:
        _wrapBlock(r'$$', r'$$', placeholder: r'E = mc^2');
      case MarkdownEditorCommand.mermaidDiagram:
        _insertSeparatedBlock(
          '```mermaid\n'
          'flowchart TD\n'
          '  A[Start] --> B[End]\n'
          '```',
        );
      case MarkdownEditorCommand.horizontalRule:
        _insertSeparatedBlock('---');
      case MarkdownEditorCommand.wikilink:
        _wrapSelection('[[', ']]', placeholder: 'Note');
    }
  }

  /// Finds all text ranges matching [query].
  List<TextRange> findMatches(
    String query, {
    bool caseSensitive = false,
  }) {
    if (query.isEmpty) return const [];

    final haystack = caseSensitive ? text : text.toLowerCase();
    final needle = caseSensitive ? query : query.toLowerCase();
    final matches = <TextRange>[];
    var index = haystack.indexOf(needle);

    while (index != -1 && matches.length < 500) {
      matches.add(TextRange(start: index, end: index + needle.length));
      index = haystack.indexOf(needle, index + needle.length);
    }

    return matches;
  }

  /// Selects the next match for [query] and returns it.
  TextRange? selectNextMatch(
    String query, {
    bool caseSensitive = false,
  }) {
    final matches = findMatches(query, caseSensitive: caseSensitive);
    if (matches.isEmpty) return null;

    final currentEnd = selection.isValid ? selection.end : 0;
    var next = matches.first;
    for (final match in matches) {
      if (match.start >= currentEnd) {
        next = match;
        break;
      }
    }

    textController.selection = TextSelection(
      baseOffset: next.start,
      extentOffset: next.end,
    );
    return next;
  }

  void _wrapSelection(
    String prefix,
    String suffix, {
    required String placeholder,
  }) {
    final value = textController.value;
    final range = _normalizedSelection(value);
    final selected = value.text.substring(range.start, range.end);
    final body = selected.isEmpty ? placeholder : selected;
    final replacement = '$prefix$body$suffix';
    final selectedStart = prefix.length;
    final selectedEnd = prefix.length + body.length;

    replaceRange(
      range,
      replacement,
      selection: TextSelection(
        baseOffset: range.start + selectedStart,
        extentOffset: range.start + selectedEnd,
      ),
    );
  }

  void _wrapBlock(
    String opening,
    String closing, {
    required String placeholder,
  }) {
    final value = textController.value;
    final range = _normalizedSelection(value);
    final selected = value.text.substring(range.start, range.end);
    final body = selected.isEmpty ? placeholder : selected;
    final replacement = '$opening\n$body\n$closing';

    replaceRange(
      range,
      replacement,
      selection: TextSelection(
        baseOffset: range.start + opening.length + 1,
        extentOffset: range.start + opening.length + 1 + body.length,
      ),
    );
  }

  void _insertImage(String url) {
    final value = textController.value;
    final range = _normalizedSelection(value);
    final selected = value.text.substring(range.start, range.end);
    final alt = selected.isEmpty ? 'alt text' : selected;
    final replacement = '![$alt]($url)';

    replaceRange(
      range,
      replacement,
      selection: TextSelection(
        baseOffset: range.start + 2,
        extentOffset: range.start + 2 + alt.length,
      ),
    );
  }

  void _insertSeparatedBlock(String block) {
    final value = textController.value;
    final range = _normalizedSelection(value);
    final before = value.text.substring(0, range.start);
    final after = value.text.substring(range.end);
    final leading = before.isEmpty || before.endsWith('\n\n')
        ? ''
        : before.endsWith('\n')
            ? '\n'
            : '\n\n';
    final trailing = after.isEmpty || after.startsWith('\n\n')
        ? ''
        : after.startsWith('\n')
            ? '\n'
            : '\n\n';
    final replacement = '$leading$block$trailing';

    replaceRange(range, replacement);
  }

  void _prefixSelectedLines(
    String prefix, {
    bool ordered = false,
    bool stripHeading = false,
  }) {
    final value = textController.value;
    final range = _selectedLineRange(value);
    final selected = value.text.substring(range.start, range.end);
    final lines = selected.split('\n');

    final transformed = <String>[];
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (stripHeading) {
        line = line.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
      }
      transformed.add(ordered ? '${i + 1}. $line' : '$prefix$line');
    }

    final replacement = transformed.join('\n');
    replaceRange(
      range,
      replacement,
      selection: TextSelection(
        baseOffset: range.start,
        extentOffset: range.start + replacement.length,
      ),
    );
  }

  void _setSelectedLinesToParagraph() {
    final value = textController.value;
    final range = _selectedLineRange(value);
    final selected = value.text.substring(range.start, range.end);
    final replacement = selected
        .split('\n')
        .map(
          (line) => line
              .replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '')
              .replaceFirst(RegExp(r'^\s{0,3}>\s?'), '')
              .replaceFirst(RegExp(r'^\s{0,3}[-*+]\s+\[[ xX]\]\s+'), '')
              .replaceFirst(RegExp(r'^\s{0,3}[-*+]\s+'), '')
              .replaceFirst(RegExp(r'^\s{0,3}\d+[.)]\s+'), ''),
        )
        .join('\n');

    replaceRange(
      range,
      replacement,
      selection: TextSelection(
        baseOffset: range.start,
        extentOffset: range.start + replacement.length,
      ),
    );
  }

  TextSelection _selectionForReplacement(
    int replacementStart,
    int replacementLength,
    int? selectionStart,
    int? selectionEnd,
  ) {
    if (selectionStart == null && selectionEnd == null) {
      return TextSelection.collapsed(
        offset: replacementStart + replacementLength,
      );
    }

    final start = replacementStart + (selectionStart ?? replacementLength);
    final end = replacementStart + (selectionEnd ?? selectionStart ?? 0);
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  TextRange _normalizedSelection(TextEditingValue value) {
    if (!value.selection.isValid) {
      final end = value.text.length;
      return TextRange(start: end, end: end);
    }

    return TextRange(
      start: value.selection.start,
      end: value.selection.end,
    );
  }

  TextRange _selectedLineRange(TextEditingValue value) {
    final selection = _normalizedSelection(value);
    final text = value.text;
    var effectiveEnd = selection.end;

    if (effectiveEnd > selection.start &&
        effectiveEnd <= text.length &&
        text[effectiveEnd - 1] == '\n') {
      effectiveEnd--;
    }

    final lineStart = selection.start <= 0
        ? 0
        : text.lastIndexOf('\n', selection.start - 1) + 1;
    final nextNewline = text.indexOf('\n', effectiveEnd);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;

    return TextRange(start: lineStart, end: lineEnd);
  }

  void _handleTextControllerChanged() {
    if (_syncingSourceFromDocument) return;

    final source = textController.text;
    if (!_hasActiveComposing(textController.value)) {
      _recordSourceHistory(textController.value, coalesceEventLoop: true);
    }
    if (source != _lastParsedText) {
      _lastParsedText = source;
      _syncingDocumentFromSource = true;
      documentEditor.replaceDocument(
        _parseEditableDocument(source),
        recordHistory: false,
      );
      _syncingDocumentFromSource = false;
    }

    notifyListeners();
  }

  MarkdownDocument _parseEditableDocument(String source) {
    return _withScratchTrailingParagraph(_codec.parse(source));
  }

  MarkdownDocument _withScratchTrailingParagraph(MarkdownDocument document) {
    if (document.blocks.isNotEmpty &&
        document.blocks.last is MarkdownParagraphBlock) {
      return document;
    }

    final id = _scratchTrailingParagraphId(document);
    return MarkdownDocument(
      blocks: [
        ...document.blocks,
        MarkdownParagraphBlock(
          id: id,
          children: const [MarkdownText('')],
        ),
      ],
    );
  }

  String _scratchTrailingParagraphId(MarkdownDocument document) {
    final base = document.blocks.isEmpty
        ? 'block-0'
        : '${document.blocks.last.id}-scratch-trailing';
    var id = base;
    var suffix = 1;
    while (document.blockById(id) != null) {
      id = '$base-$suffix';
      suffix++;
    }
    return id;
  }

  void _syncSourceSelectionFromDocumentResult(
    MarkdownSelectionTransactionResult? result,
  ) {
    if (result == null) return;

    final offset = _sourceOffsetForDocumentCursor(
      result.document,
      result.activeBlockId,
      result.selectionOffset,
    );
    if (offset == null) return;

    final clampedOffset = offset.clamp(0, textController.text.length).toInt();
    final nextValue = _editingValueForSourceMutation(
      textController.value,
      text: textController.text,
      selection: TextSelection.collapsed(offset: clampedOffset),
    );
    _syncingSourceFromDocument = true;
    textController.value = nextValue;
    _syncingSourceFromDocument = false;
    _lastHistoryValue = textController.value;
  }

  int? _sourceOffsetForDocumentCursor(
    MarkdownDocument document,
    String blockId,
    int plainOffset,
  ) {
    var sourceOffset = 0;
    for (var index = 0; index < document.blocks.length; index++) {
      final block = document.blocks[index];
      final blockMarkdown = block.toMarkdown();
      if (block.findBlock(blockId) != null) {
        final blockOffset = _sourceOffsetInsideBlock(
          block,
          blockId,
          plainOffset,
        );
        return sourceOffset + blockOffset.clamp(0, blockMarkdown.length);
      }

      if (blockMarkdown.trim().isEmpty) continue;
      sourceOffset += blockMarkdown.length;
      if (_hasSerializedBlockAfter(document.blocks, index)) {
        sourceOffset += 2;
      }
    }
    return null;
  }

  bool _hasSerializedBlockAfter(List<MarkdownBlock> blocks, int index) {
    for (var next = index + 1; next < blocks.length; next++) {
      if (blocks[next].toMarkdown().trim().isNotEmpty) return true;
    }
    return false;
  }

  int _sourceOffsetInsideBlock(
    MarkdownBlock block,
    String blockId,
    int plainOffset,
  ) {
    if (block.id == blockId) {
      return _sourceOffsetForOwnBlockText(block, plainOffset);
    }

    final markdown = block.toMarkdown();
    if (block is MarkdownBlockquoteBlock) {
      return _sourceOffsetInsideNestedBlocks(
            markdown,
            block.blocks,
            blockId,
            plainOffset,
          ) ??
          0;
    }
    if (block is MarkdownListBlock) {
      var searchStart = 0;
      for (final item in block.items) {
        final itemOffset = _sourceOffsetInsideNestedBlocks(
          markdown.substring(searchStart),
          item.blocks,
          blockId,
          plainOffset,
        );
        if (itemOffset != null) return searchStart + itemOffset;

        final itemMarkdown = item.toMarkdown();
        final itemIndex = markdown.indexOf(itemMarkdown, searchStart);
        if (itemIndex != -1) {
          searchStart = itemIndex + itemMarkdown.length;
        }
      }
    }
    return 0;
  }

  int? _sourceOffsetInsideNestedBlocks(
    String containerMarkdown,
    List<MarkdownBlock> blocks,
    String blockId,
    int plainOffset,
  ) {
    var searchStart = 0;
    for (final block in blocks) {
      final blockMarkdown = block.toMarkdown();
      if (block.findBlock(blockId) == null) {
        final relative = containerMarkdown.indexOf(blockMarkdown, searchStart);
        if (relative != -1) {
          searchStart = relative + blockMarkdown.length;
        }
        continue;
      }

      final nestedOffset = _sourceOffsetInsideBlock(
        block,
        blockId,
        plainOffset,
      );
      final relative = containerMarkdown.indexOf(blockMarkdown, searchStart);
      if (relative != -1) return relative + nestedOffset;

      final firstLine = blockMarkdown.split('\n').first;
      final firstLineRelative =
          firstLine.isEmpty ? -1 : containerMarkdown.indexOf(firstLine);
      if (firstLineRelative != -1) return firstLineRelative + nestedOffset;
      return nestedOffset;
    }
    return null;
  }

  int _sourceOffsetForOwnBlockText(MarkdownBlock block, int plainOffset) {
    final markdown = block.toMarkdown();
    final plainLength = block.plainText.length;
    final offset = plainOffset.clamp(0, plainLength).toInt();
    if (offset == plainLength) return markdown.length;

    if (block is MarkdownParagraphBlock) {
      return _inlineSourceOffsetForPlainTextOffset(block.children, offset);
    }
    if (block is MarkdownHeadingBlock) {
      return block.level +
          1 +
          _inlineSourceOffsetForPlainTextOffset(block.children, offset);
    }
    return offset.clamp(0, markdown.length).toInt();
  }

  int _inlineSourceOffsetForPlainTextOffset(
    List<MarkdownInlineNode> children,
    int plainOffset,
  ) {
    var remaining = plainOffset;
    var sourceOffset = 0;
    for (final child in children) {
      final childPlainLength = child.plainText.length;
      if (remaining >= childPlainLength) {
        sourceOffset += child.toMarkdown().length;
        remaining -= childPlainLength;
        continue;
      }

      return sourceOffset + _inlineNodePartialSourceOffset(child, remaining);
    }
    return sourceOffset;
  }

  int _inlineNodePartialSourceOffset(MarkdownInlineNode node, int offset) {
    final clampedOffset = offset.clamp(0, node.plainText.length).toInt();
    if (node is MarkdownText) return clampedOffset;
    if (node is MarkdownStrong) {
      return 2 +
          _inlineSourceOffsetForPlainTextOffset(node.children, clampedOffset);
    }
    if (node is MarkdownEmphasis) {
      return 1 +
          _inlineSourceOffsetForPlainTextOffset(node.children, clampedOffset);
    }
    if (node is MarkdownStrikethrough) {
      return 2 +
          _inlineSourceOffsetForPlainTextOffset(node.children, clampedOffset);
    }
    if (node is MarkdownLink) {
      return 1 +
          _inlineSourceOffsetForPlainTextOffset(node.children, clampedOffset);
    }
    if (node is MarkdownInlineCode) return 1 + clampedOffset;
    if (node is MarkdownInlineMath) return 1 + clampedOffset;
    if (node is MarkdownImage) return 2 + clampedOffset;
    if (clampedOffset == 0) return 0;
    return node.toMarkdown().length;
  }

  void _handleDocumentChanged() {
    if (_syncingDocumentFromSource || _normalizingScratchTrailingParagraph) {
      return;
    }

    final editableDocument =
        _withScratchTrailingParagraph(documentEditor.document);
    if (!identical(editableDocument, documentEditor.document)) {
      _normalizingScratchTrailingParagraph = true;
      documentEditor.replaceDocument(
        editableDocument,
        recordHistory: false,
      );
      _normalizingScratchTrailingParagraph = false;
    }

    final nextText = _codec.serialize(editableDocument);
    _lastParsedText = nextText;
    if (nextText != textController.text) {
      final selection = _clampSelection(
        textController.selection,
        nextText.length,
      );
      final sourceValue = _editingValueForSourceMutation(
        textController.value,
        text: nextText,
        selection: selection,
      );
      _recordSourceHistory(sourceValue);
      _syncingSourceFromDocument = true;
      textController.value = sourceValue;
      _syncingSourceFromDocument = false;
    }

    notifyListeners();
  }

  TextSelection _clampSelection(TextSelection selection, int textLength) {
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: textLength);
    }
    return TextSelection(
      baseOffset: selection.baseOffset.clamp(0, textLength),
      extentOffset: selection.extentOffset.clamp(0, textLength),
    );
  }

  void _recordSourceHistory(
    TextEditingValue nextValue, {
    bool coalesceEventLoop = false,
  }) {
    if (_applyingHistory) {
      _lastHistoryValue = nextValue;
      return;
    }

    final previous = _lastHistoryValue;
    if (previous.text == nextValue.text) {
      _lastHistoryValue = nextValue;
      return;
    }

    if (_sourceTransactionDepth > 0) {
      _sourceTransactionChanged = true;
      _lastHistoryValue = nextValue;
      return;
    }

    if (coalesceEventLoop && _sourceHistoryBatchOpen) {
      _lastHistoryValue = nextValue;
      return;
    }

    _pushUndo(previous);
    _redoStack.clear();
    _lastHistoryValue = nextValue;
    if (coalesceEventLoop) {
      _openSourceHistoryBatch();
    }
  }

  void _openSourceHistoryBatch() {
    _sourceHistoryBatchOpen = true;
    final token = ++_sourceHistoryBatchToken;
    scheduleMicrotask(() {
      if (_sourceHistoryBatchToken == token) {
        _sourceHistoryBatchOpen = false;
      }
    });
  }

  void _closeSourceHistoryBatch() {
    if (!_sourceHistoryBatchOpen) return;
    _sourceHistoryBatchOpen = false;
    _sourceHistoryBatchToken++;
  }

  void _pushUndo(TextEditingValue value) {
    _undoStack.add(value);
    if (_undoStack.length > _historyLimit) {
      _undoStack.removeAt(0);
    }
  }

  void _applyHistoryValue(TextEditingValue value) {
    final selection = value.selection.isValid
        ? _clampSelection(value.selection, value.text.length)
        : TextSelection.collapsed(offset: value.text.length);
    final nextValue = value.copyWith(
      selection: selection,
    );

    _applyingHistory = true;
    try {
      textController.value = _editingValueForSourceMutation(
        textController.value,
        text: nextValue.text,
        selection: nextValue.selection,
      );
    } finally {
      _applyingHistory = false;
    }
  }

  TextEditingValue _editingValueForSourceMutation(
    TextEditingValue current, {
    required String text,
    required TextSelection selection,
  }) {
    final preserveComposing =
        text == current.text && _isValidComposingRange(current.composing, text);
    return current.copyWith(
      text: text,
      selection: selection,
      composing: preserveComposing ? current.composing : TextRange.empty,
    );
  }

  bool _hasActiveComposing(TextEditingValue value) {
    return _isValidComposingRange(value.composing, value.text);
  }

  bool _isValidComposingRange(TextRange range, String text) {
    return range.isValid &&
        !range.isCollapsed &&
        range.start >= 0 &&
        range.end <= text.length;
  }

  @override
  void dispose() {
    documentEditor
      ..removeListener(_handleDocumentChanged)
      ..dispose();
    textController.removeListener(_handleTextControllerChanged);
    if (_ownsTextController) {
      textController.dispose();
    }
    super.dispose();
  }
}

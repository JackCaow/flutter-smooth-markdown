import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../markdown_editor_command.dart';
import 'markdown_document.dart';

/// Result of applying an as-you-type Markdown input rule.
class MarkdownInputRuleResult {
  /// Creates an input-rule result.
  const MarkdownInputRuleResult({
    required this.document,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  /// Updated document.
  final MarkdownDocument document;

  /// Block that should stay active after the rule runs.
  final String activeBlockId;

  /// Local selection offset inside the active block.
  final int selectionOffset;
}

/// Result of splitting an editable block at the caret.
class MarkdownSplitBlockResult {
  /// Creates a split-block result.
  const MarkdownSplitBlockResult({
    required this.document,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  /// Updated document.
  final MarkdownDocument document;

  /// Block that should become active after the split.
  final String activeBlockId;

  /// Local selection offset inside the active block.
  final int selectionOffset;
}

/// Result of replacing text with a block math node.
class MarkdownBlockMathInsertResult {
  /// Creates a block-math insert result.
  const MarkdownBlockMathInsertResult({
    required this.document,
    required this.blockId,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  /// Updated document.
  final MarkdownDocument document;

  /// Inserted block math ID.
  final String blockId;

  /// Block that should become active after the inserted math block.
  final String activeBlockId;

  /// Local selection offset inside the active block.
  final int selectionOffset;
}

/// Result of replacing text with a standalone image block.
class MarkdownImageBlockInsertResult {
  /// Creates an image-block insert result.
  const MarkdownImageBlockInsertResult({
    required this.document,
    required this.blockId,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  /// Updated document.
  final MarkdownDocument document;

  /// Inserted image block ID.
  final String blockId;

  /// Block that should become active after the inserted image block.
  final String activeBlockId;

  /// Local selection offset inside the active block.
  final int selectionOffset;
}

/// Result of inserting parsed blocks into a text range.
class MarkdownBlockPasteResult {
  /// Creates a block paste result.
  const MarkdownBlockPasteResult({
    required this.document,
    required this.selectionOffset,
  });

  /// Updated document.
  final MarkdownDocument document;

  /// Markdown-source offset inside the top-level container after the paste.
  final int selectionOffset;
}

/// A plain-text position inside an editable text block.
class MarkdownDocumentPosition {
  /// Creates a document position.
  const MarkdownDocumentPosition({
    required this.blockId,
    required this.offset,
  });

  /// Target block ID.
  final String blockId;

  /// Plain-text offset inside [blockId].
  final int offset;
}

/// A document-wide selection between two editable text block positions.
class MarkdownDocumentSelection {
  /// Creates a document selection.
  const MarkdownDocumentSelection({
    required this.anchor,
    required this.focus,
  });

  /// Selection anchor.
  final MarkdownDocumentPosition anchor;

  /// Selection focus.
  final MarkdownDocumentPosition focus;
}

/// Result of applying a document-wide selection transaction.
class MarkdownSelectionTransactionResult {
  /// Creates a selection transaction result.
  const MarkdownSelectionTransactionResult({
    required this.document,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  /// Updated document.
  final MarkdownDocument document;

  /// Block that should become active after the transaction.
  final String activeBlockId;

  /// Plain-text cursor offset inside [activeBlockId].
  final int selectionOffset;
}

/// Result of applying a rich-editor backspace at the caret.
class MarkdownDeleteBackwardResult {
  /// Creates a delete-backward result.
  const MarkdownDeleteBackwardResult({
    required this.document,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  /// Updated document.
  final MarkdownDocument document;

  /// Block that should become active after deletion.
  final String activeBlockId;

  /// Local selection offset inside the active block.
  final int selectionOffset;
}

/// Result of changing a list item's nesting level.
class MarkdownListIndentResult {
  /// Creates a list-indent result.
  const MarkdownListIndentResult({
    required this.document,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  /// Updated document.
  final MarkdownDocument document;

  /// Block that should stay active after the indent change.
  final String activeBlockId;

  /// Local selection offset inside the active block.
  final int selectionOffset;
}

/// Mutable transaction facade over [MarkdownDocument].
///
/// This class owns document mutations for Scratch-style rich editing. The UI can
/// bind to [document], apply commands/input rules, and serialize with
/// [MarkdownDocument.toMarkdown] when it needs the plain Markdown source.
class MarkdownDocumentEditor extends ChangeNotifier {
  /// Creates a document editor.
  MarkdownDocumentEditor(this._document);

  static const int _defaultHistoryLimit = 100;

  MarkdownDocument _document;
  final List<MarkdownDocument> _undoStack = <MarkdownDocument>[];
  final List<MarkdownDocument> _redoStack = <MarkdownDocument>[];

  final _historyLimit = _defaultHistoryLimit;
  var _applyingHistory = false;
  var _transactionDepth = 0;
  var _transactionChanged = false;
  var _transactionShouldRecordHistory = false;
  MarkdownDocument? _transactionBefore;

  /// Current editable document.
  MarkdownDocument get document => _document;

  /// Whether an undo step is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether a redo step is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Replaces the whole document.
  set document(MarkdownDocument value) {
    replaceDocument(value);
  }

  /// Replaces the whole document.
  ///
  /// Set [recordHistory] to false when loading or synchronizing an external
  /// source snapshot rather than applying a user-editable transaction.
  void replaceDocument(
    MarkdownDocument value, {
    bool recordHistory = true,
  }) {
    _replaceDocument(value, recordHistory: recordHistory);
  }

  /// Clears undo and redo history without changing the current document.
  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// Runs several document mutations as one undoable transaction.
  T runTransaction<T>(
    T Function() transaction, {
    bool recordHistory = true,
  }) {
    final outermost = _transactionDepth == 0;
    if (outermost) {
      _transactionBefore = _document;
      _transactionChanged = false;
      _transactionShouldRecordHistory = false;
    }

    _transactionDepth++;
    try {
      return transaction();
    } finally {
      _transactionDepth--;
      if (outermost) {
        final before = _transactionBefore;
        final changed = _transactionChanged;
        final shouldRecord = recordHistory && _transactionShouldRecordHistory;
        _transactionBefore = null;
        _transactionChanged = false;
        _transactionShouldRecordHistory = false;

        if (changed) {
          if (before != null && shouldRecord && !_applyingHistory) {
            _pushUndo(before);
            _redoStack.clear();
          }
          notifyListeners();
        }
      }
    }
  }

  /// Restores the previous document snapshot.
  bool undo() {
    if (!canUndo) return false;

    final previous = _undoStack.removeLast();
    _redoStack.add(_document);
    _applyingHistory = true;
    try {
      _replaceDocument(previous, recordHistory: false);
    } finally {
      _applyingHistory = false;
    }
    return true;
  }

  /// Reapplies the most recently undone document snapshot.
  bool redo() {
    if (!canRedo) return false;

    final next = _redoStack.removeLast();
    _pushUndo(_document);
    _applyingHistory = true;
    try {
      _replaceDocument(next, recordHistory: false);
    } finally {
      _applyingHistory = false;
    }
    return true;
  }

  bool _replaceDocument(
    MarkdownDocument value, {
    bool recordHistory = true,
  }) {
    if (_documentsEqual(_document, value)) return false;

    final previous = _document;
    final shouldRecord = recordHistory && !_applyingHistory;
    if (_transactionDepth > 0) {
      _document = value;
      _transactionChanged = true;
      _transactionShouldRecordHistory =
          _transactionShouldRecordHistory || shouldRecord;
      return true;
    }

    if (shouldRecord) {
      _pushUndo(previous);
      _redoStack.clear();
    }
    _document = value;
    notifyListeners();
    return true;
  }

  void _pushUndo(MarkdownDocument value) {
    _undoStack.add(value);
    if (_undoStack.length > _historyLimit) {
      _undoStack.removeAt(0);
    }
  }

  bool _documentsEqual(MarkdownDocument a, MarkdownDocument b) {
    return identical(a, b) || jsonEncode(a.toJson()) == jsonEncode(b.toJson());
  }

  /// Replaces [block].
  void replaceBlock(MarkdownBlock block) {
    _replaceDocument(_document.replaceBlock(block));
  }

  /// Replaces a top-level block with [blocks].
  void replaceTopLevelBlockWithBlocks(
    String blockId,
    List<MarkdownBlock> blocks,
  ) {
    final nextDocument = _document.replaceTopLevelBlockWithBlocks(
      blockId,
      blocks,
    );
    _replaceDocument(nextDocument);
  }

  /// Inserts [block] after [anchorBlockId].
  void insertBlockAfter(String anchorBlockId, MarkdownBlock block) {
    _replaceDocument(_document.insertBlockAfter(anchorBlockId, block));
  }

  /// Removes the block with [blockId].
  void removeBlock(String blockId) {
    _replaceDocument(_document.removeBlock(blockId));
  }

  /// Applies a toolbar command to a whole text block.
  ///
  /// This is intentionally document-model based. It avoids Markdown source
  /// marker edits and changes the semantic block/inline nodes directly.
  void applyBlockCommand(String blockId, MarkdownEditorCommand command) {
    final block = _document.blockById(blockId);
    if (block == null) return;

    final replacement = switch (command) {
      MarkdownEditorCommand.paragraph => _asParagraph(block),
      MarkdownEditorCommand.heading1 => _asHeading(block, 1),
      MarkdownEditorCommand.heading2 => _asHeading(block, 2),
      MarkdownEditorCommand.heading3 => _asHeading(block, 3),
      MarkdownEditorCommand.heading4 => _asHeading(block, 4),
      MarkdownEditorCommand.heading5 => _asHeading(block, 5),
      MarkdownEditorCommand.heading6 => _asHeading(block, 6),
      MarkdownEditorCommand.unorderedList =>
        _asList(block, MarkdownListKind.bullet),
      MarkdownEditorCommand.orderedList =>
        _asList(block, MarkdownListKind.ordered),
      MarkdownEditorCommand.taskList => _asList(block, MarkdownListKind.task),
      MarkdownEditorCommand.blockquote => MarkdownBlockquoteBlock(
          id: block.id,
          blocks: [_asParagraph(block).copyWith(id: '$blockId-quote-p')],
        ),
      MarkdownEditorCommand.codeBlock => MarkdownCodeBlock(
          id: block.id,
          code: block.plainText,
        ),
      MarkdownEditorCommand.blockMath => MarkdownBlockMathBlock(
          id: block.id,
          latex: block.plainText.isEmpty ? r'E = mc^2' : block.plainText,
        ),
      MarkdownEditorCommand.mermaidDiagram => MarkdownMermaidBlock(
          id: block.id,
          code: block.plainText.isEmpty
              ? 'flowchart TD\n  A[Start] --> B[End]'
              : block.plainText,
        ),
      MarkdownEditorCommand.horizontalRule => MarkdownHorizontalRuleBlock(
          id: block.id,
        ),
      MarkdownEditorCommand.image => MarkdownImageBlock(
          id: block.id,
          url: 'image-url',
          alt: block.plainText.isEmpty ? 'image' : block.plainText,
        ),
      MarkdownEditorCommand.table => tableBlock(id: block.id),
      MarkdownEditorCommand.bold ||
      MarkdownEditorCommand.italic ||
      MarkdownEditorCommand.strikethrough ||
      MarkdownEditorCommand.inlineCode ||
      MarkdownEditorCommand.link ||
      MarkdownEditorCommand.wikilink =>
        block,
    };

    if (!identical(block, replacement)) {
      replaceBlock(replacement);
    }
  }

  /// Creates a Scratch-style table block.
  ///
  /// [rows] is the total row count, including the header row. This mirrors
  /// TipTap's `insertTable({ rows, cols, withHeaderRow: true })` behavior.
  static MarkdownTableBlock tableBlock({
    required String id,
    int rows = 3,
    int columns = 3,
  }) {
    final safeRows = rows < 1 ? 1 : rows;
    final safeColumns = columns < 1 ? 1 : columns;
    return MarkdownTableBlock(
      id: id,
      headers: List<List<MarkdownInlineNode>>.generate(
        safeColumns,
        (_) => const [MarkdownText('Column')],
      ),
      alignments: List<MarkdownTableAlignment?>.filled(safeColumns, null),
      rows: List<List<List<MarkdownInlineNode>>>.generate(
        safeRows - 1,
        (_) => List<List<MarkdownInlineNode>>.generate(
          safeColumns,
          (_) => const [MarkdownText('Cell')],
        ),
      ),
    );
  }

  /// Replaces [blockId] with a table of the requested dimensions.
  void replaceBlockWithTable(
    String blockId, {
    int rows = 3,
    int columns = 3,
  }) {
    final block = _document.blockById(blockId);
    if (block == null) return;
    replaceBlock(tableBlock(id: block.id, rows: rows, columns: columns));
  }

  /// Replaces [blockId] with a standalone image block.
  void replaceBlockWithImage(
    String blockId, {
    required String url,
    required String alt,
    String? title,
  }) {
    final block = _document.blockById(blockId);
    if (block == null) return;
    replaceBlock(
      MarkdownImageBlock(
        id: block.id,
        url: url,
        alt: alt,
        title: title,
      ),
    );
  }

  /// Replaces an empty document with a standalone image and trailing paragraph.
  ///
  /// TipTap's block image command leaves an editable paragraph after an inserted
  /// block node. This keeps the formatted editor active after inserting into an
  /// otherwise empty document.
  MarkdownImageBlockInsertResult? replaceEmptyDocumentWithImageBlock({
    required String url,
    required String alt,
    String? title,
  }) {
    if (_document.toMarkdown().trim().isNotEmpty) return null;

    final imageId = _uniqueBlockId('image');
    final afterId = _uniqueBlockId('$imageId-after-image');
    final afterBlock = MarkdownParagraphBlock(
      id: afterId,
      children: const [MarkdownText('')],
    );
    _replaceDocument(
      MarkdownDocument(
        blocks: [
          MarkdownImageBlock(
            id: imageId,
            url: url,
            alt: alt,
            title: title,
          ),
          afterBlock,
        ],
      ),
    );

    return MarkdownImageBlockInsertResult(
      document: _document,
      blockId: imageId,
      activeBlockId: afterBlock.id,
      selectionOffset: 0,
    );
  }

  /// Applies TipTap's block-image input rule to a paragraph-like block.
  ///
  /// A block image inserted from a full Markdown image match splits the active
  /// textblock, preserving an empty textblock before the image and creating a
  /// paragraph after it. When the active textblock is nested in a list or quote,
  /// the trailing paragraph is created after the top-level container, matching
  /// ProseMirror's block insertion behavior.
  MarkdownImageBlockInsertResult? replaceBlockWithImageInputRule(
    String blockId, {
    required String url,
    required String alt,
    String? title,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return null;
    }

    return _replaceTextBlockWithImageParts(
      blockId,
      block!,
      beforeChildren: const [MarkdownText('')],
      afterChildren: const [MarkdownText('')],
      url: url,
      alt: alt,
      preserveEmptyBefore: true,
      title: title,
    );
  }

  /// Inserts a standalone image block after [anchorBlockId].
  String insertImageBlockAfter(
    String anchorBlockId, {
    required String url,
    required String alt,
    String? title,
  }) {
    final id = _uniqueBlockId('$anchorBlockId-image');
    insertBlockAfter(
      anchorBlockId,
      MarkdownImageBlock(
        id: id,
        url: url,
        alt: alt,
        title: title,
      ),
    );
    return id;
  }

  /// Updates a standalone image block.
  void updateImageBlock(
    String blockId, {
    required String url,
    required String alt,
    String? title,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownImageBlock) return;
    replaceBlock(
      block.copyWith(
        url: url,
        alt: alt,
        title: title,
      ),
    );
  }

  /// Applies an inline mark to a text range in a paragraph or heading.
  void applyInlineCommand(
    String blockId,
    TextRange range,
    MarkdownEditorCommand command, {
    String? argument,
  }) {
    final block = _document.blockById(blockId);
    final wrap = _inlineWrapForCommand(command);
    if (wrap == null) return;
    final marked = _wrapRange(
      block,
      range,
      wrap,
      argument: _inlineArgumentForCommand(command, argument),
    );

    if (marked != null) replaceBlock(marked);
  }

  /// Serializes a document-wide text selection as Markdown.
  ///
  /// This first implementation intentionally supports only top-level paragraph
  /// and heading blocks. Nested containers and table-cell selections are handled
  /// by their existing single-block APIs until the richer selection model is
  /// extended.
  String? copySelectionAsMarkdown(MarkdownDocumentSelection selection) {
    final resolved = _resolveTopLevelTextSelection(selection);
    if (resolved == null || resolved.isCollapsed) return null;

    final selected = _selectedTopLevelTextBlocks(resolved);
    if (selected.isEmpty) return '';
    return MarkdownDocument(blocks: selected).toMarkdown();
  }

  /// Deletes a document-wide text selection.
  MarkdownSelectionTransactionResult? deleteSelection(
    MarkdownDocumentSelection selection,
  ) {
    return replaceSelectionWithBlocks(selection, const []);
  }

  /// Replaces a document-wide text selection with parsed Markdown [blocks].
  MarkdownSelectionTransactionResult? replaceSelectionWithBlocks(
    MarkdownDocumentSelection selection,
    List<MarkdownBlock> blocks,
  ) {
    final resolved = _resolveTopLevelTextSelection(selection);
    if (resolved == null || resolved.isCollapsed) return null;

    final startBlock = resolved.startBlock;
    final endBlock = resolved.endBlock;
    final startSplit = _splitInlineNodes(
      _textBlockChildren(startBlock),
      resolved.startOffset,
    );
    final endSplit = _splitInlineNodes(
      _textBlockChildren(endBlock),
      resolved.endOffset,
    );
    final beforeChildren = startSplit.before;
    final afterChildren = endSplit.after;
    final hasBefore = _hasVisibleInlineContent(beforeChildren);
    final hasAfter = _hasVisibleInlineContent(afterChildren);

    final replacements = <MarkdownBlock>[];
    String activeBlockId;
    int selectionOffset;

    if (blocks.isEmpty) {
      final mergedChildren = _mergeInlineChildren(
        hasBefore ? beforeChildren : const <MarkdownInlineNode>[],
        hasAfter ? afterChildren : const <MarkdownInlineNode>[],
      );
      final merged = _copyTextBlockWithChildren(startBlock, mergedChildren);
      replacements.add(merged);
      activeBlockId = merged.id;
      selectionOffset = hasBefore ? _inlinePlainText(beforeChildren).length : 0;
    } else {
      final reservedBlockIds = <String>{};
      final reservedListItemIds = <String>{};
      _collectInsertionIds(
        _document.blocks.take(resolved.startIndex),
        reservedBlockIds,
        reservedListItemIds,
      );
      _collectInsertionIds(
        _document.blocks.skip(resolved.endIndex + 1),
        reservedBlockIds,
        reservedListItemIds,
      );

      MarkdownBlock? beforeBlock;
      MarkdownBlock? afterBlock;
      if (hasBefore) {
        beforeBlock = _copyTextBlockWithChildren(startBlock, beforeChildren);
        _collectInsertionIds(
          [beforeBlock],
          reservedBlockIds,
          reservedListItemIds,
        );
        replacements.add(beforeBlock);
      }
      if (hasAfter) {
        afterBlock = resolved.startIndex == resolved.endIndex
            ? _afterTextBlockForRangePaste(endBlock, afterChildren)
            : _copyTextBlockWithChildren(endBlock, afterChildren);
        _collectInsertionIds(
          [afterBlock],
          reservedBlockIds,
          reservedListItemIds,
        );
      }

      final insertedBlocks = _retagBlocksForInsertion(
        blocks,
        reservedBlockIds,
        reservedListItemIds,
      );
      replacements.addAll(insertedBlocks);
      if (afterBlock != null) {
        replacements.add(afterBlock);
      }

      final active =
          afterBlock ?? _lastEditableTextBlock(insertedBlocks) ?? beforeBlock;
      if (active == null) return null;
      activeBlockId = active.id;
      selectionOffset = afterBlock == null ? active.plainText.length : 0;
    }

    final nextBlocks = <MarkdownBlock>[
      ..._document.blocks.take(resolved.startIndex),
      ...replacements,
      ..._document.blocks.skip(resolved.endIndex + 1),
    ];
    if (!_replaceDocument(MarkdownDocument(blocks: nextBlocks))) return null;

    return MarkdownSelectionTransactionResult(
      document: _document,
      activeBlockId: activeBlockId,
      selectionOffset: selectionOffset,
    );
  }

  /// Replaces a block with parsed Markdown blocks after retagging inserted IDs.
  MarkdownDocument? replaceBlockWithBlocks(
    String blockId,
    List<MarkdownBlock> blocks,
  ) {
    if (blocks.isEmpty) return null;

    final replacements = _retagBlocksForDocumentInsertion(blocks);
    final nextDocument = _document.replaceBlockWithBlocks(
      blockId,
      replacements,
    );
    if (!_replaceDocument(nextDocument)) return null;
    return MarkdownDocument(blocks: replacements);
  }

  /// Applies an inline command to each text fragment in a document selection.
  bool applyInlineCommandToSelection(
    MarkdownDocumentSelection selection,
    MarkdownEditorCommand command, {
    String? argument,
  }) {
    final resolved = _resolveTopLevelTextSelection(selection);
    final wrap = _inlineWrapForCommand(command);
    if (resolved == null || resolved.isCollapsed || wrap == null) return false;

    final nextBlocks = [..._document.blocks];
    var changed = false;
    for (var index = resolved.startIndex; index <= resolved.endIndex; index++) {
      final block = nextBlocks[index];
      if (!_isTextBlock(block)) return false;

      final start = index == resolved.startIndex ? resolved.startOffset : 0;
      final end = index == resolved.endIndex
          ? resolved.endOffset
          : block.plainText.length;
      if (start == end) continue;

      final marked = _wrapRange(
        block,
        TextRange(start: start, end: end),
        wrap,
        argument: _inlineArgumentForCommand(command, argument),
      );
      if (marked == null) return false;
      nextBlocks[index] = marked;
      changed = true;
    }

    if (!changed) return false;
    return _replaceDocument(MarkdownDocument(blocks: nextBlocks));
  }

  /// Applies a block command to every top-level block touched by [selection].
  ///
  /// List and blockquote commands group the selected blocks into one container,
  /// matching TipTap's block-range behavior for the common top-level case.
  bool applyBlockCommandToSelection(
    MarkdownDocumentSelection selection,
    MarkdownEditorCommand command,
  ) {
    if (_inlineWrapForCommand(command) != null) {
      return applyInlineCommandToSelection(selection, command);
    }

    final resolved = _resolveTopLevelTextSelection(selection);
    if (resolved == null || resolved.isCollapsed) return false;

    final selected =
        _document.blocks.sublist(resolved.startIndex, resolved.endIndex + 1);
    if (selected.any((block) => !_isTextBlock(block))) return false;

    final replacements = switch (command) {
      MarkdownEditorCommand.unorderedList => [
          _rangeListBlock(selected, MarkdownListKind.bullet),
        ],
      MarkdownEditorCommand.orderedList => [
          _rangeListBlock(selected, MarkdownListKind.ordered),
        ],
      MarkdownEditorCommand.taskList => [
          _rangeListBlock(selected, MarkdownListKind.task),
        ],
      MarkdownEditorCommand.blockquote => [
          MarkdownBlockquoteBlock(
            id: selected.first.id,
            blocks: [
              for (var i = 0; i < selected.length; i++)
                _asParagraph(selected[i]).copyWith(
                  id: _uniqueBlockId('${selected.first.id}-quote-$i'),
                ),
            ],
          ),
        ],
      MarkdownEditorCommand.paragraph => [
          for (final block in selected) _asParagraph(block),
        ],
      MarkdownEditorCommand.heading1 => [
          for (final block in selected) _asHeading(block, 1),
        ],
      MarkdownEditorCommand.heading2 => [
          for (final block in selected) _asHeading(block, 2),
        ],
      MarkdownEditorCommand.heading3 => [
          for (final block in selected) _asHeading(block, 3),
        ],
      MarkdownEditorCommand.heading4 => [
          for (final block in selected) _asHeading(block, 4),
        ],
      MarkdownEditorCommand.heading5 => [
          for (final block in selected) _asHeading(block, 5),
        ],
      MarkdownEditorCommand.heading6 => [
          for (final block in selected) _asHeading(block, 6),
        ],
      _ => <MarkdownBlock>[],
    };
    if (replacements.isEmpty) return false;

    final nextBlocks = <MarkdownBlock>[
      ..._document.blocks.take(resolved.startIndex),
      ...replacements,
      ..._document.blocks.skip(resolved.endIndex + 1),
    ];
    return _replaceDocument(MarkdownDocument(blocks: nextBlocks));
  }

  /// Returns the link intersecting [range] inside a paragraph or heading.
  MarkdownLinkEdit? linkAtTextRange(String blockId, TextRange range) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return null;
    }

    return _linkInInlineRange(_textBlockChildren(block!), range);
  }

  /// Updates the link intersecting [range] inside a paragraph or heading.
  bool updateLinkAtTextRange(
    String blockId,
    TextRange range, {
    required String url,
    String? title,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return false;
    }

    final children = _textBlockChildren(block!);
    final link = _linkInInlineRange(children, range);
    if (link == null) return false;

    final nextChildren = _replaceLinkInInlineRange(
      children,
      link.range,
      (link) => [
        MarkdownLink(
          url: url,
          title: title,
          children: link.children,
        ),
      ],
    );
    if (nextChildren == null) return false;
    replaceBlock(_copyTextBlockWithChildren(block, nextChildren));
    return true;
  }

  /// Removes the link intersecting [range] while preserving its children.
  bool unlinkAtTextRange(String blockId, TextRange range) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return false;
    }

    final children = _textBlockChildren(block!);
    final link = _linkInInlineRange(children, range);
    if (link == null) return false;

    final nextChildren = _replaceLinkInInlineRange(
      children,
      link.range,
      (link) => link.children,
    );
    if (nextChildren == null) return false;
    replaceBlock(_copyTextBlockWithChildren(block, nextChildren));
    return true;
  }

  /// Applies an inline mark to a text range inside one table cell.
  bool applyTableCellInlineCommand({
    required String blockId,
    required int rowIndex,
    required int columnIndex,
    required TextRange range,
    required MarkdownEditorCommand command,
    String? argument,
    bool header = false,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownTableBlock) return false;

    final wrap = _inlineWrapForCommand(command);
    if (wrap == null) return false;

    final children = _tableCellInlineChildren(
      block,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      header: header,
    );
    if (children == null) return false;

    final nextChildren = _wrapInlineRange(
      children,
      range,
      wrap,
      argument: _inlineArgumentForCommand(command, argument),
    );
    if (nextChildren == null) return false;

    updateTable(
      blockId,
      (table) => table.updateCell(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        header: header,
        children: nextChildren,
      ),
    );
    return true;
  }

  /// Returns the link intersecting [range] inside one table cell.
  MarkdownLinkEdit? tableCellLinkAtRange({
    required String blockId,
    required int rowIndex,
    required int columnIndex,
    required TextRange range,
    bool header = false,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownTableBlock) return null;

    final children = _tableCellInlineChildren(
      block,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      header: header,
    );
    if (children == null) return null;

    return _linkInInlineRange(children, range);
  }

  /// Updates the link intersecting [range] inside one table cell.
  bool updateTableCellLinkAtRange({
    required String blockId,
    required int rowIndex,
    required int columnIndex,
    required TextRange range,
    required String url,
    String? title,
    bool header = false,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownTableBlock) return false;

    final children = _tableCellInlineChildren(
      block,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      header: header,
    );
    if (children == null) return false;

    final link = _linkInInlineRange(children, range);
    if (link == null) return false;

    final nextChildren = _replaceLinkInInlineRange(
      children,
      link.range,
      (link) => [
        MarkdownLink(
          url: url,
          title: title,
          children: link.children,
        ),
      ],
    );
    if (nextChildren == null) return false;

    updateTable(
      blockId,
      (table) => table.updateCell(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        header: header,
        children: nextChildren,
      ),
    );
    return true;
  }

  /// Removes the link intersecting [range] inside one table cell.
  bool unlinkTableCellAtRange({
    required String blockId,
    required int rowIndex,
    required int columnIndex,
    required TextRange range,
    bool header = false,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownTableBlock) return false;

    final children = _tableCellInlineChildren(
      block,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      header: header,
    );
    if (children == null) return false;

    final link = _linkInInlineRange(children, range);
    if (link == null) return false;

    final nextChildren = _replaceLinkInInlineRange(
      children,
      link.range,
      (link) => link.children,
    );
    if (nextChildren == null) return false;

    updateTable(
      blockId,
      (table) => table.updateCell(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        header: header,
        children: nextChildren,
      ),
    );
    return true;
  }

  /// Replaces a plain-text [range] inside a paragraph or heading block.
  ///
  /// This is used by rich-editor command triggers, where the slash token has
  /// already been typed into the active semantic block and must be removed
  /// before the block command runs.
  bool replaceTextRange(
    String blockId,
    TextRange range,
    String replacement,
  ) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return false;
    }

    final text = block!.plainText;
    final start = range.start.clamp(0, text.length);
    final end = range.end.clamp(start, text.length);
    final children = _textBlockChildren(block);
    final nextChildren = _replaceInlineRange(
      children,
      TextRange(start: start, end: end),
      replacement,
    );
    final nextBlock = _copyTextBlockWithChildren(
      block,
      nextChildren,
    );
    replaceBlock(nextBlock);
    return true;
  }

  /// Replaces a plain-text [range] inside a paragraph or heading with inline
  /// nodes.
  bool replaceTextRangeWithInlineNodes(
    String blockId,
    TextRange range,
    List<MarkdownInlineNode> replacement,
  ) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return false;
    }

    final text = block!.plainText;
    final start = range.start.clamp(0, text.length);
    final end = range.end.clamp(start, text.length);
    final children = _textBlockChildren(block);
    final nextChildren = _replaceInlineRangeWithNodes(
      children,
      TextRange(start: start, end: end),
      replacement,
    );
    final nextBlock = _copyTextBlockWithChildren(
      block,
      nextChildren,
    );
    replaceBlock(nextBlock);
    return true;
  }

  /// Replaces a plain-text range with a standalone block math node.
  ///
  /// Surrounding text is preserved as text blocks before and after the inserted
  /// math block. This mirrors the Scratch flow where block math is committed
  /// only after the math editor submits non-empty LaTeX.
  MarkdownBlockMathInsertResult? replaceTextRangeWithBlockMath(
    String blockId,
    TextRange range, {
    required String latex,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return null;
    }

    final text = block!.plainText;
    final start = range.start.clamp(0, text.length).toInt();
    final end = range.end.clamp(start, text.length).toInt();
    final children = _textBlockChildren(block);
    final beforeSplit = _splitInlineNodes(children, start);
    final afterSplit = _splitInlineNodes(beforeSplit.after, end - start);
    final beforeChildren = beforeSplit.before;
    final afterChildren = afterSplit.after;

    final topLevelIndex = _topLevelBlockIndexContaining(blockId);
    if (topLevelIndex == -1) return null;

    final mathId = _uniqueBlockId('$blockId-math');
    final mathBlock = MarkdownBlockMathBlock(id: mathId, latex: latex);
    final afterBlock = MarkdownParagraphBlock(
      id: _uniqueBlockId('$blockId-after-math'),
      children: _hasVisibleInlineContent(afterChildren)
          ? afterChildren
          : const [MarkdownText('')],
    );
    final replacements = <MarkdownBlock>[
      if (_hasVisibleInlineContent(beforeChildren))
        _copyTextBlockWithChildren(block, beforeChildren),
      mathBlock,
      afterBlock,
    ];

    if (_document.blocks[topLevelIndex].id != blockId) {
      final container = _document.blocks[topLevelIndex];
      final nextContainer = container.replaceNestedBlockWithBlocks(
        blockId,
        replacements,
      );
      if (identical(nextContainer, container)) return null;

      final activeAfterBlock = MarkdownParagraphBlock(
        id: _uniqueBlockId('${container.id}-after-math'),
        children: const [MarkdownText('')],
      );
      _replaceDocument(
        MarkdownDocument(
          blocks: [
            ..._document.blocks.take(topLevelIndex),
            nextContainer,
            activeAfterBlock,
            ..._document.blocks.skip(topLevelIndex + 1),
          ],
        ),
      );

      return MarkdownBlockMathInsertResult(
        document: _document,
        blockId: mathId,
        activeBlockId: activeAfterBlock.id,
        selectionOffset: 0,
      );
    }

    _replaceDocument(
      MarkdownDocument(
        blocks: [
          ..._document.blocks.take(topLevelIndex),
          ...replacements,
          ..._document.blocks.skip(topLevelIndex + 1),
        ],
      ),
    );

    return MarkdownBlockMathInsertResult(
      document: _document,
      blockId: mathId,
      activeBlockId: afterBlock.id,
      selectionOffset: 0,
    );
  }

  /// Inserts parsed Markdown [blocks] into a plain-text range.
  ///
  /// The text before and after [range] is preserved as sibling text blocks,
  /// matching TipTap's `insertContent(parsedMarkdown)` behavior when block
  /// Markdown is pasted into the middle of a paragraph.
  MarkdownBlockPasteResult? replaceTextRangeWithBlocks(
    String blockId,
    TextRange range,
    List<MarkdownBlock> blocks,
  ) {
    if (blocks.isEmpty) return null;

    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return null;
    }

    final text = block!.plainText;
    final start = range.start.clamp(0, text.length).toInt();
    final end = range.end.clamp(start, text.length).toInt();
    final children = _textBlockChildren(block);
    final beforeSplit = _splitInlineNodes(children, start);
    final afterSplit = _splitInlineNodes(beforeSplit.after, end - start);
    final beforeChildren = beforeSplit.before;
    final afterChildren = afterSplit.after;
    final hasBefore = _hasVisibleInlineContent(beforeChildren);
    final hasAfter = _hasVisibleInlineContent(afterChildren);
    final beforeBlock =
        hasBefore ? _copyTextBlockWithChildren(block, beforeChildren) : null;
    final afterBlock =
        hasAfter ? _afterTextBlockForRangePaste(block, afterChildren) : null;
    final insertedBlocks = _retagBlocksForDocumentInsertion(
      blocks,
      additionalReservedBlocks: [
        if (afterBlock != null) afterBlock,
      ],
    );
    final replacements = <MarkdownBlock>[
      if (beforeBlock != null) beforeBlock,
      ...insertedBlocks,
      if (afterBlock != null) afterBlock,
    ];

    final topLevelIndex = _topLevelBlockIndexContaining(blockId);
    if (topLevelIndex == -1) return null;

    final insertedMarkdown =
        MarkdownDocument(blocks: insertedBlocks).toMarkdown();
    if (_document.blocks[topLevelIndex].id == blockId) {
      final beforeMarkdown = beforeBlock?.toMarkdown() ?? '';
      final selectionOffset = beforeMarkdown.isEmpty
          ? insertedMarkdown.length
          : beforeMarkdown.length + 2 + insertedMarkdown.length;
      final nextDocument = _document.replaceBlockWithBlocks(
        blockId,
        replacements,
      );
      if (!_replaceDocument(nextDocument)) return null;

      return MarkdownBlockPasteResult(
        document: _document,
        selectionOffset: selectionOffset,
      );
    }

    final container = _document.blocks[topLevelIndex];
    final nextContainer = container.replaceNestedBlockWithBlocks(
      blockId,
      replacements,
    );
    if (identical(nextContainer, container)) return null;

    _replaceDocument(
      MarkdownDocument(
        blocks: [
          ..._document.blocks.take(topLevelIndex),
          nextContainer,
          ..._document.blocks.skip(topLevelIndex + 1),
        ],
      ),
    );

    return MarkdownBlockPasteResult(
      document: _document,
      selectionOffset: nextContainer.toMarkdown().length,
    );
  }

  /// Replaces a plain-text range with a standalone image block.
  ///
  /// Surrounding text is preserved as text blocks before and after the inserted
  /// image. This mirrors TipTap Image with `inline: false`, where typed
  /// `![alt](src)` becomes a block image even when entered from a paragraph.
  MarkdownImageBlockInsertResult? replaceTextRangeWithImageBlock(
    String blockId,
    TextRange range, {
    required String url,
    required String alt,
    String? title,
    bool preserveEmptyBefore = false,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return null;
    }

    final text = block!.plainText;
    final start = range.start.clamp(0, text.length).toInt();
    final end = range.end.clamp(start, text.length).toInt();
    final children = _textBlockChildren(block);
    final beforeSplit = _splitInlineNodes(children, start);
    final afterSplit = _splitInlineNodes(beforeSplit.after, end - start);
    final beforeChildren = beforeSplit.before;
    final afterChildren = afterSplit.after;

    return _replaceTextBlockWithImageParts(
      blockId,
      block,
      beforeChildren: beforeChildren,
      afterChildren: afterChildren,
      url: url,
      alt: alt,
      preserveEmptyBefore: preserveEmptyBefore,
      title: title,
    );
  }

  MarkdownImageBlockInsertResult? _replaceTextBlockWithImageParts(
    String blockId,
    MarkdownBlock block, {
    required List<MarkdownInlineNode> beforeChildren,
    required List<MarkdownInlineNode> afterChildren,
    required String url,
    required String alt,
    required bool preserveEmptyBefore,
    String? title,
  }) {
    final imageId = _uniqueBlockId('$blockId-image');
    final afterId = _uniqueBlockId('$blockId-after-image');
    final beforeBlock = _copyTextBlockWithChildren(
      block,
      _hasVisibleInlineContent(beforeChildren) || preserveEmptyBefore
          ? beforeChildren
          : const [MarkdownText('')],
    );
    final imageBlock = MarkdownImageBlock(
      id: imageId,
      url: url,
      alt: alt,
      title: title,
    );
    final afterBlock = MarkdownParagraphBlock(
      id: afterId,
      children: _hasVisibleInlineContent(afterChildren)
          ? afterChildren
          : const [MarkdownText('')],
    );

    final topLevelIndex = _topLevelBlockIndexContaining(blockId);
    if (topLevelIndex == -1) return null;

    if (_document.blocks[topLevelIndex].id == blockId) {
      final replacements = <MarkdownBlock>[
        if (_hasVisibleInlineContent(beforeChildren) || preserveEmptyBefore)
          beforeBlock,
        imageBlock,
        afterBlock,
      ];

      final nextDocument =
          _document.replaceBlockWithBlocks(blockId, replacements);
      if (!_replaceDocument(nextDocument)) return null;

      return MarkdownImageBlockInsertResult(
        document: _document,
        blockId: imageId,
        activeBlockId: afterBlock.id,
        selectionOffset: 0,
      );
    }

    final hasVisibleAfter = _hasVisibleInlineContent(afterChildren);
    final nestedReplacements = <MarkdownBlock>[
      if (_hasVisibleInlineContent(beforeChildren) || preserveEmptyBefore)
        beforeBlock,
      imageBlock,
      if (hasVisibleAfter) afterBlock,
    ];
    final container = _document.blocks[topLevelIndex];
    final nextContainer = container.replaceNestedBlockWithBlocks(
      blockId,
      nestedReplacements,
    );
    if (identical(nextContainer, container)) return null;

    final activeAfterBlock = hasVisibleAfter
        ? afterBlock
        : MarkdownParagraphBlock(
            id: _uniqueBlockId('${container.id}-after-image'),
            children: const [MarkdownText('')],
          );
    _replaceDocument(
      MarkdownDocument(
        blocks: [
          ..._document.blocks.take(topLevelIndex),
          nextContainer,
          if (!hasVisibleAfter) activeAfterBlock,
          ..._document.blocks.skip(topLevelIndex + 1),
        ],
      ),
    );

    return MarkdownImageBlockInsertResult(
      document: _document,
      blockId: imageId,
      activeBlockId: activeAfterBlock.id,
      selectionOffset: 0,
    );
  }

  /// Replaces the visible plain text of a paragraph or heading while preserving
  /// existing inline nodes outside the changed range.
  bool replaceTextBlockText(String blockId, String text) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return false;
    }

    final previous = block!.plainText;
    if (previous == text) return true;

    final diff = _plainTextDiff(previous, text);
    return replaceTextRange(block.id, diff.range, diff.replacement);
  }

  /// Applies Scratch-style Markdown input rules to [blockId].
  ///
  /// Returns null when no rule matched. The caller should only invoke this after
  /// text input changes in a paragraph-like block.
  MarkdownInputRuleResult? applyInputRules({
    required String blockId,
    required String text,
    required int selectionOffset,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock) return null;
    if (selectionOffset != text.length) return null;

    MarkdownBlock? replacement;
    String? activeBlockId;
    const nextSelectionOffset = 0;

    final heading = RegExp(r'^(#{1,6})\s$').firstMatch(text);
    final codeFence = RegExp(r'^(```|~~~)([a-z]+)?[\s\n]$').firstMatch(text);
    final blockMath = RegExp(r'^\$\$([^$]+)\$\$$').firstMatch(text);
    final taskItem = _taskItemInput(text);
    if (taskItem != null) {
      final nextList = _taskItemInputListInBlocks(
        _document.blocks,
        blockId,
        checked: taskItem,
      );
      if (nextList != null) {
        _replaceDocument(_document.replaceBlock(nextList));
        return MarkdownInputRuleResult(
          document: _document,
          activeBlockId: blockId,
          selectionOffset: nextSelectionOffset,
        );
      }
    }

    if (heading != null) {
      replacement = MarkdownHeadingBlock(
        id: block.id,
        level: heading.group(1)!.length,
        children: const [MarkdownText('')],
      );
      activeBlockId = replacement.id;
    } else if (_isBlockquoteInput(text)) {
      final paragraphId = '$blockId-quote-p';
      replacement = MarkdownBlockquoteBlock(
        id: block.id,
        blocks: [
          MarkdownParagraphBlock(
            id: paragraphId,
            children: const [MarkdownText('')],
          ),
        ],
      );
      activeBlockId = paragraphId;
    } else if (_isBulletListInput(text)) {
      replacement = _emptyList(block.id, MarkdownListKind.bullet);
      activeBlockId = '$blockId-item-0-p';
    } else if (RegExp(r'^\d+\.\s$').hasMatch(text)) {
      final number = int.tryParse(text.substring(0, text.length - 2)) ?? 1;
      final paragraphId = '$blockId-item-0-p';
      replacement = MarkdownListBlock(
        id: block.id,
        kind: MarkdownListKind.ordered,
        startIndex: number,
        items: [
          MarkdownListItem(
            id: '$blockId-item-0',
            blocks: [
              MarkdownParagraphBlock(
                id: paragraphId,
                children: const [MarkdownText('')],
              ),
            ],
          ),
        ],
      );
      activeBlockId = paragraphId;
    } else if (text == '- [ ] ' || text == '- [x] ' || text == '- [X] ') {
      replacement = _emptyList(
        block.id,
        MarkdownListKind.task,
        checked: text.toLowerCase() == '- [x] ',
      );
      activeBlockId = '$blockId-item-0-p';
    } else if (codeFence != null) {
      final fence = codeFence.group(1)!;
      final language = codeFence.group(2) ?? '';
      replacement = language == 'mermaid'
          ? MarkdownMermaidBlock(
              id: block.id,
              code: '',
              theme: null,
              fence: fence,
              info: 'mermaid',
            )
          : MarkdownCodeBlock(
              id: block.id,
              language: language,
              code: '',
              fence: fence,
              info: language.isEmpty ? null : language,
            );
      activeBlockId = replacement.id;
    } else if (blockMath != null) {
      final latex = blockMath.group(1)!.trim();
      if (latex.isEmpty) return null;
      replacement = MarkdownBlockMathBlock(
        id: block.id,
        latex: latex,
      );
      activeBlockId = replacement.id;
    } else if (_isHorizontalRuleInput(text)) {
      final paragraphId = _uniqueBlockId('$blockId-after-hr');
      final nextDocument = _document.replaceBlockWithBlocks(
        block.id,
        [
          MarkdownHorizontalRuleBlock(id: block.id),
          MarkdownParagraphBlock(
            id: paragraphId,
            children: const [MarkdownText('')],
          ),
        ],
      );
      if (!_replaceDocument(nextDocument)) return null;
      return MarkdownInputRuleResult(
        document: _document,
        activeBlockId: paragraphId,
        selectionOffset: nextSelectionOffset,
      );
    }

    if (replacement == null) return null;

    _replaceDocument(_replaceInputRuleBlock(block.id, replacement));
    return MarkdownInputRuleResult(
      document: _document,
      activeBlockId: activeBlockId ?? replacement.id,
      selectionOffset: nextSelectionOffset,
    );
  }

  /// Updates code block language.
  void updateCodeBlockLanguage(String blockId, String language) {
    final block = _document.blockById(blockId);
    if (block is MarkdownCodeBlock) {
      if (language == 'mermaid') {
        replaceBlock(
          MarkdownMermaidBlock(
            id: block.id,
            code: block.code,
            fence: block.fence,
            info: 'mermaid',
          ),
        );
      } else {
        replaceBlock(block.copyWith(language: language, info: language));
      }
    } else if (block is MarkdownMermaidBlock && language != 'mermaid') {
      replaceBlock(
        MarkdownCodeBlock(
          id: block.id,
          language: language,
          code: block.code,
          fence: block.fence,
          info: language,
        ),
      );
    }
  }

  /// Updates Mermaid source.
  void updateMermaidCode(String blockId, String code) {
    final block = _document.blockById(blockId);
    if (block is MarkdownMermaidBlock) {
      replaceBlock(block.copyWith(code: code));
    }
  }

  /// Updates block math source.
  void updateBlockMath(String blockId, String latex) {
    final block = _document.blockById(blockId);
    if (block is MarkdownBlockMathBlock) {
      replaceBlock(block.copyWith(latex: latex));
    }
  }

  /// Updates frontmatter content.
  void updateFrontmatter(String blockId, String content) {
    final block = _document.blockById(blockId);
    if (block is MarkdownFrontmatterBlock) {
      replaceBlock(block.copyWith(content: content));
    }
  }

  bool _isHorizontalRuleInput(String text) {
    return text == '---' ||
        text == '\u2014-' ||
        RegExp(r'^(?:___|\*\*\*)\s$').hasMatch(text);
  }

  bool _isBulletListInput(String text) {
    return RegExp(r'^\s*[-+*]\s$').hasMatch(text);
  }

  bool _isBlockquoteInput(String text) {
    return RegExp(r'^\s*>\s$').hasMatch(text);
  }

  bool? _taskItemInput(String text) {
    final match = RegExp(r'^\s*\[( |x|X)?\]\s$').firstMatch(text);
    if (match == null) return null;
    return match.group(1)?.toLowerCase() == 'x';
  }

  MarkdownDocument _replaceInputRuleBlock(
    String blockId,
    MarkdownBlock replacement,
  ) {
    final joinedBlocks = _replaceWithJoinedWrappingInputInBlocks(
      _document.blocks,
      blockId,
      replacement,
    );
    if (joinedBlocks != null) return MarkdownDocument(blocks: joinedBlocks);
    return _document.replaceBlock(replacement);
  }

  List<MarkdownBlock>? _replaceWithJoinedWrappingInputInBlocks(
    List<MarkdownBlock> blocks,
    String blockId,
    MarkdownBlock replacement,
  ) {
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      if (block.id == blockId) {
        if (index == 0) return null;
        final joined = _joinWrappingInputBlocks(
          blocks[index - 1],
          replacement,
        );
        if (joined == null) return null;
        return [
          ...blocks.take(index - 1),
          joined,
          ...blocks.skip(index + 1),
        ];
      }

      final nested = _replaceWithJoinedWrappingInputInBlock(
        block,
        blockId,
        replacement,
      );
      if (nested != null) {
        return [
          ...blocks.take(index),
          nested,
          ...blocks.skip(index + 1),
        ];
      }
    }
    return null;
  }

  MarkdownBlock? _replaceWithJoinedWrappingInputInBlock(
    MarkdownBlock block,
    String blockId,
    MarkdownBlock replacement,
  ) {
    if (block is MarkdownBlockquoteBlock) {
      final blocks = _replaceWithJoinedWrappingInputInBlocks(
        block.blocks,
        blockId,
        replacement,
      );
      return blocks == null ? null : block.copyWith(blocks: blocks);
    }

    if (block is MarkdownListBlock) {
      for (var index = 0; index < block.items.length; index++) {
        final item = block.items[index];
        final blocks = _replaceWithJoinedWrappingInputInBlocks(
          item.blocks,
          blockId,
          replacement,
        );
        if (blocks != null) {
          return block.copyWith(
            items: [
              ...block.items.take(index),
              item.copyWith(blocks: blocks),
              ...block.items.skip(index + 1),
            ],
          );
        }
      }
    }

    return null;
  }

  MarkdownBlock? _joinWrappingInputBlocks(
    MarkdownBlock previous,
    MarkdownBlock replacement,
  ) {
    if (previous is MarkdownBlockquoteBlock &&
        replacement is MarkdownBlockquoteBlock) {
      return previous.copyWith(
        blocks: [
          ...previous.blocks,
          ...replacement.blocks,
        ],
      );
    }

    if (previous is! MarkdownListBlock || replacement is! MarkdownListBlock) {
      return null;
    }
    if (previous.kind != replacement.kind) return null;

    if (previous.kind == MarkdownListKind.ordered &&
        previous.startIndex + previous.items.length != replacement.startIndex) {
      return null;
    }

    return previous.copyWith(
      items: [
        ...previous.items,
        ...replacement.items,
      ],
    );
  }

  /// Applies a table edit.
  void updateTable(
    String blockId,
    MarkdownTableBlock Function(MarkdownTableBlock table) update,
  ) {
    final block = _document.blockById(blockId);
    if (block is MarkdownTableBlock) {
      replaceBlock(update(block));
    }
  }

  /// Updates one table cell with plain text.
  void updateTableCellText({
    required String blockId,
    required int rowIndex,
    required int columnIndex,
    required String text,
    bool header = false,
  }) {
    updateTable(
      blockId,
      (table) => table.updateCell(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        header: header,
        children: [MarkdownText(text)],
      ),
    );
  }

  /// Replaces the visible plain text of one table cell while preserving
  /// existing inline nodes outside the changed range.
  bool replaceTableCellText({
    required String blockId,
    required int rowIndex,
    required int columnIndex,
    required String text,
    bool header = false,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownTableBlock) return false;

    final children = _tableCellInlineChildren(
      block,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      header: header,
    );
    if (children == null) return false;

    final previous = _inlinePlainText(children);
    if (previous == text) return true;

    final diff = _plainTextDiff(previous, text);
    final nextChildren = _replaceInlineRange(
      children,
      diff.range,
      diff.replacement,
    );

    updateTable(
      blockId,
      (table) => table.updateCell(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        header: header,
        children: nextChildren,
      ),
    );
    return true;
  }

  /// Replaces a plain-text range inside one table cell with inline nodes.
  bool replaceTableCellRangeWithInlineNodes({
    required String blockId,
    required int rowIndex,
    required int columnIndex,
    required TextRange range,
    required List<MarkdownInlineNode> replacement,
    bool header = false,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownTableBlock) return false;

    final children = _tableCellInlineChildren(
      block,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      header: header,
    );
    if (children == null) return false;

    final plainText = _inlinePlainText(children);
    final start = range.start.clamp(0, plainText.length);
    final end = range.end.clamp(start, plainText.length);
    final nextChildren = _replaceInlineRangeWithNodes(
      children,
      TextRange(start: start, end: end),
      replacement,
    );

    updateTable(
      blockId,
      (table) => table.updateCell(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        header: header,
        children: nextChildren,
      ),
    );
    return true;
  }

  /// Inserts an empty row after [rowIndex].
  void insertTableRowAfter(String blockId, int rowIndex) {
    updateTable(blockId, (table) => table.insertRowAfter(rowIndex));
  }

  /// Inserts an empty row before [rowIndex].
  void insertTableRowBefore(String blockId, int rowIndex) {
    updateTable(blockId, (table) => table.insertRowBefore(rowIndex));
  }

  /// Deletes table row [rowIndex].
  void deleteTableRow(String blockId, int rowIndex) {
    updateTable(blockId, (table) => table.deleteRow(rowIndex));
  }

  /// Inserts an empty column after [columnIndex].
  void insertTableColumnAfter(String blockId, int columnIndex) {
    updateTable(blockId, (table) => table.insertColumnAfter(columnIndex));
  }

  /// Inserts an empty column before [columnIndex].
  void insertTableColumnBefore(String blockId, int columnIndex) {
    updateTable(blockId, (table) => table.insertColumnBefore(columnIndex));
  }

  /// Deletes table column [columnIndex].
  void deleteTableColumn(String blockId, int columnIndex) {
    updateTable(blockId, (table) => table.deleteColumn(columnIndex));
  }

  /// Toggles the first row between header and body semantics.
  void toggleTableHeaderRow(String blockId) {
    updateTable(blockId, (table) => table.toggleHeaderRow());
  }

  /// Toggles the first column between header and body semantics.
  void toggleTableHeaderColumn(String blockId) {
    updateTable(blockId, (table) => table.toggleHeaderColumn());
  }

  /// Deletes the whole table block.
  void deleteTable(String blockId) {
    removeBlock(blockId);
  }

  /// Updates one list item by ID.
  void updateListItem(
    String itemId,
    MarkdownListItem Function(MarkdownListItem item) update,
  ) {
    final nextBlocks =
        _updateListItemInBlocks(_document.blocks, itemId, update);
    if (identical(nextBlocks, _document.blocks)) return;
    _replaceDocument(MarkdownDocument(blocks: nextBlocks));
  }

  /// Updates a task-list checkbox state.
  void updateListItemChecked(String itemId, bool checked) {
    updateListItem(itemId, (item) => item.copyWith(checked: checked));
  }

  /// Splits a paragraph-like block at [selectionOffset].
  ///
  /// This models the rich-editor Enter key: paragraphs split into paragraphs,
  /// headings continue as a paragraph, list items create the next item, and an
  /// empty list item exits the list.
  MarkdownSplitBlockResult? splitBlockAt({
    required String blockId,
    required int selectionOffset,
  }) {
    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return null;
    }
    final textBlock = block!;

    final topLevelIndex = _document.blocks.indexWhere(
      (block) => block.id == blockId,
    );
    if (topLevelIndex != -1) {
      return _splitTopLevelTextBlock(
        topLevelIndex,
        textBlock,
        selectionOffset,
      );
    }

    final nestedEdit = _splitNestedTextBlockInBlocks(
      blocks: _document.blocks,
      blockId: blockId,
      selectionOffset: selectionOffset,
    );
    if (nestedEdit == null) return null;

    final nestedResult = MarkdownSplitBlockResult(
      document: MarkdownDocument(blocks: nestedEdit.blocks),
      activeBlockId: nestedEdit.activeBlockId,
      selectionOffset: nestedEdit.selectionOffset,
    );
    _replaceDocument(nestedResult.document);
    return nestedResult;
  }

  /// Applies rich-editor Backspace semantics at [selectionOffset].
  ///
  /// Only collapsed carets at the start of paragraph-like blocks are handled.
  /// Top-level text blocks join with the previous text block, list items join
  /// with the previous item, and the first list item exits the list.
  MarkdownDeleteBackwardResult? deleteBackwardAt({
    required String blockId,
    required int selectionOffset,
  }) {
    if (selectionOffset != 0) return null;

    final block = _document.blockById(blockId);
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return null;
    }

    final topLevelIndex = _document.blocks.indexWhere(
      (block) => block.id == blockId,
    );
    if (topLevelIndex != -1) {
      return _deleteBackwardTopLevelTextBlock(topLevelIndex);
    }

    final nestedEdit = _deleteBackwardNestedTextBlockInBlocks(
      blocks: _document.blocks,
      blockId: blockId,
    );
    if (nestedEdit == null) return null;

    final nestedResult = MarkdownDeleteBackwardResult(
      document: MarkdownDocument(blocks: nestedEdit.blocks),
      activeBlockId: nestedEdit.activeBlockId,
      selectionOffset: nestedEdit.selectionOffset,
    );
    _replaceDocument(nestedResult.document);
    return nestedResult;
  }

  /// Indents the list item containing [blockId] into the previous sibling item.
  MarkdownListIndentResult? indentListItemContainingBlock({
    required String blockId,
    required int selectionOffset,
  }) {
    final nextBlocks = _indentListItemInBlocks(_document.blocks, blockId);
    if (nextBlocks == null) return null;

    _replaceDocument(MarkdownDocument(blocks: nextBlocks));
    return MarkdownListIndentResult(
      document: _document,
      activeBlockId: blockId,
      selectionOffset: selectionOffset,
    );
  }

  /// Outdents the list item containing [blockId] by one nesting level.
  MarkdownListIndentResult? outdentListItemContainingBlock({
    required String blockId,
    required int selectionOffset,
  }) {
    final nextBlocks = _outdentListItemInBlocks(_document.blocks, blockId);
    if (nextBlocks == null) return null;

    _replaceDocument(MarkdownDocument(blocks: nextBlocks));
    return MarkdownListIndentResult(
      document: _document,
      activeBlockId: blockId,
      selectionOffset: selectionOffset,
    );
  }

  MarkdownParagraphBlock _asParagraph(MarkdownBlock block) {
    if (block is MarkdownParagraphBlock) return block;
    return MarkdownParagraphBlock(
      id: block.id,
      children: [MarkdownText(block.plainText)],
    );
  }

  MarkdownHeadingBlock _asHeading(MarkdownBlock block, int level) {
    if (block is MarkdownHeadingBlock) {
      return block.copyWith(level: level);
    }
    return MarkdownHeadingBlock(
      id: block.id,
      level: level,
      children: [MarkdownText(block.plainText)],
    );
  }

  MarkdownListBlock _asList(MarkdownBlock block, MarkdownListKind kind) {
    return MarkdownListBlock(
      id: block.id,
      kind: kind,
      items: [
        MarkdownListItem(
          id: '${block.id}-item-0',
          blocks: [
            MarkdownParagraphBlock(
              id: '${block.id}-item-0-p',
              children: [MarkdownText(block.plainText)],
            ),
          ],
        ),
      ],
    );
  }

  MarkdownListBlock _emptyList(
    String id,
    MarkdownListKind kind, {
    bool checked = false,
  }) {
    return MarkdownListBlock(
      id: id,
      kind: kind,
      items: [
        MarkdownListItem(
          id: '$id-item-0',
          checked: checked,
          blocks: [
            MarkdownParagraphBlock(
              id: '$id-item-0-p',
              children: const [MarkdownText('')],
            ),
          ],
        ),
      ],
    );
  }

  MarkdownBlock? _wrapRange(
      MarkdownBlock? block, TextRange range, _InlineWrap wrap,
      {String? argument}) {
    if (block is! MarkdownParagraphBlock && block is! MarkdownHeadingBlock) {
      return null;
    }

    final children = block is MarkdownParagraphBlock
        ? block.children
        : (block as MarkdownHeadingBlock).children;
    final nextChildren = _wrapInlineRange(
      children,
      range,
      wrap,
      argument: argument,
    );
    if (nextChildren == null) return null;

    if (block is MarkdownParagraphBlock) {
      return block.copyWith(children: nextChildren);
    }
    return (block as MarkdownHeadingBlock).copyWith(children: nextChildren);
  }

  List<MarkdownInlineNode>? _wrapInlineRange(
      List<MarkdownInlineNode> children, TextRange range, _InlineWrap wrap,
      {String? argument}) {
    final plainText = _inlinePlainText(children);
    final start = range.start.clamp(0, plainText.length).toInt();
    final end = range.end.clamp(start, plainText.length).toInt();
    if (start == end) return null;

    final beforeSplit = _splitInlineNodes(children, start);
    final selectedSplit = _splitInlineNodes(
      beforeSplit.after,
      end - start,
    );
    final selected = _removeEmptyInlineSentinel(selectedSplit.before);
    if (selected.isEmpty) return null;

    return _normalizeInlineChildren([
      ..._removeEmptyInlineSentinel(beforeSplit.before),
      _wrappedInline(selected, wrap, argument: argument),
      ..._removeEmptyInlineSentinel(selectedSplit.after),
    ]);
  }

  MarkdownInlineNode _wrappedInline(
      List<MarkdownInlineNode> children, _InlineWrap wrap,
      {String? argument}) {
    return switch (wrap) {
      _InlineWrap.strong => MarkdownStrong(children),
      _InlineWrap.emphasis => MarkdownEmphasis(children),
      _InlineWrap.strikethrough => MarkdownStrikethrough(children),
      _InlineWrap.code => MarkdownInlineCode(_inlinePlainText(children)),
      _InlineWrap.link => MarkdownLink(
          url: argument ?? 'https://example.com',
          children: children,
        ),
      _InlineWrap.image => MarkdownImage(
          url: argument ?? 'image-url',
          alt: _inlinePlainText(children),
        ),
      _InlineWrap.wikilink => MarkdownWikilink(
          target: _inlinePlainText(children),
        ),
    };
  }

  _InlineWrap? _inlineWrapForCommand(MarkdownEditorCommand command) {
    return switch (command) {
      MarkdownEditorCommand.bold => _InlineWrap.strong,
      MarkdownEditorCommand.italic => _InlineWrap.emphasis,
      MarkdownEditorCommand.strikethrough => _InlineWrap.strikethrough,
      MarkdownEditorCommand.inlineCode => _InlineWrap.code,
      MarkdownEditorCommand.link => _InlineWrap.link,
      MarkdownEditorCommand.image => _InlineWrap.image,
      MarkdownEditorCommand.wikilink => _InlineWrap.wikilink,
      _ => null,
    };
  }

  String? _inlineArgumentForCommand(
    MarkdownEditorCommand command,
    String? argument,
  ) {
    return switch (command) {
      MarkdownEditorCommand.link =>
        argument == null || argument.isEmpty ? 'https://example.com' : argument,
      MarkdownEditorCommand.image =>
        argument == null || argument.isEmpty ? 'image-url' : argument,
      _ => argument,
    };
  }

  _PlainTextDiff _plainTextDiff(String previous, String next) {
    var prefix = 0;
    final minLength =
        previous.length < next.length ? previous.length : next.length;
    while (prefix < minLength && previous[prefix] == next[prefix]) {
      prefix++;
    }

    var previousSuffix = previous.length;
    var nextSuffix = next.length;
    while (previousSuffix > prefix &&
        nextSuffix > prefix &&
        previous[previousSuffix - 1] == next[nextSuffix - 1]) {
      previousSuffix--;
      nextSuffix--;
    }

    return _PlainTextDiff(
      range: TextRange(start: prefix, end: previousSuffix),
      replacement: next.substring(prefix, nextSuffix),
    );
  }

  List<MarkdownInlineNode> _replaceInlineRange(
    List<MarkdownInlineNode> children,
    TextRange range,
    String replacement,
  ) {
    final plainText = children.map((child) => child.plainText).join();
    final start = range.start.clamp(0, plainText.length).toInt();
    final end = range.end.clamp(start, plainText.length).toInt();

    final beforeSplit = _splitInlineNodes(children, start);
    final removedSplit = _splitInlineNodes(
      beforeSplit.after,
      end - start,
    );
    final inserted = replacement.isEmpty
        ? const <MarkdownInlineNode>[]
        : _wrapInsertedInlineText(
            children,
            start,
            replacement,
            collapsed: start == end,
          );

    return _normalizeInlineChildren([
      ..._removeEmptyInlineSentinel(beforeSplit.before),
      ...inserted,
      ..._removeEmptyInlineSentinel(removedSplit.after),
    ]);
  }

  List<MarkdownInlineNode> _replaceInlineRangeWithNodes(
    List<MarkdownInlineNode> children,
    TextRange range,
    List<MarkdownInlineNode> replacement,
  ) {
    final plainText = _inlinePlainText(children);
    final start = range.start.clamp(0, plainText.length).toInt();
    final end = range.end.clamp(start, plainText.length).toInt();

    final beforeSplit = _splitInlineNodes(children, start);
    final removedSplit = _splitInlineNodes(
      beforeSplit.after,
      end - start,
    );

    return _normalizeInlineChildren([
      ..._removeEmptyInlineSentinel(beforeSplit.before),
      ..._removeEmptyInlineSentinel(replacement),
      ..._removeEmptyInlineSentinel(removedSplit.after),
    ]);
  }

  MarkdownLinkEdit? _linkInInlineRange(
    List<MarkdownInlineNode> children,
    TextRange range,
  ) {
    final plainText = _inlinePlainText(children);
    final start = range.start.clamp(0, plainText.length).toInt();
    final end = range.end.clamp(start, plainText.length).toInt();
    final probe = start == end && start > 0 ? start - 1 : start;
    return _linkInInlineNodesAt(children, probe, baseOffset: 0);
  }

  MarkdownLinkEdit? _linkInInlineNodesAt(
    List<MarkdownInlineNode> nodes,
    int offset, {
    required int baseOffset,
  }) {
    var cursor = baseOffset;
    for (final node in nodes) {
      final length = node.plainText.length;
      final end = cursor + length;
      final contains =
          length == 0 ? offset == cursor : offset >= cursor && offset < end;
      if (!contains) {
        cursor = end;
        continue;
      }

      if (node is MarkdownLink) {
        return MarkdownLinkEdit(
          range: TextRange(start: cursor, end: end),
          url: node.url,
          title: node.title,
          children: node.children,
        );
      }

      final childNodes = switch (node) {
        MarkdownStrong() => node.children,
        MarkdownEmphasis() => node.children,
        MarkdownStrikethrough() => node.children,
        _ => null,
      };
      if (childNodes != null) {
        final nested = _linkInInlineNodesAt(
          childNodes,
          offset,
          baseOffset: cursor,
        );
        if (nested != null) return nested;
      }

      return null;
    }
    return null;
  }

  List<MarkdownInlineNode>? _replaceLinkInInlineRange(
    List<MarkdownInlineNode> nodes,
    TextRange range,
    List<MarkdownInlineNode> Function(MarkdownLink link) replacement,
  ) {
    final plainText = _inlinePlainText(nodes);
    final start = range.start.clamp(0, plainText.length).toInt();
    final probe = start == range.end && start > 0 ? start - 1 : start;
    return _replaceLinkInInlineNodesAt(
      nodes,
      probe,
      baseOffset: 0,
      replacement: replacement,
    );
  }

  List<MarkdownInlineNode>? _replaceLinkInInlineNodesAt(
    List<MarkdownInlineNode> nodes,
    int offset, {
    required int baseOffset,
    required List<MarkdownInlineNode> Function(MarkdownLink link) replacement,
  }) {
    var cursor = baseOffset;
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final length = node.plainText.length;
      final end = cursor + length;
      final contains =
          length == 0 ? offset == cursor : offset >= cursor && offset < end;
      if (!contains) {
        cursor = end;
        continue;
      }

      if (node is MarkdownLink) {
        return _normalizeInlineChildren([
          ...nodes.take(index),
          ...replacement(node),
          ...nodes.skip(index + 1),
        ]);
      }

      final childNodes = switch (node) {
        MarkdownStrong() => node.children,
        MarkdownEmphasis() => node.children,
        MarkdownStrikethrough() => node.children,
        _ => null,
      };
      if (childNodes == null) return null;

      final nextChildren = _replaceLinkInInlineNodesAt(
        childNodes,
        offset,
        baseOffset: cursor,
        replacement: replacement,
      );
      if (nextChildren == null) return null;

      final nextNode = switch (node) {
        MarkdownStrong() => MarkdownStrong(nextChildren),
        MarkdownEmphasis() => MarkdownEmphasis(nextChildren),
        MarkdownStrikethrough() => MarkdownStrikethrough(nextChildren),
        _ => node,
      };
      return _normalizeInlineChildren([
        ...nodes.take(index),
        nextNode,
        ...nodes.skip(index + 1),
      ]);
    }
    return null;
  }

  List<MarkdownInlineNode> _wrapInsertedInlineText(
    List<MarkdownInlineNode> children,
    int offset,
    String text, {
    required bool collapsed,
  }) {
    var nodes = _inlineNodesFromPlainText(text);
    if (!collapsed) return nodes;

    final wrappers = _inlineWrappersAtOffset(children, offset);
    for (final wrapper in wrappers.reversed) {
      nodes = [wrapper.wrap(nodes)];
    }
    return nodes;
  }

  List<MarkdownInlineNode> _inlineNodesFromPlainText(String text) {
    if (text.isEmpty) return const [];
    final nodes = <MarkdownInlineNode>[];
    final parts = text.split('\n');
    for (var index = 0; index < parts.length; index++) {
      if (index > 0) {
        nodes.add(const MarkdownHardBreak());
      }
      if (parts[index].isNotEmpty) {
        nodes.add(MarkdownText(parts[index]));
      }
    }
    return nodes;
  }

  List<_InlineWrapper> _inlineWrappersAtOffset(
    List<MarkdownInlineNode> children,
    int offset,
  ) {
    var cursor = 0;
    for (final child in children) {
      final length = child.plainText.length;
      final end = cursor + length;
      final inside = offset > cursor && offset < end;
      if (inside) {
        return _inlineWrappersInsideNode(child, offset - cursor);
      }
      cursor = end;
    }
    return const [];
  }

  List<_InlineWrapper> _inlineWrappersInsideNode(
    MarkdownInlineNode node,
    int offset,
  ) {
    switch (node) {
      case MarkdownStrong():
        return [
          const _StrongInlineWrapper(),
          ..._inlineWrappersAtOffset(node.children, offset),
        ];
      case MarkdownEmphasis():
        return [
          const _EmphasisInlineWrapper(),
          ..._inlineWrappersAtOffset(node.children, offset),
        ];
      case MarkdownStrikethrough():
        return [
          const _StrikethroughInlineWrapper(),
          ..._inlineWrappersAtOffset(node.children, offset),
        ];
      case MarkdownLink():
        return [
          _LinkInlineWrapper(url: node.url, title: node.title),
          ..._inlineWrappersAtOffset(node.children, offset),
        ];
      case MarkdownInlineCode():
        return const [_InlineCodeWrapper()];
      case MarkdownInlineMath():
        return const [_InlineMathWrapper()];
      default:
        return const [];
    }
  }

  List<MarkdownInlineNode> _removeEmptyInlineSentinel(
    List<MarkdownInlineNode> nodes,
  ) {
    return nodes
        .where((node) => node is! MarkdownText || node.text.isNotEmpty)
        .toList();
  }

  List<MarkdownInlineNode>? _tableCellInlineChildren(
    MarkdownTableBlock table, {
    required int rowIndex,
    required int columnIndex,
    required bool header,
  }) {
    if (columnIndex < 0 || columnIndex >= table.columnCount) return null;
    if (header) {
      return columnIndex < table.headers.length
          ? table.headers[columnIndex]
          : null;
    }

    if (rowIndex < 0 || rowIndex >= table.rows.length) return null;
    final row = table.rows[rowIndex];
    return columnIndex < row.length ? row[columnIndex] : null;
  }

  String _inlinePlainText(List<MarkdownInlineNode> nodes) {
    return nodes.map((node) => node.plainText).join();
  }

  List<MarkdownBlock> _updateListItemInBlocks(
    List<MarkdownBlock> blocks,
    String itemId,
    MarkdownListItem Function(MarkdownListItem item) update,
  ) {
    var changed = false;
    final next = <MarkdownBlock>[
      for (final block in blocks) _updateListItemInBlock(block, itemId, update),
    ];

    for (var i = 0; i < blocks.length; i++) {
      if (!identical(blocks[i], next[i])) {
        changed = true;
        break;
      }
    }

    return changed ? next : blocks;
  }

  MarkdownBlock _updateListItemInBlock(
    MarkdownBlock block,
    String itemId,
    MarkdownListItem Function(MarkdownListItem item) update,
  ) {
    if (block is MarkdownListBlock) {
      var changed = false;
      final items = <MarkdownListItem>[];
      for (final item in block.items) {
        if (item.id == itemId) {
          items.add(update(item));
          changed = true;
          continue;
        }

        final blocks = _updateListItemInBlocks(item.blocks, itemId, update);
        if (identical(blocks, item.blocks)) {
          items.add(item);
        } else {
          items.add(item.copyWith(blocks: blocks));
          changed = true;
        }
      }

      return changed ? block.copyWith(items: items) : block;
    }

    if (block is MarkdownBlockquoteBlock) {
      final blocks = _updateListItemInBlocks(block.blocks, itemId, update);
      return identical(blocks, block.blocks)
          ? block
          : block.copyWith(blocks: blocks);
    }

    return block;
  }

  MarkdownListBlock? _taskItemInputListInBlocks(
    List<MarkdownBlock> blocks,
    String blockId, {
    required bool checked,
  }) {
    for (final block in blocks) {
      if (block is MarkdownListBlock) {
        final list = _taskItemInputListInList(
          block,
          blockId,
          checked: checked,
        );
        if (list != null) return list;
      } else if (block is MarkdownBlockquoteBlock) {
        final list = _taskItemInputListInBlocks(
          block.blocks,
          blockId,
          checked: checked,
        );
        if (list != null) return list;
      }
    }
    return null;
  }

  MarkdownListBlock? _taskItemInputListInList(
    MarkdownListBlock list,
    String blockId, {
    required bool checked,
  }) {
    final location = _directListItemBlockLocation(list, blockId);
    if (location != null) {
      final item = list.items[location.itemIndex];
      final child = item.blocks[location.childIndex];
      if (child is! MarkdownParagraphBlock) return null;

      final nextItem = item.copyWith(
        checked: checked,
        blocks: [
          ...item.blocks.take(location.childIndex),
          _copyTextBlockWithChildren(
            child,
            const [MarkdownText('')],
          ),
          ...item.blocks.skip(location.childIndex + 1),
        ],
      );
      return list.copyWith(
        kind: MarkdownListKind.task,
        items: [
          ...list.items.take(location.itemIndex),
          nextItem,
          ...list.items.skip(location.itemIndex + 1),
        ],
      );
    }

    for (final item in list.items) {
      final nested = _taskItemInputListInBlocks(
        item.blocks,
        blockId,
        checked: checked,
      );
      if (nested != null) return nested;
    }
    return null;
  }

  List<MarkdownBlock>? _indentListItemInBlocks(
    List<MarkdownBlock> blocks,
    String blockId,
  ) {
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];

      if (block is MarkdownListBlock) {
        final nextList = _indentListItemInList(block, blockId);
        if (nextList != null) {
          return [
            ...blocks.take(index),
            nextList,
            ...blocks.skip(index + 1),
          ];
        }
      }

      if (block is MarkdownBlockquoteBlock) {
        final nextChildren = _indentListItemInBlocks(block.blocks, blockId);
        if (nextChildren != null) {
          return [
            ...blocks.take(index),
            block.copyWith(blocks: nextChildren),
            ...blocks.skip(index + 1),
          ];
        }
      }
    }

    return null;
  }

  MarkdownListBlock? _indentListItemInList(
    MarkdownListBlock list,
    String blockId,
  ) {
    for (var itemIndex = 0; itemIndex < list.items.length; itemIndex++) {
      final item = list.items[itemIndex];
      final nextBlocks = _indentListItemInBlocks(item.blocks, blockId);
      if (nextBlocks != null) {
        return list.copyWith(
          items: [
            ...list.items.take(itemIndex),
            item.copyWith(blocks: nextBlocks),
            ...list.items.skip(itemIndex + 1),
          ],
        );
      }
    }

    final itemIndex = _directListItemIndexContainingBlock(list, blockId);
    if (itemIndex <= 0) return null;

    final previousItem = list.items[itemIndex - 1];
    final movedItem = list.items[itemIndex];
    final nextPreviousItem = _appendNestedListItem(
      previousItem,
      kind: list.kind,
      item: movedItem,
    );

    return list.copyWith(
      items: [
        ...list.items.take(itemIndex - 1),
        nextPreviousItem,
        ...list.items.skip(itemIndex + 1),
      ],
    );
  }

  MarkdownListItem _appendNestedListItem(
    MarkdownListItem parent, {
    required MarkdownListKind kind,
    required MarkdownListItem item,
  }) {
    final blocks = [...parent.blocks];
    final tail = blocks.isEmpty ? null : blocks.last;
    if (tail is MarkdownListBlock && tail.kind == kind) {
      blocks[blocks.length - 1] = tail.copyWith(
        items: [
          ...tail.items,
          item,
        ],
      );
    } else {
      blocks.add(
        MarkdownListBlock(
          id: _uniqueBlockId('${parent.id}-children'),
          kind: kind,
          items: [item],
        ),
      );
    }
    return parent.copyWith(blocks: blocks);
  }

  List<MarkdownBlock>? _outdentListItemInBlocks(
    List<MarkdownBlock> blocks,
    String blockId,
  ) {
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];

      if (block is MarkdownListBlock) {
        final nestedOutdent = _outdentNestedListItemInList(block, blockId);
        if (nestedOutdent != null) {
          return [
            ...blocks.take(index),
            nestedOutdent,
            ...blocks.skip(index + 1),
          ];
        }

        final itemIndex = _directListItemIndexContainingBlock(block, blockId);
        if (itemIndex != -1) {
          return [
            ...blocks.take(index),
            ..._liftListItemOutOfList(block, itemIndex),
            ...blocks.skip(index + 1),
          ];
        }
      }

      if (block is MarkdownBlockquoteBlock) {
        final nextChildren = _outdentListItemInBlocks(block.blocks, blockId);
        if (nextChildren != null) {
          return [
            ...blocks.take(index),
            block.copyWith(blocks: nextChildren),
            ...blocks.skip(index + 1),
          ];
        }
      }
    }

    return null;
  }

  MarkdownListBlock? _outdentNestedListItemInList(
    MarkdownListBlock list,
    String blockId,
  ) {
    for (var itemIndex = 0; itemIndex < list.items.length; itemIndex++) {
      final item = list.items[itemIndex];
      for (var blockIndex = 0; blockIndex < item.blocks.length; blockIndex++) {
        final child = item.blocks[blockIndex];
        if (child is! MarkdownListBlock) continue;

        final nestedItemIndex =
            _directListItemIndexContainingBlock(child, blockId);
        if (nestedItemIndex != -1) {
          final movedItem = child.items[nestedItemIndex];
          final remainingNestedItems = [
            ...child.items.take(nestedItemIndex),
            ...child.items.skip(nestedItemIndex + 1),
          ];
          final nextItemBlocks = [
            ...item.blocks.take(blockIndex),
            if (remainingNestedItems.isNotEmpty)
              _copyListWithItemsAtOffset(
                child,
                remainingNestedItems,
                nestedItemIndex == 0 ? 1 : 0,
              ),
            ...item.blocks.skip(blockIndex + 1),
          ];
          final nextItem = item.copyWith(blocks: nextItemBlocks);
          return list.copyWith(
            items: [
              ...list.items.take(itemIndex),
              nextItem,
              movedItem,
              ...list.items.skip(itemIndex + 1),
            ],
          );
        }

        final nextChild = _outdentNestedListItemInList(child, blockId);
        if (nextChild != null) {
          final nextItem = item.copyWith(
            blocks: [
              ...item.blocks.take(blockIndex),
              nextChild,
              ...item.blocks.skip(blockIndex + 1),
            ],
          );
          return list.copyWith(
            items: [
              ...list.items.take(itemIndex),
              nextItem,
              ...list.items.skip(itemIndex + 1),
            ],
          );
        }
      }
    }

    return null;
  }

  List<MarkdownBlock> _liftListItemOutOfList(
    MarkdownListBlock list,
    int itemIndex,
  ) {
    final beforeItems = list.items.take(itemIndex).toList();
    final afterItems = list.items.skip(itemIndex + 1).toList();
    final liftedItem = list.items[itemIndex];

    return [
      if (beforeItems.isNotEmpty)
        _copyListWithItemsAtOffset(list, beforeItems, 0),
      ...liftedItem.blocks,
      if (afterItems.isNotEmpty)
        _copyListWithItemsAtOffset(list, afterItems, itemIndex + 1),
    ];
  }

  MarkdownListBlock _copyListWithItemsAtOffset(
    MarkdownListBlock list,
    List<MarkdownListItem> items,
    int startOffset,
  ) {
    return list.copyWith(
      startIndex: list.kind == MarkdownListKind.ordered
          ? list.startIndex + startOffset
          : list.startIndex,
      items: items,
    );
  }

  _BlockListSplitEdit? _splitNestedTextBlockInBlocks({
    required List<MarkdownBlock> blocks,
    required String blockId,
    required int selectionOffset,
  }) {
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      final edit = switch (block) {
        MarkdownListBlock() => _splitListBlockAt(
            block,
            blockId: blockId,
            selectionOffset: selectionOffset,
          ),
        MarkdownBlockquoteBlock() => _splitBlockquoteBlockAt(
            block,
            blockId: blockId,
            selectionOffset: selectionOffset,
          ),
        _ => null,
      };
      if (edit == null) continue;

      return _BlockListSplitEdit(
        blocks: [
          ...blocks.take(index),
          ...edit.replacements,
          ...blocks.skip(index + 1),
        ],
        activeBlockId: edit.activeBlockId,
        selectionOffset: edit.selectionOffset,
      );
    }

    return null;
  }

  _BlockSplitEdit? _splitListBlockAt(
    MarkdownListBlock list, {
    required String blockId,
    required int selectionOffset,
  }) {
    final directLocation = _directListItemBlockLocation(list, blockId);
    if (directLocation != null) {
      final item = list.items[directLocation.itemIndex];
      final child = item.blocks[directLocation.childIndex];
      if (child is! MarkdownParagraphBlock && child is! MarkdownHeadingBlock) {
        return null;
      }

      if (child.plainText.isEmpty && item.blocks.length == 1) {
        final paragraph = MarkdownParagraphBlock(
          id: _uniqueBlockId('${list.id}-after-list'),
          children: const [MarkdownText('')],
        );
        return _BlockSplitEdit(
          replacements: _exitListItemReplacements(
            list: list,
            itemIndex: directLocation.itemIndex,
            paragraph: paragraph,
          ),
          activeBlockId: paragraph.id,
          selectionOffset: 0,
        );
      }

      final direct = _splitDirectListItemTextBlock(
        list,
        blockId: blockId,
        selectionOffset: selectionOffset,
      );
      if (direct == null) return null;
      return _BlockSplitEdit(
        replacements: [direct.list],
        activeBlockId: direct.activeBlockId,
        selectionOffset: direct.selectionOffset,
      );
    }

    final activeBlock = _document.blockById(blockId);
    if (activeBlock != null && activeBlock.plainText.isEmpty) {
      final outdented = _outdentNestedListItemInList(list, blockId);
      if (outdented != null) {
        return _BlockSplitEdit(
          replacements: [outdented],
          activeBlockId: blockId,
          selectionOffset: 0,
        );
      }
    }

    for (var itemIndex = 0; itemIndex < list.items.length; itemIndex++) {
      final item = list.items[itemIndex];
      final nested = _splitNestedTextBlockInBlocks(
        blocks: item.blocks,
        blockId: blockId,
        selectionOffset: selectionOffset,
      );
      if (nested == null) continue;

      return _BlockSplitEdit(
        replacements: [
          list.copyWith(
            items: [
              ...list.items.take(itemIndex),
              item.copyWith(blocks: nested.blocks),
              ...list.items.skip(itemIndex + 1),
            ],
          ),
        ],
        activeBlockId: nested.activeBlockId,
        selectionOffset: nested.selectionOffset,
      );
    }

    return null;
  }

  _BlockSplitEdit? _splitBlockquoteBlockAt(
    MarkdownBlockquoteBlock blockquote, {
    required String blockId,
    required int selectionOffset,
  }) {
    final childIndex =
        blockquote.blocks.indexWhere((child) => child.id == blockId);
    if (childIndex != -1) {
      final child = blockquote.blocks[childIndex];
      if (child is! MarkdownParagraphBlock && child is! MarkdownHeadingBlock) {
        return null;
      }

      if (child.plainText.isEmpty && blockquote.blocks.length == 1) {
        final paragraph = MarkdownParagraphBlock(
          id: _uniqueBlockId('${blockquote.id}-after-quote'),
          children: const [MarkdownText('')],
        );
        return _BlockSplitEdit(
          replacements: [paragraph],
          activeBlockId: paragraph.id,
          selectionOffset: 0,
        );
      }

      final split = _splitTextBlock(child, selectionOffset);
      return _BlockSplitEdit(
        replacements: [
          blockquote.copyWith(
            blocks: [
              ...blockquote.blocks.take(childIndex),
              split.before,
              split.after,
              ...blockquote.blocks.skip(childIndex + 1),
            ],
          ),
        ],
        activeBlockId: split.after.id,
        selectionOffset: 0,
      );
    }

    final nested = _splitNestedTextBlockInBlocks(
      blocks: blockquote.blocks,
      blockId: blockId,
      selectionOffset: selectionOffset,
    );
    if (nested == null) return null;

    return _BlockSplitEdit(
      replacements: [blockquote.copyWith(blocks: nested.blocks)],
      activeBlockId: nested.activeBlockId,
      selectionOffset: nested.selectionOffset,
    );
  }

  _BlockListDeleteEdit? _deleteBackwardNestedTextBlockInBlocks({
    required List<MarkdownBlock> blocks,
    required String blockId,
  }) {
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      final edit = switch (block) {
        MarkdownListBlock() => _deleteBackwardListBlockAt(
            block,
            blockId: blockId,
          ),
        MarkdownBlockquoteBlock() => _deleteBackwardBlockquoteBlockAt(
            block,
            blockId: blockId,
          ),
        _ => null,
      };
      if (edit == null) continue;

      return _BlockListDeleteEdit(
        blocks: [
          ...blocks.take(index),
          ...edit.replacements,
          ...blocks.skip(index + 1),
        ],
        activeBlockId: edit.activeBlockId,
        selectionOffset: edit.selectionOffset,
      );
    }

    return null;
  }

  _BlockDeleteEdit? _deleteBackwardListBlockAt(
    MarkdownListBlock list, {
    required String blockId,
  }) {
    final directLocation = _directListItemBlockLocation(list, blockId);
    if (directLocation != null) {
      final direct = _deleteBackwardDirectListItemTextBlock(
        list,
        blockId,
      );
      if (direct != null) {
        return _BlockDeleteEdit(
          replacements: [direct.list],
          activeBlockId: direct.activeBlockId,
          selectionOffset: direct.selectionOffset,
        );
      }

      if (directLocation.itemIndex == 0) {
        return _liftFirstListItemFromList(list);
      }

      return null;
    }

    final nested = _deleteBackwardNestedListItemTextBlock(list, blockId);
    if (nested != null) {
      return _BlockDeleteEdit(
        replacements: [nested.list],
        activeBlockId: nested.activeBlockId,
        selectionOffset: nested.selectionOffset,
      );
    }

    for (var itemIndex = 0; itemIndex < list.items.length; itemIndex++) {
      final item = list.items[itemIndex];
      final nested = _deleteBackwardNestedTextBlockInBlocks(
        blocks: item.blocks,
        blockId: blockId,
      );
      if (nested == null) continue;

      return _BlockDeleteEdit(
        replacements: [
          list.copyWith(
            items: [
              ...list.items.take(itemIndex),
              item.copyWith(blocks: nested.blocks),
              ...list.items.skip(itemIndex + 1),
            ],
          ),
        ],
        activeBlockId: nested.activeBlockId,
        selectionOffset: nested.selectionOffset,
      );
    }

    return null;
  }

  _BlockDeleteEdit? _liftFirstListItemFromList(MarkdownListBlock list) {
    if (list.items.isEmpty || list.items.first.blocks.isEmpty) {
      return null;
    }

    final liftedItem = list.items.first;
    final remainingItems = list.items.skip(1).toList();
    return _BlockDeleteEdit(
      replacements: [
        ...liftedItem.blocks,
        if (remainingItems.isNotEmpty)
          _copyListWithItemsAtOffset(list, remainingItems, 1),
      ],
      activeBlockId: liftedItem.blocks.first.id,
      selectionOffset: 0,
    );
  }

  _BlockDeleteEdit? _deleteBackwardBlockquoteBlockAt(
    MarkdownBlockquoteBlock blockquote, {
    required String blockId,
  }) {
    final childIndex =
        blockquote.blocks.indexWhere((child) => child.id == blockId);
    if (childIndex != -1) {
      final child = blockquote.blocks[childIndex];
      if (!_isTextBlock(child)) return null;

      if (childIndex == 0) {
        final remaining = blockquote.blocks.skip(1).toList();
        return _BlockDeleteEdit(
          replacements: [
            child,
            if (remaining.isNotEmpty) blockquote.copyWith(blocks: remaining),
          ],
          activeBlockId: child.id,
          selectionOffset: 0,
        );
      }

      final previousBlock = blockquote.blocks[childIndex - 1];
      if (!_isTextBlock(previousBlock)) return null;
      final selectionOffset = previousBlock.plainText.length;
      final merged = _mergeTextBlocks(previousBlock, child);
      return _BlockDeleteEdit(
        replacements: [
          blockquote.copyWith(
            blocks: [
              ...blockquote.blocks.take(childIndex - 1),
              merged,
              ...blockquote.blocks.skip(childIndex + 1),
            ],
          ),
        ],
        activeBlockId: merged.id,
        selectionOffset: selectionOffset,
      );
    }

    final nested = _deleteBackwardNestedTextBlockInBlocks(
      blocks: blockquote.blocks,
      blockId: blockId,
    );
    if (nested == null) return null;

    return _BlockDeleteEdit(
      replacements: [blockquote.copyWith(blocks: nested.blocks)],
      activeBlockId: nested.activeBlockId,
      selectionOffset: nested.selectionOffset,
    );
  }

  int _directListItemIndexContainingBlock(
    MarkdownListBlock list,
    String blockId,
  ) {
    for (var index = 0; index < list.items.length; index++) {
      if (_itemDirectlyContainsBlock(list.items[index], blockId)) return index;
    }
    return -1;
  }

  bool _itemDirectlyContainsBlock(MarkdownListItem item, String blockId) {
    for (final block in item.blocks) {
      if (block is MarkdownListBlock) continue;
      if (block.findBlock(blockId) != null) return true;
    }
    return false;
  }

  _ListItemBlockLocation? _directListItemBlockLocation(
    MarkdownListBlock list,
    String blockId,
  ) {
    for (var itemIndex = 0; itemIndex < list.items.length; itemIndex++) {
      final childIndex = list.items[itemIndex].blocks.indexWhere(
        (block) => block.id == blockId,
      );
      if (childIndex != -1) {
        return _ListItemBlockLocation(
          itemIndex: itemIndex,
          childIndex: childIndex,
        );
      }
    }
    return null;
  }

  MarkdownDeleteBackwardResult? _deleteBackwardTopLevelTextBlock(
    int blockIndex,
  ) {
    if (blockIndex <= 0) return null;

    final previous = _document.blocks[blockIndex - 1];
    final current = _document.blocks[blockIndex];
    if (!_isTextBlock(previous) || !_isTextBlock(current)) return null;

    final selectionOffset = previous.plainText.length;
    final merged = _mergeTextBlocks(previous, current);
    _replaceDocument(
      MarkdownDocument(
        blocks: [
          ..._document.blocks.take(blockIndex - 1),
          merged,
          ..._document.blocks.skip(blockIndex + 1),
        ],
      ),
    );
    return MarkdownDeleteBackwardResult(
      document: _document,
      activeBlockId: merged.id,
      selectionOffset: selectionOffset,
    );
  }

  _ListDeleteEdit? _deleteBackwardDirectListItemTextBlock(
    MarkdownListBlock list,
    String blockId,
  ) {
    final location = _directListItemBlockLocation(list, blockId);
    if (location == null) return null;

    final child = list.items[location.itemIndex].blocks[location.childIndex];
    if (!_isTextBlock(child)) return null;

    if (location.childIndex > 0) {
      return _mergeListItemChildWithPreviousBlock(
        list: list,
        itemIndex: location.itemIndex,
        childIndex: location.childIndex,
      );
    }

    if (location.itemIndex == 0) return null;

    return _mergeListItemWithPreviousItem(
      list: list,
      itemIndex: location.itemIndex,
    );
  }

  _ListDeleteEdit? _deleteBackwardNestedListItemTextBlock(
    MarkdownListBlock list,
    String blockId,
  ) {
    for (var itemIndex = 0; itemIndex < list.items.length; itemIndex++) {
      final item = list.items[itemIndex];
      for (var blockIndex = 0; blockIndex < item.blocks.length; blockIndex++) {
        final child = item.blocks[blockIndex];
        if (child is! MarkdownListBlock) continue;

        final directLocation = _directListItemBlockLocation(child, blockId);
        if (directLocation != null) {
          final direct = _deleteBackwardDirectListItemTextBlock(child, blockId);
          if (direct != null) {
            final nextItem = item.copyWith(
              blocks: [
                ...item.blocks.take(blockIndex),
                direct.list,
                ...item.blocks.skip(blockIndex + 1),
              ],
            );
            return _ListDeleteEdit(
              list: list.copyWith(
                items: [
                  ...list.items.take(itemIndex),
                  nextItem,
                  ...list.items.skip(itemIndex + 1),
                ],
              ),
              activeBlockId: direct.activeBlockId,
              selectionOffset: direct.selectionOffset,
            );
          }

          if (directLocation.itemIndex == 0) {
            final outdented = _outdentNestedListItemInList(list, blockId);
            if (outdented == null) return null;
            return _ListDeleteEdit(
              list: outdented,
              activeBlockId: blockId,
              selectionOffset: 0,
            );
          }

          return null;
        }

        final nested = _deleteBackwardNestedListItemTextBlock(child, blockId);
        if (nested != null) {
          final nextItem = item.copyWith(
            blocks: [
              ...item.blocks.take(blockIndex),
              nested.list,
              ...item.blocks.skip(blockIndex + 1),
            ],
          );
          return _ListDeleteEdit(
            list: list.copyWith(
              items: [
                ...list.items.take(itemIndex),
                nextItem,
                ...list.items.skip(itemIndex + 1),
              ],
            ),
            activeBlockId: nested.activeBlockId,
            selectionOffset: nested.selectionOffset,
          );
        }
      }
    }

    return null;
  }

  _ListDeleteEdit? _mergeListItemChildWithPreviousBlock({
    required MarkdownListBlock list,
    required int itemIndex,
    required int childIndex,
  }) {
    final item = list.items[itemIndex];
    final previousBlock = item.blocks[childIndex - 1];
    final currentBlock = item.blocks[childIndex];
    if (!_isTextBlock(previousBlock) || !_isTextBlock(currentBlock)) {
      return null;
    }

    final selectionOffset = previousBlock.plainText.length;
    final merged = _mergeTextBlocks(previousBlock, currentBlock);
    final nextItem = item.copyWith(
      blocks: [
        ...item.blocks.take(childIndex - 1),
        merged,
        ...item.blocks.skip(childIndex + 1),
      ],
    );
    final nextList = list.copyWith(
      items: [
        ...list.items.take(itemIndex),
        nextItem,
        ...list.items.skip(itemIndex + 1),
      ],
    );
    return _ListDeleteEdit(
      list: nextList,
      activeBlockId: merged.id,
      selectionOffset: selectionOffset,
    );
  }

  _ListDeleteEdit? _mergeListItemWithPreviousItem({
    required MarkdownListBlock list,
    required int itemIndex,
  }) {
    final previousItem = list.items[itemIndex - 1];
    final currentItem = list.items[itemIndex];
    if (previousItem.blocks.isEmpty || currentItem.blocks.isEmpty) {
      return null;
    }

    final previousBlock = previousItem.blocks.last;
    final currentBlock = currentItem.blocks.first;
    if (!_isTextBlock(previousBlock) || !_isTextBlock(currentBlock)) {
      return null;
    }

    final selectionOffset = previousBlock.plainText.length;
    final merged = _mergeTextBlocks(previousBlock, currentBlock);
    final nextPreviousItem = previousItem.copyWith(
      blocks: [
        ...previousItem.blocks.take(previousItem.blocks.length - 1),
        merged,
        ...currentItem.blocks.skip(1),
      ],
    );
    final nextList = list.copyWith(
      items: [
        ...list.items.take(itemIndex - 1),
        nextPreviousItem,
        ...list.items.skip(itemIndex + 1),
      ],
    );
    return _ListDeleteEdit(
      list: nextList,
      activeBlockId: merged.id,
      selectionOffset: selectionOffset,
    );
  }

  bool _isTextBlock(MarkdownBlock block) {
    return block is MarkdownParagraphBlock || block is MarkdownHeadingBlock;
  }

  _ResolvedTopLevelTextSelection? _resolveTopLevelTextSelection(
    MarkdownDocumentSelection selection,
  ) {
    final anchorIndex = _document.blocks.indexWhere(
      (block) => block.id == selection.anchor.blockId,
    );
    final focusIndex = _document.blocks.indexWhere(
      (block) => block.id == selection.focus.blockId,
    );
    if (anchorIndex == -1 || focusIndex == -1) return null;

    final anchorBlock = _document.blocks[anchorIndex];
    final focusBlock = _document.blocks[focusIndex];
    if (!_isTextBlock(anchorBlock) || !_isTextBlock(focusBlock)) {
      return null;
    }

    var startIndex = anchorIndex;
    var endIndex = focusIndex;
    var startOffset = selection.anchor.offset;
    var endOffset = selection.focus.offset;
    if (anchorIndex > focusIndex ||
        (anchorIndex == focusIndex && startOffset > endOffset)) {
      startIndex = focusIndex;
      endIndex = anchorIndex;
      startOffset = selection.focus.offset;
      endOffset = selection.anchor.offset;
    }

    final startBlock = _document.blocks[startIndex];
    final endBlock = _document.blocks[endIndex];
    for (var index = startIndex; index <= endIndex; index++) {
      if (!_isTextBlock(_document.blocks[index])) return null;
    }

    final clampedStart =
        startOffset.clamp(0, startBlock.plainText.length).toInt();
    final clampedEnd = endOffset.clamp(0, endBlock.plainText.length).toInt();

    return _ResolvedTopLevelTextSelection(
      startIndex: startIndex,
      endIndex: endIndex,
      startBlock: startBlock,
      endBlock: endBlock,
      startOffset: clampedStart,
      endOffset: clampedEnd,
    );
  }

  List<MarkdownBlock> _selectedTopLevelTextBlocks(
    _ResolvedTopLevelTextSelection selection,
  ) {
    final blocks = <MarkdownBlock>[];
    for (var index = selection.startIndex;
        index <= selection.endIndex;
        index++) {
      final block = _document.blocks[index];
      final start = index == selection.startIndex ? selection.startOffset : 0;
      final end = index == selection.endIndex
          ? selection.endOffset
          : block.plainText.length;
      final slice = _textBlockSlice(block, start, end);
      if (slice != null) blocks.add(slice);
    }
    return blocks;
  }

  MarkdownBlock? _textBlockSlice(
    MarkdownBlock block,
    int start,
    int end,
  ) {
    final children = _textBlockChildren(block);
    final plainText = _inlinePlainText(children);
    final clampedStart = start.clamp(0, plainText.length).toInt();
    final clampedEnd = end.clamp(clampedStart, plainText.length).toInt();
    if (clampedStart == clampedEnd) return null;
    if (clampedStart == 0 && clampedEnd == plainText.length) return block;

    final beforeSplit = _splitInlineNodes(children, clampedStart);
    final selectedSplit = _splitInlineNodes(
      beforeSplit.after,
      clampedEnd - clampedStart,
    );
    return _copyTextBlockWithChildren(block, selectedSplit.before);
  }

  MarkdownBlock? _lastEditableTextBlock(List<MarkdownBlock> blocks) {
    for (final block in blocks.reversed) {
      if (_isTextBlock(block)) return block;
      if (block is MarkdownBlockquoteBlock) {
        final nested = _lastEditableTextBlock(block.blocks);
        if (nested != null) return nested;
      }
      if (block is MarkdownListBlock) {
        for (final item in block.items.reversed) {
          final nested = _lastEditableTextBlock(item.blocks);
          if (nested != null) return nested;
        }
      }
    }
    return null;
  }

  void _collectInsertionIds(
    Iterable<MarkdownBlock> blocks,
    Set<String> blockIds,
    Set<String> listItemIds,
  ) {
    for (final block in blocks) {
      blockIds.add(block.id);
      if (block is MarkdownBlockquoteBlock) {
        _collectInsertionIds(block.blocks, blockIds, listItemIds);
      } else if (block is MarkdownListBlock) {
        for (final item in block.items) {
          listItemIds.add(item.id);
          _collectInsertionIds(item.blocks, blockIds, listItemIds);
        }
      }
    }
  }

  List<MarkdownBlock> _retagBlocksForInsertion(
    List<MarkdownBlock> blocks,
    Set<String> reservedBlockIds,
    Set<String> reservedListItemIds,
  ) {
    return [
      for (final block in blocks)
        _retagBlockForInsertion(
          block,
          reservedBlockIds,
          reservedListItemIds,
        ),
    ];
  }

  List<MarkdownBlock> _retagBlocksForDocumentInsertion(
    List<MarkdownBlock> blocks, {
    Iterable<MarkdownBlock> additionalReservedBlocks = const [],
  }) {
    final reservedBlockIds = <String>{};
    final reservedListItemIds = <String>{};
    _collectInsertionIds(
      _document.blocks,
      reservedBlockIds,
      reservedListItemIds,
    );
    _collectInsertionIds(
      additionalReservedBlocks,
      reservedBlockIds,
      reservedListItemIds,
    );
    return _retagBlocksForInsertion(
      blocks,
      reservedBlockIds,
      reservedListItemIds,
    );
  }

  MarkdownBlock _retagBlockForInsertion(
    MarkdownBlock block,
    Set<String> reservedBlockIds,
    Set<String> reservedListItemIds,
  ) {
    final id = _reserveInsertionId(block.id, reservedBlockIds);
    if (block is MarkdownParagraphBlock) {
      return block.copyWith(id: id);
    }
    if (block is MarkdownHeadingBlock) {
      return block.copyWith(id: id);
    }
    if (block is MarkdownBlockquoteBlock) {
      return block.copyWith(
        id: id,
        blocks: _retagBlocksForInsertion(
          block.blocks,
          reservedBlockIds,
          reservedListItemIds,
        ),
      );
    }
    if (block is MarkdownListBlock) {
      return block.copyWith(
        id: id,
        items: [
          for (final item in block.items)
            item.copyWith(
              id: _reserveInsertionId(item.id, reservedListItemIds),
              blocks: _retagBlocksForInsertion(
                item.blocks,
                reservedBlockIds,
                reservedListItemIds,
              ),
            ),
        ],
      );
    }
    if (block is MarkdownFrontmatterBlock) {
      return block.copyWith(id: id);
    }
    if (block is MarkdownCodeBlock) {
      return block.copyWith(id: id);
    }
    if (block is MarkdownMermaidBlock) {
      return block.copyWith(id: id);
    }
    if (block is MarkdownBlockMathBlock) {
      return block.copyWith(id: id);
    }
    if (block is MarkdownHorizontalRuleBlock) {
      return MarkdownHorizontalRuleBlock(id: id);
    }
    if (block is MarkdownRawBlock) {
      return block.copyWith(id: id);
    }
    if (block is MarkdownImageBlock) {
      return block.copyWith(id: id);
    }
    if (block is MarkdownTableBlock) {
      return block.copyWith(id: id);
    }
    return block;
  }

  String _reserveInsertionId(String preferred, Set<String> reservedIds) {
    final base = preferred.isEmpty ? 'block' : preferred;
    var id = base;
    var index = 1;
    while (reservedIds.contains(id)) {
      id = '$base-$index';
      index++;
    }
    reservedIds.add(id);
    return id;
  }

  MarkdownListBlock _rangeListBlock(
    List<MarkdownBlock> blocks,
    MarkdownListKind kind,
  ) {
    final id = blocks.first.id;
    return MarkdownListBlock(
      id: id,
      kind: kind,
      items: [
        for (var index = 0; index < blocks.length; index++)
          MarkdownListItem(
            id: _uniqueListItemId('$id-item-$index'),
            checked: false,
            blocks: [
              _asParagraph(blocks[index]).copyWith(
                id: _uniqueBlockId('$id-item-$index-p'),
              ),
            ],
          ),
      ],
    );
  }

  MarkdownBlock _mergeTextBlocks(
    MarkdownBlock first,
    MarkdownBlock second,
  ) {
    return _copyTextBlockWithChildren(
      first,
      _mergeInlineChildren(
        _textBlockChildren(first),
        _textBlockChildren(second),
      ),
    );
  }

  List<MarkdownInlineNode> _textBlockChildren(MarkdownBlock block) {
    if (block is MarkdownParagraphBlock) return block.children;
    if (block is MarkdownHeadingBlock) return block.children;
    return const [MarkdownText('')];
  }

  MarkdownBlock _copyTextBlockWithChildren(
      MarkdownBlock block, List<MarkdownInlineNode> children,
      {String? id}) {
    if (block is MarkdownParagraphBlock) {
      return block.copyWith(id: id, children: children);
    }
    if (block is MarkdownHeadingBlock) {
      return block.copyWith(id: id, children: children);
    }
    return block;
  }

  MarkdownBlock _afterTextBlockForRangePaste(
    MarkdownBlock block,
    List<MarkdownInlineNode> children,
  ) {
    final id = _uniqueBlockId('${block.id}-after-paste');
    if (block is MarkdownHeadingBlock) {
      return MarkdownParagraphBlock(id: id, children: children);
    }
    return _copyTextBlockWithChildren(block, children, id: id);
  }

  List<MarkdownInlineNode> _mergeInlineChildren(
    List<MarkdownInlineNode> first,
    List<MarkdownInlineNode> second,
  ) {
    final nodes = [
      ...first,
      ...second,
    ].where((node) => node.plainText.isNotEmpty);
    final merged = <MarkdownInlineNode>[];

    for (final node in nodes) {
      final last = merged.isEmpty ? null : merged.last;
      if (last is MarkdownText && node is MarkdownText) {
        merged[merged.length - 1] = MarkdownText(last.text + node.text);
      } else {
        merged.add(node);
      }
    }

    return merged.isEmpty ? const [MarkdownText('')] : merged;
  }

  MarkdownSplitBlockResult _splitTopLevelTextBlock(
    int blockIndex,
    MarkdownBlock block,
    int selectionOffset,
  ) {
    final split = _splitTextBlock(block, selectionOffset);
    final nextBlocks = <MarkdownBlock>[
      ..._document.blocks.take(blockIndex),
      split.before,
      split.after,
      ..._document.blocks.skip(blockIndex + 1),
    ];
    _replaceDocument(MarkdownDocument(blocks: nextBlocks));
    return MarkdownSplitBlockResult(
      document: _document,
      activeBlockId: split.after.id,
      selectionOffset: 0,
    );
  }

  _ListSplitEdit? _splitDirectListItemTextBlock(
    MarkdownListBlock list, {
    required String blockId,
    required int selectionOffset,
  }) {
    final location = _directListItemBlockLocation(list, blockId);
    if (location == null) return null;

    final item = list.items[location.itemIndex];
    final child = item.blocks[location.childIndex];
    if (child is! MarkdownParagraphBlock && child is! MarkdownHeadingBlock) {
      return null;
    }
    if (child.plainText.isEmpty && item.blocks.length == 1) return null;

    final split = _splitTextBlock(child, selectionOffset);
    final beforeItem = item.copyWith(
      blocks: [
        ...item.blocks.take(location.childIndex),
        split.before,
      ],
    );
    final afterItem = MarkdownListItem(
      id: _uniqueListItemId('${item.id}-split'),
      checked: false,
      blocks: [
        split.after,
        ...item.blocks.skip(location.childIndex + 1),
      ],
    );

    return _ListSplitEdit(
      list: list.copyWith(
        items: [
          ...list.items.take(location.itemIndex),
          beforeItem,
          afterItem,
          ...list.items.skip(location.itemIndex + 1),
        ],
      ),
      activeBlockId: split.after.id,
      selectionOffset: 0,
    );
  }

  List<MarkdownBlock> _exitListItemReplacements({
    required MarkdownListBlock list,
    required int itemIndex,
    required MarkdownParagraphBlock paragraph,
  }) {
    final beforeItems = list.items.take(itemIndex).toList();
    final afterItems = list.items.skip(itemIndex + 1).toList();
    return [
      if (beforeItems.isNotEmpty)
        _copyListWithItemsAtOffset(list, beforeItems, 0),
      paragraph,
      if (afterItems.isNotEmpty)
        _copyListWithItemsAtOffset(list, afterItems, itemIndex + 1),
    ];
  }

  _TextBlockSplit _splitTextBlock(
    MarkdownBlock block,
    int selectionOffset,
  ) {
    final children = block is MarkdownParagraphBlock
        ? block.children
        : (block as MarkdownHeadingBlock).children;
    final plainText = children.map((child) => child.plainText).join();
    final offset = selectionOffset.clamp(0, plainText.length).toInt();
    final splitChildren = _splitInlineNodes(children, offset);
    final afterId = _uniqueBlockId('${block.id}-split');

    if (block is MarkdownHeadingBlock) {
      return _TextBlockSplit(
        before: block.copyWith(children: splitChildren.before),
        after: MarkdownParagraphBlock(
          id: afterId,
          children: splitChildren.after,
        ),
      );
    }

    return _TextBlockSplit(
      before: (block as MarkdownParagraphBlock).copyWith(
        children: splitChildren.before,
      ),
      after: MarkdownParagraphBlock(
        id: afterId,
        children: splitChildren.after,
      ),
    );
  }

  _InlineSplit _splitInlineNodes(
    List<MarkdownInlineNode> children,
    int selectionOffset,
  ) {
    var remaining = selectionOffset;
    final before = <MarkdownInlineNode>[];
    final after = <MarkdownInlineNode>[];
    var splitReached = false;

    for (final child in children) {
      if (splitReached) {
        after.add(child);
        continue;
      }

      final length = child.plainText.length;
      if (remaining >= length) {
        before.add(child);
        remaining -= length;
        continue;
      }

      final childSplit = _splitInlineNode(child, remaining);
      before.addAll(childSplit.before);
      after.addAll(childSplit.after);
      splitReached = true;
    }

    return _InlineSplit(
      before: _normalizeInlineChildren(before),
      after: _normalizeInlineChildren(after),
    );
  }

  _InlineSplit _splitInlineNode(MarkdownInlineNode node, int offset) {
    final length = node.plainText.length;
    if (offset <= 0) {
      return _InlineSplit(before: const [], after: [node]);
    }
    if (offset >= length) {
      return _InlineSplit(before: [node], after: const []);
    }

    switch (node) {
      case MarkdownText():
        return _InlineSplit(
          before: [MarkdownText(node.text.substring(0, offset))],
          after: [MarkdownText(node.text.substring(offset))],
        );
      case MarkdownStrong():
        final split = _splitInlineNodes(node.children, offset);
        return _InlineSplit(
          before: [MarkdownStrong(split.before)],
          after: [MarkdownStrong(split.after)],
        );
      case MarkdownEmphasis():
        final split = _splitInlineNodes(node.children, offset);
        return _InlineSplit(
          before: [MarkdownEmphasis(split.before)],
          after: [MarkdownEmphasis(split.after)],
        );
      case MarkdownStrikethrough():
        final split = _splitInlineNodes(node.children, offset);
        return _InlineSplit(
          before: [MarkdownStrikethrough(split.before)],
          after: [MarkdownStrikethrough(split.after)],
        );
      case MarkdownLink():
        final split = _splitInlineNodes(node.children, offset);
        return _InlineSplit(
          before: [
            MarkdownLink(
              url: node.url,
              title: node.title,
              children: split.before,
            ),
          ],
          after: [
            MarkdownLink(
              url: node.url,
              title: node.title,
              children: split.after,
            ),
          ],
        );
      case MarkdownInlineCode():
        return _InlineSplit(
          before: [MarkdownInlineCode(node.code.substring(0, offset))],
          after: [MarkdownInlineCode(node.code.substring(offset))],
        );
      case MarkdownInlineMath():
        return _InlineSplit(
          before: [MarkdownInlineMath(node.latex.substring(0, offset))],
          after: [MarkdownInlineMath(node.latex.substring(offset))],
        );
      case MarkdownWikilink() || MarkdownImage() || MarkdownHardBreak():
        return offset < length
            ? _InlineSplit(before: const [], after: [node])
            : _InlineSplit(before: [node], after: const []);
      default:
        final text = node.plainText;
        return _InlineSplit(
          before: [MarkdownText(text.substring(0, offset))],
          after: [MarkdownText(text.substring(offset))],
        );
    }
  }

  List<MarkdownInlineNode> _normalizeInlineChildren(
    List<MarkdownInlineNode> children,
  ) {
    final visible = children.where((child) => child.plainText.isNotEmpty);
    final merged = <MarkdownInlineNode>[];
    for (final child in visible) {
      if (merged.isEmpty) {
        merged.add(child);
        continue;
      }

      final combined = _mergeInlineNodes(merged.last, child);
      if (combined == null) {
        merged.add(child);
      } else {
        merged[merged.length - 1] = combined;
      }
    }
    return merged.isEmpty ? const [MarkdownText('')] : merged;
  }

  bool _hasVisibleInlineContent(List<MarkdownInlineNode> children) {
    return children.any((child) => child.plainText.isNotEmpty);
  }

  MarkdownInlineNode? _mergeInlineNodes(
    MarkdownInlineNode left,
    MarkdownInlineNode right,
  ) {
    if (left is MarkdownText && right is MarkdownText) {
      return MarkdownText(left.text + right.text);
    }
    if (left is MarkdownStrong && right is MarkdownStrong) {
      return MarkdownStrong(
        _normalizeInlineChildren([...left.children, ...right.children]),
      );
    }
    if (left is MarkdownEmphasis && right is MarkdownEmphasis) {
      return MarkdownEmphasis(
        _normalizeInlineChildren([...left.children, ...right.children]),
      );
    }
    if (left is MarkdownStrikethrough && right is MarkdownStrikethrough) {
      return MarkdownStrikethrough(
        _normalizeInlineChildren([...left.children, ...right.children]),
      );
    }
    if (left is MarkdownInlineCode && right is MarkdownInlineCode) {
      return MarkdownInlineCode(left.code + right.code);
    }
    if (left is MarkdownInlineMath && right is MarkdownInlineMath) {
      return MarkdownInlineMath(left.latex + right.latex);
    }
    if (left is MarkdownLink &&
        right is MarkdownLink &&
        left.url == right.url &&
        left.title == right.title) {
      return MarkdownLink(
        url: left.url,
        title: left.title,
        children: _normalizeInlineChildren([
          ...left.children,
          ...right.children,
        ]),
      );
    }
    return null;
  }

  String _uniqueBlockId(String base) {
    var id = base;
    var index = 1;
    while (_document.blockById(id) != null) {
      id = '$base-$index';
      index++;
    }
    return id;
  }

  int _topLevelBlockIndexContaining(String blockId) {
    for (var index = 0; index < _document.blocks.length; index++) {
      if (_document.blocks[index].findBlock(blockId) != null) {
        return index;
      }
    }
    return -1;
  }

  String _uniqueListItemId(String base) {
    var id = base;
    var index = 1;
    while (_listItemIdExists(_document.blocks, id)) {
      id = '$base-$index';
      index++;
    }
    return id;
  }

  bool _listItemIdExists(List<MarkdownBlock> blocks, String itemId) {
    for (final block in blocks) {
      if (block is MarkdownListBlock) {
        for (final item in block.items) {
          if (item.id == itemId) return true;
          if (_listItemIdExists(item.blocks, itemId)) return true;
        }
      } else if (block is MarkdownBlockquoteBlock) {
        if (_listItemIdExists(block.blocks, itemId)) return true;
      }
    }
    return false;
  }
}

class _ListItemBlockLocation {
  const _ListItemBlockLocation({
    required this.itemIndex,
    required this.childIndex,
  });

  final int itemIndex;
  final int childIndex;
}

class _BlockListSplitEdit {
  const _BlockListSplitEdit({
    required this.blocks,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  final List<MarkdownBlock> blocks;
  final String activeBlockId;
  final int selectionOffset;
}

class _BlockSplitEdit {
  const _BlockSplitEdit({
    required this.replacements,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  final List<MarkdownBlock> replacements;
  final String activeBlockId;
  final int selectionOffset;
}

class _BlockListDeleteEdit {
  const _BlockListDeleteEdit({
    required this.blocks,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  final List<MarkdownBlock> blocks;
  final String activeBlockId;
  final int selectionOffset;
}

class _BlockDeleteEdit {
  const _BlockDeleteEdit({
    required this.replacements,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  final List<MarkdownBlock> replacements;
  final String activeBlockId;
  final int selectionOffset;
}

class _ListSplitEdit {
  const _ListSplitEdit({
    required this.list,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  final MarkdownListBlock list;
  final String activeBlockId;
  final int selectionOffset;
}

class _ListDeleteEdit {
  const _ListDeleteEdit({
    required this.list,
    required this.activeBlockId,
    required this.selectionOffset,
  });

  final MarkdownListBlock list;
  final String activeBlockId;
  final int selectionOffset;
}

class _TextBlockSplit {
  const _TextBlockSplit({
    required this.before,
    required this.after,
  });

  final MarkdownBlock before;
  final MarkdownParagraphBlock after;
}

class _ResolvedTopLevelTextSelection {
  const _ResolvedTopLevelTextSelection({
    required this.startIndex,
    required this.endIndex,
    required this.startBlock,
    required this.endBlock,
    required this.startOffset,
    required this.endOffset,
  });

  final int startIndex;
  final int endIndex;
  final MarkdownBlock startBlock;
  final MarkdownBlock endBlock;
  final int startOffset;
  final int endOffset;

  bool get isCollapsed => startIndex == endIndex && startOffset == endOffset;
}

class _InlineSplit {
  const _InlineSplit({
    required this.before,
    required this.after,
  });

  final List<MarkdownInlineNode> before;
  final List<MarkdownInlineNode> after;
}

class _PlainTextDiff {
  const _PlainTextDiff({
    required this.range,
    required this.replacement,
  });

  final TextRange range;
  final String replacement;
}

/// Link metadata and full plain-text range returned by link editing queries.
class MarkdownLinkEdit {
  /// Creates link edit metadata.
  const MarkdownLinkEdit({
    required this.range,
    required this.url,
    required this.children,
    this.title,
  });

  /// The full plain-text range covered by the link.
  final TextRange range;

  /// Link URL.
  final String url;

  /// Optional link title.
  final String? title;

  /// Link label inline children.
  final List<MarkdownInlineNode> children;

  /// Visible link label text.
  String get text => children.map((child) => child.plainText).join();
}

class _InlineWrapper {
  const _InlineWrapper();

  MarkdownInlineNode wrap(List<MarkdownInlineNode> children) {
    throw UnimplementedError();
  }
}

class _StrongInlineWrapper extends _InlineWrapper {
  const _StrongInlineWrapper();

  @override
  MarkdownInlineNode wrap(List<MarkdownInlineNode> children) {
    return MarkdownStrong(children);
  }
}

class _EmphasisInlineWrapper extends _InlineWrapper {
  const _EmphasisInlineWrapper();

  @override
  MarkdownInlineNode wrap(List<MarkdownInlineNode> children) {
    return MarkdownEmphasis(children);
  }
}

class _StrikethroughInlineWrapper extends _InlineWrapper {
  const _StrikethroughInlineWrapper();

  @override
  MarkdownInlineNode wrap(List<MarkdownInlineNode> children) {
    return MarkdownStrikethrough(children);
  }
}

class _LinkInlineWrapper extends _InlineWrapper {
  const _LinkInlineWrapper({
    required this.url,
    required this.title,
  });

  final String url;
  final String? title;

  @override
  MarkdownInlineNode wrap(List<MarkdownInlineNode> children) {
    return MarkdownLink(url: url, title: title, children: children);
  }
}

class _InlineCodeWrapper extends _InlineWrapper {
  const _InlineCodeWrapper();

  @override
  MarkdownInlineNode wrap(List<MarkdownInlineNode> children) {
    return MarkdownInlineCode(children.map((child) => child.plainText).join());
  }
}

class _InlineMathWrapper extends _InlineWrapper {
  const _InlineMathWrapper();

  @override
  MarkdownInlineNode wrap(List<MarkdownInlineNode> children) {
    return MarkdownInlineMath(children.map((child) => child.plainText).join());
  }
}

enum _InlineWrap {
  strong,
  emphasis,
  strikethrough,
  code,
  link,
  image,
  wikilink,
}

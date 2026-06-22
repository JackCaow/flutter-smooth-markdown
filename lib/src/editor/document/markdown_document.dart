/// Editable Markdown document model used by the editor.
///
/// This model is intentionally separate from the renderer AST. The renderer AST
/// describes parsed Markdown for display; this model describes user-editable
/// document structure, stable block IDs, and operations that can be serialized
/// back to Markdown.
class MarkdownDocument {
  /// Creates a Markdown document.
  const MarkdownDocument({required this.blocks});

  /// Top-level editable blocks.
  final List<MarkdownBlock> blocks;

  /// Whether the document has no visible content.
  bool get isEmpty => blocks.every((block) => block.plainText.trim().isEmpty);

  /// Plain text representation for search and copy-as-plain-text flows.
  String get plainText => blocks.map((block) => block.plainText).join('\n\n');

  /// Serializes the editable document to Markdown.
  String toMarkdown() {
    final markdown = blocks
        .map((block) => block is MarkdownRawBlock
            ? block.toMarkdown()
            : _normalizeSerializedMarkdown(block.toMarkdown()))
        .where((block) => block.trim().isNotEmpty)
        .join('\n\n')
        .trimRight();
    return markdown;
  }

  /// Returns the first block with the given ID, or null.
  MarkdownBlock? blockById(String id) {
    for (final block in blocks) {
      final match = block.findBlock(id);
      if (match != null) return match;
    }
    return null;
  }

  /// Replaces the block with the same ID as [block].
  MarkdownDocument replaceBlock(MarkdownBlock block) {
    return MarkdownDocument(
      blocks: _replaceBlockInList(blocks, block),
    );
  }

  /// Replaces a top-level block with [replacements].
  ///
  /// This is used by rich-editing paste operations where a single active block
  /// can expand into several parsed Markdown blocks.
  MarkdownDocument replaceTopLevelBlockWithBlocks(
    String blockId,
    List<MarkdownBlock> replacements,
  ) {
    final nextBlocks = <MarkdownBlock>[];
    var replaced = false;

    for (final block in blocks) {
      if (block.id == blockId) {
        nextBlocks.addAll(replacements);
        replaced = true;
      } else {
        nextBlocks.add(block);
      }
    }

    return replaced ? MarkdownDocument(blocks: nextBlocks) : this;
  }

  /// Replaces a block at any depth with [replacements].
  ///
  /// This is used by rich-editing paste operations where a single active block
  /// can expand into several parsed Markdown blocks, including inside nested
  /// containers such as blockquotes and list items.
  MarkdownDocument replaceBlockWithBlocks(
    String blockId,
    List<MarkdownBlock> replacements,
  ) {
    final nextBlocks = _replaceBlockWithBlocksInList(
      blocks,
      blockId,
      replacements,
    );
    return identical(nextBlocks, blocks)
        ? this
        : MarkdownDocument(blocks: nextBlocks);
  }

  /// Inserts [block] after [anchorBlockId].
  MarkdownDocument insertBlockAfter(String anchorBlockId, MarkdownBlock block) {
    final nextBlocks = <MarkdownBlock>[];
    var inserted = false;

    for (final current in blocks) {
      nextBlocks.add(current);
      if (current.id == anchorBlockId) {
        nextBlocks.add(block);
        inserted = true;
      }
    }

    if (!inserted) {
      nextBlocks.add(block);
    }

    return MarkdownDocument(blocks: nextBlocks);
  }

  /// Moves the top-level block containing [blockId] up or down.
  MarkdownDocument moveTopLevelBlock(
    String blockId, {
    required bool upward,
  }) {
    final fromIndex = blocks.indexWhere(
      (block) => block.findBlock(blockId) != null,
    );
    if (fromIndex == -1) return this;

    final toIndex = upward ? fromIndex - 1 : fromIndex + 1;
    if (toIndex < 0 || toIndex >= blocks.length) return this;

    final nextBlocks = [...blocks];
    final moved = nextBlocks.removeAt(fromIndex);
    nextBlocks.insert(toIndex, moved);
    return MarkdownDocument(blocks: nextBlocks);
  }

  /// Moves the top-level block containing [blockId] to [targetIndex].
  MarkdownDocument moveTopLevelBlockToIndex(
    String blockId, {
    required int targetIndex,
  }) {
    final fromIndex = blocks.indexWhere(
      (block) => block.findBlock(blockId) != null,
    );
    if (fromIndex == -1) return this;

    final clampedTarget = targetIndex.clamp(0, blocks.length - 1).toInt();
    if (fromIndex == clampedTarget) return this;

    final nextBlocks = [...blocks];
    final moved = nextBlocks.removeAt(fromIndex);
    nextBlocks.insert(clampedTarget, moved);
    return MarkdownDocument(blocks: nextBlocks);
  }

  /// Removes the block with [blockId].
  MarkdownDocument removeBlock(String blockId) {
    return MarkdownDocument(
      blocks: _removeBlockInList(blocks, blockId),
    );
  }

  /// Converts the document to a serializable map.
  Map<String, dynamic> toJson() => {
        'type': 'document',
        'blocks': blocks.map((block) => block.toJson()).toList(),
      };
}

/// A visual position inside one editable table.
///
/// Row `0` addresses the table header row. Body rows start at visual row `1`
/// and map to `MarkdownTableBlock.rows[rowIndex - 1]`.
class MarkdownTableCellPosition {
  /// Creates a table cell position.
  const MarkdownTableCellPosition({
    required this.rowIndex,
    required this.columnIndex,
  });

  /// Visual row index. Header row is `0`; body rows start at `1`.
  final int rowIndex;

  /// Zero-based column index.
  final int columnIndex;

  /// Whether this position addresses the header row.
  bool get isHeader => rowIndex == 0;

  /// Body row index for [MarkdownTableBlock.rows].
  int get bodyRowIndex => rowIndex - 1;

  @override
  bool operator ==(Object other) {
    return other is MarkdownTableCellPosition &&
        other.rowIndex == rowIndex &&
        other.columnIndex == columnIndex;
  }

  @override
  int get hashCode => Object.hash(rowIndex, columnIndex);
}

/// A rectangular selection inside a single editable table.
class MarkdownTableCellSelection {
  /// Creates a table cell selection from an anchor and focus position.
  const MarkdownTableCellSelection({
    required this.tableId,
    required this.anchor,
    required this.focus,
  });

  /// Target table block ID.
  final String tableId;

  /// Selection anchor.
  final MarkdownTableCellPosition anchor;

  /// Selection focus.
  final MarkdownTableCellPosition focus;

  /// Topmost visual row index in the normalized rectangle.
  int get startRowIndex =>
      anchor.rowIndex < focus.rowIndex ? anchor.rowIndex : focus.rowIndex;

  /// Bottommost visual row index in the normalized rectangle.
  int get endRowIndex =>
      anchor.rowIndex > focus.rowIndex ? anchor.rowIndex : focus.rowIndex;

  /// Leftmost column index in the normalized rectangle.
  int get startColumnIndex => anchor.columnIndex < focus.columnIndex
      ? anchor.columnIndex
      : focus.columnIndex;

  /// Rightmost column index in the normalized rectangle.
  int get endColumnIndex => anchor.columnIndex > focus.columnIndex
      ? anchor.columnIndex
      : focus.columnIndex;

  /// Returns this selection with anchor at top-left and focus at bottom-right.
  MarkdownTableCellSelection get normalized => MarkdownTableCellSelection(
        tableId: tableId,
        anchor: MarkdownTableCellPosition(
          rowIndex: startRowIndex,
          columnIndex: startColumnIndex,
        ),
        focus: MarkdownTableCellPosition(
          rowIndex: endRowIndex,
          columnIndex: endColumnIndex,
        ),
      );

  /// Whether [position] is inside the normalized rectangle.
  bool contains(MarkdownTableCellPosition position) {
    return position.rowIndex >= startRowIndex &&
        position.rowIndex <= endRowIndex &&
        position.columnIndex >= startColumnIndex &&
        position.columnIndex <= endColumnIndex;
  }

  @override
  bool operator ==(Object other) {
    return other is MarkdownTableCellSelection &&
        other.tableId == tableId &&
        other.anchor == anchor &&
        other.focus == focus;
  }

  @override
  int get hashCode => Object.hash(tableId, anchor, focus);
}

List<MarkdownBlock> _replaceBlockInList(
  List<MarkdownBlock> blocks,
  MarkdownBlock replacement, {
  bool appendIfMissing = true,
}) {
  var replaced = false;
  final next = <MarkdownBlock>[];

  for (final block in blocks) {
    if (block.id == replacement.id) {
      next.add(replacement);
      replaced = true;
    } else {
      final nested = block.replaceNestedBlock(replacement);
      next.add(nested);
      replaced = replaced || nested != block;
    }
  }

  return replaced
      ? next
      : appendIfMissing
          ? [...blocks, replacement]
          : blocks;
}

List<MarkdownBlock> _replaceBlockWithBlocksInList(
  List<MarkdownBlock> blocks,
  String blockId,
  List<MarkdownBlock> replacements,
) {
  var replaced = false;
  final next = <MarkdownBlock>[];

  for (final block in blocks) {
    if (block.id == blockId) {
      next.addAll(replacements);
      replaced = true;
      continue;
    }

    final nested = block.replaceNestedBlockWithBlocks(blockId, replacements);
    next.add(nested);
    replaced = replaced || nested != block;
  }

  return replaced ? next : blocks;
}

List<MarkdownBlock> _removeBlockInList(
  List<MarkdownBlock> blocks,
  String blockId,
) {
  var changed = false;
  final next = <MarkdownBlock>[];

  for (final block in blocks) {
    if (block.id == blockId) {
      changed = true;
      continue;
    }

    final nested = _removeNestedBlock(block, blockId);
    next.add(nested);
    changed = changed || nested != block;
  }

  return changed ? next : blocks;
}

MarkdownBlock _removeNestedBlock(MarkdownBlock block, String blockId) {
  if (block is MarkdownBlockquoteBlock) {
    final nextBlocks = _removeBlockInList(block.blocks, blockId);
    return identical(nextBlocks, block.blocks)
        ? block
        : block.copyWith(blocks: nextBlocks);
  }

  if (block is MarkdownListBlock) {
    var changed = false;
    final nextItems = <MarkdownListItem>[];
    for (final item in block.items) {
      final nextBlocks = _removeBlockInList(item.blocks, blockId);
      if (identical(nextBlocks, item.blocks)) {
        nextItems.add(item);
      } else {
        nextItems.add(item.copyWith(blocks: nextBlocks));
        changed = true;
      }
    }
    return changed ? block.copyWith(items: nextItems) : block;
  }

  return block;
}

String _normalizeSerializedMarkdown(String markdown) {
  return markdown
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#160;', ' ')
      .replaceAll(String.fromCharCode(0x00A0), ' ');
}

/// Base class for editable block nodes.
abstract class MarkdownBlock {
  /// Creates an editable block.
  const MarkdownBlock({required this.id});

  /// Stable block identifier used by selections and transactions.
  final String id;

  /// Block type identifier.
  String get type;

  /// User-visible plain text.
  String get plainText;

  /// Serializes this block to Markdown.
  String toMarkdown();

  /// Converts this block to a serializable map.
  Map<String, dynamic> toJson();

  /// Finds [blockId] in this block or its children.
  MarkdownBlock? findBlock(String blockId) => id == blockId ? this : null;

  /// Replaces a nested block. Blocks without children return themselves.
  MarkdownBlock replaceNestedBlock(MarkdownBlock replacement) => this;

  /// Replaces a nested block with several blocks.
  MarkdownBlock replaceNestedBlockWithBlocks(
    String blockId,
    List<MarkdownBlock> replacements,
  ) =>
      this;
}

/// Paragraph block.
class MarkdownParagraphBlock extends MarkdownBlock {
  /// Creates a paragraph block.
  const MarkdownParagraphBlock({
    required super.id,
    required this.children,
  });

  /// Inline content.
  final List<MarkdownInlineNode> children;

  @override
  String get type => 'paragraph';

  @override
  String get plainText => children.map((child) => child.plainText).join();

  @override
  String toMarkdown() => children.map((child) => child.toMarkdown()).join();

  /// Returns a copy with updated fields.
  MarkdownParagraphBlock copyWith({
    String? id,
    List<MarkdownInlineNode>? children,
  }) {
    return MarkdownParagraphBlock(
      id: id ?? this.id,
      children: children ?? this.children,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'children': children.map((child) => child.toJson()).toList(),
      };
}

/// Heading block.
class MarkdownHeadingBlock extends MarkdownBlock {
  /// Creates a heading block.
  const MarkdownHeadingBlock({
    required super.id,
    required this.level,
    required this.children,
  }) : assert(level >= 1 && level <= 6, 'Heading level must be 1-6.');

  /// Heading level.
  final int level;

  /// Inline content.
  final List<MarkdownInlineNode> children;

  @override
  String get type => 'heading';

  @override
  String get plainText => children.map((child) => child.plainText).join();

  @override
  String toMarkdown() {
    final marker = List<String>.filled(level, '#').join();
    return '$marker ${children.map((child) => child.toMarkdown()).join()}'
        .trimRight();
  }

  /// Returns a copy with updated fields.
  MarkdownHeadingBlock copyWith({
    String? id,
    int? level,
    List<MarkdownInlineNode>? children,
  }) {
    return MarkdownHeadingBlock(
      id: id ?? this.id,
      level: level ?? this.level,
      children: children ?? this.children,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'level': level,
        'children': children.map((child) => child.toJson()).toList(),
      };
}

/// Blockquote block.
class MarkdownBlockquoteBlock extends MarkdownBlock {
  /// Creates a blockquote block.
  const MarkdownBlockquoteBlock({
    required super.id,
    required this.blocks,
  });

  /// Quoted child blocks.
  final List<MarkdownBlock> blocks;

  @override
  String get type => 'blockquote';

  @override
  String get plainText => blocks.map((block) => block.plainText).join('\n\n');

  @override
  MarkdownBlock? findBlock(String blockId) {
    if (id == blockId) return this;
    for (final block in blocks) {
      final match = block.findBlock(blockId);
      if (match != null) return match;
    }
    return null;
  }

  @override
  MarkdownBlock replaceNestedBlock(MarkdownBlock replacement) {
    final nextBlocks = _replaceBlockInList(
      blocks,
      replacement,
      appendIfMissing: false,
    );
    return identical(nextBlocks, blocks) ? this : copyWith(blocks: nextBlocks);
  }

  @override
  MarkdownBlock replaceNestedBlockWithBlocks(
    String blockId,
    List<MarkdownBlock> replacements,
  ) {
    final nextBlocks = _replaceBlockWithBlocksInList(
      blocks,
      blockId,
      replacements,
    );
    return identical(nextBlocks, blocks) ? this : copyWith(blocks: nextBlocks);
  }

  @override
  String toMarkdown() {
    final markdown = blocks.map((block) => block.toMarkdown()).join('\n\n');
    return markdown
        .split('\n')
        .map((line) => line.isEmpty ? '>' : '> $line')
        .join('\n');
  }

  /// Returns a copy with updated fields.
  MarkdownBlockquoteBlock copyWith({
    String? id,
    List<MarkdownBlock>? blocks,
  }) {
    return MarkdownBlockquoteBlock(
      id: id ?? this.id,
      blocks: blocks ?? this.blocks,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'blocks': blocks.map((block) => block.toJson()).toList(),
      };
}

/// List block kind.
enum MarkdownListKind {
  /// Bullet list.
  bullet,

  /// Ordered list.
  ordered,

  /// Task list.
  task,
}

/// List block.
class MarkdownListBlock extends MarkdownBlock {
  /// Creates a list block.
  const MarkdownListBlock({
    required super.id,
    required this.kind,
    required this.items,
    this.startIndex = 1,
  });

  /// List kind.
  final MarkdownListKind kind;

  /// Ordered list start index.
  final int startIndex;

  /// List items.
  final List<MarkdownListItem> items;

  @override
  String get type => 'list';

  @override
  String get plainText => items.map((item) => item.plainText).join('\n');

  @override
  MarkdownBlock? findBlock(String blockId) {
    if (id == blockId) return this;
    for (final item in items) {
      for (final block in item.blocks) {
        final match = block.findBlock(blockId);
        if (match != null) return match;
      }
    }
    return null;
  }

  @override
  MarkdownBlock replaceNestedBlock(MarkdownBlock replacement) {
    var changed = false;
    final nextItems = <MarkdownListItem>[];
    for (final item in items) {
      final nextBlocks = _replaceBlockInList(
        item.blocks,
        replacement,
        appendIfMissing: false,
      );
      if (identical(nextBlocks, item.blocks)) {
        nextItems.add(item);
      } else {
        nextItems.add(item.copyWith(blocks: nextBlocks));
        changed = true;
      }
    }
    if (!changed) return this;
    return copyWith(
      items: nextItems,
    );
  }

  @override
  MarkdownBlock replaceNestedBlockWithBlocks(
    String blockId,
    List<MarkdownBlock> replacements,
  ) {
    var changed = false;
    final nextItems = <MarkdownListItem>[];
    for (final item in items) {
      final nextBlocks = _replaceBlockWithBlocksInList(
        item.blocks,
        blockId,
        replacements,
      );
      if (identical(nextBlocks, item.blocks)) {
        nextItems.add(item);
      } else {
        nextItems.add(item.copyWith(blocks: nextBlocks));
        changed = true;
      }
    }
    if (!changed) return this;
    return copyWith(items: nextItems);
  }

  @override
  String toMarkdown() {
    final lines = <String>[];
    for (var i = 0; i < items.length; i++) {
      final marker = switch (kind) {
        MarkdownListKind.bullet => '- ',
        MarkdownListKind.ordered => '${startIndex + i}. ',
        MarkdownListKind.task => items[i].checked ? '- [x] ' : '- [ ] ',
      };
      final itemMarkdown = items[i].toMarkdown();
      final itemLines = itemMarkdown.isEmpty ? [''] : itemMarkdown.split('\n');
      lines.add(
        itemLines.first.isEmpty
            ? marker.trimRight()
            : '$marker${itemLines.first}',
      );
      for (final line in itemLines.skip(1)) {
        lines.add('  $line');
      }
    }
    return lines.join('\n');
  }

  /// Returns a copy with updated fields.
  MarkdownListBlock copyWith({
    String? id,
    MarkdownListKind? kind,
    int? startIndex,
    List<MarkdownListItem>? items,
  }) {
    return MarkdownListBlock(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      startIndex: startIndex ?? this.startIndex,
      items: items ?? this.items,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'kind': kind.name,
        'startIndex': startIndex,
        'items': items.map((item) => item.toJson()).toList(),
      };
}

/// Editable list item.
class MarkdownListItem {
  /// Creates a list item.
  const MarkdownListItem({
    required this.id,
    required this.blocks,
    this.checked = false,
  });

  /// Stable item ID.
  final String id;

  /// Child blocks in the item.
  final List<MarkdownBlock> blocks;

  /// Task-list checked state.
  final bool checked;

  /// User-visible text.
  String get plainText => blocks.map((block) => block.plainText).join('\n');

  /// Serializes item content without list marker.
  String toMarkdown() {
    final buffer = StringBuffer();
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      if (index > 0) {
        final previous = blocks[index - 1];
        buffer.write(
          block is MarkdownListBlock || previous is MarkdownListBlock
              ? '\n'
              : '\n\n',
        );
      }
      buffer.write(block.toMarkdown());
    }
    return buffer.toString();
  }

  /// Returns a copy with updated fields.
  MarkdownListItem copyWith({
    String? id,
    List<MarkdownBlock>? blocks,
    bool? checked,
  }) {
    return MarkdownListItem(
      id: id ?? this.id,
      blocks: blocks ?? this.blocks,
      checked: checked ?? this.checked,
    );
  }

  /// Converts item to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'checked': checked,
        'blocks': blocks.map((block) => block.toJson()).toList(),
      };
}

/// YAML frontmatter block.
class MarkdownFrontmatterBlock extends MarkdownBlock {
  /// Creates a frontmatter block.
  const MarkdownFrontmatterBlock({
    required super.id,
    required this.content,
  });

  /// Raw frontmatter content without fence markers.
  final String content;

  @override
  String get type => 'frontmatter';

  @override
  String get plainText => content;

  @override
  String toMarkdown() {
    final normalizedContent = content.replaceFirst(RegExp(r'\r?\n$'), '');
    return '---\n$normalizedContent\n---';
  }

  /// Returns a copy with updated fields.
  MarkdownFrontmatterBlock copyWith({
    String? id,
    String? content,
  }) {
    return MarkdownFrontmatterBlock(
      id: id ?? this.id,
      content: content ?? this.content,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'content': content,
      };
}

/// Fenced code block.
class MarkdownCodeBlock extends MarkdownBlock {
  /// Creates a code block.
  const MarkdownCodeBlock({
    required super.id,
    required this.code,
    this.language = '',
    this.fence = '```',
    this.info,
  });

  /// Code language.
  final String language;

  /// Code content.
  final String code;

  /// Fence marker.
  final String fence;

  /// Full code fence info string, including the language.
  final String? info;

  @override
  String get type => 'code';

  @override
  String get plainText => code;

  @override
  String toMarkdown() {
    final openingInfo = info ?? language;
    return '$fence$openingInfo\n$code\n$fence';
  }

  /// Returns a copy with updated fields.
  MarkdownCodeBlock copyWith({
    String? id,
    String? language,
    String? code,
    String? fence,
    String? info,
  }) {
    return MarkdownCodeBlock(
      id: id ?? this.id,
      language: language ?? this.language,
      code: code ?? this.code,
      fence: fence ?? this.fence,
      info: info ?? this.info,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'language': language,
        'code': code,
        'fence': fence,
        if (info != null) 'info': info,
      };
}

/// Mermaid diagram block.
class MarkdownMermaidBlock extends MarkdownBlock {
  /// Creates a Mermaid block.
  const MarkdownMermaidBlock({
    required super.id,
    required this.code,
    this.theme,
    this.fence = '```',
    this.info,
  });

  /// Mermaid source code.
  final String code;

  /// Optional Mermaid theme.
  final String? theme;

  /// Fence marker.
  final String fence;

  /// Full Mermaid fence info string, including `mermaid`.
  final String? info;

  @override
  String get type => 'mermaid';

  @override
  String get plainText => code;

  @override
  String toMarkdown() {
    final openingInfo = info ??
        (theme == null || theme!.isEmpty ? 'mermaid' : 'mermaid theme=$theme');
    return '$fence$openingInfo\n$code\n$fence';
  }

  /// Returns a copy with updated fields.
  MarkdownMermaidBlock copyWith({
    String? id,
    String? code,
    String? theme,
    String? fence,
    String? info,
  }) {
    return MarkdownMermaidBlock(
      id: id ?? this.id,
      code: code ?? this.code,
      theme: theme ?? this.theme,
      fence: fence ?? this.fence,
      info: info ?? this.info,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'code': code,
        if (theme != null) 'theme': theme,
        'fence': fence,
        if (info != null) 'info': info,
      };
}

/// Display math block.
class MarkdownBlockMathBlock extends MarkdownBlock {
  /// Creates a block math block.
  const MarkdownBlockMathBlock({
    required super.id,
    required this.latex,
  });

  /// LaTeX source.
  final String latex;

  @override
  String get type => 'block_math';

  @override
  String get plainText => latex;

  @override
  String toMarkdown() => '${r'$$'}\n$latex\n${r'$$'}';

  /// Returns a copy with updated fields.
  MarkdownBlockMathBlock copyWith({
    String? id,
    String? latex,
  }) {
    return MarkdownBlockMathBlock(
      id: id ?? this.id,
      latex: latex ?? this.latex,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'latex': latex,
      };
}

/// Horizontal rule block.
class MarkdownHorizontalRuleBlock extends MarkdownBlock {
  /// Creates a horizontal rule block.
  const MarkdownHorizontalRuleBlock({required super.id});

  @override
  String get type => 'horizontal_rule';

  @override
  String get plainText => '';

  @override
  String toMarkdown() => '---';

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
      };
}

/// Raw Markdown block preserved for unsupported or custom AST nodes.
class MarkdownRawBlock extends MarkdownBlock {
  /// Creates a raw Markdown block.
  const MarkdownRawBlock({
    required super.id,
    required this.markdown,
  });

  /// Original Markdown source for this block.
  final String markdown;

  @override
  String get type => 'raw';

  @override
  String get plainText => markdown;

  @override
  String toMarkdown() => markdown;

  /// Returns a copy with updated fields.
  MarkdownRawBlock copyWith({
    String? id,
    String? markdown,
  }) {
    return MarkdownRawBlock(
      id: id ?? this.id,
      markdown: markdown ?? this.markdown,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'markdown': markdown,
      };
}

/// Standalone image block.
class MarkdownImageBlock extends MarkdownBlock {
  /// Creates an image block.
  const MarkdownImageBlock({
    required super.id,
    required this.url,
    required this.alt,
    this.title,
  });

  /// Image URL.
  final String url;

  /// Alt text.
  final String alt;

  /// Optional image title.
  final String? title;

  @override
  String get type => 'image';

  @override
  String get plainText => alt;

  @override
  String toMarkdown() {
    final titleSuffix = title == null ? '' : ' "${_escapeLinkTitle(title!)}"';
    return '![${_escapeMarkdownText(alt)}]($url$titleSuffix)';
  }

  /// Returns a copy with updated fields.
  MarkdownImageBlock copyWith({
    String? id,
    String? url,
    String? alt,
    String? title,
  }) {
    return MarkdownImageBlock(
      id: id ?? this.id,
      url: url ?? this.url,
      alt: alt ?? this.alt,
      title: title ?? this.title,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'url': url,
        'alt': alt,
        if (title != null) 'title': title,
      };
}

/// Table alignment.
enum MarkdownTableAlignment {
  /// Left alignment.
  left,

  /// Center alignment.
  center,

  /// Right alignment.
  right,
}

/// Editable table block.
class MarkdownTableBlock extends MarkdownBlock {
  /// Creates a table block.
  const MarkdownTableBlock({
    required super.id,
    required this.headers,
    required this.rows,
    required this.alignments,
    this.headerRow = true,
    this.headerColumn = false,
  });

  /// Header cells.
  final List<List<MarkdownInlineNode>> headers;

  /// Body rows.
  final List<List<List<MarkdownInlineNode>>> rows;

  /// Per-column alignment.
  final List<MarkdownTableAlignment?> alignments;

  /// Whether the first row is semantically a header row.
  final bool headerRow;

  /// Whether the first column is semantically a header column.
  final bool headerColumn;

  /// Number of columns in the table.
  int get columnCount => headers.length;

  @override
  String get type => 'table';

  @override
  String get plainText {
    final lines = <String>[
      headers.map(_plainInlineText).join('\t'),
      for (final row in rows) row.map(_plainInlineText).join('\t'),
    ];
    return lines.join('\n');
  }

  @override
  String toMarkdown() {
    final header = '| ${headers.map(_tableCellMarkdown).join(' | ')} |';
    final separator =
        '| ${List.generate(columnCount, (index) => _alignmentMarker(index)).join(' | ')} |';
    final body = rows
        .map((row) => '| ${row.map(_tableCellMarkdown).join(' | ')} |')
        .join('\n');
    return body.isEmpty ? '$header\n$separator' : '$header\n$separator\n$body';
  }

  String _alignmentMarker(int index) {
    final alignment = index < alignments.length ? alignments[index] : null;
    return switch (alignment) {
      MarkdownTableAlignment.left => ':---',
      MarkdownTableAlignment.center => ':---:',
      MarkdownTableAlignment.right => '---:',
      null => '---',
    };
  }

  /// Inserts an empty row after [rowIndex].
  MarkdownTableBlock insertRowAfter(int rowIndex) {
    final emptyRow = List<List<MarkdownInlineNode>>.generate(
      columnCount,
      (_) => const [MarkdownText('')],
    );
    final insertIndex = (rowIndex + 1).clamp(0, rows.length);
    return copyWith(
      rows: [
        ...rows.take(insertIndex),
        emptyRow,
        ...rows.skip(insertIndex),
      ],
    );
  }

  /// Inserts an empty row before [rowIndex].
  MarkdownTableBlock insertRowBefore(int rowIndex) {
    final emptyRow = List<List<MarkdownInlineNode>>.generate(
      columnCount,
      (_) => const [MarkdownText('')],
    );
    final insertIndex = rowIndex.clamp(0, rows.length);
    return copyWith(
      rows: [
        ...rows.take(insertIndex),
        emptyRow,
        ...rows.skip(insertIndex),
      ],
    );
  }

  /// Deletes row [rowIndex].
  MarkdownTableBlock deleteRow(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= rows.length) return this;
    return copyWith(
      rows: [
        for (var i = 0; i < rows.length; i++)
          if (i != rowIndex) rows[i],
      ],
    );
  }

  /// Inserts an empty column after [columnIndex].
  MarkdownTableBlock insertColumnAfter(int columnIndex) {
    final insertIndex = (columnIndex + 1).clamp(0, columnCount);
    List<List<MarkdownInlineNode>> insertCell(
      List<List<MarkdownInlineNode>> cells,
    ) {
      return [
        ...cells.take(insertIndex),
        const [MarkdownText('')],
        ...cells.skip(insertIndex),
      ];
    }

    return copyWith(
      headers: insertCell(headers),
      alignments: [
        ...alignments.take(insertIndex),
        null,
        ...alignments.skip(insertIndex),
      ],
      rows: [for (final row in rows) insertCell(row)],
    );
  }

  /// Inserts an empty column before [columnIndex].
  MarkdownTableBlock insertColumnBefore(int columnIndex) {
    final insertIndex = columnIndex.clamp(0, columnCount);
    List<List<MarkdownInlineNode>> insertCell(
      List<List<MarkdownInlineNode>> cells,
    ) {
      return [
        ...cells.take(insertIndex),
        const [MarkdownText('')],
        ...cells.skip(insertIndex),
      ];
    }

    return copyWith(
      headers: insertCell(headers),
      alignments: [
        ...alignments.take(insertIndex),
        null,
        ...alignments.skip(insertIndex),
      ],
      rows: [for (final row in rows) insertCell(row)],
    );
  }

  /// Deletes column [columnIndex].
  MarkdownTableBlock deleteColumn(int columnIndex) {
    if (columnIndex < 0 || columnIndex >= columnCount || columnCount == 1) {
      return this;
    }

    List<List<MarkdownInlineNode>> removeCell(
      List<List<MarkdownInlineNode>> cells,
    ) {
      return [
        for (var i = 0; i < cells.length; i++)
          if (i != columnIndex) cells[i],
      ];
    }

    return copyWith(
      headers: removeCell(headers),
      alignments: [
        for (var i = 0; i < alignments.length; i++)
          if (i != columnIndex) alignments[i],
      ],
      rows: [for (final row in rows) removeCell(row)],
    );
  }

  /// Sets the alignment for column [columnIndex].
  MarkdownTableBlock setColumnAlignment(
    int columnIndex,
    MarkdownTableAlignment? alignment,
  ) {
    if (columnIndex < 0 || columnIndex >= columnCount) return this;
    final nextAlignments = List<MarkdownTableAlignment?>.generate(
      columnCount,
      (index) => index < alignments.length ? alignments[index] : null,
    );
    nextAlignments[columnIndex] = alignment;
    return copyWith(alignments: nextAlignments);
  }

  /// Toggles whether the first row is semantically a header row.
  MarkdownTableBlock toggleHeaderRow() {
    return copyWith(headerRow: !headerRow);
  }

  /// Toggles whether the first column is semantically a header column.
  MarkdownTableBlock toggleHeaderColumn() {
    return copyWith(headerColumn: !headerColumn);
  }

  /// Updates one table cell.
  MarkdownTableBlock updateCell({
    required int rowIndex,
    required int columnIndex,
    required List<MarkdownInlineNode> children,
    bool header = false,
  }) {
    if (columnIndex < 0 || columnIndex >= columnCount) return this;

    if (header) {
      return copyWith(
        headers: [
          for (var i = 0; i < headers.length; i++)
            i == columnIndex ? children : headers[i],
        ],
      );
    }

    if (rowIndex < 0 || rowIndex >= rows.length) return this;
    return copyWith(
      rows: [
        for (var row = 0; row < rows.length; row++)
          if (row == rowIndex)
            [
              for (var col = 0; col < rows[row].length; col++)
                col == columnIndex ? children : rows[row][col],
            ]
          else
            rows[row],
      ],
    );
  }

  /// Returns a copy with updated fields.
  MarkdownTableBlock copyWith({
    String? id,
    List<List<MarkdownInlineNode>>? headers,
    List<List<List<MarkdownInlineNode>>>? rows,
    List<MarkdownTableAlignment?>? alignments,
    bool? headerRow,
    bool? headerColumn,
  }) {
    return MarkdownTableBlock(
      id: id ?? this.id,
      headers: headers ?? this.headers,
      rows: rows ?? this.rows,
      alignments: alignments ?? this.alignments,
      headerRow: headerRow ?? this.headerRow,
      headerColumn: headerColumn ?? this.headerColumn,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'headerRow': headerRow,
        'headerColumn': headerColumn,
        'headers': headers
            .map((cell) => cell.map((child) => child.toJson()).toList())
            .toList(),
        'alignments': alignments.map((alignment) => alignment?.name).toList(),
        'rows': rows
            .map(
              (row) => row
                  .map((cell) => cell.map((child) => child.toJson()).toList())
                  .toList(),
            )
            .toList(),
      };
}

/// Base class for editable inline nodes.
abstract class MarkdownInlineNode {
  /// Creates an inline node.
  const MarkdownInlineNode();

  /// Inline type identifier.
  String get type;

  /// User-visible plain text.
  String get plainText;

  /// Serializes this inline node to Markdown.
  String toMarkdown();

  /// Converts this inline node to JSON.
  Map<String, dynamic> toJson();
}

/// Plain text inline node.
class MarkdownText extends MarkdownInlineNode {
  /// Creates plain inline text.
  const MarkdownText(this.text);

  /// Text content.
  final String text;

  @override
  String get type => 'text';

  @override
  String get plainText => text;

  @override
  String toMarkdown() => _escapeMarkdownText(text);

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
      };
}

/// Strong/bold inline node.
class MarkdownStrong extends MarkdownInlineNode {
  /// Creates strong inline content.
  const MarkdownStrong(this.children);

  /// Child inline nodes.
  final List<MarkdownInlineNode> children;

  @override
  String get type => 'strong';

  @override
  String get plainText => children.map((child) => child.plainText).join();

  @override
  String toMarkdown() => '**${_inlineMarkdown(children)}**';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'children': children.map((child) => child.toJson()).toList(),
      };
}

/// Emphasis/italic inline node.
class MarkdownEmphasis extends MarkdownInlineNode {
  /// Creates emphasis inline content.
  const MarkdownEmphasis(this.children);

  /// Child inline nodes.
  final List<MarkdownInlineNode> children;

  @override
  String get type => 'emphasis';

  @override
  String get plainText => children.map((child) => child.plainText).join();

  @override
  String toMarkdown() => '*${_inlineMarkdown(children)}*';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'children': children.map((child) => child.toJson()).toList(),
      };
}

/// Strikethrough inline node.
class MarkdownStrikethrough extends MarkdownInlineNode {
  /// Creates strikethrough inline content.
  const MarkdownStrikethrough(this.children);

  /// Child inline nodes.
  final List<MarkdownInlineNode> children;

  @override
  String get type => 'strikethrough';

  @override
  String get plainText => children.map((child) => child.plainText).join();

  @override
  String toMarkdown() => '~~${_inlineMarkdown(children)}~~';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'children': children.map((child) => child.toJson()).toList(),
      };
}

/// Inline code.
class MarkdownInlineCode extends MarkdownInlineNode {
  /// Creates inline code.
  const MarkdownInlineCode(this.code);

  /// Code text.
  final String code;

  @override
  String get type => 'inline_code';

  @override
  String get plainText => code;

  @override
  String toMarkdown() => '`$code`';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'code': code,
      };
}

/// Hard line break inline node.
class MarkdownHardBreak extends MarkdownInlineNode {
  /// Creates a hard line break.
  const MarkdownHardBreak();

  @override
  String get type => 'hard_break';

  @override
  String get plainText => '\n';

  @override
  String toMarkdown() => '  \n';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
      };
}

/// Inline math.
class MarkdownInlineMath extends MarkdownInlineNode {
  /// Creates inline math.
  const MarkdownInlineMath(this.latex);

  /// LaTeX source.
  final String latex;

  @override
  String get type => 'inline_math';

  @override
  String get plainText => latex;

  @override
  String toMarkdown() => '\$$latex\$';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'latex': latex,
      };
}

/// Markdown link inline node.
class MarkdownLink extends MarkdownInlineNode {
  /// Creates a link inline node.
  const MarkdownLink({
    required this.children,
    required this.url,
    this.title,
  });

  /// Link text.
  final List<MarkdownInlineNode> children;

  /// Link URL.
  final String url;

  /// Optional link title.
  final String? title;

  @override
  String get type => 'link';

  @override
  String get plainText => children.map((child) => child.plainText).join();

  @override
  String toMarkdown() {
    final titleSuffix = title == null ? '' : ' "${_escapeLinkTitle(title!)}"';
    return '[${_inlineMarkdown(children)}]($url$titleSuffix)';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'url': url,
        if (title != null) 'title': title,
        'children': children.map((child) => child.toJson()).toList(),
      };
}

/// Markdown image inline node.
class MarkdownImage extends MarkdownInlineNode {
  /// Creates an image inline node.
  const MarkdownImage({
    required this.url,
    required this.alt,
    this.title,
  });

  /// Image URL.
  final String url;

  /// Alt text.
  final String alt;

  /// Optional title.
  final String? title;

  @override
  String get type => 'image';

  @override
  String get plainText => alt;

  @override
  String toMarkdown() {
    final titleSuffix = title == null ? '' : ' "${_escapeLinkTitle(title!)}"';
    return '![${_escapeMarkdownText(alt)}]($url$titleSuffix)';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'url': url,
        'alt': alt,
        if (title != null) 'title': title,
      };
}

/// Wikilink inline node.
class MarkdownWikilink extends MarkdownInlineNode {
  /// Creates a wikilink inline node.
  const MarkdownWikilink({
    required this.target,
  });

  /// Target note/page.
  ///
  /// Scratch treats the entire text inside `[[...]]` as the target.
  final String target;

  /// Visible label.
  String get label => target;

  @override
  String get type => 'wikilink';

  @override
  String get plainText => label;

  @override
  String toMarkdown() => '[[$target]]';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target,
      };
}

String _inlineMarkdown(List<MarkdownInlineNode> children) {
  return children.map((child) => child.toMarkdown()).join();
}

String _tableCellMarkdown(List<MarkdownInlineNode> children) {
  return _inlineMarkdown(children).replaceAll('|', r'\|');
}

String _plainInlineText(List<MarkdownInlineNode> children) {
  return children.map((child) => child.plainText).join();
}

String _escapeMarkdownText(String text) {
  final escaped = text
      .replaceAll('\\', r'\\')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]')
      .replaceAll('`', r'\`')
      .replaceAll('*', r'\*');
  return _escapeMarkdownLineStarts(
    _escapeMarkdownTildeRuns(_escapeMarkdownUnderscores(escaped)),
  );
}

String _escapeMarkdownUnderscores(String text) {
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    final char = text[index];
    if (char != '_') {
      buffer.write(char);
      continue;
    }

    final previous = index == 0 ? null : text.codeUnitAt(index - 1);
    final next = index + 1 >= text.length ? null : text.codeUnitAt(index + 1);
    if (_isAsciiWord(previous) && _isAsciiWord(next)) {
      buffer.write(char);
    } else {
      buffer.write(r'\_');
    }
  }
  return buffer.toString();
}

bool _isAsciiWord(int? codeUnit) {
  if (codeUnit == null) return false;
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A);
}

String _escapeMarkdownTildeRuns(String text) {
  final buffer = StringBuffer();
  var index = 0;
  while (index < text.length) {
    if (text[index] != '~') {
      buffer.write(text[index]);
      index++;
      continue;
    }

    var end = index + 1;
    while (end < text.length && text[end] == '~') {
      end++;
    }

    final runLength = end - index;
    if (runLength == 2) {
      buffer.write(r'\~\~');
    } else {
      buffer.write(text.substring(index, end));
    }
    index = end;
  }
  return buffer.toString();
}

String _escapeMarkdownLineStarts(String text) {
  return text.split('\n').map(_escapeMarkdownLineStart).join('\n');
}

String _escapeMarkdownLineStart(String line) {
  final trimmedLeft = line.trimLeft();
  final indent = line.substring(0, line.length - trimmedLeft.length);
  if (trimmedLeft.isEmpty) return line;

  if (RegExp(r'^#{1,6}\s+').hasMatch(trimmedLeft)) {
    return '$indent\\$trimmedLeft';
  }
  if (RegExp(r'^[-+]\s+').hasMatch(trimmedLeft)) {
    return '$indent\\$trimmedLeft';
  }
  if (RegExp(r'^\d+\.\s+').hasMatch(trimmedLeft)) {
    return '$indent${trimmedLeft.replaceFirst('.', r'\.')}';
  }
  if (trimmedLeft.startsWith('>')) {
    return '$indent\\$trimmedLeft';
  }
  if (RegExp(r'^-{3,}\s*$').hasMatch(trimmedLeft) ||
      RegExp(r'^_{3,}\s*$').hasMatch(trimmedLeft)) {
    return '$indent\\$trimmedLeft';
  }
  return line;
}

String _escapeLinkTitle(String text) => text.replaceAll('"', r'\"');

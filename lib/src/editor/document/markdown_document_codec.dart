import 'dart:convert';

import '../../parser/ast/markdown_node.dart' as ast;
import '../../parser/markdown_parser.dart';
import '../../parser/parser_plugin.dart';
import '../../parser/plugins/mermaid_plugin.dart';
import '../wikilink.dart';
import 'markdown_document.dart';

/// Markdown import/export bridge for [MarkdownDocument].
class MarkdownDocumentCodec {
  /// Creates a document codec.
  MarkdownDocumentCodec({ParserPluginRegistry? plugins})
      : _plugins = _withEditorPlugins(plugins);

  final ParserPluginRegistry _plugins;

  /// Parses [markdown] into an editable document tree.
  MarkdownDocument parse(String markdown) {
    final parser = MarkdownParser(plugins: _plugins);
    final ids = _DocumentIdFactory();
    final frontmatter = _consumeFrontmatter(markdown);
    final body = frontmatter?.body ?? markdown;
    final sourceReader = _MarkdownBlockSourceReader(body, _plugins);
    final nodes = parser.parse(body);
    return MarkdownDocument(
      blocks: [
        if (frontmatter != null)
          MarkdownFrontmatterBlock(
            id: ids.block(),
            content: frontmatter.content,
          ),
        for (final node in nodes)
          _blockFromAst(
            node,
            ids,
            parser,
            sourceMarkdown: sourceReader.nextBlockSource(),
          ),
      ],
    );
  }

  /// Serializes [document] to Markdown.
  String serialize(MarkdownDocument document) => document.toMarkdown();

  static ParserPluginRegistry _withEditorPlugins(
      ParserPluginRegistry? plugins) {
    final registry = plugins?.copy() ?? ParserPluginRegistry();
    if (registry.getBlockPlugin('mermaid') == null) {
      registry.register(const MermaidPlugin());
    }
    if (registry.getInlinePlugin('wikilink') == null) {
      registry.register(const WikilinkPlugin());
    }
    return registry;
  }

  _FrontmatterParseResult? _consumeFrontmatter(String markdown) {
    final match = RegExp(
      '^(?:\uFEFF)?---[ \\t]*\\r?\\n'
      '([\\s\\S]*?\\r?\\n)?'
      '---[ \\t]*(?:\\r?\\n|\$)',
    ).firstMatch(markdown);
    if (match == null) return null;

    final content = (match.group(1) ?? '').replaceFirst(
      RegExp(r'\r?\n$'),
      '',
    );
    return _FrontmatterParseResult(
      content: content,
      body: markdown.substring(match.end),
    );
  }

  MarkdownBlock _blockFromAst(
    ast.MarkdownNode node,
    _DocumentIdFactory ids,
    MarkdownParser parser, {
    String? sourceMarkdown,
  }) {
    switch (node) {
      case ast.HeaderNode():
        return MarkdownHeadingBlock(
          id: ids.block(),
          level: node.level,
          children: _inlineFromAstList(
            node.children ?? parser.parseInlineOnly(node.content),
          ),
        );
      case ast.ParagraphNode():
        if (node.children.length == 1 &&
            node.children.single is ast.ImageNode) {
          final image = node.children.single as ast.ImageNode;
          return MarkdownImageBlock(
            id: ids.block(),
            url: image.url,
            alt: image.alt,
            title: image.title,
          );
        }
        return MarkdownParagraphBlock(
          id: ids.block(),
          children: _inlineFromAstList(node.children),
        );
      case ast.BlockquoteNode():
        final childSourceReader = sourceMarkdown == null
            ? null
            : _MarkdownBlockSourceReader(
                _blockquoteInnerMarkdown(sourceMarkdown),
                _plugins,
              );
        return MarkdownBlockquoteBlock(
          id: ids.block(),
          blocks: [
            for (final child in node.children)
              _blockFromAst(
                child,
                ids,
                parser,
                sourceMarkdown: childSourceReader?.nextBlockSource(),
              ),
          ],
        );
      case ast.ListNode():
        final hasTasks = node.items.any((item) => item.checked != null);
        final kind = hasTasks
            ? MarkdownListKind.task
            : node.ordered
                ? MarkdownListKind.ordered
                : MarkdownListKind.bullet;
        return MarkdownListBlock(
          id: ids.block(),
          kind: kind,
          startIndex: node.startIndex,
          items: [
            for (final item in node.items)
              MarkdownListItem(
                id: ids.item(),
                checked: item.checked ?? false,
                blocks: _blocksFromListItemAst(item, ids, parser),
              ),
          ],
        );
      case ast.CodeBlockNode():
        final language = node.language ?? '';
        if (language == 'mermaid') {
          return MarkdownMermaidBlock(
            id: ids.block(),
            code: node.code,
            fence: node.fence,
            info: node.info,
          );
        }
        return MarkdownCodeBlock(
          id: ids.block(),
          language: language,
          code: node.code,
          fence: node.fence,
          info: node.info,
        );
      case MermaidDiagramNode():
        return MarkdownMermaidBlock(
          id: ids.block(),
          code: node.code,
          theme: node.theme,
          fence: node.fence,
          info: node.info,
        );
      case ast.BlockMathNode():
        return MarkdownBlockMathBlock(
          id: ids.block(),
          latex: node.latex,
        );
      case ast.TableNode():
        final columnCount = node.headers.length;
        return MarkdownTableBlock(
          id: ids.block(),
          headers: _normalizedTableCells(node.headers, columnCount),
          alignments: _normalizedTableAlignments(
            node.alignments,
            columnCount,
          ),
          rows: [
            for (final row in node.rows)
              _normalizedTableCells(row.cells, columnCount),
          ],
        );
      case ast.HorizontalRuleNode():
        return MarkdownHorizontalRuleBlock(id: ids.block());
      case ast.ImageNode():
        return MarkdownImageBlock(
          id: ids.block(),
          url: node.url,
          alt: node.alt,
          title: node.title,
        );
      default:
        return MarkdownRawBlock(
          id: ids.block(),
          markdown: _unsupportedMarkdownFromAst(node, sourceMarkdown),
        );
    }
  }

  List<MarkdownBlock> _blocksFromListItemAst(
    ast.ListItemNode item,
    _DocumentIdFactory ids,
    MarkdownParser parser,
  ) {
    final blocks = <MarkdownBlock>[];
    final inlineBuffer = <ast.MarkdownNode>[];

    void flushInlineBuffer() {
      if (inlineBuffer.isEmpty) return;
      blocks.add(
        MarkdownParagraphBlock(
          id: ids.block(),
          children: _inlineFromAstList(inlineBuffer),
        ),
      );
      inlineBuffer.clear();
    }

    for (final child in item.children) {
      if (_canBeInline(child)) {
        inlineBuffer.add(child);
      } else {
        flushInlineBuffer();
        blocks.add(_blockFromAst(child, ids, parser));
      }
    }
    flushInlineBuffer();

    if (blocks.isEmpty) {
      blocks.add(
        MarkdownParagraphBlock(
          id: ids.block(),
          children: const [MarkdownText('')],
        ),
      );
    }
    return blocks;
  }

  bool _canBeInline(ast.MarkdownNode node) {
    return node is ast.TextNode ||
        node is ast.HardBreakNode ||
        node is ast.InlineCodeNode ||
        node is ast.InlineMathNode ||
        node is ast.BoldNode ||
        node is ast.ItalicNode ||
        node is ast.StrikethroughNode ||
        node is ast.LinkNode ||
        node is ast.ImageNode ||
        node is WikilinkNode;
  }

  List<MarkdownInlineNode> _inlineFromAstList(List<ast.MarkdownNode> nodes) {
    final children = <MarkdownInlineNode>[];
    for (final node in nodes) {
      children.add(_inlineFromAst(node));
    }
    return children;
  }

  List<List<MarkdownInlineNode>> _normalizedTableCells(
    List<List<ast.MarkdownNode>> cells,
    int columnCount,
  ) {
    return [
      for (var column = 0; column < columnCount; column++)
        column < cells.length
            ? _inlineFromAstList(cells[column])
            : const [MarkdownText('')],
    ];
  }

  List<MarkdownTableAlignment?> _normalizedTableAlignments(
    List<ast.TableAlignment?> alignments,
    int columnCount,
  ) {
    return [
      for (var column = 0; column < columnCount; column++)
        if (column < alignments.length)
          switch (alignments[column]) {
            ast.TableAlignment.left => MarkdownTableAlignment.left,
            ast.TableAlignment.center => MarkdownTableAlignment.center,
            ast.TableAlignment.right => MarkdownTableAlignment.right,
            null => null,
          }
        else
          null,
    ];
  }

  MarkdownInlineNode _inlineFromAst(ast.MarkdownNode node) {
    switch (node) {
      case ast.TextNode():
        return MarkdownText(node.content);
      case ast.HardBreakNode():
        return const MarkdownHardBreak();
      case ast.InlineCodeNode():
        return MarkdownInlineCode(node.code);
      case ast.InlineMathNode():
        return MarkdownInlineMath(node.latex);
      case ast.BoldNode():
        return MarkdownStrong(_inlineFromAstList(node.children));
      case ast.ItalicNode():
        return MarkdownEmphasis(_inlineFromAstList(node.children));
      case ast.StrikethroughNode():
        return MarkdownStrikethrough(_inlineFromAstList(node.children));
      case ast.LinkNode():
        return MarkdownLink(
          url: node.url,
          title: node.title,
          children: _inlineFromAstList(node.children),
        );
      case ast.ImageNode():
        return MarkdownImage(
          url: node.url,
          alt: node.alt,
          title: node.title,
        );
      case WikilinkNode():
        return MarkdownWikilink(target: node.target);
      default:
        return MarkdownText(_plainTextFromAst(node));
    }
  }

  String _plainTextFromAst(ast.MarkdownNode node) {
    switch (node) {
      case ast.TextNode():
        return node.content;
      case ast.HeaderNode():
        return node.content;
      case ast.ParagraphNode():
        return node.children.map(_plainTextFromAst).join();
      case ast.BlockquoteNode():
        return node.children.map(_plainTextFromAst).join('\n');
      case ast.ListNode():
        return node.items.map(_plainTextFromAst).join('\n');
      case ast.ListItemNode():
        return node.children.map(_plainTextFromAst).join();
      case ast.CodeBlockNode():
        return node.code;
      case ast.InlineCodeNode():
        return node.code;
      case ast.HardBreakNode():
        return '\n';
      case ast.BoldNode():
        return node.children.map(_plainTextFromAst).join();
      case ast.ItalicNode():
        return node.children.map(_plainTextFromAst).join();
      case ast.StrikethroughNode():
        return node.children.map(_plainTextFromAst).join();
      case ast.LinkNode():
        return node.children.map(_plainTextFromAst).join();
      case ast.ImageNode():
        return node.alt;
      case ast.InlineMathNode():
        return node.latex;
      case ast.BlockMathNode():
        return node.latex;
      case WikilinkNode():
        return node.label;
      case MermaidDiagramNode():
        return node.code;
      default:
        return '';
    }
  }

  String _unsupportedMarkdownFromAst(
    ast.MarkdownNode node,
    String? sourceMarkdown,
  ) {
    if (sourceMarkdown != null && sourceMarkdown.trim().isNotEmpty) {
      return sourceMarkdown;
    }

    final encoded = const JsonEncoder.withIndent('  ').convert(node.toJson());
    final fence = _safeFallbackFence(encoded);
    return '$fence unsupported-${node.type}\n$encoded\n$fence';
  }

  String _blockquoteInnerMarkdown(String sourceMarkdown) {
    return sourceMarkdown.split('\n').map((line) {
      final trimmed = line.trim();
      if (trimmed.startsWith('> ')) {
        return trimmed.substring(2);
      }
      if (trimmed.startsWith('>')) {
        return trimmed.substring(1);
      }
      return '';
    }).join('\n');
  }

  String _safeFallbackFence(String content) {
    var length = 3;
    var fence = ''.padRight(length, '~');
    while (content.contains(fence)) {
      length++;
      fence = ''.padRight(length, '~');
    }
    return fence;
  }
}

class _MarkdownBlockSourceReader {
  _MarkdownBlockSourceReader(String markdown, ParserPluginRegistry plugins)
      : _lines = markdown.split('\n'),
        _plugins = plugins;

  final List<String> _lines;
  final ParserPluginRegistry _plugins;
  var _index = 0;

  static final _hrDashPattern = RegExp(r'^-{3,}$');
  static final _hrStarPattern = RegExp(r'^\*{3,}$');
  static final _hrUnderscorePattern = RegExp(r'^_{3,}$');
  static final _headerPattern = RegExp(r'^#{1,6}\s+.+');
  static final _unorderedListPattern = RegExp(r'^[-*+]\s+');
  static final _orderedListPattern = RegExp(r'^\d+\.\s+');
  static final _orderedListStartPattern = RegExp(r'^(\d+)\.');
  static final _footnotePattern = RegExp(r'^\[\^[^\]]+\]:\s+.+');
  static final _tableSeparatorPattern = RegExp(r'^\s*:?-+:?\s*$');

  String? nextBlockSource() {
    while (_index < _lines.length && _lines[_index].trim().isEmpty) {
      _index++;
    }
    if (_index >= _lines.length) return null;

    final start = _index;
    final consumed = _clampConsumed(_consumeBlockAt(_index), _index);
    _index += consumed;
    return _lines.sublist(start, start + consumed).join('\n');
  }

  int _clampConsumed(int consumed, int startIndex) {
    final remaining = _lines.length - startIndex;
    if (remaining <= 0) return 0;
    if (consumed <= 0) return 1;
    return consumed > remaining ? remaining : consumed;
  }

  int _consumeBlockAt(int index) {
    final line = _lines[index];

    final pluginResult = _tryParseWithPlugins(line, index);
    if (pluginResult != null) {
      return pluginResult.linesConsumed;
    }

    if (_isHorizontalRule(line) || _isHeader(line)) {
      return 1;
    }
    if (_isCodeBlockStart(line)) {
      return _consumeCodeBlock(index);
    }
    if (_isBlockMathStart(line)) {
      return _consumeBlockMath(index);
    }
    if (_isBlockquote(line)) {
      return _consumeBlockquote(index);
    }
    if (_isListItem(line)) {
      return _consumeList(index);
    }
    if (_isFootnoteDefinition(line)) {
      return _consumeFootnoteDefinition(index);
    }
    if (_isDetailsStart(line)) {
      return _consumeDetails(index);
    }
    if (_isTableStart(index)) {
      return _consumeTable(index);
    }
    return _consumeParagraph(index);
  }

  BlockParseResult? _tryParseWithPlugins(String line, int index) {
    for (final plugin in _plugins.blockPlugins) {
      if (plugin.canParse(line, _lines, index)) {
        final result = plugin.parse(_lines, index);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  bool _isHorizontalRule(String line) {
    final trimmed = line.trim();
    if (trimmed.length < 3) return false;
    return _hrDashPattern.hasMatch(trimmed) ||
        _hrStarPattern.hasMatch(trimmed) ||
        _hrUnderscorePattern.hasMatch(trimmed);
  }

  bool _isHeader(String line) => _headerPattern.hasMatch(line);

  bool _isCodeBlockStart(String line) => _parseCodeFenceStart(line) != null;

  int _consumeCodeBlock(int startIndex) {
    final openingFence = _parseCodeFenceStart(_lines[startIndex]);
    if (openingFence == null) return 1;

    var index = startIndex + 1;
    while (index < _lines.length) {
      if (_isCodeFenceClose(_lines[index], openingFence)) {
        return index - startIndex + 1;
      }
      index++;
    }
    return index - startIndex;
  }

  _CodeFence? _parseCodeFenceStart(String line) {
    final trimmed = line.trim();
    if (trimmed.length < 3) return null;

    final marker = trimmed[0];
    if (marker != '`' && marker != '~') return null;

    var length = 0;
    while (length < trimmed.length && trimmed[length] == marker) {
      length++;
    }
    if (length < 3) return null;

    return _CodeFence(marker: marker, literal: trimmed.substring(0, length));
  }

  bool _isCodeFenceClose(String line, _CodeFence openingFence) {
    final trimmed = line.trim();
    var length = 0;
    while (length < trimmed.length && trimmed[length] == openingFence.marker) {
      length++;
    }
    return length >= openingFence.literal.length && length == trimmed.length;
  }

  bool _isBlockMathStart(String line) => line.trim().startsWith('\$\$');

  int _consumeBlockMath(int startIndex) {
    final opening = _lines[startIndex].trim();
    final openingContent = opening.substring(2);
    if (openingContent.endsWith('\$\$')) {
      return 1;
    }

    var index = startIndex + 1;
    while (index < _lines.length) {
      if (_lines[index].trim().startsWith('\$\$')) {
        return index - startIndex + 1;
      }
      index++;
    }
    return index - startIndex;
  }

  bool _isBlockquote(String line) => line.trim().startsWith('>');

  int _consumeBlockquote(int startIndex) {
    var index = startIndex;
    while (index < _lines.length && _isBlockquote(_lines[index])) {
      index++;
    }
    return index - startIndex;
  }

  bool _isListItem(String line) {
    final trimmed = line.trim();
    return _unorderedListPattern.hasMatch(trimmed) ||
        _orderedListPattern.hasMatch(trimmed);
  }

  int _consumeList(int startIndex) {
    final firstLine = _lines[startIndex].trim();
    final baseIndent = _leadingIndent(_lines[startIndex]);
    final isOrdered = _orderedListStartPattern.hasMatch(firstLine);
    final isTaskList = !isOrdered && _isTaskListItem(firstLine);

    var hasItems = false;
    var index = startIndex;

    while (index < _lines.length) {
      final rawLine = _lines[index];
      final line = rawLine.trim();

      if (line.isEmpty) {
        index++;
        if (index < _lines.length &&
            _isListItem(_lines[index]) &&
            _leadingIndent(_lines[index]) >= baseIndent) {
          continue;
        }
        break;
      }

      if (!_isListItem(line)) {
        break;
      }

      final indent = _leadingIndent(rawLine);
      if (indent < baseIndent) {
        break;
      }

      if (indent > baseIndent) {
        if (!hasItems) break;
        index += _clampConsumed(_consumeList(index), index);
        continue;
      }

      final lineIsOrdered = _orderedListStartPattern.hasMatch(line);
      if (lineIsOrdered != isOrdered) {
        break;
      }
      if (!isOrdered && _isTaskListItem(line) != isTaskList) {
        break;
      }

      hasItems = true;
      index++;
    }

    return index - startIndex;
  }

  bool _isTaskListItem(String line) {
    if (!_unorderedListPattern.hasMatch(line)) {
      return false;
    }
    final content = line.replaceFirst(_unorderedListPattern, '');
    return content.startsWith('[ ] ') ||
        content.startsWith('[x] ') ||
        content.startsWith('[X] ');
  }

  int _leadingIndent(String line) {
    var indent = 0;
    for (final unit in line.codeUnits) {
      if (unit == 0x20) {
        indent++;
      } else if (unit == 0x09) {
        indent += 4;
      } else {
        break;
      }
    }
    return indent;
  }

  bool _isFootnoteDefinition(String line) {
    return _footnotePattern.hasMatch(line.trim());
  }

  int _consumeFootnoteDefinition(int startIndex) {
    var index = startIndex + 1;
    while (index < _lines.length) {
      final line = _lines[index];
      if (line.trim().isEmpty) {
        index++;
        continue;
      }
      if (line.startsWith('    ') || line.startsWith('\t')) {
        index++;
        continue;
      }
      break;
    }
    return index - startIndex;
  }

  bool _isDetailsStart(String line) {
    final trimmed = line.trim().toLowerCase();
    return trimmed == '<details>' || trimmed == '<details open>';
  }

  int _consumeDetails(int startIndex) {
    var index = startIndex + 1;
    while (index < _lines.length) {
      if (_lines[index].trim().toLowerCase() == '</details>') {
        return index - startIndex + 1;
      }
      index++;
    }
    return index - startIndex + 1;
  }

  bool _isTableStart(int index) {
    if (index >= _lines.length) return false;

    final line = _lines[index].trim();
    if (!_hasUnescapedPipe(line)) return false;

    if (index + 1 >= _lines.length) return false;
    final nextLine = _lines[index + 1].trim();

    return _isTableSeparator(nextLine);
  }

  bool _isTableSeparator(String line) {
    if (!_hasUnescapedPipe(line)) return false;

    final parts = _splitTableCells(line);
    if (parts.isEmpty) return false;

    return parts.every((part) => _tableSeparatorPattern.hasMatch(part));
  }

  int _consumeTable(int startIndex) {
    var index = startIndex + 2;
    while (index < _lines.length) {
      final line = _lines[index].trim();
      if (line.isEmpty || !_hasUnescapedPipe(line)) {
        break;
      }
      index++;
    }
    return index - startIndex;
  }

  bool _hasUnescapedPipe(String line) {
    for (var index = 0; index < line.length; index++) {
      if (line[index] == '|' && !_isEscaped(line, index)) return true;
    }
    return false;
  }

  List<String> _splitTableCells(String line) {
    final trimmed = _trimTableBoundaryPipes(line);
    final cells = <String>[];
    final buffer = StringBuffer();

    for (var index = 0; index < trimmed.length; index++) {
      final char = trimmed[index];
      if (char == '|' && !_isEscaped(trimmed, index)) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    cells.add(buffer.toString());
    return cells;
  }

  String _trimTableBoundaryPipes(String line) {
    var trimmed = line.trim();
    if (trimmed.isNotEmpty &&
        trimmed.startsWith('|') &&
        !_isEscaped(trimmed, 0)) {
      trimmed = trimmed.substring(1);
    }
    if (trimmed.isNotEmpty &&
        trimmed.endsWith('|') &&
        !_isEscaped(trimmed, trimmed.length - 1)) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  bool _isEscaped(String text, int index) {
    var slashCount = 0;
    for (var i = index - 1; i >= 0 && text[i] == r'\'; i--) {
      slashCount++;
    }
    return slashCount.isOdd;
  }

  int _consumeParagraph(int startIndex) {
    var index = startIndex;

    while (index < _lines.length) {
      final line = _lines[index];

      if (line.trim().isEmpty) {
        break;
      }

      if (_isHeader(line) ||
          _isCodeBlockStart(line) ||
          _isBlockMathStart(line) ||
          _isBlockquote(line) ||
          _isListItem(line) ||
          _isHorizontalRule(line) ||
          _isFootnoteDefinition(line) ||
          _isTableStart(index)) {
        break;
      }

      index++;
    }

    return index - startIndex;
  }
}

class _CodeFence {
  const _CodeFence({
    required this.marker,
    required this.literal,
  });

  final String marker;
  final String literal;
}

class _FrontmatterParseResult {
  const _FrontmatterParseResult({
    required this.content,
    required this.body,
  });

  final String content;
  final String body;
}

class _DocumentIdFactory {
  var _blockCount = 0;
  var _itemCount = 0;

  String block() => 'block-${_blockCount++}';

  String item() => 'item-${_itemCount++}';
}

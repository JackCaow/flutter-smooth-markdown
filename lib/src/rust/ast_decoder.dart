part of 'wire.dart';

final _codeLanguageWhitespace = RegExp(r'\s');
final _codeFence = RegExp(r'^\s*(`{3,}|~{3,})');

/// Consumes SMR1 directly into the supported AST. The legacy CoreNode decoder
/// remains available to contract tests, never on the production parse path.
extension MarkdownWireDecoder on CoreWireReader {
  /// Appends directly to flat retained nodes plus native-block end offsets.
  /// Empty reference blocks and split lists keep exact native retention indices.
  void markdownAppend(String source, List<MarkdownNode> nodes, List<int> ends) {
    _remaining = count();
    _markdownNode(
      source,
      const {},
      0,
      nodes,
      requireDocument: true,
      rootEnds: ends,
    );
    if (_remaining != 0) throw const FormatException('Invalid core tree');
    finish();
  }

  List<MarkdownNode> markdown(String source, Map<int, MarkdownNode> custom) {
    _remaining = count();
    final result = <MarkdownNode>[];
    _markdownNode(source, custom, 0, result, requireDocument: true);
    if (_remaining != 0) throw const FormatException('Invalid core tree');
    finish();
    return result;
  }

  /// Keep the native top-level grouping: one native list may become several
  /// Flutter lists, and a reference definition may produce no Flutter nodes.
  List<List<MarkdownNode>> markdownBlocks(String source) {
    _remaining = count();
    final blocks = <List<MarkdownNode>>[];
    _markdownNode(
      source,
      const {},
      0,
      [],
      requireDocument: true,
      rootBlocks: blocks,
    );
    if (_remaining != 0) throw const FormatException('Invalid core tree');
    finish();
    return blocks;
  }

  String _sourceText(
    String source,
    int start,
    int length,
    int encodedLength,
    int encodedOffset,
  ) {
    if (encodedLength == 0xfffffffe) {
      return source.substring(start, start + length);
    }
    final end = _offset;
    _offset = encodedOffset;
    final result = _stringBody(encodedLength);
    _offset = end;
    return result;
  }

  List<MarkdownNode> _markdownChildren(
    String source,
    Map<int, MarkdownNode> custom,
    int depth,
    int count,
    StringBuffer? plain, {
    List<List<MarkdownNode>>? cells,
    List<List<List<MarkdownNode>>>? rows,
  }) {
    final nodes = <MarkdownNode>[];
    for (var i = 0; i < count; i++) {
      _markdownNode(
        source,
        custom,
        depth + 1,
        nodes,
        plain: plain,
        tableCells: cells,
        tableRows: rows,
      );
    }
    return nodes;
  }

  void _markdownNode(
    String source,
    Map<int, MarkdownNode> custom,
    int depth,
    List<MarkdownNode> output, {
    bool requireDocument = false,
    List<List<MarkdownNode>>? rootBlocks,
    List<int>? rootEnds,
    List<List<List<MarkdownNode>>>? tableRows,
    List<List<MarkdownNode>>? tableCells,
    StringBuffer? plain,
  }) {
    if (_remaining-- <= 0 || depth > 256) {
      throw const FormatException('Invalid core tree depth/count');
    }
    final kind = word(),
        start = word(),
        length = word(),
        level = word(),
        flags = word(),
        listStart = word(),
        childrenCount = word();
    if (kind > 32 ||
        flags & ~255 != 0 ||
        start > source.length ||
        length > source.length - start ||
        childrenCount > _remaining ||
        (requireDocument && kind != 0)) {
      throw const FormatException('Invalid core node');
    }
    final sourceLength = word(), sourceOffset = _offset;
    if (sourceLength == 0xffffffff) {
      throw const FormatException('Unexpected null source');
    }
    if (sourceLength != 0xfffffffe) {
      if (sourceLength > (_data.lengthInBytes - _offset) ~/ 2) {
        throw const FormatException('Truncated UTF16 source');
      }
      _offset += sourceLength * 2;
    }
    // Text leaves dominate ordinary documents. Recognize the standard SMR1
    // field layout in place, retaining the general decoder for other layouts.
    // All offsets (including the two trailing fields) are checked before reads.
    if (kind == 12 &&
        childrenCount == 0 &&
        _data.lengthInBytes - _offset >= 24 &&
        _data.getUint32(_offset, Endian.little) == 0 &&
        _data.getUint32(_offset + 4, Endian.little) == 0 &&
        _data.getUint32(_offset + 8, Endian.little) == 0xffffffff) {
      final units = _data.getUint32(_offset + 12, Endian.little);
      if (units <= (_data.lengthInBytes - _offset - 24) ~/ 2) {
        final end = _offset + 16 + units * 2;
        if (_data.getUint32(end, Endian.little) == 0 &&
            _data.getUint32(end + 4, Endian.little) == 0) {
          _offset += 16;
          final text = _stringBody(units);
          _offset = end + 8;
          plain?.write(text);
          output.add(TextNode(text));
          return;
        }
      }
    }
    final info = requiredString(),
        destination = requiredString(),
        title = string(),
        literal = string(),
        label = requiredString();
    final alignmentCount = count();
    final alignments = kind == 5
        ? <TableAlignment?>[]
        : const <TableAlignment?>[];
    for (var i = 0; i < alignmentCount; i++) {
      final value = string();
      if (kind == 5) {
        alignments.add(switch (value) {
          'left' => TableAlignment.left,
          'center' => TableAlignment.center,
          'right' => TableAlignment.right,
          _ => null,
        });
      }
    }
    if (plain != null) {
      if (literal != null) {
        plain.write(literal);
      } else if (childrenCount == 0) {
        plain.write(
          _sourceText(source, start, length, sourceLength, sourceOffset),
        );
      }
    }
    final childPlain = literal == null && childrenCount > 0 ? plain : null;

    switch (kind) {
      case 0:
        for (var i = 0; i < childrenCount; i++) {
          final target = rootBlocks == null ? output : <MarkdownNode>[];
          _markdownNode(source, custom, depth + 1, target, plain: childPlain);
          rootBlocks?.add(target);
          rootEnds?.add(output.length);
        }
      case 1:
        output.add(
          ParagraphNode(
            _markdownChildren(source, custom, depth, childrenCount, childPlain),
          ),
        );
      case 2:
        if (level < 1 || level > 6)
          throw const FormatException('Invalid heading level');
        final text = StringBuffer();
        final nodes = _markdownChildren(
          source,
          custom,
          depth,
          childrenCount,
          text,
        );
        final content = text.toString();
        if (childPlain != null) childPlain.write(content);
        output.add(HeaderNode(level: level, content: content, children: nodes));
      case 3:
      case 4:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
        final trimmed = info.trim();
        final space = trimmed.indexOf(_codeLanguageWhitespace);
        final language = space < 0 ? trimmed : trimmed.substring(0, space);
        final fence =
            _codeFence
                .firstMatch(
                  _sourceText(
                    source,
                    start,
                    length,
                    sourceLength,
                    sourceOffset,
                  ),
                )
                ?.group(1) ??
            '```';
        final code = literal ?? '';
        output.add(
          CodeBlockNode(
            code: code.endsWith('\n')
                ? code.substring(0, code.length - 1)
                : code,
            language: language.isEmpty ? null : language,
            info: info.isEmpty ? null : info,
            fence: fence,
          ),
        );
      case 5:
        final rows = <List<List<MarkdownNode>>>[];
        _markdownChildren(
          source,
          custom,
          depth,
          childrenCount,
          childPlain,
          rows: rows,
        );
        if (rows.isNotEmpty) {
          output.add(
            TableNode(
              headers: rows.first,
              alignments: alignments,
              rows: [
                for (var i = 1; i < rows.length; i++) TableRowNode(rows[i]),
              ],
            ),
          );
        }
      case 6:
        if (tableRows == null) {
          output.addAll(
            _markdownChildren(source, custom, depth, childrenCount, childPlain),
          );
        } else {
          final cells = <List<MarkdownNode>>[];
          _markdownChildren(
            source,
            custom,
            depth,
            childrenCount,
            childPlain,
            cells: cells,
          );
          tableRows.add(cells);
        }
      case 7:
        final nodes = _markdownChildren(
          source,
          custom,
          depth,
          childrenCount,
          childPlain,
        );
        if (tableCells == null) {
          output.addAll(nodes);
        } else {
          tableCells.add(nodes);
        }
      case 8:
        final items = _markdownChildren(
          source,
          custom,
          depth,
          childrenCount,
          childPlain,
        ).whereType<ListItemNode>().toList();
        var from = 0;
        while (from < items.length) {
          var to = from + 1;
          while (to < items.length &&
              (items[to].checked != null) == (items[from].checked != null)) {
            to++;
          }
          output.add(
            ListNode(
              items: items.sublist(from, to),
              ordered: flags & 1 != 0,
              startIndex: (flags & 32 != 0 ? listStart : 1) + from,
            ),
          );
          from = to;
        }
      case 9:
        final nodes = _markdownChildren(
          source,
          custom,
          depth,
          childrenCount,
          childPlain,
        );
        if (nodes.isNotEmpty && nodes.first is ParagraphNode) {
          final first = (nodes.first as ParagraphNode).children;
          nodes.replaceRange(0, 1, first);
        }
        output.add(
          ListItemNode(
            children: nodes,
            checked: flags & 4 != 0 ? flags & 2 != 0 : null,
          ),
        );
      case 10:
        output.add(
          BlockquoteNode(
            _markdownChildren(source, custom, depth, childrenCount, childPlain),
          ),
        );
      case 11:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
        output.add(const HorizontalRuleNode());
      case 12:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
        output.add(
          TextNode(
            literal ??
                _sourceText(source, start, length, sourceLength, sourceOffset),
          ),
        );
      case 13:
        output.add(
          BoldNode(
            _markdownChildren(source, custom, depth, childrenCount, childPlain),
          ),
        );
      case 14:
        output.add(
          ItalicNode(
            _markdownChildren(source, custom, depth, childrenCount, childPlain),
          ),
        );
      case 15:
        output.add(
          StrikethroughNode(
            _markdownChildren(source, custom, depth, childrenCount, childPlain),
          ),
        );
      case 16:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
        output.add(InlineCodeNode(literal ?? ''));
      case 17:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
        output.add(InlineMathNode(literal ?? ''));
      case 18:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
        output.add(const TextNode('\n'));
      case 19:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
        output.add(const HardBreakNode());
      case 20:
      case 27:
      case 28:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
        output.add(
          TextNode(
            literal ??
                _sourceText(source, start, length, sourceLength, sourceOffset),
          ),
        );
      case 21:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
        output.add(BlockMathNode((literal ?? '').trim()));
      case 22:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
        output.add(FootnoteReferenceNode(label));
      case 23:
        output.add(
          FootnoteDefinitionNode(
            label: label,
            children: _markdownChildren(
              source,
              custom,
              depth,
              childrenCount,
              childPlain,
            ),
          ),
        );
      case 24:
        referenceLabels?.add(label.trim());
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
      case 32:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
      case 25:
        output.add(
          LinkNode(
            url: destination,
            title: title,
            children: _markdownChildren(
              source,
              custom,
              depth,
              childrenCount,
              childPlain,
            ),
          ),
        );
      case 26:
        final text = StringBuffer();
        _markdownChildren(source, custom, depth, childrenCount, text);
        final alt = text.toString();
        if (childPlain != null) childPlain.write(alt);
        output.add(ImageNode(url: destination, title: title, alt: alt));
      case 29:
        if (childrenCount != 0) {
          _markdownChildren(source, custom, depth, childrenCount, childPlain);
        }
        final id = int.tryParse(label);
        if (id == null || !custom.containsKey(id))
          throw const FormatException('Unknown custom node');
        output.add(custom[id]!);
      case 30:
      case 31:
        output.addAll(
          _markdownChildren(source, custom, depth, childrenCount, childPlain),
        );
    }
  }
}

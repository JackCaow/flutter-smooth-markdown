import '../ast/html_nodes.dart';
import '../ast/markdown_node.dart';
import 'html_utils.dart';

/// Parses nested block Markdown inside an HTML block.
typedef HtmlBlockChildrenParser = List<MarkdownNode> Function(String source);

/// A recognized HTML line that may interrupt normal paragraph parsing.
sealed class HtmlBlockMatch {
  const HtmlBlockMatch();
}

/// Match for a standalone HTML horizontal rule.
final class HtmlHorizontalRuleMatch extends HtmlBlockMatch {
  /// Creates a horizontal-rule match.
  const HtmlHorizontalRuleMatch();
}

/// Match for a whitelisted container block.
final class HtmlContainerBlockMatch extends HtmlBlockMatch {
  /// Creates a match carrying the normalized line and lexed opening tag.
  const HtmlContainerBlockMatch({
    required this.firstLine,
    required this.openTag,
  });

  /// Trimmed first source line used by block parsing.
  final String firstLine;

  /// Opening tag lexed during probing and reused during block parsing.
  final HtmlTag openTag;
}

/// Result of parsing one HTML block.
class HtmlBlockParseResult {
  /// Creates a block HTML parse result.
  const HtmlBlockParseResult({
    required this.node,
    required this.linesConsumed,
  });

  /// Existing Markdown AST node generated for the block.
  final MarkdownNode node;

  /// Number of source lines consumed.
  final int linesConsumed;
}

/// Internal parser for whitelisted block HTML.
class HtmlBlockParser {
  /// Creates a parser that delegates nested Markdown to [parseChildren].
  const HtmlBlockParser({required HtmlBlockChildrenParser parseChildren})
      : _parseChildren = parseChildren;

  static final RegExp _blockStartPattern = RegExp(
    r'^<(?:div|p|center|blockquote)\b',
    caseSensitive: false,
  );
  static final RegExp _horizontalRulePattern = RegExp(
    r'^<hr\s*/?>$',
    caseSensitive: false,
  );

  final HtmlBlockChildrenParser _parseChildren;

  /// Recognizes a supported HTML block marker at the start of [line].
  HtmlBlockMatch? probe(String line) {
    if (!_couldStartHtmlLine(line)) return null;
    final trimmed = line.trim();
    if (_horizontalRulePattern.hasMatch(trimmed)) {
      return const HtmlHorizontalRuleMatch();
    }
    if (!_blockStartPattern.hasMatch(trimmed)) return null;
    final openTag = lexHtmlTag(trimmed, 0);
    if (openTag == null || openTag.isClosing) return null;
    return HtmlContainerBlockMatch(firstLine: trimmed, openTag: openTag);
  }

  /// Parses a block previously recognized by [probe].
  HtmlBlockParseResult parseBlock(
    List<String> lines,
    int startIndex,
    HtmlContainerBlockMatch match,
  ) {
    assert(startIndex >= 0 && startIndex < lines.length);
    assert(lines[startIndex].trim() == match.firstLine);

    final openTag = match.openTag;
    final tagName = openTag.name;
    final align = _parseAlignment(openTag);
    if (openTag.isSelfClosing) {
      return HtmlBlockParseResult(
        node: _buildBlockNode(tagName, const <MarkdownNode>[], align),
        linesConsumed: 1,
      );
    }

    final contentLines = <String>[];
    var nesting = 1;
    var lineIndex = startIndex;
    while (lineIndex < lines.length) {
      final isFirst = lineIndex == startIndex;
      final lineText = isFirst ? match.firstLine : lines[lineIndex];
      final from = isFirst ? openTag.end : 0;
      final scan = scanHtmlCloseTag(
        lineText,
        from,
        tagName,
        initialNesting: nesting,
      );
      nesting = scan.nesting;

      final close = scan.close;
      if (close != null) {
        final before = lineText.substring(from, close.start);
        final after = lineText.substring(close.end);
        if (before.trim().isNotEmpty) contentLines.add(before);
        if (after.trim().isNotEmpty) contentLines.add(after);
        lineIndex++;
        break;
      }

      final content = lineText.substring(from);
      if (!isFirst || content.trim().isNotEmpty) contentLines.add(content);
      lineIndex++;
    }

    final source = contentLines.join('\n');
    final children =
        source.trim().isEmpty ? const <MarkdownNode>[] : _parseChildren(source);
    return HtmlBlockParseResult(
      node: _buildBlockNode(tagName, children, align),
      linesConsumed: lineIndex - startIndex,
    );
  }

  static bool _couldStartHtmlLine(String line) {
    if (line.isEmpty) return false;
    final first = line.codeUnitAt(0);
    return first <= 0x20 || first == 0x3C;
  }

  static HtmlBlockAlignment? _parseAlignment(HtmlTag tag) {
    if (tag.name == 'center') return HtmlBlockAlignment.center;
    return switch (tag.attributes['align']?.toLowerCase()) {
      'left' => HtmlBlockAlignment.left,
      'center' => HtmlBlockAlignment.center,
      'right' => HtmlBlockAlignment.right,
      _ => null,
    };
  }

  static MarkdownNode _buildBlockNode(
    String tag,
    List<MarkdownNode> children,
    HtmlBlockAlignment? align,
  ) {
    if (tag == 'blockquote') return BlockquoteNode(children);
    return HtmlBlockNode(tag: tag, children: children, align: align);
  }
}

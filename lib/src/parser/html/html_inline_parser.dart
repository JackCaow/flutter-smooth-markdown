import '../ast/html_nodes.dart';
import '../ast/markdown_node.dart';
import 'html_utils.dart';

/// Parses the children of a paired HTML tag at the supplied nesting [depth].
typedef HtmlInlineChildrenParser = List<MarkdownNode> Function(
  String source,
  int depth,
);

/// Result of parsing one HTML tag, which may yield zero or more nodes.
class HtmlInlineParseResult {
  /// Creates an HTML inline parse result.
  const HtmlInlineParseResult({
    required this.nodes,
    required this.consumed,
  });

  /// Nodes produced by the parsed HTML tag.
  final List<MarkdownNode> nodes;

  /// Number of source characters consumed.
  final int consumed;
}

/// Parses supported inline HTML tags into Markdown AST nodes.
///
/// Unknown tags are stripped while retaining their parsed children. Invalid
/// tags return `null` so callers can preserve the opening `<` as text.
class HtmlInlineParser {
  /// Creates an HTML inline parser using [parseChildren] for nested content.
  const HtmlInlineParser({required HtmlInlineChildrenParser parseChildren})
      : _parseChildren = parseChildren;

  final HtmlInlineChildrenParser _parseChildren;

  /// Attempts to parse an HTML tag starting at [start].
  ///
  /// [depth] is passed to nested child parsing after incrementing it by one.
  HtmlInlineParseResult? tryParse(String text, int start, int depth) {
    final tag = lexHtmlTag(text, start);
    if (tag == null) return null;

    final openConsumed = tag.end - start;
    if (tag.isClosing) {
      return HtmlInlineParseResult(nodes: const [], consumed: openConsumed);
    }

    final name = tag.name;
    if (htmlVoidTags.contains(name)) {
      return switch (name) {
        'br' => HtmlInlineParseResult(
            nodes: const [HardBreakNode()],
            consumed: openConsumed,
          ),
        'img' => HtmlInlineParseResult(
            nodes: _buildHtmlImageNodes(tag),
            consumed: openConsumed,
          ),
        _ => HtmlInlineParseResult(nodes: const [], consumed: openConsumed),
      };
    }

    if (tag.isSelfClosing) {
      return HtmlInlineParseResult(nodes: const [], consumed: openConsumed);
    }

    final contentStart = tag.end;
    final close = findHtmlCloseTag(text, contentStart, name);
    final contentEnd = close?.start ?? text.length;
    final consumed = (close?.end ?? text.length) - start;
    final inner = text.substring(contentStart, contentEnd);

    if (name == 'code') {
      return HtmlInlineParseResult(
        nodes: [InlineCodeNode(inner)],
        consumed: consumed,
      );
    }

    final children = _parseChildren(inner, depth + 1);
    final node = _buildHtmlInlineNode(name, tag.attributes, children);
    return HtmlInlineParseResult(
      nodes: node != null ? [node] : children,
      consumed: consumed,
    );
  }

  MarkdownNode? _buildHtmlInlineNode(
    String name,
    Map<String, String> attributes,
    List<MarkdownNode> children,
  ) {
    switch (name) {
      case 'b':
      case 'strong':
        return BoldNode(children);
      case 'i':
      case 'em':
        return ItalicNode(children);
      case 's':
      case 'del':
      case 'strike':
        return StrikethroughNode(children);
      case 'u':
      case 'ins':
        return UnderlineNode(children);
      case 'mark':
        return HighlightNode(children);
      case 'sub':
        return SubscriptNode(children);
      case 'sup':
        return SuperscriptNode(children);
      case 'kbd':
        return KbdNode(children);
      case 'a':
        return _buildHtmlLinkNode(attributes, children);
      case 'font':
      case 'span':
        return _buildStyledSpanNode(name, attributes, children);
      default:
        return null;
    }
  }

  MarkdownNode? _buildHtmlLinkNode(
    Map<String, String> attributes,
    List<MarkdownNode> children,
  ) {
    final href = attributes['href'];
    if (href == null || href.isEmpty || !isSafeHtmlUrl(href)) return null;

    final title = attributes['title'];
    return LinkNode(
      url: href,
      children: children,
      title: title == null || title.isEmpty ? null : title,
    );
  }

  MarkdownNode? _buildStyledSpanNode(
    String name,
    Map<String, String> attributes,
    List<MarkdownNode> children,
  ) {
    int? color;
    int? backgroundColor;
    double? fontSize;

    if (name == 'font') {
      final colorAttr = attributes['color'];
      if (colorAttr != null) color = parseHtmlColor(colorAttr);
      final sizeAttr = attributes['size'];
      if (sizeAttr != null) fontSize = parseFontSizeAttr(sizeAttr);
    } else {
      final style = attributes['style'];
      if (style != null) {
        final declarations = parseInlineCssDeclarations(style);
        final colorValue = declarations['color'];
        if (colorValue != null) color = parseHtmlColor(colorValue);
        final backgroundValue = declarations['background-color'];
        if (backgroundValue != null) {
          backgroundColor = parseHtmlColor(backgroundValue);
        }
        final sizeValue = declarations['font-size'];
        if (sizeValue != null) fontSize = parseHtmlFontSize(sizeValue);
      }
    }

    if (color == null && backgroundColor == null && fontSize == null) {
      return null;
    }
    return StyledSpanNode(
      children: children,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
    );
  }

  List<MarkdownNode> _buildHtmlImageNodes(HtmlTag tag) {
    final src = tag.attributes['src'] ?? '';
    final alt = tag.attributes['alt'] ?? '';
    if (src.isEmpty || !isSafeHtmlImageSrc(src)) {
      return alt.isEmpty ? const [] : [TextNode(alt)];
    }

    final title = tag.attributes['title'];
    final width = tag.attributes['width'];
    final height = tag.attributes['height'];
    return [
      ImageNode(
        url: src,
        alt: alt,
        title: title == null || title.isEmpty ? null : title,
        width: width == null ? null : parseHtmlDimension(width),
        height: height == null ? null : parseHtmlDimension(height),
      ),
    ];
  }
}

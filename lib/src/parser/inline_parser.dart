import 'ast/html_nodes.dart';
import 'ast/markdown_node.dart';
import 'html/html_utils.dart';
import 'parser_plugin.dart';

/// Parser for inline-level Markdown elements
///
/// Handles parsing of:
/// - Bold (**text** or __text__)
/// - Italic (*text* or _text_)
/// - Inline code (`code`)
/// - Links ([text](url))
/// - Images (![alt](url))
/// - Strikethrough (~~text~~)
/// - Whitelisted HTML tags (when [InlineParser.new] `enableHtml` is set)
///
/// Supports custom inline plugins through [ParserPluginRegistry].
class InlineParser {
  /// Creates a new inline parser
  ///
  /// Optionally accepts a [ParserPluginRegistry] for custom inline plugins.
  /// When [enableHtml] is true, whitelisted inline HTML tags such as
  /// `<b>`, `<mark>`, or `<img>` are parsed; unknown tags are stripped
  /// while their content is kept.
  InlineParser({ParserPluginRegistry? plugins, bool enableHtml = false})
      : _plugins = plugins,
        _enableHtml = enableHtml;

  /// Plugin registry for custom inline parsers
  final ParserPluginRegistry? _plugins;

  /// Whether whitelisted inline HTML tags are parsed
  final bool _enableHtml;

  /// Maximum recursion depth to prevent stack overflow on deeply nested input
  static const _maxDepth = 16;

  /// Characters that can be escaped with backslash per CommonMark spec
  static const _escapableChars = r'\`*_{}[]()#+-.!~$|><';

  /// Parses inline elements from text
  List<MarkdownNode> parse(String text, {int depth = 0}) {
    if (text.isEmpty) {
      return [];
    }

    // Prevent stack overflow on deeply nested input
    if (depth >= _maxDepth) {
      return [TextNode(text)];
    }

    final nodes = <MarkdownNode>[];
    var i = 0;

    while (i < text.length) {
      final hardBreak = _tryParseHardBreak(text, i);
      if (hardBreak != null) {
        nodes.add(hardBreak.node);
        i += hardBreak.consumed;
        continue;
      }

      // Handle backslash escapes first
      if (text[i] == r'\' &&
          i + 1 < text.length &&
          _escapableChars.contains(text[i + 1])) {
        nodes.add(TextNode(text[i + 1]));
        i += 2;
        continue;
      }

      // Try to match different inline patterns
      MarkdownNode? node;
      var consumed = 0;

      // Try plugins first (they have higher priority)
      if (_plugins != null) {
        final pluginResult = _tryParseWithPlugins(text, i);
        if (pluginResult != null) {
          node = pluginResult.node;
          consumed = pluginResult.consumed;
        }
      }

      // Try image first (must be before link as it starts with !)
      if (node == null && i < text.length && text[i] == '!') {
        final result = _tryParseImage(text, i);
        if (result != null) {
          node = result.node;
          consumed = result.consumed;
        }
      }

      // Try footnote reference (must be before link as it starts with [)
      if (node == null && i < text.length && text[i] == '[') {
        // Check if it's a footnote reference [^label]
        if (i + 1 < text.length && text[i + 1] == '^') {
          final result = _tryParseFootnoteReference(text, i);
          if (result != null) {
            node = result.node;
            consumed = result.consumed;
          }
        }
      }

      // Try link
      if (node == null && i < text.length && text[i] == '[') {
        final result = _tryParseLink(text, i, depth);
        if (result != null) {
          node = result.node;
          consumed = result.consumed;
        }
      }

      // Try HTML tag (may yield zero or several nodes, so it bypasses
      // the single-node flow and continues the loop directly)
      if (node == null && _enableHtml && text[i] == '<') {
        final result = _tryParseHtmlTag(text, i, depth);
        if (result != null) {
          assert(result.consumed > 0, 'HTML parsing must consume input');
          nodes.addAll(result.nodes);
          i += result.consumed;
          continue;
        }
      }

      // Try inline code
      if (node == null && i < text.length && text[i] == '`') {
        final result = _tryParseInlineCode(text, i);
        if (result != null) {
          node = result.node;
          consumed = result.consumed;
        }
      }

      // Try inline math
      if (node == null && i < text.length && text[i] == '\$') {
        final result = _tryParseInlineMath(text, i);
        if (result != null) {
          node = result.node;
          consumed = result.consumed;
        }
      }

      // Try strikethrough
      if (node == null &&
          i + 1 < text.length &&
          text[i] == '~' &&
          text[i + 1] == '~') {
        final result = _tryParseStrikethrough(text, i, depth);
        if (result != null) {
          node = result.node;
          consumed = result.consumed;
        }
      }

      // Try bold (** or __)
      if (node == null &&
          i + 1 < text.length &&
          ((text[i] == '*' && text[i + 1] == '*') ||
              (text[i] == '_' && text[i + 1] == '_'))) {
        final result = _tryParseBold(text, i, depth);
        if (result != null) {
          node = result.node;
          consumed = result.consumed;
        }
      }

      // Try italic (* or _)
      if (node == null &&
          i < text.length &&
          (text[i] == '*' || text[i] == '_')) {
        final result = _tryParseItalic(text, i, depth);
        if (result != null) {
          node = result.node;
          consumed = result.consumed;
        }
      }

      // If no special pattern matched, consume plain text
      if (node == null) {
        final plainText = _consumePlainText(text, i);
        nodes.add(TextNode(plainText.text));
        i += plainText.length;
      } else {
        nodes.add(node);
        i += consumed;
      }
    }

    return _mergeTextNodes(nodes);
  }

  /// Tries to parse a hard line break.
  ///
  /// CommonMark supports either a backslash before the line ending or at least
  /// two trailing spaces before the line ending.
  _InlineParseResult? _tryParseHardBreak(String text, int start) {
    if (start >= text.length) return null;

    if (text[start] == r'\') {
      final newlineLength = _newlineLengthAt(text, start + 1);
      if (newlineLength == 0) return null;
      return _InlineParseResult(
        node: const HardBreakNode(),
        consumed: 1 + newlineLength,
      );
    }

    if (text[start] != ' ') return null;

    var index = start;
    while (index < text.length && text[index] == ' ') {
      index++;
    }
    if (index - start < 2) return null;

    final newlineLength = _newlineLengthAt(text, index);
    if (newlineLength == 0) return null;
    return _InlineParseResult(
      node: const HardBreakNode(),
      consumed: index - start + newlineLength,
    );
  }

  int _newlineLengthAt(String text, int index) {
    if (index >= text.length) return 0;
    if (text[index] == '\n') return 1;
    if (text[index] == '\r') {
      return index + 1 < text.length && text[index + 1] == '\n' ? 2 : 1;
    }
    return 0;
  }

  /// Tries to parse an image
  _InlineParseResult? _tryParseImage(String text, int start) {
    if (start >= text.length || text[start] != '!') {
      return null;
    }

    if (start + 1 >= text.length || text[start + 1] != '[') {
      return null;
    }

    // Find closing ]
    var i = start + 2;
    var altEnd = -1;
    while (i < text.length) {
      if (text[i] == ']') {
        altEnd = i;
        break;
      }
      i++;
    }

    if (altEnd == -1) return null;

    // Check for (url)
    if (altEnd + 1 >= text.length || text[altEnd + 1] != '(') {
      return null;
    }

    // Find closing ) with parentheses nesting support
    final urlStart = altEnd + 2;
    final urlEnd = _findClosingParen(text, urlStart);

    if (urlEnd == -1) return null;

    final alt = text.substring(start + 2, altEnd);
    final urlAndTitle = text.substring(urlStart, urlEnd);

    // Parse URL and optional title
    final parts = _parseUrlAndTitle(urlAndTitle);

    return _InlineParseResult(
      node: ImageNode(
        url: parts.url,
        alt: alt,
        title: parts.title,
      ),
      consumed: urlEnd - start + 1,
    );
  }

  /// Tries to parse a link
  _InlineParseResult? _tryParseLink(String text, int start, int depth) {
    if (start >= text.length || text[start] != '[') {
      return null;
    }

    // Find closing ]
    var i = start + 1;
    var textEnd = -1;
    while (i < text.length) {
      if (text[i] == ']') {
        textEnd = i;
        break;
      }
      i++;
    }

    if (textEnd == -1) return null;

    // Check for (url)
    if (textEnd + 1 >= text.length || text[textEnd + 1] != '(') {
      return null;
    }

    // Find closing ) with parentheses nesting support
    final urlStart = textEnd + 2;
    final urlEnd = _findClosingParen(text, urlStart);

    if (urlEnd == -1) return null;

    final linkText = text.substring(start + 1, textEnd);
    final urlAndTitle = text.substring(urlStart, urlEnd);

    // Parse URL and optional title
    final parts = _parseUrlAndTitle(urlAndTitle);

    // Recursively parse link text
    final children = parse(linkText, depth: depth + 1);

    return _InlineParseResult(
      node: LinkNode(
        url: parts.url,
        children: children,
        title: parts.title,
      ),
      consumed: urlEnd - start + 1,
    );
  }

  /// Finds the closing parenthesis matching the opening one, handling nesting.
  ///
  /// [start] is the index right after the opening `(`.
  /// Returns the index of the matching `)`, or -1 if not found.
  int _findClosingParen(String text, int start) {
    var depth = 1;
    var i = start;
    while (i < text.length) {
      if (text[i] == '(') {
        depth++;
      } else if (text[i] == ')') {
        depth--;
        if (depth == 0) {
          return i;
        }
      }
      i++;
    }
    return -1;
  }

  /// Parses URL and optional title from link/image URL part
  _UrlAndTitle _parseUrlAndTitle(String urlPart) {
    final trimmed = urlPart.trim();

    // Check for title in quotes: url "title" or url 'title'
    final titleMatch =
        RegExp(r'^(.+?)\s+["' "'" r'](.+)["' "'" r']$').firstMatch(trimmed);

    if (titleMatch != null) {
      return _UrlAndTitle(
        url: titleMatch.group(1)!.trim(),
        title: titleMatch.group(2),
      );
    }

    return _UrlAndTitle(url: trimmed, title: null);
  }

  /// Tries to parse inline code
  _InlineParseResult? _tryParseInlineCode(String text, int start) {
    if (start >= text.length || text[start] != '`') {
      return null;
    }

    // Find closing `
    var i = start + 1;
    while (i < text.length) {
      if (text[i] == '`') {
        final code = text.substring(start + 1, i);
        return _InlineParseResult(
          node: InlineCodeNode(code),
          consumed: i - start + 1,
        );
      }
      i++;
    }

    return null;
  }

  /// Tries to parse inline math (LaTeX)
  _InlineParseResult? _tryParseInlineMath(String text, int start) {
    if (start >= text.length || text[start] != '\$') {
      return null;
    }

    // Make sure it's not block math ($$)
    if (start + 1 < text.length && text[start + 1] == '\$') {
      return null;
    }

    // Find closing $
    var i = start + 1;
    while (i < text.length) {
      if (text[i] == '\$') {
        final latex = text.substring(start + 1, i);
        if (latex.isEmpty) return null;

        return _InlineParseResult(
          node: InlineMathNode(latex),
          consumed: i - start + 1,
        );
      }
      i++;
    }

    return null;
  }

  /// Tries to parse a footnote reference
  ///
  /// Format: [^label] where label is alphanumeric
  _InlineParseResult? _tryParseFootnoteReference(String text, int start) {
    if (start >= text.length || text[start] != '[') {
      return null;
    }

    if (start + 1 >= text.length || text[start + 1] != '^') {
      return null;
    }

    // Find closing ]
    var i = start + 2;
    var labelEnd = -1;
    while (i < text.length) {
      if (text[i] == ']') {
        labelEnd = i;
        break;
      }
      i++;
    }

    if (labelEnd == -1) return null;

    final label = text.substring(start + 2, labelEnd);
    if (label.isEmpty) return null;

    return _InlineParseResult(
      node: FootnoteReferenceNode(label),
      consumed: labelEnd - start + 1,
    );
  }

  /// Tries to parse bold text
  _InlineParseResult? _tryParseBold(String text, int start, int depth) {
    if (start + 1 >= text.length) return null;

    final marker = text.substring(start, start + 2);
    if (marker != '**' && marker != '__') return null;

    // Find closing marker
    var i = start + 2;
    while (i + 1 < text.length) {
      if (text.substring(i, i + 2) == marker) {
        final content = text.substring(start + 2, i);
        if (content.isEmpty) return null;

        // Recursively parse content
        final children = parse(content, depth: depth + 1);

        return _InlineParseResult(
          node: BoldNode(children),
          consumed: i - start + 2,
        );
      }
      i++;
    }

    return null;
  }

  /// Tries to parse italic text
  _InlineParseResult? _tryParseItalic(String text, int start, int depth) {
    if (start >= text.length) return null;

    final marker = text[start];
    if (marker != '*' && marker != '_') return null;

    // Make sure it's not bold
    if (start + 1 < text.length && text[start + 1] == marker) {
      return null;
    }

    // Find closing marker
    var i = start + 1;
    while (i < text.length) {
      if (text[i] == marker) {
        final content = text.substring(start + 1, i);
        if (content.isEmpty) return null;

        // Recursively parse content
        final children = parse(content, depth: depth + 1);

        return _InlineParseResult(
          node: ItalicNode(children),
          consumed: i - start + 1,
        );
      }
      i++;
    }

    return null;
  }

  /// Tries to parse strikethrough text
  _InlineParseResult? _tryParseStrikethrough(
      String text, int start, int depth) {
    if (start + 1 >= text.length) return null;
    if (text.substring(start, start + 2) != '~~') return null;

    // Find closing ~~
    var i = start + 2;
    while (i + 1 < text.length) {
      if (text.substring(i, i + 2) == '~~') {
        final content = text.substring(start + 2, i);
        if (content.isEmpty) return null;

        // Recursively parse content
        final children = parse(content, depth: depth + 1);

        return _InlineParseResult(
          node: StrikethroughNode(children),
          consumed: i - start + 2,
        );
      }
      i++;
    }

    return null;
  }

  /// Consumes plain text until a special character
  _PlainTextResult _consumePlainText(String text, int start) {
    final buffer = StringBuffer();
    var i = start;

    while (i < text.length) {
      final char = text[i];

      if (char == ' ' && _tryParseHardBreak(text, i) != null) {
        break;
      }

      // Stop at special characters (including backslash for escape handling)
      if (char == r'\' ||
          char == '*' ||
          char == '_' ||
          char == '`' ||
          char == '~' ||
          char == '[' ||
          char == '!' ||
          char == '\$' ||
          (_enableHtml && char == '<')) {
        break;
      }

      // Stop at plugin trigger characters
      final plugins = _plugins;
      if (plugins != null && plugins.isInlineTrigger(char)) {
        break;
      }

      buffer.write(char);
      i++;
    }

    final result = buffer.toString();
    return _PlainTextResult(
      text: result.isEmpty ? text[start] : result,
      length: result.isEmpty ? 1 : result.length,
    );
  }

  /// Tries to parse using registered plugins
  ///
  /// Returns null if no plugin can parse at the current position.
  InlineParseResult? _tryParseWithPlugins(String text, int index) {
    final plugins = _plugins;
    if (plugins == null || index >= text.length) return null;

    final char = text[index];
    for (final plugin in plugins.inlinePlugins) {
      if (plugin.triggerCharacter == char && plugin.canParse(text, index)) {
        final result = plugin.parse(text, index);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  /// Tries to parse a whitelisted HTML tag at [start].
  ///
  /// Returns `null` when the text is not a syntactically valid tag, so
  /// the `<` character falls through as literal text. Valid but unknown
  /// tags are stripped while their inner content is kept. Unclosed
  /// whitelisted tags are auto-closed at the end of the text, which
  /// keeps streaming (incremental re-parse) rendering stable.
  _HtmlParseResult? _tryParseHtmlTag(String text, int start, int depth) {
    final tag = lexHtmlTag(text, start);
    if (tag == null) return null;

    // Stray closing tag with no matching open tag: consume silently.
    if (tag.isClosing) {
      return _HtmlParseResult(nodes: const [], consumed: tag.end - start);
    }

    final name = tag.name;

    // Void tags produce leaf nodes directly.
    if (name == 'br') {
      return _HtmlParseResult(
        nodes: const [HardBreakNode()],
        consumed: tag.end - start,
      );
    }
    if (name == 'img') {
      return _HtmlParseResult(
        nodes: _buildHtmlImageNodes(tag),
        consumed: tag.end - start,
      );
    }
    if (name == 'hr') {
      // An inline <hr> has no meaningful inline rendering.
      return _HtmlParseResult(nodes: const [], consumed: tag.end - start);
    }

    // Explicitly self-closed non-void tags produce nothing.
    if (tag.isSelfClosing) {
      return _HtmlParseResult(nodes: const [], consumed: tag.end - start);
    }

    // Paired tag: find the matching close with a same-name counter.
    // A missing close tag auto-closes at the end of the text.
    final contentStart = tag.end;
    final close = findHtmlCloseTag(text, contentStart, name);
    final contentEnd = close?.start ?? text.length;
    final consumed = (close?.end ?? text.length) - start;
    final inner = text.substring(contentStart, contentEnd);

    // <code> keeps its content verbatim, like a backtick code span.
    if (name == 'code') {
      return _HtmlParseResult(
        nodes: [InlineCodeNode(inner)],
        consumed: consumed,
      );
    }

    final children = parse(inner, depth: depth + 1);
    final node = _buildHtmlInlineNode(name, tag.attributes, children);

    // Unknown tags (and spans without usable styles) are stripped:
    // their children are spliced into the surrounding content.
    return _HtmlParseResult(
      nodes: node != null ? [node] : children,
      consumed: consumed,
    );
  }

  /// Maps a whitelisted inline HTML tag to its AST node.
  ///
  /// Returns `null` for unknown tags and for `a`/`span`/`font` tags
  /// without usable attributes, which callers treat as "strip the tag
  /// and keep the children".
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

  /// Builds a [LinkNode] from `<a>` attributes.
  ///
  /// Returns `null` (strip tag, keep children) when the `href` is
  /// missing, empty, or uses an unsafe scheme.
  MarkdownNode? _buildHtmlLinkNode(
    Map<String, String> attributes,
    List<MarkdownNode> children,
  ) {
    final href = attributes['href'];
    if (href == null || href.isEmpty || !isSafeHtmlUrl(href)) {
      return null;
    }
    final title = attributes['title'];
    return LinkNode(
      url: href,
      children: children,
      title: title == null || title.isEmpty ? null : title,
    );
  }

  /// Builds a [StyledSpanNode] from `<font>` attributes or a `<span>`
  /// `style` attribute.
  ///
  /// Only the safe subset (color, background color, font size) is
  /// honored; all other styling is ignored. Returns `null` when no
  /// usable style remains.
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
      if (colorAttr != null) {
        color = parseHtmlColor(colorAttr);
      }
      final sizeAttr = attributes['size'];
      if (sizeAttr != null) {
        fontSize = parseFontSizeAttr(sizeAttr);
      }
    } else {
      final style = attributes['style'];
      if (style != null) {
        final declarations = parseInlineCssDeclarations(style);
        final colorValue = declarations['color'];
        if (colorValue != null) {
          color = parseHtmlColor(colorValue);
        }
        final backgroundValue = declarations['background-color'];
        if (backgroundValue != null) {
          backgroundColor = parseHtmlColor(backgroundValue);
        }
        final sizeValue = declarations['font-size'];
        if (sizeValue != null) {
          fontSize = parseHtmlFontSize(sizeValue);
        }
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

  /// Builds the nodes for an `<img>` tag.
  ///
  /// An unsafe or missing `src` degrades to the alt text (or nothing).
  List<MarkdownNode> _buildHtmlImageNodes(HtmlTag tag) {
    final src = tag.attributes['src'] ?? '';
    final alt = tag.attributes['alt'] ?? '';
    if (src.isEmpty || !isSafeHtmlUrl(src)) {
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

  /// Merges consecutive TextNode instances
  List<MarkdownNode> _mergeTextNodes(List<MarkdownNode> nodes) {
    if (nodes.isEmpty) return nodes;

    final merged = <MarkdownNode>[];
    var i = 0;

    while (i < nodes.length) {
      if (nodes[i] is TextNode) {
        final buffer = StringBuffer((nodes[i] as TextNode).content);

        // Collect consecutive text nodes
        while (i + 1 < nodes.length && nodes[i + 1] is TextNode) {
          i++;
          buffer.write((nodes[i] as TextNode).content);
        }

        merged.add(TextNode(buffer.toString()));
      } else {
        merged.add(nodes[i]);
      }
      i++;
    }

    return merged;
  }
}

/// Result of inline parsing operation
class _InlineParseResult {
  const _InlineParseResult({
    required this.node,
    required this.consumed,
  });

  final MarkdownNode node;
  final int consumed;
}

/// Result of parsing an HTML tag, which may yield zero or more nodes
class _HtmlParseResult {
  const _HtmlParseResult({
    required this.nodes,
    required this.consumed,
  });

  final List<MarkdownNode> nodes;
  final int consumed;
}

/// URL and optional title
class _UrlAndTitle {
  const _UrlAndTitle({
    required this.url,
    this.title,
  });

  final String url;
  final String? title;
}

/// Plain text result
class _PlainTextResult {
  const _PlainTextResult({
    required this.text,
    required this.length,
  });

  final String text;
  final int length;
}

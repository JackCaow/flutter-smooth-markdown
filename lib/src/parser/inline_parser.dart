import 'ast/markdown_node.dart';
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
///
/// Supports custom inline plugins through [ParserPluginRegistry].
class InlineParser {
  /// Creates a new inline parser
  ///
  /// Optionally accepts a [ParserPluginRegistry] for custom inline plugins.
  InlineParser({ParserPluginRegistry? plugins}) : _plugins = plugins;

  /// Plugin registry for custom inline parsers
  final ParserPluginRegistry? _plugins;

  /// Maximum recursion depth to prevent stack overflow on deeply nested input
  static const _maxDepth = 16;

  /// Characters that can be escaped with backslash per CommonMark spec
  static const _escapableChars = r'\`*_{}[]()#+-.!~$|>';

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
          char == '\$') {
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

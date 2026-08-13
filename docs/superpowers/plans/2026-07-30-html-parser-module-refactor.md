# HTML Parser Module Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move behavior-preserving inline and block HTML parsing behind two focused internal module interfaces without changing public interfaces, AST output, rendering, security, fallbacks, or streaming behavior.

**Architecture:** `InlineParser` and `BlockParser` retain Markdown precedence and feature gating, then delegate HTML-specific work to `HtmlInlineParser` and `HtmlBlockParser`. Both new modules receive callbacks for nested Markdown parsing, while `html_utils.dart` remains the pure lexer and sanitizer layer.

**Tech Stack:** Dart 3, Flutter, `flutter_test`, the package's custom Markdown AST and parser.

---

## File Map

- Create `lib/src/parser/html/html_inline_parser.dart`: inline HTML matching,
  sanitization fallback, and AST construction.
- Create `test/parser/html_inline_parser_test.dart`: direct tests of the inline
  HTML module interface.
- Modify `lib/src/parser/inline_parser.dart`: construct and call the inline HTML
  module; remove HTML-specific implementation details.
- Create `lib/src/parser/html/html_block_parser.dart`: block HTML probing,
  multiline scanning, alignment parsing, and AST construction.
- Create `test/parser/html_block_parser_test.dart`: direct tests of the block
  HTML module interface.
- Modify `lib/src/parser/block_parser.dart`: construct and call the block HTML
  module; remove HTML-specific implementation details.
- Do not modify renderers, AST definitions, public exports, configuration,
  style sheets, `StreamMarkdown`, or user-facing documentation.

### Task 1: Extract The Inline HTML Parser Module

**Files:**
- Create: `test/parser/html_inline_parser_test.dart`
- Create: `lib/src/parser/html/html_inline_parser.dart`
- Modify: `lib/src/parser/inline_parser.dart:1-35`
- Modify: `lib/src/parser/inline_parser.dart:115-130`
- Modify: `lib/src/parser/inline_parser.dart:638-844`
- Modify: `lib/src/parser/inline_parser.dart:885-894`

- [ ] **Step 1: Write the failing direct module tests**

Create `test/parser/html_inline_parser_test.dart`:

```dart
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/html/html_inline_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HtmlInlineParser', () {
    late HtmlInlineParser parser;

    setUp(() {
      parser = HtmlInlineParser(
        parseChildren: (source, depth) => <MarkdownNode>[
          TextNode('$depth:$source'),
        ],
      );
    });

    test('returns null for text that is not a valid tag', () {
      expect(parser.tryParse('< b>', 0, 0), isNull);
    });

    test('returns nodes and a positive consumed count for a valid tag', () {
      final result = parser.tryParse('<b>x</b>tail', 0, 0);

      expect(result, isNotNull);
      expect(result!.consumed, 8);
      expect(result.consumed, greaterThan(0));
      final bold = result.nodes.single as BoldNode;
      expect((bold.children.single as TextNode).content, '1:x');
    });

    test('splices children from an unknown tag', () {
      final result = parser.tryParse('<video>x</video>', 0, 0)!;

      expect(result.nodes, hasLength(1));
      expect((result.nodes.single as TextNode).content, '1:x');
    });

    test('keeps child text when an anchor URL is unsafe', () {
      final result = parser.tryParse(
        '<a href="javascript:alert(1)">click</a>',
        0,
        0,
      )!;

      expect(result.nodes.whereType<LinkNode>(), isEmpty);
      expect((result.nodes.single as TextNode).content, '1:click');
    });

    test('uses alt text when an image URL is unsafe', () {
      final result = parser.tryParse(
        '<img src="javascript:x" alt="fallback">',
        0,
        0,
      )!;

      expect(result.nodes.whereType<ImageNode>(), isEmpty);
      expect((result.nodes.single as TextNode).content, 'fallback');
    });

    test('auto closes an incomplete paired tag at input end', () {
      const source = '<mark>partial';
      final result = parser.tryParse(source, 0, 0)!;

      expect(result.consumed, source.length);
      final mark = result.nodes.single as HighlightNode;
      expect((mark.children.single as TextNode).content, '1:partial');
    });
  });
}
```

- [ ] **Step 2: Run the new test and verify that it fails**

Run:

```bash
flutter test --no-pub test/parser/html_inline_parser_test.dart
```

Expected: FAIL because
`package:flutter_smooth_markdown/src/parser/html/html_inline_parser.dart` and
`HtmlInlineParser` do not exist.

- [ ] **Step 3: Create the inline HTML module**

Create `lib/src/parser/html/html_inline_parser.dart` with this interface and
move the current HTML method bodies into it:

```dart
import '../ast/html_nodes.dart';
import '../ast/markdown_node.dart';
import 'html_utils.dart';

/// Parses nested inline Markdown inside an HTML element.
typedef HtmlInlineChildrenParser = List<MarkdownNode> Function(
  String source,
  int depth,
);

/// Result of parsing one inline HTML tag.
class HtmlInlineParseResult {
  /// Creates an inline HTML parse result.
  const HtmlInlineParseResult({
    required this.nodes,
    required this.consumed,
  });

  /// Nodes generated by the tag, or its children when the tag is stripped.
  final List<MarkdownNode> nodes;

  /// Number of source characters consumed from the supplied start offset.
  final int consumed;
}

/// Internal parser for whitelisted inline HTML.
class HtmlInlineParser {
  /// Creates a parser that delegates nested Markdown to [parseChildren].
  const HtmlInlineParser({required HtmlInlineChildrenParser parseChildren})
      : _parseChildren = parseChildren;

  final HtmlInlineChildrenParser _parseChildren;

  /// Attempts to parse an HTML tag at [start].
  ///
  /// Returns `null` for invalid tag syntax so callers can preserve `<` as
  /// literal text. A successful result always consumes at least one character.
  HtmlInlineParseResult? tryParse(String text, int start, int depth) {
    final tag = lexHtmlTag(text, start);
    if (tag == null) return null;

    final openConsumed = tag.end - start;
    if (tag.isClosing) {
      return HtmlInlineParseResult(
        nodes: const <MarkdownNode>[],
        consumed: openConsumed,
      );
    }

    final name = tag.name;
    if (htmlVoidTags.contains(name)) {
      return switch (name) {
        'br' => HtmlInlineParseResult(
            nodes: const <MarkdownNode>[HardBreakNode()],
            consumed: openConsumed,
          ),
        'img' => HtmlInlineParseResult(
            nodes: _buildImageNodes(tag),
            consumed: openConsumed,
          ),
        _ => HtmlInlineParseResult(
            nodes: const <MarkdownNode>[],
            consumed: openConsumed,
          ),
      };
    }

    if (tag.isSelfClosing) {
      return HtmlInlineParseResult(
        nodes: const <MarkdownNode>[],
        consumed: openConsumed,
      );
    }

    final contentStart = tag.end;
    final close = findHtmlCloseTag(text, contentStart, name);
    final contentEnd = close?.start ?? text.length;
    final consumed = (close?.end ?? text.length) - start;
    final inner = text.substring(contentStart, contentEnd);

    if (name == 'code') {
      return HtmlInlineParseResult(
        nodes: <MarkdownNode>[InlineCodeNode(inner)],
        consumed: consumed,
      );
    }

    final children = _parseChildren(inner, depth + 1);
    final node = _buildInlineNode(name, tag.attributes, children);
    return HtmlInlineParseResult(
      nodes: node == null ? children : <MarkdownNode>[node],
      consumed: consumed,
    );
  }

  MarkdownNode? _buildInlineNode(
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
        return _buildLinkNode(attributes, children);
      case 'font':
      case 'span':
        return _buildStyledSpanNode(name, attributes, children);
      default:
        return null;
    }
  }

  MarkdownNode? _buildLinkNode(
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
      final colorAttribute = attributes['color'];
      final sizeAttribute = attributes['size'];
      if (colorAttribute != null) color = parseHtmlColor(colorAttribute);
      if (sizeAttribute != null) fontSize = parseFontSizeAttr(sizeAttribute);
    } else {
      final style = attributes['style'];
      if (style != null) {
        final declarations = parseInlineCssDeclarations(style);
        final colorValue = declarations['color'];
        final backgroundValue = declarations['background-color'];
        final sizeValue = declarations['font-size'];
        if (colorValue != null) color = parseHtmlColor(colorValue);
        if (backgroundValue != null) {
          backgroundColor = parseHtmlColor(backgroundValue);
        }
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

  List<MarkdownNode> _buildImageNodes(HtmlTag tag) {
    final src = tag.attributes['src'] ?? '';
    final alt = tag.attributes['alt'] ?? '';
    if (src.isEmpty || !isSafeHtmlUrl(src)) {
      return alt.isEmpty ? const <MarkdownNode>[] : <MarkdownNode>[TextNode(alt)];
    }
    final title = tag.attributes['title'];
    final width = tag.attributes['width'];
    final height = tag.attributes['height'];
    return <MarkdownNode>[
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
```

Keep all mappings and fallback decisions identical to the methods currently in
`InlineParser`; only ownership changes.

- [ ] **Step 4: Delegate from `InlineParser` and remove its HTML implementation**

Replace the HTML imports with the new module import:

```dart
import 'ast/markdown_node.dart';
import 'html/html_inline_parser.dart';
import 'parser_plugin.dart';
```

Change the constructor and add the nullable module field:

```dart
InlineParser({ParserPluginRegistry? plugins, bool enableHtml = false})
    : _plugins = plugins,
      _enableHtml = enableHtml {
  _htmlParser = enableHtml
      ? HtmlInlineParser(
          parseChildren: (source, depth) => parse(source, depth: depth),
        )
      : null;
}

late final HtmlInlineParser? _htmlParser;
```

At the current HTML decision point, replace `_tryParseHtmlTag` with:

```dart
final result = _htmlParser!.tryParse(text, i, depth);
if (result != null) {
  assert(result.consumed > 0, 'HTML parsing must consume input');
  nodes.addAll(result.nodes);
  i += result.consumed;
  continue;
}
```

Delete `_tryParseHtmlTag`, `_buildHtmlInlineNode`, `_buildHtmlLinkNode`,
`_buildStyledSpanNode`, `_buildHtmlImageNodes`, and `_HtmlParseResult` from
`inline_parser.dart`. Keep `_canStartHtmlTag` in `InlineParser` because it is
part of the general parser's fast-path and plain-text scanning policy.

- [ ] **Step 5: Format and run inline tests**

Run:

```bash
dart format lib/src/parser/html/html_inline_parser.dart \
  lib/src/parser/inline_parser.dart \
  test/parser/html_inline_parser_test.dart
flutter test --no-pub test/parser/html_inline_parser_test.dart \
  test/parser/html_inline_test.dart \
  test/parser/html_utils_test.dart
dart analyze lib/src/parser/html/html_inline_parser.dart \
  lib/src/parser/inline_parser.dart \
  test/parser/html_inline_parser_test.dart
```

Expected: formatting succeeds, all inline HTML tests pass, and analysis reports
`No issues found!`.

- [ ] **Step 6: Commit the inline module extraction**

```bash
git add lib/src/parser/html/html_inline_parser.dart \
  lib/src/parser/inline_parser.dart \
  test/parser/html_inline_parser_test.dart
git commit -m "refactor: extract inline HTML parser"
```

### Task 2: Extract The Block HTML Parser Module

**Files:**
- Create: `test/parser/html_block_parser_test.dart`
- Create: `lib/src/parser/html/html_block_parser.dart`
- Modify: `lib/src/parser/block_parser.dart:1-55`
- Modify: `lib/src/parser/block_parser.dart:129-150`
- Modify: `lib/src/parser/block_parser.dart:682-720`
- Modify: `lib/src/parser/block_parser.dart:901-1028`

- [ ] **Step 1: Write the failing direct module tests**

Create `test/parser/html_block_parser_test.dart`:

```dart
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/html/html_block_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HtmlBlockParser', () {
    late List<String> parsedSources;
    late HtmlBlockParser parser;

    setUp(() {
      parsedSources = <String>[];
      parser = HtmlBlockParser(
        parseChildren: (source) {
          parsedSources.add(source);
          return <MarkdownNode>[
            ParagraphNode(<MarkdownNode>[TextNode(source)]),
          ];
        },
      );
    });

    test('probes standalone hr without treating mid-line html as a block', () {
      expect(parser.probe('  <hr />  '), isA<HtmlHorizontalRuleMatch>());
      expect(parser.probe('before <div>x</div>'), isNull);
      expect(parser.probe('< div>'), isNull);
    });

    test('probe carries the lexed opening tag into block parsing', () {
      final match = parser.probe('<div align="right">')
          as HtmlContainerBlockMatch;

      expect(match.openTag.name, 'div');
      expect(match.openTag.attributes['align'], 'right');
      final result = parser.parseBlock(
        <String>['<div align="right">', 'text', '</div>'],
        0,
        match,
      );

      final node = result.node as HtmlBlockNode;
      expect(node.align, HtmlBlockAlignment.right);
      expect(result.linesConsumed, 3);
      expect(parsedSources, <String>['text']);
    });

    test('tracks same-name nesting across lines', () {
      final lines = <String>[
        '<div>',
        '<div>',
        'inner',
        '</div>',
        'outer',
        '</div>',
      ];
      final match = parser.probe(lines.first) as HtmlContainerBlockMatch;

      final result = parser.parseBlock(lines, 0, match);

      expect(result.linesConsumed, lines.length);
      expect(parsedSources.single, contains('<div>'));
      expect(parsedSources.single, contains('outer'));
    });

    test('keeps content after the terminating close tag', () {
      const line = '<div>a</div><div>b</div>';
      final match = parser.probe(line) as HtmlContainerBlockMatch;

      parser.parseBlock(<String>[line], 0, match);

      expect(parsedSources.single, 'a\n<div>b</div>');
    });

    test('consumes an incomplete block through input end', () {
      final lines = <String>['<div>', 'rest', 'more'];
      final match = parser.probe(lines.first) as HtmlContainerBlockMatch;

      final result = parser.parseBlock(lines, 0, match);

      expect(result.linesConsumed, lines.length);
      expect(parsedSources.single, 'rest\nmore');
    });

    test('maps blockquote to the existing markdown node', () {
      final lines = <String>['<blockquote>', 'quote', '</blockquote>'];
      final match = parser.probe(lines.first) as HtmlContainerBlockMatch;

      final result = parser.parseBlock(lines, 0, match);

      expect(result.node, isA<BlockquoteNode>());
    });
  });
}
```

- [ ] **Step 2: Run the new test and verify that it fails**

Run:

```bash
flutter test --no-pub test/parser/html_block_parser_test.dart
```

Expected: FAIL because
`package:flutter_smooth_markdown/src/parser/html/html_block_parser.dart` and
the block HTML module types do not exist.

- [ ] **Step 3: Create the block HTML module**

Create `lib/src/parser/html/html_block_parser.dart`:

```dart
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
    final children = source.trim().isEmpty
        ? const <MarkdownNode>[]
        : _parseChildren(source);
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
```

- [ ] **Step 4: Delegate from `BlockParser` and remove its HTML implementation**

Use these imports:

```dart
import 'ast/markdown_node.dart';
import 'html/html_block_parser.dart';
import 'inline_parser.dart';
import 'parser_plugin.dart';
```

Construct the module only when HTML is enabled:

```dart
BlockParser({ParserPluginRegistry? plugins, bool enableHtml = false})
    : _plugins = plugins,
      _inlineParser = InlineParser(plugins: plugins, enableHtml: enableHtml) {
  _htmlParser = enableHtml
      ? HtmlBlockParser(parseChildren: parse)
      : null;
}

late final HtmlBlockParser? _htmlParser;
```

After the dedicated `details` branch and before table parsing, probe once and
dispatch by match type:

```dart
final htmlMatch = node == null ? _htmlParser?.probe(line) : null;
if (node == null && htmlMatch is HtmlHorizontalRuleMatch) {
  node = const HorizontalRuleNode();
  consumed = 1;
}
if (node == null && htmlMatch is HtmlContainerBlockMatch) {
  final result = _htmlParser!.parseBlock(lines, i, htmlMatch);
  node = result.node;
  consumed = result.linesConsumed;
}
```

Replace the two HTML checks in `_parseParagraph` with one probe:

```dart
final startsHtmlBlock = _htmlParser?.probe(line) != null;
if (_isHeader(line) ||
    _isCodeBlockStart(line) ||
    _isBlockMathStart(line) ||
    _isBlockquote(line) ||
    _isListItem(line) ||
    _isHorizontalRule(line) ||
    _isFootnoteDefinition(line) ||
    _isTableStart(lines, i) ||
    startsHtmlBlock) {
  break;
}
```

Delete `_htmlBlockStartPattern`, `_htmlHrPattern`, `_enableHtml`,
`_isHtmlHrLine`, `_isHtmlBlockStart`, `_couldStartHtmlLine`, `_parseHtmlBlock`,
`_parseHtmlBlockAlignment`, and `_buildHtmlBlockNode` from `block_parser.dart`.
Keep the dedicated details parser unchanged and before HTML probing.

- [ ] **Step 5: Format and run block tests**

Run:

```bash
dart format lib/src/parser/html/html_block_parser.dart \
  lib/src/parser/block_parser.dart \
  test/parser/html_block_parser_test.dart
flutter test --no-pub test/parser/html_block_parser_test.dart \
  test/parser/html_block_test.dart \
  test/integration/html_integration_test.dart
dart analyze lib/src/parser/html/html_block_parser.dart \
  lib/src/parser/block_parser.dart \
  test/parser/html_block_parser_test.dart
```

Expected: all block and integration tests pass and analysis reports
`No issues found!`.

- [ ] **Step 6: Commit the block module extraction**

```bash
git add lib/src/parser/html/html_block_parser.dart \
  lib/src/parser/block_parser.dart \
  test/parser/html_block_parser_test.dart
git commit -m "refactor: extract block HTML parser"
```

### Task 3: Verify The Complete Behavior-Preserving Refactor

**Files:**
- Verify: `lib/src/parser/html/html_utils.dart`
- Verify: `lib/src/parser/html/html_inline_parser.dart`
- Verify: `lib/src/parser/html/html_block_parser.dart`
- Verify: `lib/src/parser/inline_parser.dart`
- Verify: `lib/src/parser/block_parser.dart`
- Verify: all HTML-focused and repository tests

- [ ] **Step 1: Confirm ownership moved to the intended modules**

Run:

```bash
rg -n "_tryParseHtmlTag|_buildHtmlInlineNode|_buildHtmlLinkNode|_buildStyledSpanNode|_buildHtmlImageNodes|_parseHtmlBlock|_parseHtmlBlockAlignment|_buildHtmlBlockNode|scanHtmlCloseTag|lexHtmlTag|isSafeHtmlUrl|parseHtmlColor|parseHtmlDimension" \
  lib/src/parser/inline_parser.dart \
  lib/src/parser/block_parser.dart
```

Expected: no matches. The general parsers should contain only module
construction, fast-path gating, probing, delegation, and result handling.

- [ ] **Step 2: Run the focused HTML suite and benchmarks**

Run:

```bash
flutter test --no-pub \
  test/parser/html_utils_test.dart \
  test/parser/html_nodes_test.dart \
  test/parser/html_inline_parser_test.dart \
  test/parser/html_inline_test.dart \
  test/parser/html_block_parser_test.dart \
  test/parser/html_block_test.dart \
  test/renderer/html_builder_test.dart \
  test/integration/html_integration_test.dart \
  test/performance/html_parse_benchmark_test.dart
```

Expected: all tests pass. The existing generous performance assertions pass;
do not convert one local timing sample into a stricter threshold.

- [ ] **Step 3: Run full repository validation**

Run:

```bash
flutter analyze --no-pub
flutter test --no-pub
git diff --check
```

Expected: analysis reports no issues, the complete test suite passes, and
`git diff --check` prints no output.

- [ ] **Step 4: Inspect the final branch state**

Run:

```bash
git status --short --branch
git log -3 --oneline --decorate
```

Expected: the worktree is clean. The latest commits are the block extraction,
inline extraction, and implementation plan commits, in that order, with the
design document immediately before them. Do not push the branch unless the
user explicitly requests it.

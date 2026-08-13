import 'package:flutter/widgets.dart';

import '../config/style_sheet.dart';
import '../parser/ast/markdown_node.dart';
import 'builders/block_math_builder.dart';
import 'builders/blockquote_builder.dart';
import 'builders/code_block_builder.dart';
import 'builders/details_builder.dart';
import 'builders/footnote_definition_builder.dart';
import 'builders/footnote_reference_builder.dart';
import 'builders/hard_break_builder.dart';
import 'builders/header_builder.dart';
import 'builders/horizontal_rule_builder.dart';
import 'builders/html_block_builder.dart';
import 'builders/html_inline_builder.dart';
import 'builders/image_builder.dart';
import 'builders/inline_code_builder.dart';
import 'builders/inline_math_builder.dart';
import 'builders/link_builder.dart';
import 'builders/list_builder.dart';
import 'builders/paragraph_builder.dart';
import 'builders/table_builder.dart';
import 'builders/text_builder.dart';
import 'builders/text_style_builder.dart';

// Forward declaration to avoid circular imports
typedef InlineRenderer = Widget Function(
  List<MarkdownNode> nodes,
  TextStyle? baseStyle,
);

/// Function type for rendering block-level nodes.
///
/// This is the public callback contract and is intentionally kept
/// single-argument: a plain `(nodes) => widget` function is assignable here,
/// so existing callbacks keep working. It deliberately carries no context
/// parameter so that changes to the context model never become a
/// source-breaking change for callers that only render children. Use
/// [ContextualBlockRenderer] (via [MarkdownRenderContext.contextualBlockRenderer])
/// when a builder needs to override the render context.
typedef BlockRenderer = Widget Function(List<MarkdownNode> nodes);

/// Context-aware variant of [BlockRenderer].
///
/// The renderer's internal closure implements this so that builders can
/// override the [MarkdownRenderContext] for their rendered children (for
/// example an HTML block that applies text alignment). That closure backs
/// both typedefs: it matches [ContextualBlockRenderer] exactly, and because
/// a function accepting an optional `context` is also assignable to the
/// single-argument [BlockRenderer] (callers that omit `context` still
/// work), the same closure can populate
/// [MarkdownRenderContext.blockRenderer] as well.
///
/// This typedef is intentionally additive so the public [BlockRenderer]
/// stays single-argument and existing `(nodes) => widget` callbacks remain
/// assignable to it. The subtyping runs one direction only: a plain
/// single-argument callback is *not* assignable to [ContextualBlockRenderer]
/// (it could not honor a `context` override), which is why builders that
/// need the override go through this typedef rather than [BlockRenderer].
typedef ContextualBlockRenderer = Widget Function(
  List<MarkdownNode> nodes, {
  MarkdownRenderContext? context,
});

/// Extracts plain text from a list of nodes by joining [TextNode] content.
///
/// Used as a fallback when no inline/block renderer is available, so the
/// content is still readable instead of rendering nothing.
String extractPlainText(List<MarkdownNode> nodes) {
  return nodes.whereType<TextNode>().map((n) => n.content).join();
}

/// Renders [children] via the inline renderer when available, otherwise
/// falls back to a flat [Text] widget built from [extractPlainText].
///
/// Shared by inline-style builders (bold, italic, underline, etc.) so the
/// null-check dispatch lives in one place.
Widget renderInlineOrFallback(
  List<MarkdownNode> children,
  TextStyle? style,
  MarkdownRenderContext context,
) {
  final inlineRenderer = context.inlineRenderer;
  return inlineRenderer != null
      ? inlineRenderer(children, style)
      : Text(extractPlainText(children), style: style);
}

/// Base class for building widgets from Markdown nodes
///
/// Each type of Markdown element (header, paragraph, list, etc.)
/// has its own builder that extends this class.
abstract class MarkdownWidgetBuilder {
  /// Creates a new widget builder
  const MarkdownWidgetBuilder();

  /// Builds a widget from a Markdown node
  ///
  /// [node] - The Markdown node to render
  /// [styleSheet] - The style sheet to apply
  /// [context] - Additional rendering context
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  );

  /// Checks if this builder can handle the given node type
  bool canBuild(MarkdownNode node);
}

/// Context passed to builders during rendering
///
/// Contains information needed during the rendering process,
/// including references to renderers for nested content.
class MarkdownRenderContext {
  /// Creates a new render context
  const MarkdownRenderContext({
    this.onTapLink,
    this.onTapImage,
    this.imageBuilder,
    this.codeBuilder,
    this.listLevel = 0,
    this.inlineRenderer,
    this.blockRenderer,
    this.contextualBlockRenderer,
    this.styleSheet,
    this.selectable = false,
    this.textAlign,
  });

  /// Callback for link taps
  final void Function(String url)? onTapLink;

  /// Callback for image taps
  final void Function(String url, String? alt, String? title)? onTapImage;

  /// Custom image widget builder
  final Widget Function(String url, String? alt, String? title)? imageBuilder;

  /// Custom code block widget builder
  final Widget Function(String code, String? language)? codeBuilder;

  /// Current list nesting level (for indentation)
  final int listLevel;

  /// Inline renderer function for rendering inline child nodes
  ///
  /// This allows builders to render inline content using the same
  /// renderer instance, preserving custom builder registrations.
  final InlineRenderer? inlineRenderer;

  /// Block renderer function for rendering block-level child nodes.
  ///
  /// This allows builders to render block content (like blockquote children)
  /// using the same renderer instance, preserving custom builder
  /// registrations. The contract is a plain single-argument
  /// `(nodes) => widget` function so existing callbacks remain assignable.
  final BlockRenderer? blockRenderer;

  /// Context-aware block renderer for rendering child blocks with a context
  /// override.
  ///
  /// Set internally by the renderer. Builders that need to override the
  /// context for their children (for example an HTML block applying text
  /// alignment) call this with `context`; passing `null` renders with the
  /// renderer's current context, exactly like [blockRenderer]. When unset,
  /// fall back to [blockRenderer].
  final ContextualBlockRenderer? contextualBlockRenderer;

  /// The style sheet being used for rendering
  final MarkdownStyleSheet? styleSheet;

  /// Whether the rendered content is inside a SelectionArea.
  ///
  /// When `true`, builders should use `Text` instead of `SelectableText`
  /// to avoid nested selection conflicts.
  final bool selectable;

  /// Text alignment applied to inline text rendered within this context.
  ///
  /// Used by HTML block builders (`<center>`, `align="right"`) so the
  /// contained text is aligned at the text level rather than by shrink-
  /// wrapping the block, which avoids layout reflow during streaming.
  /// `null` leaves alignment at the default (start/left).
  final TextAlign? textAlign;

  /// Creates a copy with updated fields
  MarkdownRenderContext copyWith({
    void Function(String url)? onTapLink,
    void Function(String url, String? alt, String? title)? onTapImage,
    Widget Function(String url, String? alt, String? title)? imageBuilder,
    Widget Function(String code, String? language)? codeBuilder,
    int? listLevel,
    InlineRenderer? inlineRenderer,
    BlockRenderer? blockRenderer,
    ContextualBlockRenderer? contextualBlockRenderer,
    MarkdownStyleSheet? styleSheet,
    bool? selectable,
    TextAlign? textAlign,
  }) {
    return MarkdownRenderContext(
      onTapLink: onTapLink ?? this.onTapLink,
      onTapImage: onTapImage ?? this.onTapImage,
      imageBuilder: imageBuilder ?? this.imageBuilder,
      codeBuilder: codeBuilder ?? this.codeBuilder,
      listLevel: listLevel ?? this.listLevel,
      inlineRenderer: inlineRenderer ?? this.inlineRenderer,
      blockRenderer: blockRenderer ?? this.blockRenderer,
      contextualBlockRenderer:
          contextualBlockRenderer ?? this.contextualBlockRenderer,
      styleSheet: styleSheet ?? this.styleSheet,
      selectable: selectable ?? this.selectable,
      textAlign: textAlign ?? this.textAlign,
    );
  }
}

/// Registry for Markdown widget builders
class BuilderRegistry {
  /// Creates a new builder registry
  BuilderRegistry() : _builders = {};

  /// Creates a registry with default builders
  factory BuilderRegistry.defaults() {
    return BuilderRegistry()
      ..register('text', const TextBuilder())
      ..register('header', const HeaderBuilder())
      ..register('paragraph', const ParagraphBuilder())
      ..register('code_block', const CodeBlockBuilder())
      ..register('blockquote', const BlockquoteBuilder())
      ..register('list', const ListBuilder())
      ..register('table', const TableBuilder())
      ..register('horizontal_rule', const HorizontalRuleBuilder())
      ..register('inline_code', const InlineCodeBuilder())
      ..register('hard_break', const HardBreakBuilder())
      ..register('inline_math', const InlineMathBuilder())
      ..register('block_math', const BlockMathBuilder())
      ..register('footnote_reference', const FootnoteReferenceBuilder())
      ..register('footnote_definition', const FootnoteDefinitionBuilder())
      ..register('details', const DetailsBuilder())
      ..register('bold', const BoldBuilder())
      ..register('italic', const ItalicBuilder())
      ..register('strikethrough', const StrikethroughBuilder())
      ..register('underline', const UnderlineBuilder())
      ..register('highlight', const HighlightBuilder())
      ..register('subscript', const SubscriptBuilder())
      ..register('superscript', const SuperscriptBuilder())
      ..register('kbd', const KbdBuilder())
      ..register('styled_span', const StyledSpanBuilder())
      ..register('html_block', const HtmlBlockBuilder())
      ..register('link', const LinkBuilder())
      ..register('image', const ImageBuilder());
  }

  final Map<String, MarkdownWidgetBuilder> _builders;

  /// Returns an iterable of all registered builder entries.
  ///
  /// Useful for merging registries or iterating over all builders.
  Iterable<MapEntry<String, MarkdownWidgetBuilder>> get entries =>
      _builders.entries;

  /// Registers a builder for a specific node type
  void register(String nodeType, MarkdownWidgetBuilder builder) {
    _builders[nodeType] = builder;
  }

  /// Gets the builder for a node type
  MarkdownWidgetBuilder? getBuilder(String nodeType) {
    return _builders[nodeType];
  }

  /// Finds a builder that can handle the given node
  MarkdownWidgetBuilder? findBuilder(MarkdownNode node) {
    // First try exact type match
    final exactBuilder = _builders[node.type];
    if (exactBuilder != null && exactBuilder.canBuild(node)) {
      return exactBuilder;
    }

    // Then try all builders
    for (final builder in _builders.values) {
      if (builder.canBuild(node)) {
        return builder;
      }
    }

    return null;
  }

  /// Checks if a builder exists for a node type
  bool hasBuilder(String nodeType) {
    return _builders.containsKey(nodeType);
  }

  /// Removes a builder
  void unregister(String nodeType) {
    _builders.remove(nodeType);
  }

  /// Clears all builders
  void clear() {
    _builders.clear();
  }
}

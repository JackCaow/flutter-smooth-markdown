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

/// Function type for rendering block-level nodes
typedef BlockRenderer = Widget Function(
  List<MarkdownNode> nodes,
);

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
    this.styleSheet,
    this.selectable = false,
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

  /// Block renderer function for rendering block-level child nodes
  ///
  /// This allows builders to render block content (like blockquote children)
  /// using the same renderer instance, preserving custom builder registrations.
  final BlockRenderer? blockRenderer;

  /// The style sheet being used for rendering
  final MarkdownStyleSheet? styleSheet;

  /// Whether the rendered content is inside a SelectionArea.
  ///
  /// When `true`, builders should use `Text` instead of `SelectableText`
  /// to avoid nested selection conflicts.
  final bool selectable;

  /// Creates a copy with updated fields
  MarkdownRenderContext copyWith({
    void Function(String url)? onTapLink,
    void Function(String url, String? alt, String? title)? onTapImage,
    Widget Function(String url, String? alt, String? title)? imageBuilder,
    Widget Function(String code, String? language)? codeBuilder,
    int? listLevel,
    InlineRenderer? inlineRenderer,
    BlockRenderer? blockRenderer,
    MarkdownStyleSheet? styleSheet,
    bool? selectable,
  }) {
    return MarkdownRenderContext(
      onTapLink: onTapLink ?? this.onTapLink,
      onTapImage: onTapImage ?? this.onTapImage,
      imageBuilder: imageBuilder ?? this.imageBuilder,
      codeBuilder: codeBuilder ?? this.codeBuilder,
      listLevel: listLevel ?? this.listLevel,
      inlineRenderer: inlineRenderer ?? this.inlineRenderer,
      blockRenderer: blockRenderer ?? this.blockRenderer,
      styleSheet: styleSheet ?? this.styleSheet,
      selectable: selectable ?? this.selectable,
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

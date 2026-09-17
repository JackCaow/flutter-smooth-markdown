import 'package:flutter/material.dart';

import '../config/style_sheet.dart';
import '../parser/ast/markdown_node.dart';
import 'widget_builder.dart';

/// Main renderer that converts Markdown AST nodes to Flutter widgets.
///
/// [MarkdownRenderer] is responsible for transforming a parsed markdown AST
/// (Abstract Syntax Tree) into Flutter widgets using a builder registry system.
/// Each markdown element type has a corresponding builder that knows how to
/// render it.
///
/// ## Architecture
///
/// The renderer uses a builder pattern where:
/// 1. Each AST node type (header, paragraph, code block, etc.) has a builder
/// 2. Builders are registered in a [BuilderRegistry]
/// 3. During rendering, the renderer looks up the appropriate builder for each node
/// 4. Builders create widgets using the provided [MarkdownStyleSheet]
///
/// ## Basic Usage
///
/// Most users won't interact with this class directly - `SmoothMarkdown` handles
/// it automatically. However, for advanced use cases:
///
/// ```dart
/// // Parse markdown
/// final parser = MarkdownParser();
/// final nodes = parser.parse('# Hello **World**');
///
/// // Create renderer
/// final renderer = MarkdownRenderer(
///   styleSheet: MarkdownStyleSheet.github(),
/// );
///
/// // Render to widget
/// final widget = renderer.render(nodes);
/// ```
///
/// ## Custom Builders
///
/// You can register custom builders to override default rendering:
///
/// ```dart
/// final renderer = MarkdownRenderer();
///
/// // Register a custom header builder
/// renderer.registerBuilder('header', MyCustomHeaderBuilder());
///
/// // Or create with custom registry
/// final customRegistry = BuilderRegistry()
///   ..register('header', MyCustomHeaderBuilder())
///   ..register('code_block', MyCustomCodeBlockBuilder());
///
/// final customRenderer = MarkdownRenderer(
///   builderRegistry: customRegistry,
/// );
/// ```
///
/// ## Builder Types
///
/// Standard builders included:
/// - **Block elements**: header, paragraph, code_block, blockquote, list, table
/// - **Inline elements**: bold, italic, strikethrough, inline_code, link, image
/// - **Special**: horizontal_rule, inline_math, block_math, footnote_reference, footnote_definition
///
/// ## Performance
///
/// The renderer is optimized for efficiency:
/// - Builders are stateless and reusable
/// - Widget tree is built directly without intermediate representations
/// - Spacing between blocks is calculated once
/// - Builder lookup is O(1) via hash map
///
/// See also:
///
/// - `MarkdownParser`, which creates the AST nodes that this renderer processes
/// - [MarkdownWidgetBuilder], the base class for custom builders
/// - [BuilderRegistry], which manages builder registration and lookup
/// - `SmoothMarkdown`, the high-level widget that uses this renderer
class MarkdownRenderer {
  /// Creates a new Markdown renderer with the specified configuration.
  ///
  /// Parameters:
  /// - [styleSheet]: The stylesheet to use for rendering. Defaults to
  ///   [MarkdownStyleSheet.light] if not provided.
  /// - [builderRegistry]: Custom builder registry. If not provided, uses
  ///   the default registry with all standard builders.
  ///
  /// Example:
  ///
  /// ```dart
  /// // With default settings
  /// final renderer = MarkdownRenderer();
  ///
  /// // With custom stylesheet
  /// final renderer = MarkdownRenderer(
  ///   styleSheet: MarkdownStyleSheet.vscode(brightness: Brightness.dark),
  /// );
  ///
  /// // With custom builders
  /// final customRegistry = BuilderRegistry()
  ///   ..register('header', EnhancedHeaderBuilder());
  ///
  /// final renderer = MarkdownRenderer(
  ///   styleSheet: MarkdownStyleSheet.github(),
  ///   builderRegistry: customRegistry,
  /// );
  /// ```
  MarkdownRenderer({
    MarkdownStyleSheet? styleSheet,
    BuilderRegistry? builderRegistry,
  })  : styleSheet = styleSheet ?? MarkdownStyleSheet.light(),
        _builderRegistry = builderRegistry ?? BuilderRegistry.defaults();

  /// The style sheet to use for rendering
  final MarkdownStyleSheet styleSheet;

  /// The builder registry
  final BuilderRegistry _builderRegistry;

  /// Renders a list of Markdown AST nodes into a Flutter widget tree.
  ///
  /// This is the main entry point for rendering. It processes each node,
  /// builds corresponding widgets, and combines them into a Column with
  /// appropriate spacing.
  ///
  /// Parameters:
  /// - [nodes]: The AST nodes to render (typically from `MarkdownParser.parse`)
  /// - [context]: Optional rendering context containing callbacks and custom builders
  ///
  /// Returns a [Widget] (usually a [Column]) containing all rendered elements.
  /// Returns an empty [SizedBox.shrink] if the node list is empty.
  ///
  /// Example:
  ///
  /// ```dart
  /// final nodes = MarkdownParser().parse('# Title\n\nParagraph');
  /// final context = MarkdownRenderContext(
  ///   onTapLink: (url) => launchUrl(Uri.parse(url)),
  /// );
  /// final widget = renderer.render(nodes, context: context);
  /// ```
  Widget render(
    List<MarkdownNode> nodes, {
    MarkdownRenderContext? context,
  }) {
    // Create context with renderer references for nested rendering
    final baseContext = context ?? const MarkdownRenderContext();
    // A single context-aware closure renders child blocks and (optionally)
    // overrides the context. It is exposed twice so that builders can use it
    // without a context (through [BlockRenderer], which keeps single-argument
    // callbacks assignable) and *with* a context override (through
    // [ContextualBlockRenderer], e.g. the HTML block applying text alignment).
    Widget renderChildren(
      List<MarkdownNode> childNodes, {
      MarkdownRenderContext? context,
    }) =>
        render(childNodes, context: context ?? baseContext);

    final renderContext = baseContext.copyWith(
      inlineRenderer: (childNodes, baseStyle) =>
          renderInline(childNodes, baseStyle, baseContext),
      blockRenderer: renderChildren,
      contextualBlockRenderer: renderChildren,
      styleSheet: styleSheet,
    );

    final widgets = nodes
        .map((node) => _renderNode(node, renderContext))
        .where((widget) => widget != null)
        .cast<Widget>()
        .toList();

    if (widgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _addSpacing(widgets),
    );
  }

  /// Node types that produce non-text block widgets.
  ///
  /// When inside a [SelectionArea], these are wrapped with an invisible
  /// [Text] overlay so that selection handles can anchor on them.
  static const _nonTextBlockTypes = {
    'image',
    'horizontal_rule',
    'table',
    'block_math',
  };

  /// Renders a single node
  Widget? _renderNode(MarkdownNode node, MarkdownRenderContext context) {
    // When selectable, a paragraph that contains only a single image should
    // be rendered as a block-level widget with a selectable overlay instead
    // of a Text.rich + WidgetSpan (whose handles can't anchor on the image).
    if (context.selectable && node is ParagraphNode) {
      final onlyImage = _extractSoleImage(node);
      if (onlyImage != null) {
        final imageBuilder = _builderRegistry.findBuilder(onlyImage);
        if (imageBuilder != null) {
          return _selectableOverlay(
            imageBuilder.build(onlyImage, styleSheet, context),
          );
        }
      }
    }

    final builder = _builderRegistry.findBuilder(node);

    if (builder == null) {
      // Fallback for unknown node types
      return Text('Unknown node type: ${node.type}');
    }

    final widget = builder.build(node, styleSheet, context);

    if (context.selectable && _nonTextBlockTypes.contains(node.type)) {
      return _selectableOverlay(widget);
    }

    return widget;
  }

  /// Returns the [ImageNode] if [paragraph] contains exactly one image
  /// and nothing else (ignoring whitespace-only text nodes).
  static ImageNode? _extractSoleImage(ParagraphNode paragraph) {
    ImageNode? image;
    for (final child in paragraph.children) {
      if (child is ImageNode) {
        if (image != null) return null; // more than one image
        image = child;
      } else if (child is TextNode) {
        if (child.content.trim().isNotEmpty) return null;
      } else {
        return null; // other inline content
      }
    }
    return image;
  }

  /// Wraps [child] with an invisible multi-line [Text] overlay whose
  /// selectable geometry covers the full widget area, giving selection
  /// handles an anchor point inside a [SelectionArea].
  static Widget _selectableOverlay(Widget child) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const fontSize = 14.0;
              final rows =
                  (constraints.maxHeight / fontSize).ceil().clamp(1, 200);
              final line = '\u00A0' * 500;
              return IgnorePointer(
                child: DefaultSelectionStyle(
                  selectionColor: const Color(0x00000000),
                  child: Text(
                    List.filled(rows, line).join('\n'),
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    maxLines: rows,
                    style: const TextStyle(
                      fontSize: fontSize,
                      height: 1,
                      color: Color(0x00000000),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Renders inline nodes (used by builders)
  ///
  /// This method uses the registered builders to render inline content,
  /// preserving any custom builder registrations for plugin nodes.
  Widget renderInline(
    List<MarkdownNode> nodes,
    TextStyle? baseStyle,
    MarkdownRenderContext context,
  ) {
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    // Ensure context has inlineRenderer for nested rendering
    final renderContext = context.inlineRenderer == null
        ? context.copyWith(
            inlineRenderer: (childNodes, style) =>
                renderInline(childNodes, style, context),
            styleSheet: styleSheet,
          )
        : context;

    final spans = nodes.map((node) {
      final builder = _builderRegistry.findBuilder(node);
      if (builder == null) {
        return TextSpan(text: 'Unknown: ${node.type}');
      }

      final widget = builder.build(node, styleSheet, renderContext);

      // If it's a text-based node, extract the TextSpan
      if (widget is Text) {
        return widget.textSpan ?? TextSpan(text: widget.data);
      } else if (widget is RichText) {
        return widget.text;
      } else if (widget is SelectableText) {
        return widget.textSpan ?? TextSpan(text: widget.data);
      }

      // For non-text widgets (like images), wrap in WidgetSpan
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: widget,
      );
    }).toList();

    if (context.selectable) {
      return Text.rich(
        TextSpan(
          style: baseStyle,
          children: spans,
        ),
        textAlign: context.textAlign,
      );
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: spans,
      ),
      textAlign: context.textAlign ?? TextAlign.start,
    );
  }

  /// Adds spacing between block elements
  List<Widget> _addSpacing(List<Widget> widgets) {
    if (widgets.length <= 1) {
      return widgets;
    }

    final spacing = styleSheet.blockSpacing ?? 16.0;
    final result = <Widget>[];

    for (var i = 0; i < widgets.length; i++) {
      result.add(widgets[i]);

      // Add spacing between blocks (but not after the last one)
      if (i < widgets.length - 1) {
        result.add(SizedBox(height: spacing));
      }
    }

    return result;
  }

  /// Registers a custom builder for a specific node type.
  ///
  /// This allows you to override the default rendering for any markdown element.
  /// The builder will be used for all nodes with the specified [nodeType].
  ///
  /// Parameters:
  /// - [nodeType]: The node type identifier (e.g., 'header', 'code_block', 'link')
  /// - [builder]: The custom builder instance to use for this node type
  ///
  /// Example:
  ///
  /// ```dart
  /// // Override header rendering
  /// renderer.registerBuilder('header', CustomHeaderBuilder());
  ///
  /// // Override code block rendering
  /// renderer.registerBuilder('code_block', SyntaxHighlightedCodeBuilder());
  ///
  /// // Override link rendering
  /// renderer.registerBuilder('link', CustomLinkBuilder());
  /// ```
  ///
  /// See [MarkdownWidgetBuilder] for how to create custom builders.
  void registerBuilder(String nodeType, MarkdownWidgetBuilder builder) {
    _builderRegistry.register(nodeType, builder);
  }

  /// Removes a custom builder for a specific node type.
  ///
  /// After unregistering, the default builder (if any) will be used for
  /// the specified node type. If no default exists, unknown node fallback
  /// will be used.
  ///
  /// Parameters:
  /// - [nodeType]: The node type identifier to unregister
  ///
  /// Example:
  ///
  /// ```dart
  /// // Remove custom header builder, revert to default
  /// renderer.unregisterBuilder('header');
  /// ```
  void unregisterBuilder(String nodeType) {
    _builderRegistry.unregister(nodeType);
  }
}

import 'package:flutter/widgets.dart';

import '../../config/style_sheet.dart';
import '../../parser/ast/markdown_node.dart';
import '../widget_builder.dart';

/// Builder for bold text nodes
class BoldBuilder extends MarkdownWidgetBuilder {
  /// Creates a new bold builder
  const BoldBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is BoldNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final boldNode = node as BoldNode;
    return renderInlineOrFallback(
      boldNode.children,
      styleSheet.boldStyle,
      context,
    );
  }
}

/// Builder for italic text nodes
class ItalicBuilder extends MarkdownWidgetBuilder {
  /// Creates a new italic builder
  const ItalicBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is ItalicNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final italicNode = node as ItalicNode;
    return renderInlineOrFallback(
      italicNode.children,
      styleSheet.italicStyle,
      context,
    );
  }
}

/// Builder for strikethrough text nodes
class StrikethroughBuilder extends MarkdownWidgetBuilder {
  /// Creates a new strikethrough builder
  const StrikethroughBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is StrikethroughNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final strikeNode = node as StrikethroughNode;
    return renderInlineOrFallback(
      strikeNode.children,
      styleSheet.strikethroughStyle,
      context,
    );
  }
}

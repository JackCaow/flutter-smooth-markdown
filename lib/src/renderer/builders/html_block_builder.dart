import 'package:flutter/widgets.dart';

import '../../config/style_sheet.dart';
import '../../parser/ast/html_nodes.dart';
import '../../parser/ast/markdown_node.dart';
import '../widget_builder.dart';

/// Builder for HTML block nodes (`<div>`, `<p>`, `<center>`)
///
/// Renders the block children through the regular block renderer and
/// applies the `align` attribute. Alignment positions the block's
/// content as a whole (the renderer's outer column is stretched, so
/// alignment has to happen here); it does not re-align individual text
/// lines within wrapped paragraphs.
class HtmlBlockBuilder extends MarkdownWidgetBuilder {
  /// Creates a new HTML block builder
  const HtmlBlockBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is HtmlBlockNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final blockNode = node as HtmlBlockNode;
    final contextualRenderer = context.contextualBlockRenderer;
    final blockRenderer = context.blockRenderer;

    // Alignment is applied as text-level alignment rather than by shrink-
    // wrapping the block. IntrinsicWidth would recompute the block width on
    // every streaming update (horizontal jitter) and force an expensive
    // intrinsic layout pass; textAlign reflows smoothly and matches browser
    // behavior for `<center>` and `align`.
    final textAlign = switch (blockNode.align) {
      HtmlBlockAlignment.center => TextAlign.center,
      HtmlBlockAlignment.right => TextAlign.right,
      null || HtmlBlockAlignment.left => null,
    };

    if (contextualRenderer != null) {
      return contextualRenderer(
        blockNode.children,
        context: textAlign == null
            ? null
            : context.copyWith(textAlign: textAlign),
      );
    }

    if (blockRenderer != null) {
      return blockRenderer(blockNode.children);
    }

    return Text(
      extractPlainText(blockNode.children),
      style: styleSheet.textStyle,
      textAlign: textAlign,
    );
  }
}

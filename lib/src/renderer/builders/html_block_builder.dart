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
    final blockRenderer = context.blockRenderer;

    final content = blockRenderer != null
        ? blockRenderer(blockNode.children)
        : Text(extractPlainText(blockNode.children),
            style: styleSheet.textStyle);

    return switch (blockNode.align) {
      null || HtmlBlockAlignment.left => content,
      HtmlBlockAlignment.center => Align(
          child: IntrinsicWidth(child: content),
        ),
      HtmlBlockAlignment.right => Align(
          alignment: Alignment.centerRight,
          child: IntrinsicWidth(child: content),
        ),
    };
  }
}

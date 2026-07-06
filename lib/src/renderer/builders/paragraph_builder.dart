import 'package:flutter/widgets.dart';

import '../../config/style_sheet.dart';
import '../../parser/ast/markdown_node.dart';
import '../widget_builder.dart';

/// Builder for paragraph nodes
class ParagraphBuilder extends MarkdownWidgetBuilder {
  /// Creates a new paragraph builder
  const ParagraphBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is ParagraphNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final paragraphNode = node as ParagraphNode;

    // Use inlineRenderer from context to preserve custom builder registrations
    final inlineRenderer = context.inlineRenderer;
    if (inlineRenderer != null) {
      return inlineRenderer(
        paragraphNode.children,
        styleSheet.paragraphStyle,
      );
    }

    // Fallback: render as plain text if no inlineRenderer available
    final text = _extractText(paragraphNode.children);
    return Text(text, style: styleSheet.paragraphStyle);
  }

  /// Extracts plain text from inline nodes (fallback)
  String _extractText(List<MarkdownNode> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      if (node is TextNode) {
        buffer.write(node.content);
      } else if (node is BoldNode) {
        buffer.write(_extractText(node.children));
      } else if (node is ItalicNode) {
        buffer.write(_extractText(node.children));
      } else if (node is StrikethroughNode) {
        buffer.write(_extractText(node.children));
      } else if (node is InlineCodeNode) {
        buffer.write(node.code);
      } else if (node is HardBreakNode) {
        buffer.write('\n');
      } else if (node is LinkNode) {
        buffer.write(_extractText(node.children));
      }
    }
    return buffer.toString();
  }
}

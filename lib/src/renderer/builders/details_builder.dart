import 'package:flutter/material.dart';

import '../../config/style_sheet.dart';
import '../../parser/ast/markdown_node.dart';
import '../reader_disclosure.dart';
import '../widget_builder.dart';

/// Builder for details/summary collapsible blocks
class DetailsBuilder extends MarkdownWidgetBuilder {
  /// Creates a new details builder
  const DetailsBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is DetailsNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final detailsNode = node as DetailsNode;
    final blockRenderer = context.blockRenderer;

    Widget summaryWidget;
    Widget? childrenWidget;

    if (blockRenderer != null) {
      summaryWidget = blockRenderer(detailsNode.summary);
      childrenWidget = detailsNode.children.isEmpty
          ? null
          : blockRenderer(detailsNode.children);
    } else {
      // Fallback: extract text
      summaryWidget = Text(_extractText(detailsNode.summary));
      childrenWidget = detailsNode.children.isEmpty
          ? null
          : Text(_extractText(detailsNode.children));
    }

    return _DetailsWidget(
      summary: summaryWidget,
      node: detailsNode,
      styleSheet: styleSheet,
      children: childrenWidget,
    );
  }

  String _extractText(List<MarkdownNode> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      if (node is ParagraphNode) {
        for (final child in node.children) {
          if (child is TextNode) {
            buffer.write(child.content);
          }
        }
        buffer.write('\n');
      } else if (node is TextNode) {
        buffer.write(node.content);
      }
    }
    return buffer.toString().trim();
  }
}

/// Stateful widget for rendering details/summary blocks
class _DetailsWidget extends StatefulWidget {
  const _DetailsWidget({
    required this.summary,
    required this.styleSheet,
    required this.node,
    this.children,
  });

  final Widget summary;
  final Widget? children;
  final DetailsNode node;
  final MarkdownStyleSheet styleSheet;

  @override
  State<_DetailsWidget> createState() => _DetailsWidgetState();
}

class _DetailsWidgetState extends State<_DetailsWidget>
    implements ReaderDisclosure {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.node.isOpen;
  }

  @override
  DetailsNode get details => widget.node;

  @override
  bool expandForReader() {
    if (_isExpanded) return false;
    setState(() => _isExpanded = true);
    return true;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.styleSheet.horizontalRuleColor ?? Colors.grey.shade300;
    final textColor = widget.styleSheet.textStyle?.color ?? Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary (clickable header)
          InkWell(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 20,
                    color: textColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DefaultTextStyle(
                      style: widget.styleSheet.paragraphStyle ?? const TextStyle(),
                      child: widget.summary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content (collapsible)
          if (_isExpanded && widget.children != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: borderColor,
                  ),
                ),
              ),
              child: widget.children,
            ),
        ],
      ),
    );
  }
}

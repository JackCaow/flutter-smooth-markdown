import 'package:flutter/material.dart';

import '../../config/style_sheet.dart';
import '../../parser/ast/markdown_node.dart';
import '../widget_builder.dart';

/// Builder for list nodes
class ListBuilder extends MarkdownWidgetBuilder {
  /// Creates a new list builder
  const ListBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is ListNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final listNode = node as ListNode;
    final indent = styleSheet.listIndent ?? 24.0;

    final listItems = <Widget>[];
    for (var i = 0; i < listNode.items.length; i++) {
      final item = listNode.items[i];
      final index = listNode.ordered ? listNode.startIndex + i : null;

      listItems.add(
        _buildListItem(
          item,
          index,
          indent,
          styleSheet,
          context,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: listItems,
    );
  }

  Widget _buildListItem(
    ListItemNode item,
    int? index,
    double indent,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    // Build marker (bullet or number)
    Widget marker;
    if (item.checked != null) {
      // Task list item
      marker = Icon(
        item.checked! ? Icons.check_box : Icons.check_box_outline_blank,
        size: 20,
      );
    } else if (index != null) {
      // Ordered list
      marker = Text(
        '$index. ',
        style: styleSheet.listBulletStyle,
      );
    } else {
      // Unordered list
      marker = Text(
        '• ',
        style: styleSheet.listBulletStyle,
      );
    }

    final inlineChildren = <MarkdownNode>[];
    final nestedLists = <ListNode>[];
    for (final child in item.children) {
      if (child is ListNode) {
        nestedLists.add(child);
      } else {
        inlineChildren.add(child);
      }
    }

    // Render item content using inlineRenderer from context
    final inlineRenderer = context.inlineRenderer;
    Widget? content;
    if (inlineChildren.isNotEmpty && inlineRenderer != null) {
      content = inlineRenderer(inlineChildren, styleSheet.textStyle);
    } else if (inlineChildren.isNotEmpty) {
      // Fallback
      final text = _extractText(inlineChildren);
      content = Text(text, style: styleSheet.textStyle);
    }

    final contentChildren = <Widget>[
      if (content != null) content,
      for (final nestedList in nestedLists)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: build(
            nestedList,
            styleSheet,
            context.copyWith(listLevel: context.listLevel + 1),
          ),
        ),
    ];

    return Padding(
      padding: EdgeInsets.only(left: context.listLevel * indent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          marker,
          const SizedBox(width: 4),
          Expanded(
            child: contentChildren.length == 1
                ? contentChildren.single
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: contentChildren,
                  ),
          ),
        ],
      ),
    );
  }

  String _extractText(List<MarkdownNode> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      if (node is TextNode) {
        buffer.write(node.content);
      } else if (node is HardBreakNode) {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }
}

import 'package:flutter/widgets.dart';

import '../../config/style_sheet.dart';
import '../../parser/ast/markdown_node.dart';
import '../widget_builder.dart';

/// Builder for inline hard line breaks.
class HardBreakBuilder extends MarkdownWidgetBuilder {
  /// Creates a hard break builder.
  const HardBreakBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is HardBreakNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    return Text('\n', style: styleSheet.textStyle);
  }
}

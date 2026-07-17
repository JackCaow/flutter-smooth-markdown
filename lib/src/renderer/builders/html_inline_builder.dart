import 'package:flutter/widgets.dart';

import '../../config/style_sheet.dart';
import '../../parser/ast/html_nodes.dart';
import '../../parser/ast/markdown_node.dart';
import '../widget_builder.dart';

/// Font scale applied to subscript and superscript text
const double _subSupFontScale = 0.75;

/// Vertical shift factors relative to the base font size
const double _superscriptShiftFactor = -0.35;
const double _subscriptShiftFactor = 0.15;

/// Fallback border color for `<kbd>` keys
const Color _kbdFallbackBorderColor = Color(0xFFBDBDBD);

String _extractText(List<MarkdownNode> nodes) {
  return nodes.whereType<TextNode>().map((n) => n.content).join();
}

double _baseFontSize(MarkdownStyleSheet styleSheet) {
  return styleSheet.textStyle?.fontSize ?? 16;
}

/// Builder for underline nodes from HTML `<u>`/`<ins>` tags
class UnderlineBuilder extends MarkdownWidgetBuilder {
  /// Creates a new underline builder
  const UnderlineBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is UnderlineNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final underlineNode = node as UnderlineNode;
    final style = styleSheet.underlineStyle ??
        (styleSheet.textStyle ?? const TextStyle())
            .copyWith(decoration: TextDecoration.underline);
    final inlineRenderer = context.inlineRenderer;

    if (inlineRenderer != null) {
      return inlineRenderer(underlineNode.children, style);
    }

    // Fallback
    return Text(_extractText(underlineNode.children), style: style);
  }
}

/// Builder for highlight nodes from the HTML `<mark>` tag
class HighlightBuilder extends MarkdownWidgetBuilder {
  /// Creates a new highlight builder
  const HighlightBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is HighlightNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final highlightNode = node as HighlightNode;
    final style = styleSheet.highlightStyle ??
        (styleSheet.textStyle ?? const TextStyle())
            .copyWith(backgroundColor: const Color(0xFFFFF176));
    final inlineRenderer = context.inlineRenderer;

    if (inlineRenderer != null) {
      return inlineRenderer(highlightNode.children, style);
    }

    // Fallback
    return Text(_extractText(highlightNode.children), style: style);
  }
}

/// Builder for subscript nodes from the HTML `<sub>` tag
///
/// Flutter has no native subscript text style, so the content is
/// rendered smaller and shifted down with a paint-time transform,
/// which keeps line layout unaffected.
class SubscriptBuilder extends MarkdownWidgetBuilder {
  /// Creates a new subscript builder
  const SubscriptBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is SubscriptNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final subscriptNode = node as SubscriptNode;
    return _buildShiftedText(
      children: subscriptNode.children,
      styleSheet: styleSheet,
      context: context,
      style: styleSheet.subscriptStyle,
      shiftFactor: _subscriptShiftFactor,
    );
  }
}

/// Builder for superscript nodes from the HTML `<sup>` tag
///
/// Flutter has no native superscript text style, so the content is
/// rendered smaller and shifted up with a paint-time transform,
/// which keeps line layout unaffected.
class SuperscriptBuilder extends MarkdownWidgetBuilder {
  /// Creates a new superscript builder
  const SuperscriptBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is SuperscriptNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final superscriptNode = node as SuperscriptNode;
    return _buildShiftedText(
      children: superscriptNode.children,
      styleSheet: styleSheet,
      context: context,
      style: styleSheet.superscriptStyle,
      shiftFactor: _superscriptShiftFactor,
    );
  }
}

Widget _buildShiftedText({
  required List<MarkdownNode> children,
  required MarkdownStyleSheet styleSheet,
  required MarkdownRenderContext context,
  required TextStyle? style,
  required double shiftFactor,
}) {
  final baseFontSize = _baseFontSize(styleSheet);
  final effectiveStyle = style ??
      (styleSheet.textStyle ?? const TextStyle())
          .copyWith(fontSize: baseFontSize * _subSupFontScale);
  final inlineRenderer = context.inlineRenderer;
  final inner = inlineRenderer != null
      ? inlineRenderer(children, effectiveStyle)
      : Text(_extractText(children), style: effectiveStyle);

  return Transform.translate(
    offset: Offset(0, baseFontSize * shiftFactor),
    child: inner,
  );
}

/// Builder for keyboard input nodes from the HTML `<kbd>` tag
class KbdBuilder extends MarkdownWidgetBuilder {
  /// Creates a new keyboard input builder
  const KbdBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is KbdNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final kbdNode = node as KbdNode;
    final borderColor =
        styleSheet.horizontalRuleColor ?? _kbdFallbackBorderColor;
    final style = styleSheet.kbdStyle ??
        (styleSheet.textStyle ?? const TextStyle())
            .copyWith(fontFamily: 'monospace', fontSize: 13);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
        color: borderColor.withValues(alpha: 0.12),
      ),
      child: Text(_extractText(kbdNode.children), style: style),
    );
  }
}

/// Builder for styled span nodes from HTML `<font>`/`<span>` tags
///
/// Builds a sparse [TextStyle] with only the parsed properties set, so
/// unset properties inherit from the surrounding text through normal
/// [TextSpan] style inheritance.
class StyledSpanBuilder extends MarkdownWidgetBuilder {
  /// Creates a new styled span builder
  const StyledSpanBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is StyledSpanNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final spanNode = node as StyledSpanNode;
    final colorValue = spanNode.color;
    final backgroundValue = spanNode.backgroundColor;
    final style = TextStyle(
      color: colorValue == null ? null : Color(colorValue),
      backgroundColor: backgroundValue == null ? null : Color(backgroundValue),
      fontSize: spanNode.fontSize,
    );
    final inlineRenderer = context.inlineRenderer;

    if (inlineRenderer != null) {
      return inlineRenderer(spanNode.children, style);
    }

    // Fallback
    return Text(_extractText(spanNode.children), style: style);
  }
}

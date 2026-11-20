import 'package:flutter/material.dart';

import '../../config/style_sheet.dart';
import '../../config/syntax_theme.dart';
import '../../rust/markdown_core.dart';
import '../../../widgets/markdown_diff_view.dart';
import '../../parser/ast/markdown_node.dart';
import '../widget_builder.dart';

/// Builder for code block nodes
class CodeBlockBuilder extends MarkdownWidgetBuilder {
  /// Creates a new code block builder
  const CodeBlockBuilder();

  @override
  bool canBuild(MarkdownNode node) => node is CodeBlockNode;

  @override
  Widget build(
    MarkdownNode node,
    MarkdownStyleSheet styleSheet,
    MarkdownRenderContext context,
  ) {
    final codeBlockNode = node as CodeBlockNode;

    // Use custom builder if provided
    if (context.codeBuilder != null) {
      return context.codeBuilder!(
        codeBlockNode.code,
        codeBlockNode.language,
      );
    }

    if (context.enableCodeHighlight && codeBlockNode.language == 'diff') {
      final parts = codeBlockNode.info?.split(RegExp(r'\s+')) ?? [];
      return MarkdownDiffView(patch: codeBlockNode.code,
        language: parts.length > 1 ? parts[1] : 'plaintext',
        selectable: false, syntaxTheme: context.syntaxTheme,
        textStyle: styleSheet.codeBlockStyle, padding: styleSheet.codeBlockPadding ?? EdgeInsets.zero);
    }
    final tokens = context.enableCodeHighlight && codeBlockNode.language != null
        ? MarkdownCore.highlightedCode(codeBlockNode.code, language: codeBlockNode.language!)
        : <MarkdownHighlightToken>[];
    final dark = (styleSheet.codeBlockDecoration?.color?.computeLuminance() ?? 1) < 0.5;
    final theme = context.syntaxTheme ?? MarkdownSyntaxTheme.fromBrightness(dark ? Brightness.dark : Brightness.light);

    // Default rendering
    return Container(
      decoration: styleSheet.codeBlockDecoration,
      padding: styleSheet.codeBlockPadding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text.rich(highlightedCodeSpan(codeBlockNode.code, tokens, theme,
          style: styleSheet.codeBlockStyle)),
      ),
    );
  }
}

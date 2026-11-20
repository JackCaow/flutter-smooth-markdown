import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/style_sheet.dart';
import '../../config/syntax_theme.dart';
import '../../rust/markdown_core.dart';
import '../../../widgets/markdown_diff_view.dart';
import '../../parser/ast/markdown_node.dart';
import '../widget_builder.dart';

/// Enhanced builder for code block nodes with copy button and language tag
class EnhancedCodeBlockBuilder extends MarkdownWidgetBuilder {
  /// Creates a new enhanced code block builder
  const EnhancedCodeBlockBuilder({
    this.showCopyButton = true,
    this.showLanguageTag = true,
    this.enableSyntaxHighlighting = true,
  });

  final bool showCopyButton;
  final bool showLanguageTag;
  final bool enableSyntaxHighlighting;

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
      return context.codeBuilder!(codeBlockNode.code, codeBlockNode.language);
    }

    return _EnhancedCodeBlockWidget(
      code: codeBlockNode.code,
      language: codeBlockNode.language,
      styleSheet: styleSheet,
      showCopyButton: showCopyButton,
      showLanguageTag: showLanguageTag,
      enableSyntaxHighlighting: enableSyntaxHighlighting && context.enableCodeHighlight,
      syntaxTheme: context.syntaxTheme,
      info: codeBlockNode.info,
      selectable: context.selectable,
    );
  }
}

class _EnhancedCodeBlockWidget extends StatefulWidget {
  const _EnhancedCodeBlockWidget({
    required this.code,
    required this.language,
    required this.styleSheet,
    required this.showCopyButton,
    required this.showLanguageTag,
    required this.enableSyntaxHighlighting,
    this.selectable = false,
    this.syntaxTheme,
    this.info,
  });

  final String code;
  final String? language;
  final MarkdownStyleSheet styleSheet;
  final bool showCopyButton;
  final bool showLanguageTag;
  final bool enableSyntaxHighlighting;
  final bool selectable;
  final MarkdownSyntaxTheme? syntaxTheme;
  final String? info;

  @override
  State<_EnhancedCodeBlockWidget> createState() =>
      _EnhancedCodeBlockWidgetState();
}

class _EnhancedCodeBlockWidgetState extends State<_EnhancedCodeBlockWidget> {
  bool _copied = false;
  bool _isHovered = false;
  Timer? _copyResetTimer;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() {
      _copied = true;
    });

    // Reset copied state after 2 seconds
    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  Widget _buildCodeContent(BuildContext context) {
    if (widget.enableSyntaxHighlighting && widget.language == 'diff') {
      final parts = widget.info?.split(RegExp(r'\s+')) ?? [];
      return MarkdownDiffView(patch: widget.code,
        language: parts.length > 1 ? parts[1] : 'plaintext',
        selectable: false, syntaxTheme: widget.syntaxTheme,
        textStyle: widget.styleSheet.codeBlockStyle, padding: EdgeInsets.zero);
    }
    final hasHighlighting =
        widget.enableSyntaxHighlighting && widget.language != null;

    if (hasHighlighting) {
      final tokens = MarkdownCore.highlightedCode(
        widget.code,
        language: widget.language!,
      );
      final spans =
          highlightedCodeSpan(
            widget.code,
            tokens,
            widget.syntaxTheme ?? MarkdownSyntaxTheme.fromBrightness(Theme.of(context).brightness),
          ).children ??
          [];
      final textSpan = TextSpan(
        style: widget.styleSheet.codeBlockStyle,
        children: spans,
      );

      if (widget.selectable) {
        return Text.rich(textSpan);
      }
      return RichText(text: textSpan);
    }

    if (widget.selectable) {
      return Text.rich(
        TextSpan(text: widget.code, style: widget.styleSheet.codeBlockStyle),
      );
    }
    return Text(widget.code, style: widget.styleSheet.codeBlockStyle);
  }

  @override
  Widget build(BuildContext context) {
    // On mobile platforms, always show the copy button (no hover support)
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: widget.styleSheet.codeBlockDecoration?.copyWith(
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Code content
            Container(
              padding: widget.styleSheet.codeBlockPadding,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildCodeContent(context),
              ),
            ),

            // Top right controls
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Language tag
                  if (widget.showLanguageTag && widget.language != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.language!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                  if (widget.showLanguageTag && widget.language != null)
                    const SizedBox(width: 8),

                  // Copy button
                  if (widget.showCopyButton)
                    AnimatedOpacity(
                      opacity: isMobile || _isHovered || _copied ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: _copyToClipboard,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _copied
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _copied ? Icons.check : Icons.content_copy,
                                  size: 16,
                                  color: _copied
                                      ? Colors.green[700]
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                ),
                                if (_copied) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    'Copied!',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

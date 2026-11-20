import 'package:flutter/material.dart';

import '../src/config/syntax_theme.dart';
import '../src/rust/markdown_core.dart';
import 'markdown_code_view.dart';

/// Unified diff viewer with old/new line numbers, per-side syntax highlighting
/// and differing-word backgrounds. Metadata is filtered by the shared core.
class MarkdownDiffView extends StatefulWidget {
  /// Creates a diff viewer for one language/file (or multiple same-language hunks).
  const MarkdownDiffView({
    required this.patch,
    required this.language,
    super.key,
    this.syntaxTheme,
    this.textStyle,
    this.showLineNumbers = true,
    this.selectable = true,
    this.tabWidth = 4,
    this.padding = const EdgeInsets.all(12),
  });

  /// Unified diff text.
  final String patch;

  /// Source language, extension, or file name, not the `diff` fence tag.
  final String language;

  /// Semantic token and diff colors.
  final MarkdownSyntaxTheme? syntaxTheme;

  /// Base typography.
  final TextStyle? textStyle;

  /// Show old/new number columns.
  final bool showLineNumbers;

  /// Enable native text selection.
  final bool selectable;

  /// Spaces per tab, in 0..16.
  final int tabWidth;

  /// Content padding.
  final EdgeInsetsGeometry padding;
  @override
  State<MarkdownDiffView> createState() => _MarkdownDiffViewState();
}

class _MarkdownDiffViewState extends State<MarkdownDiffView> {
  late List<MarkdownDiffRow> _rows;
  void _update() {
    _rows = MarkdownCore.highlightedDiff(
      widget.patch,
      language: widget.language,
      tabWidth: widget.tabWidth,
    );
  }

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(MarkdownDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patch != widget.patch ||
        oldWidget.language != widget.language ||
        oldWidget.tabWidth != widget.tabWidth)
      _update();
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty && widget.patch.isNotEmpty) {
      // Plain +/- snippets and partial streamed headers have no unified hunk.
      return MarkdownCodeView(
        code: widget.patch,
        language: widget.language,
        syntaxTheme: widget.syntaxTheme,
        textStyle: widget.textStyle,
        showLineNumbers: widget.showLineNumbers,
        selectable: widget.selectable,
        tabWidth: widget.tabWidth,
        padding: widget.padding,
      );
    }
    return CodeRowsView(
      rows: _rows,
      diff: true,
      syntaxTheme: widget.syntaxTheme,
      textStyle: widget.textStyle,
      showLineNumbers: widget.showLineNumbers,
      selectable: widget.selectable,
      padding: widget.padding,
    );
  }
}

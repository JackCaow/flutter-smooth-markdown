import 'package:flutter/material.dart';

import '../src/config/syntax_theme.dart';
import '../src/renderer/code_row.dart';
import '../src/rust/markdown_core.dart';

/// Source viewer using whole-file semantic highlighting from the shared core.
/// Place in a vertical scroll view for large files; horizontal scrolling is built in.
class MarkdownCodeView extends StatefulWidget {
  /// Creates a source viewer. No changes to existing Markdown widgets required.
  const MarkdownCodeView({
    required this.code,
    required this.language,
    super.key,
    this.syntaxTheme,
    this.textStyle,
    this.showLineNumbers = true,
    this.selectable = true,
    this.tabWidth = 4,
    this.padding = const EdgeInsets.all(12),
  });

  /// Complete source; highlighting is never restarted at line boundaries.
  final String code;

  /// Fence tag, extension, or file name.
  final String language;

  /// Optional semantic style overrides and diff colors.
  final MarkdownSyntaxTheme? syntaxTheme;

  /// Base monospace typography.
  final TextStyle? textStyle;

  /// Whether to display the line-number gutter.
  final bool showLineNumbers;

  /// Whether selection is enabled.
  final bool selectable;

  /// Spaces per tab, in 0..16 (0 preserves tabs).
  final int tabWidth;

  /// Content padding.
  final EdgeInsetsGeometry padding;
  @override
  State<MarkdownCodeView> createState() => _MarkdownCodeViewState();
}

class _MarkdownCodeViewState extends State<MarkdownCodeView> {
  late List<MarkdownHighlightedLine> _lines;
  void _update() {
    _lines = MarkdownCore.highlightedLines(
      widget.code,
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
  void didUpdateWidget(MarkdownCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code ||
        oldWidget.language != widget.language ||
        oldWidget.tabWidth != widget.tabWidth) {
      _update();
    }
  }

  @override
  Widget build(BuildContext context) => CodeRowsView(
    rows: [
      for (var i = 0; i < _lines.length; i++)
        MarkdownDiffRow(
          kind: MarkdownDiffKind.context,
          line: _lines[i],
          newLineNumber: i + 1,
        ),
    ],
    diff: false,
    syntaxTheme: widget.syntaxTheme,
    textStyle: widget.textStyle,
    showLineNumbers: widget.showLineNumbers,
    selectable: widget.selectable,
    padding: widget.padding,
  );
}

/// Internal shared layout for source and unified-diff rows.
class CodeRowsView extends StatelessWidget {
  const CodeRowsView({
    required this.rows,
    required this.diff,
    required this.showLineNumbers,
    required this.selectable,
    required this.padding,
    this.syntaxTheme,
    this.textStyle,
    super.key,
  });
  final List<MarkdownDiffRow> rows;
  final bool diff, showLineNumbers, selectable;
  final EdgeInsetsGeometry padding;
  final MarkdownSyntaxTheme? syntaxTheme;
  final TextStyle? textStyle;
  @override
  Widget build(BuildContext context) {
    final lineStyle = CodeRowStyle.of(
      context,
      largestLineNumber: CodeRowStyle.maxLineNumber(rows),
      syntaxTheme: syntaxTheme,
      textStyle: textStyle,
    );
    final content = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
          ),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in rows)
                  lineStyle.buildRow(
                    row,
                    gutter: showLineNumbers
                        ? (diff ? CodeGutter.both : CodeGutter.modified)
                        : CodeGutter.none,
                    showMarker: diff,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: padding,
      child: selectable ? SelectionArea(child: content) : content,
    );
  }
}

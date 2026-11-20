import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/syntax_theme.dart';
import '../rust/core_types.dart';

/// Number columns used by the code and diff viewers.
enum CodeGutter { none, original, modified, both }

/// Typography, gutter measurements and token spans shared by code and diffs.
class CodeRowStyle {
  CodeRowStyle._(this.theme, this.textStyle, this.gutterWidth);

  factory CodeRowStyle.of(
    BuildContext context, {
    required int largestLineNumber,
    MarkdownSyntaxTheme? syntaxTheme,
    TextStyle? textStyle,
  }) {
    final theme =
        syntaxTheme ??
        MarkdownSyntaxTheme.fromBrightness(Theme.of(context).brightness);
    final style = DefaultTextStyle.of(context).style
        .merge(
          const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
        )
        .merge(textStyle);
    return CodeRowStyle._(
      theme,
      style,
      largestLineNumber.toString().length * (style.fontSize ?? 13) * .7 + 16,
    );
  }

  final MarkdownSyntaxTheme theme;
  final TextStyle textStyle;
  final double gutterWidth;

  static int maxLineNumber(Iterable<MarkdownDiffRow> rows) {
    var largest = 1;
    for (final row in rows) {
      largest = math.max(largest, row.oldLineNumber ?? 0);
      largest = math.max(largest, row.newLineNumber ?? 0);
    }
    return largest;
  }

  Widget _number(int? number) => SizedBox(
    width: gutterWidth,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(
        number?.toString() ?? '',
        maxLines: 1,
        softWrap: false,
        style: textStyle.merge(theme.lineNumberStyle),
      ),
    ),
  );

  /// Wrapped rows accept a bounded pane width; legacy rows keep horizontal scrolling.
  Widget buildRow(
    MarkdownDiffRow row, {
    required CodeGutter gutter,
    required bool showMarker,
    bool wrap = false,
  }) {
    final prefix = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (gutter == CodeGutter.original || gutter == CodeGutter.both)
          _number(row.oldLineNumber),
        if (gutter == CodeGutter.modified || gutter == CodeGutter.both)
          _number(row.newLineNumber),
        if (gutter != CodeGutter.none) const SizedBox(width: 12),
        if (showMarker)
          Text(switch (row.kind) {
            MarkdownDiffKind.added => '+ ',
            MarkdownDiffKind.removed => '- ',
            _ => '  ',
          }, style: textStyle),
      ],
    );
    final excludedPrefix = SelectionContainer.disabled(
      child: ExcludeSemantics(child: prefix),
    );
    final code = Text.rich(
      highlightedCodeSpan(
        row.line.text.isEmpty ? ' ' : row.line.text,
        row.line.tokens,
        theme,
        style: textStyle,
        changedStart: row.changedStart,
        changedLength: row.changedLength,
        changeColor: row.kind == MarkdownDiffKind.removed
            ? theme.removedChangeBackground
            : theme.addedChangeBackground,
      ),
      softWrap: wrap,
    );
    return ColoredBox(
      color: switch (row.kind) {
        MarkdownDiffKind.added => theme.addedBackground,
        MarkdownDiffKind.removed => theme.removedBackground,
        MarkdownDiffKind.hunk => theme.hunkBackground,
        _ => Colors.transparent,
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: wrap
            ? LayoutBuilder(
                builder: (context, constraints) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Keep code readable even when both gutters have many digits
                    // or a side-by-side pane occupies half a phone screen.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * .5,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: excludedPrefix,
                      ),
                    ),
                    Expanded(child: code),
                  ],
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  excludedPrefix,
                  Flexible(child: code),
                ],
              ),
      ),
    );
  }
}

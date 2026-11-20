import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../src/config/syntax_theme.dart';
import '../src/renderer/code_row.dart';
import '../src/rust/markdown_core.dart';
import 'markdown_code_view.dart';

/// How old and new file contents are arranged within a diff.
enum MarkdownDiffLayout {
  /// Keep the original hunk order, with old and new line numbers in one gutter.
  unified,

  /// Align removals on the left with additions on the right.
  sideBySide,
}

/// A patch viewer with per-side syntax highlighting and differing-word backgrounds.
class MarkdownDiffView extends StatefulWidget {
  /// Creates an inline diff viewer. The unified layout scrolls horizontally.
  const MarkdownDiffView({
    required this.patch,
    required this.language,
    super.key,
    this.layout = MarkdownDiffLayout.unified,
    this.syntaxTheme,
    this.textStyle,
    this.showLineNumbers = true,
    this.selectable = true,
    this.tabWidth = 4,
    this.padding = const EdgeInsets.all(12),
  }) : _sliver = false;

  /// Builds only the rows in and near a vertical [CustomScrollView]'s viewport.
  ///
  /// Long lines wrap to fit the viewport or their side-by-side pane. The patch
  /// is parsed and highlighted as a whole so multiline syntax stays accurate.
  /// Set [selectable] to true for selection across the entire patch, which
  /// keeps all rows mounted.
  const MarkdownDiffView.sliver({
    required this.patch,
    required this.language,
    super.key,
    this.layout = MarkdownDiffLayout.unified,
    this.syntaxTheme,
    this.textStyle,
    this.showLineNumbers = true,
    this.selectable = false,
    this.tabWidth = 4,
    this.padding = const EdgeInsets.all(12),
  }) : _sliver = true;

  final bool _sliver;

  /// Unified diff text. Unrecognized or incomplete patches display as source.
  final String patch;

  /// Source language, extension, or file name, not the `diff` fence tag.
  final String language;

  /// Presentation of paired changes. The default is [MarkdownDiffLayout.unified].
  final MarkdownDiffLayout layout;

  /// Semantic token and diff colors.
  final MarkdownSyntaxTheme? syntaxTheme;

  /// Base typography.
  final TextStyle? textStyle;

  /// Show old/new number columns.
  final bool showLineNumbers;

  /// Enable native text selection across the entire patch.
  final bool selectable;

  /// Spaces per tab, in 0..16.
  final int tabWidth;

  /// Content padding.
  final EdgeInsetsGeometry padding;

  @override
  State<MarkdownDiffView> createState() => _MarkdownDiffViewState();
}

typedef _LinePair = ({MarkdownDiffRow? original, MarkdownDiffRow? modified});

/// Keep each change run inside its hunk. The core pairs changed words in the
/// same order. Unmatched rows keep a blank cell on the other side.
List<_LinePair> _pairRows(List<MarkdownDiffRow> rows) {
  final pairs = <_LinePair>[];
  var i = 0;
  while (i < rows.length) {
    final row = rows[i];
    if (row.kind != MarkdownDiffKind.removed &&
        row.kind != MarkdownDiffKind.added) {
      pairs.add((original: row, modified: row));
      i++;
      continue;
    }
    final removedStart = i;
    while (i < rows.length && rows[i].kind == MarkdownDiffKind.removed) {
      i++;
    }
    final addedStart = i;
    while (i < rows.length && rows[i].kind == MarkdownDiffKind.added) {
      i++;
    }
    final removedCount = addedStart - removedStart;
    final addedCount = i - addedStart;
    for (
      var offset = 0;
      offset < math.max(removedCount, addedCount);
      offset++
    ) {
      pairs.add((
        original: offset < removedCount ? rows[removedStart + offset] : null,
        modified: offset < addedCount ? rows[addedStart + offset] : null,
      ));
    }
  }
  return pairs;
}

class _MarkdownDiffViewState extends State<MarkdownDiffView> {
  late List<MarkdownDiffRow> _rows;
  late int _largestLineNumber;
  List<_LinePair>? _pairs;
  List<MarkdownHighlightedLine>? _sourceLines;

  void _update() {
    _rows = MarkdownCore.highlightedDiff(
      widget.patch,
      language: widget.language,
      tabWidth: widget.tabWidth,
    );
    _largestLineNumber = CodeRowStyle.maxLineNumber(_rows);
    _pairs = null;
    _sourceLines = null;
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
        oldWidget.tabWidth != widget.tabWidth) {
      _update();
    }
  }

  Widget _boxed(Widget child) =>
      widget._sliver ? SliverToBoxAdapter(child: child) : child;

  @override
  Widget build(BuildContext context) {
    final sourceOnly = _rows.isEmpty && widget.patch.isNotEmpty;
    final lazy = widget._sliver && !widget.selectable;
    if (!lazy && sourceOnly) {
      return _boxed(
        MarkdownCodeView(
          code: widget.patch,
          language: widget.language,
          syntaxTheme: widget.syntaxTheme,
          textStyle: widget.textStyle,
          showLineNumbers: widget.showLineNumbers,
          selectable: widget.selectable,
          tabWidth: widget.tabWidth,
          padding: widget.padding,
        ),
      );
    }
    if (!lazy && widget.layout == MarkdownDiffLayout.unified) {
      return _boxed(
        CodeRowsView(
          rows: _rows,
          diff: true,
          syntaxTheme: widget.syntaxTheme,
          textStyle: widget.textStyle,
          showLineNumbers: widget.showLineNumbers,
          selectable: widget.selectable,
          padding: widget.padding,
        ),
      );
    }
    final lines = sourceOnly
        ? _sourceLines ??= MarkdownCore.highlightedLines(
            widget.patch,
            language: widget.language,
            tabWidth: widget.tabWidth,
          )
        : null;
    final pairs = !sourceOnly && widget.layout == MarkdownDiffLayout.sideBySide
        ? _pairs ??= _pairRows(_rows)
        : null;
    final style = CodeRowStyle.of(
      context,
      largestLineNumber: lines?.length ?? _largestLineNumber,
      syntaxTheme: widget.syntaxTheme,
      textStyle: widget.textStyle,
    );
    final count = lines?.length ?? pairs?.length ?? _rows.length;
    Widget rowAt(int index) {
      if (pairs != null) return _buildPair(pairs[index], style);
      final row = lines == null
          ? _rows[index]
          : MarkdownDiffRow(
              kind: MarkdownDiffKind.context,
              line: lines[index],
              newLineNumber: index + 1,
            );
      return style.buildRow(
        row,
        gutter: _gutter(sourceOnly ? CodeGutter.modified : CodeGutter.both),
        showMarker: !sourceOnly,
        wrap: true,
      );
    }

    if (lazy) {
      return SliverPadding(
        padding: widget.padding,
        sliver: SliverList.builder(
          itemCount: count,
          itemBuilder: (context, index) => rowAt(index),
          addAutomaticKeepAlives: false,
        ),
      );
    }
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List<Widget>.generate(count, rowAt),
    );
    return _boxed(
      Padding(
        padding: widget.padding,
        child: widget.selectable ? SelectionArea(child: column) : column,
      ),
    );
  }

  CodeGutter _gutter(CodeGutter position) =>
      widget.showLineNumbers ? position : CodeGutter.none;

  Widget _buildPair(_LinePair pair, CodeRowStyle style) {
    final old = pair.original;
    // Hunk headers and "No newline" notes span both columns exactly once.
    if (old != null &&
        (old.kind == MarkdownDiffKind.hunk ||
            old.kind == MarkdownDiffKind.note)) {
      return style.buildRow(
        old,
        gutter: CodeGutter.none,
        showMarker: false,
        wrap: true,
      );
    }
    Widget pane(MarkdownDiffRow? row, bool original) {
      if (row == null) return const SizedBox.shrink();
      final number = original ? row.oldLineNumber : row.newLineNumber;
      return Semantics(
        container: true,
        label: original ? 'Original line $number' : 'Modified line $number',
        child: style.buildRow(
          row,
          gutter: _gutter(original ? CodeGutter.original : CodeGutter.modified),
          showMarker: true,
          wrap: true,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.ltr,
      children: [
        Expanded(child: pane(old, true)),
        const SizedBox(width: 4),
        Expanded(child: pane(pair.modified, false)),
      ],
    );
  }
}

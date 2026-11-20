import 'package:flutter/material.dart';

import '../rust/core_types.dart';

/// Style overrides keyed by semantic names rather than core wire identifiers.
@immutable
class MarkdownSyntaxTheme {
  /// Creates a theme. Unspecified kinds inherit their semantic family or base.
  const MarkdownSyntaxTheme({
    this.styles = const {},
    this.addedBackground = const Color(0x182DA44E),
    this.removedBackground = const Color(0x18CF222E),
    this.addedChangeBackground = const Color(0x402DA44E),
    this.removedChangeBackground = const Color(0x40CF222E),
    this.hunkBackground = const Color(0x180969DA),
    this.lineNumberStyle = const TextStyle(color: Color(0xFF8B949E)),
  });

  /// Explicit per-kind style overrides.
  final Map<MarkdownHighlightKind, TextStyle> styles;

  /// Background of an added row.
  final Color addedBackground;

  /// Background of a removed row.
  final Color removedBackground;

  /// Background of the changed portion of an added row.
  final Color addedChangeBackground;

  /// Background of the changed portion of a removed row.
  final Color removedChangeBackground;

  /// Background of a hunk header.
  final Color hunkBackground;

  /// Gutter typography.
  final TextStyle lineNumberStyle;

  /// GitHub-inspired defaults, using the surrounding brightness.
  factory MarkdownSyntaxTheme.fromBrightness(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return MarkdownSyntaxTheme(
      styles: {
        MarkdownHighlightKind.keyword: TextStyle(
          color: Color(dark ? 0xFFFF7B72 : 0xFFCF222E),
        ),
        MarkdownHighlightKind.string: TextStyle(
          color: Color(dark ? 0xFFA5D6FF : 0xFF0A3069),
        ),
        MarkdownHighlightKind.comment: TextStyle(
          color: Color(dark ? 0xFF8B949E : 0xFF6E7781),
        ),
        MarkdownHighlightKind.number: TextStyle(
          color: Color(dark ? 0xFF79C0FF : 0xFF0550AE),
        ),
        MarkdownHighlightKind.function: TextStyle(
          color: Color(dark ? 0xFFD2A8FF : 0xFF8250DF),
        ),
        MarkdownHighlightKind.type: TextStyle(
          color: Color(dark ? 0xFFFFA657 : 0xFF953800),
        ),
        MarkdownHighlightKind.tag: TextStyle(
          color: Color(dark ? 0xFF7EE787 : 0xFF116329),
        ),
        MarkdownHighlightKind.attribute: TextStyle(
          color: Color(dark ? 0xFF79C0FF : 0xFF0550AE),
        ),
        MarkdownHighlightKind.variableParameter: TextStyle(
          color: Color(dark ? 0xFFFFA657 : 0xFF953800),
        ),
      },
    );
  }

  /// Resolve a style, falling back to its semantic family.
  TextStyle? styleFor(MarkdownHighlightKind kind) =>
      styles[kind] ??
      styles[switch (kind) {
        MarkdownHighlightKind.keywordControl ||
        MarkdownHighlightKind.keywordDeclaration ||
        MarkdownHighlightKind.keywordImport ||
        MarkdownHighlightKind.keywordOperator ||
        MarkdownHighlightKind.preproc => MarkdownHighlightKind.keyword,
        MarkdownHighlightKind.stringEscape ||
        MarkdownHighlightKind.stringRegex ||
        MarkdownHighlightKind.stringSpecial ||
        MarkdownHighlightKind.linkUri => MarkdownHighlightKind.string,
        MarkdownHighlightKind.commentDoc => MarkdownHighlightKind.comment,
        MarkdownHighlightKind.functionDefinition ||
        MarkdownHighlightKind.functionMethod ||
        MarkdownHighlightKind.constructor => MarkdownHighlightKind.function,
        MarkdownHighlightKind.typeBuiltin ||
        MarkdownHighlightKind.namespace => MarkdownHighlightKind.type,
        MarkdownHighlightKind.tagDoctype ||
        MarkdownHighlightKind.tagComponent => MarkdownHighlightKind.tag,
        MarkdownHighlightKind.boolean ||
        MarkdownHighlightKind.constant ||
        MarkdownHighlightKind.constantBuiltin => MarkdownHighlightKind.number,
        MarkdownHighlightKind.propertyKey => MarkdownHighlightKind.attribute,
        _ => kind,
      }];

  /// Updates selected colors or semantic styles while keeping other defaults.
  MarkdownSyntaxTheme copyWith({
    Map<MarkdownHighlightKind, TextStyle>? styles,
    Color? addedBackground,
    Color? removedBackground,
    Color? addedChangeBackground,
    Color? removedChangeBackground,
    Color? hunkBackground,
    TextStyle? lineNumberStyle,
  }) => MarkdownSyntaxTheme(
    styles: {...this.styles, ...?styles},
    addedBackground: addedBackground ?? this.addedBackground,
    removedBackground: removedBackground ?? this.removedBackground,
    addedChangeBackground: addedChangeBackground ?? this.addedChangeBackground,
    removedChangeBackground:
        removedChangeBackground ?? this.removedChangeBackground,
    hunkBackground: hunkBackground ?? this.hunkBackground,
    lineNumberStyle: lineNumberStyle ?? this.lineNumberStyle,
  );
}

/// Builds spans without changing source text or token offsets.
TextSpan highlightedCodeSpan(
  String source,
  List<MarkdownHighlightToken> tokens,
  MarkdownSyntaxTheme theme, {
  TextStyle? style,
  int? changedStart,
  int? changedLength,
  Color? changeColor,
}) {
  final points = <int>{
    0,
    source.length,
    for (final token in tokens) ...[token.start, token.end],
    if (changedStart != null) changedStart,
    if (changedStart != null && changedLength != null)
      changedStart + changedLength,
  }.toList()..sort();
  var tokenIndex = 0;
  final spans = <TextSpan>[];
  for (var i = 0; i < points.length - 1; i++) {
    final start = points[i], end = points[i + 1];
    if (start == end) continue;
    while (tokenIndex < tokens.length && tokens[tokenIndex].end <= start) {
      tokenIndex++;
    }
    final token =
        tokenIndex < tokens.length && tokens[tokenIndex].start <= start
        ? tokens[tokenIndex]
        : null;
    var tokenStyle = token == null ? null : theme.styleFor(token.kind);
    if (changedStart != null &&
        changedLength != null &&
        start >= changedStart &&
        end <= changedStart + changedLength) {
      tokenStyle = (tokenStyle ?? const TextStyle()).copyWith(
        backgroundColor: changeColor,
      );
    }
    spans.add(TextSpan(text: source.substring(start, end), style: tokenStyle));
  }
  return TextSpan(style: style, children: spans);
}

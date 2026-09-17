import 'package:flutter/material.dart';

/// Defines the visual styling for all Markdown elements.
///
/// [MarkdownStyleSheet] provides comprehensive control over the appearance of
/// rendered markdown content. It includes text styles for different elements
/// (headers, paragraphs, code, links, etc.) as well as decorations for containers
/// (blockquotes, code blocks, tables).
///
/// ## Usage
///
/// Most commonly, you'll use one of the built-in factory constructors rather
/// than creating a custom stylesheet from scratch:
///
/// ```dart
/// // Use the default light theme
/// SmoothMarkdown(
///   data: markdownText,
///   styleSheet: MarkdownStyleSheet.light(),
/// )
///
/// // Use GitHub-style theme
/// SmoothMarkdown(
///   data: markdownText,
///   styleSheet: MarkdownStyleSheet.github(),
/// )
///
/// // Adapt to app's theme automatically
/// SmoothMarkdown(
///   data: markdownText,
///   styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
/// )
/// ```
///
/// ## Customization
///
/// To customize a theme, use [copyWith] to override specific properties:
///
/// ```dart
/// final customSheet = MarkdownStyleSheet.light().copyWith(
///   h1Style: TextStyle(
///     fontSize: 36,
///     fontWeight: FontWeight.w900,
///     color: Colors.purple,
///   ),
///   linkStyle: TextStyle(
///     color: Colors.blue[700],
///     decoration: TextDecoration.none, // Remove underline
///   ),
///   codeBlockDecoration: BoxDecoration(
///     color: Colors.grey[900],
///     borderRadius: BorderRadius.circular(12),
///   ),
/// );
/// ```
///
/// ## Available Themes
///
/// - **light()**: Clean, readable light theme (default)
/// - **dark()**: Dark theme for dark mode apps
/// - **github()**: Mimics GitHub's markdown styling (light or dark)
/// - **vscode()**: VS Code editor-style theme (light or dark)
/// - **fromTheme()**: Adapts to Flutter's ThemeData automatically
/// - **fromBrightness()**: Creates theme based on brightness setting
///
/// ## Styling Categories
///
/// The stylesheet includes properties for:
///
/// **Text Styles**:
/// - Headers (h1-h6), paragraphs, blockquotes
/// - Inline formatting (bold, italic, strikethrough, code)
/// - Links, list bullets, table cells
///
/// **Container Decorations**:
/// - Blockquotes, code blocks, tables
/// - Table headers and alternating row colors
/// - Horizontal rules
///
/// **Spacing & Layout**:
/// - Block spacing, list indentation
/// - Padding for blockquotes, code blocks, table cells
///
/// See also:
///
/// - [SmoothMarkdown], which uses this stylesheet for rendering
/// - [MarkdownConfig], for configuring parsing behavior

/// Font scale applied to subscript and superscript text, relative to the
/// surrounding text size.
const double markdownSubSupFontScale = 0.75;

class MarkdownStyleSheet {
  /// Creates a custom Markdown style sheet.
  ///
  /// All parameters are optional. Unspecified properties will inherit default
  /// values when the stylesheet is used. It's recommended to use one of the
  /// factory constructors ([light], [dark], [github], [vscode]) and customize
  /// with [copyWith] rather than constructing from scratch.
  ///
  /// Example:
  ///
  /// ```dart
  /// const customSheet = MarkdownStyleSheet(
  ///   h1Style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
  ///   paragraphStyle: TextStyle(fontSize: 16, height: 1.6),
  ///   codeBlockDecoration: BoxDecoration(
  ///     color: Color(0xFF1E1E1E),
  ///     borderRadius: BorderRadius.circular(8),
  ///   ),
  /// );
  /// ```
  const MarkdownStyleSheet({
    this.textStyle,
    this.h1Style,
    this.h2Style,
    this.h3Style,
    this.h4Style,
    this.h5Style,
    this.h6Style,
    this.paragraphStyle,
    this.blockquoteStyle,
    this.codeBlockStyle,
    this.inlineCodeStyle,
    this.linkStyle,
    this.boldStyle,
    this.italicStyle,
    this.strikethroughStyle,
    this.underlineStyle,
    this.highlightStyle,
    this.kbdStyle,
    this.subscriptStyle,
    this.superscriptStyle,
    this.listBulletStyle,
    this.tableHeaderStyle,
    this.tableCellStyle,
    this.blockquoteDecoration,
    this.codeBlockDecoration,
    this.tableBorder,
    this.tableHeaderDecoration,
    this.tableOddRowDecoration,
    this.tableEvenRowDecoration,
    this.horizontalRuleColor,
    this.horizontalRuleThickness,
    this.blockSpacing,
    this.listIndent,
    this.blockquotePadding,
    this.codeBlockPadding,
    this.tableCellPadding,
  });

  /// Creates a clean, readable light theme style sheet.
  ///
  /// This is the default theme used when no stylesheet is provided. It features:
  /// - Black text on white background (black87 for body, black for headers)
  /// - Clear visual hierarchy with font sizes from 16px (body) to 32px (H1)
  /// - Subtle gray backgrounds for code blocks and blockquotes
  /// - Blue underlined links
  /// - Light gray borders and separators
  ///
  /// The [baseStyle] parameter allows you to override the base text style.
  /// All other styles will inherit from this base.
  ///
  /// Example:
  ///
  /// ```dart
  /// // Use default base style (16px, black87, line height 1.5)
  /// MarkdownStyleSheet.light()
  ///
  /// // Custom base style
  /// MarkdownStyleSheet.light(
  ///   baseStyle: TextStyle(
  ///     fontSize: 18,
  ///     fontFamily: 'Georgia',
  ///     color: Colors.black,
  ///   ),
  /// )
  /// ```
  factory MarkdownStyleSheet.light({TextStyle? baseStyle}) {
    final base = baseStyle ??
        const TextStyle(
          fontSize: 16,
          color: Colors.black87,
          height: 1.5,
        );

    return MarkdownStyleSheet(
      textStyle: base,
      h1Style: base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h2Style: base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      h3Style: base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h4Style: base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h5Style: base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h6Style: base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      paragraphStyle: base,
      blockquoteStyle: base.copyWith(
        color: Colors.black54,
        fontStyle: FontStyle.italic,
      ),
      codeBlockStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: Colors.black87,
      ),
      inlineCodeStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        backgroundColor: Colors.grey[200],
        color: Colors.red[700],
      ),
      linkStyle: base.copyWith(
        color: Colors.blue[700],
        decoration: TextDecoration.underline,
      ),
      boldStyle: base.copyWith(fontWeight: FontWeight.bold),
      italicStyle: base.copyWith(fontStyle: FontStyle.italic),
      strikethroughStyle: base.copyWith(
        decoration: TextDecoration.lineThrough,
      ),
      underlineStyle: base.copyWith(
        decoration: TextDecoration.underline,
      ),
      highlightStyle: base.copyWith(
        backgroundColor: const Color(0xFFFFF176),
        color: Colors.black87,
      ),
      kbdStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 13,
        color: Colors.black87,
      ),
      subscriptStyle: base.copyWith(
        fontSize: (base.fontSize ?? 16) * markdownSubSupFontScale,
      ),
      superscriptStyle: base.copyWith(
        fontSize: (base.fontSize ?? 16) * markdownSubSupFontScale,
      ),
      listBulletStyle: base,
      tableHeaderStyle: base.copyWith(fontWeight: FontWeight.bold),
      tableCellStyle: base,
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Colors.grey[400]!,
            width: 4,
          ),
        ),
        color: Colors.grey[50],
      ),
      codeBlockDecoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      tableBorder: TableBorder.all(
        color: Colors.grey[400]!,
        width: 1,
      ),
      tableHeaderDecoration: BoxDecoration(
        color: Colors.grey[200],
      ),
      tableOddRowDecoration: BoxDecoration(
        color: Colors.white,
      ),
      tableEvenRowDecoration: BoxDecoration(
        color: Colors.grey[50],
      ),
      horizontalRuleColor: Colors.grey[400],
      horizontalRuleThickness: 1,
      blockSpacing: 16,
      listIndent: 24,
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      codeBlockPadding: const EdgeInsets.all(12),
      tableCellPadding: const EdgeInsets.all(8),
    );
  }

  /// Creates a style sheet that adapts to Flutter's ThemeData.
  ///
  /// This factory automatically selects between light and dark themes based on
  /// the [theme]'s brightness setting, and uses the theme's text styles as the
  /// base. This is the recommended approach for apps that support both light
  /// and dark modes.
  ///
  /// The base text style is inherited from [theme.textTheme.bodyMedium].
  ///
  /// Example:
  ///
  /// ```dart
  /// // In your widget build method
  /// SmoothMarkdown(
  ///   data: markdownText,
  ///   styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
  /// )
  /// ```
  ///
  /// This approach ensures your markdown rendering respects the user's
  /// theme preferences and system dark mode settings.
  factory MarkdownStyleSheet.fromTheme(ThemeData theme) {
    final brightness = theme.brightness;
    final baseStyle = theme.textTheme.bodyMedium ?? const TextStyle();

    return brightness == Brightness.dark
        ? MarkdownStyleSheet.dark(baseStyle: baseStyle)
        : MarkdownStyleSheet.light(baseStyle: baseStyle);
  }

  /// Creates a style sheet based on brightness value.
  ///
  /// Similar to [fromTheme], but accepts a [Brightness] value directly.
  /// Useful when you want to create a theme based on a specific brightness
  /// setting without having a full ThemeData object.
  ///
  /// Parameters:
  /// - [brightness]: The brightness to use (Brightness.light or Brightness.dark)
  /// - [baseStyle]: Optional base text style to inherit from
  ///
  /// Example:
  ///
  /// ```dart
  /// // Create dark theme explicitly
  /// MarkdownStyleSheet.fromBrightness(
  ///   Brightness.dark,
  ///   baseStyle: TextStyle(fontFamily: 'Roboto'),
  /// )
  ///
  /// // Based on system setting
  /// MarkdownStyleSheet.fromBrightness(
  ///   MediaQuery.of(context).platformBrightness,
  /// )
  /// ```
  factory MarkdownStyleSheet.fromBrightness(
    Brightness brightness, {
    TextStyle? baseStyle,
  }) {
    return brightness == Brightness.dark
        ? MarkdownStyleSheet.dark(baseStyle: baseStyle)
        : MarkdownStyleSheet.light(baseStyle: baseStyle);
  }

  /// Creates a GitHub-style theme that mimics GitHub's markdown rendering.
  ///
  /// This theme closely matches the appearance of markdown on github.com,
  /// including:
  /// - GitHub's color palette (light: #24292F text, dark: #E6EDF3 text)
  /// - Rounded code block backgrounds
  /// - GitHub's link colors (light: #0969DA, dark: #58A6FF)
  /// - Familiar spacing and sizing
  ///
  /// Parameters:
  /// - [brightness]: Whether to use light or dark variant (defaults to light)
  ///
  /// Example:
  ///
  /// ```dart
  /// // GitHub light theme
  /// MarkdownStyleSheet.github()
  ///
  /// // GitHub dark theme
  /// MarkdownStyleSheet.github(brightness: Brightness.dark)
  /// ```
  ///
  /// Perfect for documentation apps, README viewers, or any app that wants
  /// to match GitHub's familiar markdown aesthetic.
  factory MarkdownStyleSheet.github(
      {Brightness brightness = Brightness.light}) {
    if (brightness == Brightness.dark) {
      return MarkdownStyleSheet.dark().copyWith(
        textStyle: const TextStyle(fontSize: 16, color: Color(0xFFE6EDF3)),
        codeBlockStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: Color(0xFFE6EDF3),
        ),
        codeBlockDecoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(6),
        ),
        linkStyle: const TextStyle(
          color: Color(0xFF58A6FF),
          decoration: TextDecoration.underline,
        ),
      );
    }

    return MarkdownStyleSheet.light().copyWith(
      textStyle: const TextStyle(fontSize: 16, color: Color(0xFF24292F)),
      codeBlockStyle: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: Color(0xFF24292F),
      ),
      codeBlockDecoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(6),
      ),
      linkStyle: const TextStyle(
        color: Color(0xFF0969DA),
        decoration: TextDecoration.underline,
      ),
    );
  }

  /// Creates a VS Code-style theme that mimics the VS Code editor.
  ///
  /// This theme replicates the appearance of markdown in Visual Studio Code,
  /// featuring:
  /// - VS Code's color scheme (light: #1E1E1E text, dark: #CCCCCC text)
  /// - Consolas font family (when available)
  /// - Dark borders and subtle backgrounds
  /// - VS Code's link colors
  ///
  /// Parameters:
  /// - [brightness]: Whether to use light or dark variant (defaults to light)
  ///
  /// Example:
  ///
  /// ```dart
  /// // VS Code light theme
  /// MarkdownStyleSheet.vscode()
  ///
  /// // VS Code dark theme
  /// MarkdownStyleSheet.vscode(brightness: Brightness.dark)
  /// ```
  ///
  /// Ideal for code-focused apps, developer tools, or editor-style interfaces.
  factory MarkdownStyleSheet.vscode(
      {Brightness brightness = Brightness.light}) {
    if (brightness == Brightness.dark) {
      return MarkdownStyleSheet.dark().copyWith(
        textStyle: const TextStyle(fontSize: 16, color: Color(0xFFCCCCCC)),
        codeBlockStyle: const TextStyle(
          fontFamily: 'Consolas',
          fontSize: 14,
          color: Color(0xFFD4D4D4),
        ),
        codeBlockDecoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF404040)),
        ),
        linkStyle: const TextStyle(
          color: Color(0xFF4FC1FF),
          decoration: TextDecoration.underline,
        ),
      );
    }

    return MarkdownStyleSheet.light().copyWith(
      textStyle: const TextStyle(fontSize: 16, color: Color(0xFF1E1E1E)),
      codeBlockStyle: const TextStyle(
        fontFamily: 'Consolas',
        fontSize: 14,
        color: Color(0xFF1E1E1E),
      ),
      codeBlockDecoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      linkStyle: const TextStyle(
        color: Color(0xFF0066BF),
        decoration: TextDecoration.underline,
      ),
    );
  }

  /// Creates a comfortable dark theme style sheet for dark mode apps.
  ///
  /// This theme features:
  /// - White text (white70 for body, white for headers) on dark backgrounds
  /// - Dark gray backgrounds for code blocks and blockquotes
  /// - Muted colors to reduce eye strain
  /// - Light blue links for visibility
  /// - High contrast for readability in low-light conditions
  ///
  /// The [baseStyle] parameter allows you to override the base text style.
  ///
  /// Example:
  ///
  /// ```dart
  /// // Use default dark theme
  /// MarkdownStyleSheet.dark()
  ///
  /// // Custom base style
  /// MarkdownStyleSheet.dark(
  ///   baseStyle: TextStyle(
  ///     fontSize: 18,
  ///     fontFamily: 'Roboto',
  ///   ),
  /// )
  /// ```
  factory MarkdownStyleSheet.dark({TextStyle? baseStyle}) {
    final base = baseStyle ??
        const TextStyle(
          fontSize: 16,
          color: Colors.white70,
          height: 1.5,
        );

    return MarkdownStyleSheet(
      textStyle: base,
      h1Style: base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.3,
        color: Colors.white,
      ),
      h2Style: base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.3,
        color: Colors.white,
      ),
      h3Style: base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.4,
        color: Colors.white,
      ),
      h4Style: base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.4,
        color: Colors.white,
      ),
      h5Style: base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        height: 1.4,
        color: Colors.white,
      ),
      h6Style: base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        height: 1.4,
        color: Colors.white,
      ),
      paragraphStyle: base,
      blockquoteStyle: base.copyWith(
        color: Colors.white60,
        fontStyle: FontStyle.italic,
      ),
      codeBlockStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        color: Colors.white70,
      ),
      inlineCodeStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
        backgroundColor: Colors.grey[800],
        color: Colors.red[300],
      ),
      linkStyle: base.copyWith(
        color: Colors.blue[300],
        decoration: TextDecoration.underline,
      ),
      boldStyle: base.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      italicStyle: base.copyWith(fontStyle: FontStyle.italic),
      strikethroughStyle: base.copyWith(
        decoration: TextDecoration.lineThrough,
      ),
      underlineStyle: base.copyWith(
        decoration: TextDecoration.underline,
      ),
      highlightStyle: base.copyWith(
        backgroundColor: const Color(0xFF4D4400),
      ),
      kbdStyle: base.copyWith(
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      subscriptStyle: base.copyWith(
        fontSize: (base.fontSize ?? 16) * markdownSubSupFontScale,
      ),
      superscriptStyle: base.copyWith(
        fontSize: (base.fontSize ?? 16) * markdownSubSupFontScale,
      ),
      listBulletStyle: base,
      tableHeaderStyle: base.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      tableCellStyle: base,
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Colors.grey[600]!,
            width: 4,
          ),
        ),
        color: Colors.grey[900],
      ),
      codeBlockDecoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[700]!),
      ),
      tableBorder: TableBorder.all(
        color: Colors.grey[700]!,
        width: 1,
      ),
      tableHeaderDecoration: BoxDecoration(
        color: Colors.grey[850],
      ),
      tableOddRowDecoration: BoxDecoration(
        color: Colors.grey[900],
      ),
      tableEvenRowDecoration: BoxDecoration(
        color: Colors.grey[800],
      ),
      horizontalRuleColor: Colors.grey[700],
      horizontalRuleThickness: 1,
      blockSpacing: 16,
      listIndent: 24,
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      codeBlockPadding: const EdgeInsets.all(12),
      tableCellPadding: const EdgeInsets.all(8),
    );
  }

  /// Default text style
  final TextStyle? textStyle;

  /// H1 heading style
  final TextStyle? h1Style;

  /// H2 heading style
  final TextStyle? h2Style;

  /// H3 heading style
  final TextStyle? h3Style;

  /// H4 heading style
  final TextStyle? h4Style;

  /// H5 heading style
  final TextStyle? h5Style;

  /// H6 heading style
  final TextStyle? h6Style;

  /// Paragraph style
  final TextStyle? paragraphStyle;

  /// Blockquote text style
  final TextStyle? blockquoteStyle;

  /// Code block text style
  final TextStyle? codeBlockStyle;

  /// Inline code style
  final TextStyle? inlineCodeStyle;

  /// Link style
  final TextStyle? linkStyle;

  /// Bold text style
  final TextStyle? boldStyle;

  /// Italic text style
  final TextStyle? italicStyle;

  /// Strikethrough text style
  final TextStyle? strikethroughStyle;

  /// Style for underlined text from HTML `<u>`/`<ins>` tags
  final TextStyle? underlineStyle;

  /// Style for highlighted text from the HTML `<mark>` tag
  final TextStyle? highlightStyle;

  /// Style for keyboard input from the HTML `<kbd>` tag
  final TextStyle? kbdStyle;

  /// Style for subscript text from the HTML `<sub>` tag
  final TextStyle? subscriptStyle;

  /// Style for superscript text from the HTML `<sup>` tag
  final TextStyle? superscriptStyle;

  /// List bullet style
  final TextStyle? listBulletStyle;

  /// Table header style
  final TextStyle? tableHeaderStyle;

  /// Table cell style
  final TextStyle? tableCellStyle;

  /// Decoration for blockquotes
  final BoxDecoration? blockquoteDecoration;

  /// Decoration for code blocks
  final BoxDecoration? codeBlockDecoration;

  /// Border for tables
  final TableBorder? tableBorder;

  /// Decoration for table header row
  final BoxDecoration? tableHeaderDecoration;

  /// Decoration for odd table rows
  final BoxDecoration? tableOddRowDecoration;

  /// Decoration for even table rows
  final BoxDecoration? tableEvenRowDecoration;

  /// Color for horizontal rules
  final Color? horizontalRuleColor;

  /// Thickness of horizontal rules
  final double? horizontalRuleThickness;

  /// Spacing between block elements
  final double? blockSpacing;

  /// Indentation for lists
  final double? listIndent;

  /// Padding for blockquotes
  final EdgeInsets? blockquotePadding;

  /// Padding for code blocks
  final EdgeInsets? codeBlockPadding;

  /// Padding for table cells
  final EdgeInsets? tableCellPadding;

  /// Creates a copy of this style sheet with the given fields replaced
  MarkdownStyleSheet copyWith({
    TextStyle? textStyle,
    TextStyle? h1Style,
    TextStyle? h2Style,
    TextStyle? h3Style,
    TextStyle? h4Style,
    TextStyle? h5Style,
    TextStyle? h6Style,
    TextStyle? paragraphStyle,
    TextStyle? blockquoteStyle,
    TextStyle? codeBlockStyle,
    TextStyle? inlineCodeStyle,
    TextStyle? linkStyle,
    TextStyle? boldStyle,
    TextStyle? italicStyle,
    TextStyle? strikethroughStyle,
    TextStyle? underlineStyle,
    TextStyle? highlightStyle,
    TextStyle? kbdStyle,
    TextStyle? subscriptStyle,
    TextStyle? superscriptStyle,
    TextStyle? listBulletStyle,
    TextStyle? tableHeaderStyle,
    TextStyle? tableCellStyle,
    BoxDecoration? blockquoteDecoration,
    BoxDecoration? codeBlockDecoration,
    TableBorder? tableBorder,
    BoxDecoration? tableHeaderDecoration,
    BoxDecoration? tableOddRowDecoration,
    BoxDecoration? tableEvenRowDecoration,
    Color? horizontalRuleColor,
    double? horizontalRuleThickness,
    double? blockSpacing,
    double? listIndent,
    EdgeInsets? blockquotePadding,
    EdgeInsets? codeBlockPadding,
    EdgeInsets? tableCellPadding,
  }) {
    return MarkdownStyleSheet(
      textStyle: textStyle ?? this.textStyle,
      h1Style: h1Style ?? this.h1Style,
      h2Style: h2Style ?? this.h2Style,
      h3Style: h3Style ?? this.h3Style,
      h4Style: h4Style ?? this.h4Style,
      h5Style: h5Style ?? this.h5Style,
      h6Style: h6Style ?? this.h6Style,
      paragraphStyle: paragraphStyle ?? this.paragraphStyle,
      blockquoteStyle: blockquoteStyle ?? this.blockquoteStyle,
      codeBlockStyle: codeBlockStyle ?? this.codeBlockStyle,
      inlineCodeStyle: inlineCodeStyle ?? this.inlineCodeStyle,
      linkStyle: linkStyle ?? this.linkStyle,
      boldStyle: boldStyle ?? this.boldStyle,
      italicStyle: italicStyle ?? this.italicStyle,
      strikethroughStyle: strikethroughStyle ?? this.strikethroughStyle,
      underlineStyle: underlineStyle ?? this.underlineStyle,
      highlightStyle: highlightStyle ?? this.highlightStyle,
      kbdStyle: kbdStyle ?? this.kbdStyle,
      subscriptStyle: subscriptStyle ?? this.subscriptStyle,
      superscriptStyle: superscriptStyle ?? this.superscriptStyle,
      listBulletStyle: listBulletStyle ?? this.listBulletStyle,
      tableHeaderStyle: tableHeaderStyle ?? this.tableHeaderStyle,
      tableCellStyle: tableCellStyle ?? this.tableCellStyle,
      blockquoteDecoration: blockquoteDecoration ?? this.blockquoteDecoration,
      codeBlockDecoration: codeBlockDecoration ?? this.codeBlockDecoration,
      tableBorder: tableBorder ?? this.tableBorder,
      tableHeaderDecoration:
          tableHeaderDecoration ?? this.tableHeaderDecoration,
      tableOddRowDecoration:
          tableOddRowDecoration ?? this.tableOddRowDecoration,
      tableEvenRowDecoration:
          tableEvenRowDecoration ?? this.tableEvenRowDecoration,
      horizontalRuleColor: horizontalRuleColor ?? this.horizontalRuleColor,
      horizontalRuleThickness:
          horizontalRuleThickness ?? this.horizontalRuleThickness,
      blockSpacing: blockSpacing ?? this.blockSpacing,
      listIndent: listIndent ?? this.listIndent,
      blockquotePadding: blockquotePadding ?? this.blockquotePadding,
      codeBlockPadding: codeBlockPadding ?? this.codeBlockPadding,
      tableCellPadding: tableCellPadding ?? this.tableCellPadding,
    );
  }
}

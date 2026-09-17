import 'markdown_node.dart';

/// Horizontal alignment for HTML block elements
///
/// Parsed from the `align` attribute of HTML block tags such as
/// `<div align="center">` or implied by the tag itself (`<center>`).
enum HtmlBlockAlignment {
  /// Left-aligned content
  left,

  /// Center-aligned content
  center,

  /// Right-aligned content
  right,
}

/// Represents underlined text from HTML `<u>` or `<ins>` tags
class UnderlineNode extends MarkdownNode {
  /// Creates a new underline node
  const UnderlineNode(this.children);

  /// The child nodes
  final List<MarkdownNode> children;

  @override
  String get type => 'underline';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'children': children.map((child) => child.toJson()).toList(),
      };

  @override
  UnderlineNode copyWith({List<MarkdownNode>? children}) {
    return UnderlineNode(children ?? this.children);
  }

  @override
  String toString() => 'UnderlineNode(children: ${children.length})';
}

/// Represents highlighted text from the HTML `<mark>` tag
class HighlightNode extends MarkdownNode {
  /// Creates a new highlight node
  const HighlightNode(this.children);

  /// The child nodes
  final List<MarkdownNode> children;

  @override
  String get type => 'highlight';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'children': children.map((child) => child.toJson()).toList(),
      };

  @override
  HighlightNode copyWith({List<MarkdownNode>? children}) {
    return HighlightNode(children ?? this.children);
  }

  @override
  String toString() => 'HighlightNode(children: ${children.length})';
}

/// Represents subscript text from the HTML `<sub>` tag
class SubscriptNode extends MarkdownNode {
  /// Creates a new subscript node
  const SubscriptNode(this.children);

  /// The child nodes
  final List<MarkdownNode> children;

  @override
  String get type => 'subscript';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'children': children.map((child) => child.toJson()).toList(),
      };

  @override
  SubscriptNode copyWith({List<MarkdownNode>? children}) {
    return SubscriptNode(children ?? this.children);
  }

  @override
  String toString() => 'SubscriptNode(children: ${children.length})';
}

/// Represents superscript text from the HTML `<sup>` tag
class SuperscriptNode extends MarkdownNode {
  /// Creates a new superscript node
  const SuperscriptNode(this.children);

  /// The child nodes
  final List<MarkdownNode> children;

  @override
  String get type => 'superscript';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'children': children.map((child) => child.toJson()).toList(),
      };

  @override
  SuperscriptNode copyWith({List<MarkdownNode>? children}) {
    return SuperscriptNode(children ?? this.children);
  }

  @override
  String toString() => 'SuperscriptNode(children: ${children.length})';
}

/// Represents keyboard input from the HTML `<kbd>` tag
class KbdNode extends MarkdownNode {
  /// Creates a new keyboard input node
  const KbdNode(this.children);

  /// The child nodes
  final List<MarkdownNode> children;

  @override
  String get type => 'kbd';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'children': children.map((child) => child.toJson()).toList(),
      };

  @override
  KbdNode copyWith({List<MarkdownNode>? children}) {
    return KbdNode(children ?? this.children);
  }

  @override
  String toString() => 'KbdNode(children: ${children.length})';
}

/// Represents styled inline text from HTML `<font>` or `<span style>` tags
///
/// Only a safe subset of styling is supported: text color, background
/// color, and font size. Colors are stored as ARGB integers so the AST
/// stays free of Flutter imports.
class StyledSpanNode extends MarkdownNode {
  /// Creates a new styled span node
  const StyledSpanNode({
    required this.children,
    this.color,
    this.backgroundColor,
    this.fontSize,
  });

  /// The child nodes
  final List<MarkdownNode> children;

  /// The text color as an ARGB integer, if specified
  final int? color;

  /// The background color as an ARGB integer, if specified
  final int? backgroundColor;

  /// The font size in logical pixels, if specified
  final double? fontSize;

  @override
  String get type => 'styled_span';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'children': children.map((child) => child.toJson()).toList(),
        if (color != null) 'color': color,
        if (backgroundColor != null) 'backgroundColor': backgroundColor,
        if (fontSize != null) 'fontSize': fontSize,
      };

  @override
  StyledSpanNode copyWith({
    List<MarkdownNode>? children,
    int? color,
    int? backgroundColor,
    double? fontSize,
  }) {
    return StyledSpanNode(
      children: children ?? this.children,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  @override
  String toString() => 'StyledSpanNode(children: ${children.length}, '
      'color: $color, backgroundColor: $backgroundColor, '
      'fontSize: $fontSize)';
}

/// Represents an HTML block element (`<div>`, `<p>`, or `<center>`)
///
/// Block children are parsed as regular markdown, so HTML blocks can
/// contain headers, lists, code blocks, and other block-level content.
class HtmlBlockNode extends MarkdownNode {
  /// Creates a new HTML block node
  const HtmlBlockNode({
    required this.tag,
    required this.children,
    this.align,
  });

  /// The lowercased HTML tag name (`div`, `p`, or `center`)
  final String tag;

  /// The block-level child nodes
  final List<MarkdownNode> children;

  /// Optional horizontal alignment from the `align` attribute
  final HtmlBlockAlignment? align;

  @override
  String get type => 'html_block';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'tag': tag,
        'children': children.map((child) => child.toJson()).toList(),
        if (align != null) 'align': align!.name,
      };

  @override
  HtmlBlockNode copyWith({
    String? tag,
    List<MarkdownNode>? children,
    HtmlBlockAlignment? align,
  }) {
    return HtmlBlockNode(
      tag: tag ?? this.tag,
      children: children ?? this.children,
      align: align ?? this.align,
    );
  }

  @override
  String toString() => 'HtmlBlockNode(tag: $tag, '
      'children: ${children.length}, align: $align)';
}

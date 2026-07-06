/// Editing commands supported by the Markdown editor.
///
/// Commands are semantic editor intents. Source-based controllers can translate
/// them to Markdown marker edits; document-model editors can translate them to
/// node and mark transactions.
enum MarkdownEditorCommand {
  /// Convert selected lines to plain paragraph text.
  paragraph,

  /// Wrap selection with `**` or apply a strong mark.
  bold,

  /// Wrap selection with `*` or apply an emphasis mark.
  italic,

  /// Wrap selection with `~~` or apply a strikethrough mark.
  strikethrough,

  /// Wrap selection with backticks or apply inline code.
  inlineCode,

  /// Convert selected lines to a level-one heading.
  heading1,

  /// Convert selected lines to a level-two heading.
  heading2,

  /// Convert selected lines to a level-three heading.
  heading3,

  /// Convert selected lines to a level-four heading.
  heading4,

  /// Convert selected lines to a level-five heading.
  heading5,

  /// Convert selected lines to a level-six heading.
  heading6,

  /// Prefix selected lines with `- `.
  unorderedList,

  /// Prefix selected lines with numbered list markers.
  orderedList,

  /// Prefix selected lines with unchecked task list markers.
  taskList,

  /// Prefix selected lines with blockquote markers.
  blockquote,

  /// Wrap selection in a fenced code block.
  codeBlock,

  /// Wrap or insert a Markdown link.
  link,

  /// Insert a Markdown image.
  image,

  /// Insert a Markdown table.
  table,

  /// Wrap selection in a display math block.
  blockMath,

  /// Insert a Mermaid fenced code block.
  mermaidDiagram,

  /// Insert a horizontal rule.
  horizontalRule,

  /// Wrap or insert a `[[wikilink]]`.
  wikilink,
}

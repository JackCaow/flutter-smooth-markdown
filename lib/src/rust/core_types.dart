import '../parser/ast/markdown_node.dart';

/// Maximum UTF-16 code units in one native ABI source argument (MAX_UNITS).
const maxNativeSourceUnits = 8 * 1024 * 1024;

/// Semantic token classes shared with the Android and iOS core APIs.
///
/// Offsets always count UTF-16 code units, as Dart's String does. Names are the
/// public contract; wire numeric identifiers remain an internal detail.
enum MarkdownHighlightKind {
  none,
  attribute,
  boolean,
  comment,
  commentDoc,
  constant,
  constantBuiltin,
  constructor,
  diffMinus,
  diffPlus,
  embedded,
  emphasis,
  emphasisStrong,
  function,
  functionDefinition,
  functionMethod,
  keyword,
  keywordControl,
  keywordDeclaration,
  keywordImport,
  keywordOperator,
  label,
  namespace,
  number,
  operator,
  preproc,
  property,
  propertyKey,
  punctuation,
  punctuationBracket,
  punctuationDelimiter,
  punctuationListMarker,
  punctuationSpecial,
  selector,
  selectorClass,
  selectorId,
  selectorPseudo,
  string,
  stringEscape,
  stringRegex,
  stringSpecial,
  tag,
  tagDoctype,
  tagComponent,
  textLiteral,
  title,
  type,
  typeBuiltin,
  variable,
  variableParameter,
  variableSpecial,
  linkText,
  linkUri,
}

/// One non-overlapping range of highlighted source text.
class MarkdownHighlightToken {
  /// Creates a UTF-16 token range.
  const MarkdownHighlightToken({
    required this.start,
    required this.length,
    required this.kind,
  });

  /// Offset in the original source (or the display line for line APIs).
  final int start;

  /// Length in UTF-16 code units.
  final int length;

  /// Semantic style classification.
  final MarkdownHighlightKind kind;

  /// Exclusive end of this range.
  int get end => start + length;
}

/// One display line; tokens refer to [text], after tab expansion.
class MarkdownHighlightedLine {
  /// Creates a line from a whole-file highlighting pass.
  const MarkdownHighlightedLine({required this.text, required this.tokens});

  /// Line content without its line ending.
  final String text;

  /// Sorted non-overlapping token ranges, relative to [text].
  final List<MarkdownHighlightToken> tokens;
}

/// The role of a unified-diff display row.
enum MarkdownDiffKind { hunk, context, added, removed, note }

/// A unified-diff row, with original/new line numbers and an optional change.
class MarkdownDiffRow {
  /// Creates a display row.
  const MarkdownDiffRow({
    required this.kind,
    required this.line,
    this.oldLineNumber,
    this.newLineNumber,
    this.changedStart,
    this.changedLength,
  });

  /// Hunk, context, added, removed, or informational note.
  final MarkdownDiffKind kind;

  /// Highlighted display content without the diff prefix.
  final MarkdownHighlightedLine line;

  /// Primary line number, matching native readers (old for removed rows).
  int? get lineNumber =>
      kind == MarkdownDiffKind.removed ? oldLineNumber : newLineNumber;

  /// Old-file line number, when this row belongs to the old file.
  final int? oldLineNumber;

  /// New-file line number, when this row belongs to the new file.
  final int? newLineNumber;

  /// UTF-16 start of the differing middle in a paired changed line.
  final int? changedStart;

  /// UTF-16 length of the differing middle.
  final int? changedLength;
}

/// Explicit native core failure; never silently treated as a successful parse.
class MarkdownCoreException implements Exception {
  /// Creates an error carrying the C ABI status and operation.
  const MarkdownCoreException(this.operation, this.status);

  /// The failed operation.
  final String operation;

  /// Invalid input=1, limit=2, internal error=3, host callback error=4.
  final int status;
  @override
  String toString() => 'MarkdownCoreException($operation, status: $status)';
}

/// Internal lifetime boundary for a single-owner incremental session.
abstract class CoreStream {
  /// Parses a complete current prefix, retaining committed blocks.
  List<MarkdownNode> update(String source);

  /// Releases session state and any native resources. Idempotent.
  void dispose();
}

/// Internal capability: Flutter node count retained by the latest update.
/// Native block groups can project into zero or several Flutter nodes.
abstract interface class RetainedCoreStream implements CoreStream {
  int get retainedNodeCount;
}

import '../editor/markdown_editor_export.dart';
import 'core_types.dart';
import 'platform.dart' as platform;
import 'syntax_fallback.dart';

export 'core_types.dart'
    show
        MarkdownHighlightKind,
        MarkdownHighlightToken,
        MarkdownHighlightedLine,
        MarkdownDiffKind,
        MarkdownDiffRow,
        MarkdownCoreException;

/// Stable entry point for shared-core services. No wire IDs or native pointers
/// appear in this API. Native names match the Android and iOS highlighting APIs.
abstract final class MarkdownCore {
  /// Whether this target uses the shared Rust engine (false on Web).
  static bool get isNative => platform.nativeAvailable;

  /// CommonMark/GFM HTML export. Raw HTML is escaped by default.
  /// The editor's existing copy/export helper keeps its compatibility contract.
  static String exportHtml(String source, {bool escapeHtml = true}) =>
      platform.exportNativeHtml(source, escapeHtml: escapeHtml) ??
      markdownToHtml(source);

  /// Canonical language name, or an empty string for an unsupported language.
  static String normalizedCodeLanguage(String language) =>
      platform.normalizedNativeLanguage(language) ?? fallbackLanguage(language);

  /// Whole-input semantic tokens in original UTF-16 coordinates.
  static List<MarkdownHighlightToken> highlightedCode(
    String source, {
    required String language,
  }) =>
      platform.nativeHighlightedCode(source, language) ??
      fallbackCode(source, language);

  /// Highlights once, then splits into display lines with expanded tabs.
  static List<MarkdownHighlightedLine> highlightedLines(
    String source, {
    required String language,
    int tabWidth = 4,
  }) =>
      platform.nativeHighlightedLines(source, language, tabWidth) ??
      fallbackLines(source, language, tabWidth);

  /// Unified diff rows, per-side syntax highlighting and paired word changes.
  static List<MarkdownDiffRow> highlightedDiff(
    String patch, {
    required String language,
    int tabWidth = 4,
  }) =>
      platform.nativeHighlightedDiff(patch, language, tabWidth) ??
      fallbackDiff(patch, language, tabWidth);
}

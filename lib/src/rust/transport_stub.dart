import '../parser/ast/markdown_node.dart';
import '../parser/parser_plugin.dart';
import 'core_types.dart';

bool get nativeAvailable => false;
List<MarkdownNode>? parseNative(
  String source, {
  ParserPluginRegistry? plugins,
  bool inline = false,
}) => null;
String? exportNativeHtml(String source, {bool escapeHtml = true}) => null;
String? normalizedNativeLanguage(String language) => null;
List<MarkdownHighlightToken>? nativeHighlightedCode(
  String source,
  String language,
) => null;
List<MarkdownHighlightedLine>? nativeHighlightedLines(
  String source,
  String language,
  int tabWidth,
) => null;
List<MarkdownDiffRow>? nativeHighlightedDiff(
  String source,
  String language,
  int tabWidth,
) => null;
CoreStream? createNativeStream() => null;

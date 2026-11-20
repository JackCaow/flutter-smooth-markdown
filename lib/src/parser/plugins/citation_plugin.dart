import '../ast/markdown_node.dart';
import '../parser_plugin.dart';

/// A numbered inline citation in a generated answer, such as `[1]`.
class MarkdownCitationNode extends MarkdownNode {
  const MarkdownCitationNode(this.number);

  final int number;

  @override
  String get type => 'citation';

  @override
  Map<String, dynamic> toJson() => {'type': type, 'number': number};

  @override
  MarkdownCitationNode copyWith() => this;
}

/// Recognizes standalone positive source numbers. Markdown links, images,
/// reference labels, escapes, code and footnotes keep their grammar.
class MarkdownCitationPlugin extends InlineParserPlugin {
  const MarkdownCitationPlugin();

  static final _marker = RegExp(r'\[([1-9][0-9]*)\]');

  @override
  String get id => 'citation';
  @override
  String get name => 'Numbered source citations';
  @override
  String get triggerCharacter => '[';

  @override
  bool canParse(String text, int index) =>
      index + 2 < text.length &&
      text[index] == '[' &&
      (index == 0 || (text[index - 1] != '!' && text[index - 1] != ']'));

  @override
  InlineParseResult? parse(String text, int startIndex) {
    final match = _marker.matchAsPrefix(text, startIndex);
    if (match == null) return null;
    if (match.end < text.length && '([:'.contains(text[match.end])) return null;
    final number = int.tryParse(match[1]!);
    if (number == null) return null;
    return InlineParseResult(
      node: MarkdownCitationNode(number),
      consumed: match.end - startIndex,
    );
  }
}

/// Only this stateless inline plugin is eligible for retained citation parsing.
bool isCitationStreamRegistry(ParserPluginRegistry? registry) =>
    registry != null &&
    registry.runtimeType == ParserPluginRegistry &&
    registry.blockPlugins.isEmpty &&
    registry.inlinePlugins.length == 1 &&
    registry.inlinePlugins.single.runtimeType == MarkdownCitationPlugin;

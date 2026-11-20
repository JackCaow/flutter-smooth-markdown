import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/rust/platform.dart' as core;
import 'package:flutter_smooth_markdown/src/rust/stream_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ai = ParserPluginRegistry()
    ..register(const ThinkingPlugin())
    ..register(const ArtifactPlugin())
    ..register(const ToolCallPlugin());
  test(
    'real AI registry, valid tables, comparisons and code pipes can be incremental',
    () {
      const source =
          '# 中文🙂\n\nA < B and T<U>.\n\n'
          '```dart\na | b\n```\n\n| A | B |\n| -- | -- |\n| one | two |\n\ntail';
      expect(canParseIncrementally(source, ai), isTrue);
      final stream = core.createNativeStream()!;
      try {
        for (var i = 0; i <= source.length; i++) {
          final prefix = source.substring(0, i);
          if (!canParseIncrementally(prefix, ai)) continue;
          expect(
            stream.update(prefix).map((n) => n.toJson()).toList(),
            MarkdownParser(
              plugins: ai,
            ).parse(prefix).map((n) => n.toJson()).toList(),
            reason: 'prefix $i',
          );
        }
      } finally {
        stream.dispose();
      }
    },
  );
  test(
    'active extensions, ragged tables, disclosures and unknown plugins keep batch behavior',
    () {
      for (final text in [
        '<think>\nreason',
        '<|thinking|>\nreason',
        '<artifact id="a">\nx',
        '<tool_use>\nx',
      ]) {
        expect(canParseIncrementally(text, ai), isFalse);
      }
      expect(canParseIncrementally('| a | b |\n| --- |', ai), isFalse);
      expect(canParseIncrementally('<DETAILS>body', ai), isFalse);
      expect(
        canParseIncrementally(
          'plain',
          ParserPluginRegistry()..register(const _Unknown()),
        ),
        isFalse,
      );
      final mentions = ParserPluginRegistry()..register(const MentionPlugin());
      expect(canParseIncrementally('plain', mentions), isTrue);
      expect(canParseIncrementally('hello @name', mentions), isFalse);
    },
  );
}

class _Unknown extends InlineParserPlugin {
  const _Unknown();
  @override
  String get id => 'unknown';
  @override
  String get name => 'Unknown';
  @override
  String get triggerCharacter => '@';
  @override
  bool canParse(String text, int index) => true;
  @override
  InlineParseResult? parse(String text, int startIndex) => null;
}

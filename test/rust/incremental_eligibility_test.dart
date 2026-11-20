import 'dart:math';

import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/rust/stream_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

void _checkChunks(Iterable<String> chunks, ParserPluginRegistry? registry) {
  final eligibility = StreamEligibility();
  final buffer = StringBuffer();
  for (final chunk in chunks) {
    buffer.write(chunk);
    final prefix = buffer.toString();
    expect(
      eligibility.checkAppend(prefix, registry),
      canParseIncrementally(prefix, registry),
      reason: 'prefix ${prefix.codeUnits}, appended ${chunk.codeUnits}',
    );
  }
}

void main() {
  test('every split and every UTF-16 prefix agrees on built-in markers', () {
    for (final (plugin, token, mustFallback) in <(ParserPlugin?, String, bool)>[
      (null, '<DeTaIlS', true),
      (const ThinkingPlugin(), '<|THiNk', true),
      (const ThinkingPlugin(), '<ThinK', true),
      (const ThinkingPlugin(), '<THİNK', '<THİNK'.toLowerCase() == '<think'),
      (const ArtifactPlugin(), '<ARTIFACT', true),
      (const ToolCallPlugin(), '<tOOl_uSE', true),
      (const MermaidPlugin(), '```mermaid', true),
      (const MermaidPlugin(), '~~~mermaid', true),
      (const MermaidPlugin(), '```Mermaid', false),
      (const AdmonitionPlugin(), ':::', true),
      (const EmojiPlugin(), ':hello:', true),
      (const HashtagPlugin(), '#hello', true),
      (const MentionPlugin(), '@hello', true),
      (const ThinkingPlugin(), '<thin', false),
      (const ToolCallPlugin(), '<tool-use', false),
      (null, '<think', false),
    ]) {
      final registry = plugin == null
          ? null
          : (ParserPluginRegistry()..register(plugin));
      final text =
          'a paragraph already published before this marker 中文🙂 İ $token';
      expect(
        canParseIncrementally(text, registry),
        !mustFallback,
        reason: text,
      );
      for (var split = 0; split <= text.length; split++) {
        _checkChunks([
          text.substring(0, split),
          text.substring(split),
          ' tail',
        ], registry);
      }
      _checkChunks(text.codeUnits.map(String.fromCharCode), registry);
    }
  });

  test('escaped header pipes do not add table columns at any chunk split', () {
    const odd =
        r'| A \| B | C |'
        '\n| --- | --- | --- |\n| 1 | 2 |';
    const even =
        r'| A \\| B | C |'
        '\n| --- | --- | --- |\n| 1 | 2 |';
    for (final (source, eligible) in [(odd, false), (even, true)]) {
      expect(canParseIncrementally(source, null), eligible);
      for (var i = 0; i <= source.length; i++) {
        final gate = StreamEligibility();
        gate.checkAppend(source.substring(0, i), null);
        expect(gate.checkAppend(source, null), eligible);
      }
    }
  });

  test('open table delimiters may change the decision until the newline', () {
    final gate = StreamEligibility();
    final buffer = StringBuffer();
    for (final (chunk, eligible) in [
      ('before\n\na | b\r', true),
      ('\n| :', true),
      ('-', false), // One delimiter cell for a two-cell header.
      (': |', false),
      (' -', true), // Completing the second cell restores eligibility.
      (' | -', false),
      (' prose', true), // The same line is now ordinary text.
      ('\n\n| c | d |\n---', false),
      ('\r', false),
      // The mismatched line is complete and stays in the document.
      ('\n', false),
      ('after\n\n| e | f |\n| --- | --- |', false),
    ]) {
      buffer.write(chunk);
      final prefix = buffer.toString();
      expect(canParseIncrementally(prefix, null), eligible);
      expect(gate.checkAppend(prefix, null), eligible, reason: prefix);
    }
    gate.reset();
    expect(gate.checkAppend('new | source\n| --- | --- |', null), isTrue);

    final prefill =
        '| left | right |\n| --- | --- |\n| value | value |\n\n' * 64;
    for (final openTail in [
      '| a | b |\n| --- |',
      '| a | b |\n| --- |\n',
      '| a | b |\n| --- | --- |',
      '| a | b |\r',
    ]) {
      _checkChunks([prefill + openTail, ' --- |', '\n', '---', '\nend'], null);
    }
  });

  test(
    'table and marker decisions agree for multiline and generated chunks',
    () {
      const rows = [
        '|',
        '||',
        '| A | B |',
        '| A |',
        r'a \| b',
        '| - : |',
        '|:--|',
        '---',
        ':---:',
        '| --- | --- |',
        '| --- | :--: | --- |',
        ' |  ',
        '\u0085|\u0085',
        '\u0085-\u0085',
        '\ufeff | --- |\u3000',
        'a\t|b',
        '-\u2028|\u00a0-',
        '\u000b-',
        '```',
        '~~~merma',
        'id',
        '<d',
        'etails',
        '🙂',
        'ordinary',
        '',
      ];
      final plugins = ParserPluginRegistry()..register(const MermaidPlugin());
      final random = Random(405);
      for (var i = 0; i < 600; i++) {
        final source = List.generate(
          8,
          (_) => rows[random.nextInt(rows.length)],
        ).join(i.isEven ? '\n' : '\r\n');
        final chunks = <String>[];
        for (var start = 0; start < source.length;) {
          final end = min(source.length, start + 1 + random.nextInt(13));
          chunks.add(source.substring(start, end));
          start = end;
        }
        _checkChunks(chunks, plugins);
      }
    },
  );

  test('subclassed registry getters keep full-scan short circuit behavior', () {
    final gate = StreamEligibility();
    final registry = _ObservedRegistry()..register(const ThinkingPlugin());
    for (final source in [
      'plain',
      'plain <think',
      'plain <think\n| a | b |\n---',
    ]) {
      registry.calls.clear();
      final oldDecision = canParseIncrementally(source, registry);
      final oldCalls = registry.calls.toList();
      registry.calls.clear();
      expect(gate.checkAppend(source, registry), oldDecision);
      expect(registry.calls, oldCalls);
    }
  });

  test('registry mutations recheck prior text even without a new chunk', () {
    final gate = StreamEligibility();
    final registry = ParserPluginRegistry();
    var text = 'old @mentions and <tHiNk> and ```mermaid';
    void check(ParserPluginRegistry? plugins, bool eligible) {
      expect(canParseIncrementally(text, plugins), eligible);
      expect(gate.checkAppend(text, plugins), eligible);
    }

    check(null, true);
    check(registry, true);
    registry.register(const MentionPlugin());
    check(registry, false);
    registry.clear();
    check(registry, true);
    registry.register(const ThinkingPlugin());
    check(registry, false);
    text += ' tail';
    check(registry, false);
    registry
      ..unregisterBlock('thinking')
      ..register(const ArtifactPlugin());
    check(registry, true);
    check(ParserPluginRegistry()..register(const MermaidPlugin()), false);
    check(ParserPluginRegistry()..register(const _CustomThinking()), false);
    check(ParserPluginRegistry()..register(const _CustomMention()), false);
    check(null, true);

    gate.reset();
    text = 'plain replacement';
    check(ParserPluginRegistry()..register(const _CustomThinking()), false);
    check(ParserPluginRegistry()..register(const _CustomMention()), false);
    check(registry, true);
    text += '<arti';
    check(registry, true);
    text += 'fact';
    check(registry, false);
  });
}

class _CustomThinking extends ThinkingPlugin {
  const _CustomThinking();
}

class _CustomMention extends MentionPlugin {
  const _CustomMention();
}

class _ObservedRegistry extends ParserPluginRegistry {
  final calls = <String>[];

  @override
  List<BlockParserPlugin> get blockPlugins {
    calls.add('block');
    return super.blockPlugins;
  }

  @override
  List<InlineParserPlugin> get inlinePlugins {
    calls.add('inline');
    return super.inlinePlugins;
  }
}

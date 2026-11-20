import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_smooth_markdown/src/parser/parser_compatibility.dart';
import 'package:flutter_test/flutter_test.dart';

// Independent reference for the previously shipped compatibility decision.
bool previousTableDecision(String source) {
  if (!source.contains('|')) return false;
  final lines = source.split('\n');
  final delimiter = RegExp(r'^\s*\|?\s*:?-+:?\s*(?:\|\s*:?-+:?\s*)*\|?\s*$');
  int cells(String line) {
    final text = line.trim();
    if (text.length <= 1) return 1;
    var count = 1;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 124) count++;
    }
    if (text.startsWith('|')) count--;
    if (text.endsWith('|')) count--;
    return count;
  }

  for (var i = 1; i < lines.length; i++) {
    if (lines[i - 1].contains('|') &&
        delimiter.hasMatch(lines[i]) &&
        cells(lines[i - 1]) != cells(lines[i]))
      return true;
  }
  return false;
}

void main() {
  test(
    'table guard retains decisions for whitespace, prefixes and ragged rows',
    () {
      const cases = [
        '| a | b |\n| - | - |',
        '| a | b |\n-',
        'a | b\n---',
        '|\n-',
        '||\n| - |',
        '| a | b |\r\n| - |\r\n',
        '```\n| a | b |\n| - |\n```',
        'a \\| b\n---',
        '\u00a0| a | b |\u00a0\n\u00a0| - |\u00a0',
        'plain\n| - |\n| :--- | ---: |',
      ];
      for (final source in cases) {
        for (var end = 0; end <= source.length; end++) {
          final prefix = source.substring(0, end);
          expect(
            hasLegacyTable(prefix),
            previousTableDecision(prefix),
            reason: prefix,
          );
        }
      }
      expect(requiresLegacyMarkdown('<DeTaIlS open>'), isTrue);
      expect(requiresLegacyMarkdown('value < limit'), isFalse);
    },
  );

  test(
    'delimiter whitespace matches the previous guard for every BMP unit',
    () {
      for (var unit = 0; unit <= 0xffff; unit++) {
        final char = String.fromCharCode(unit);
        final source = 'a|b\n$char-$char';
        expect(
          hasLegacyTable(source),
          previousTableDecision(source),
          reason: 'U+${unit.toRadixString(16)}',
        );
      }
    },
  );

  test(
    'table guard matches the previous implementation on fixtures and generated lines',
    () {
      for (final file in ['commonmark-0.31.2.tsv', 'gfm-extensions.tsv']) {
        for (final line in File(
          'rust-core/tests/fixtures/$file',
        ).readAsLinesSync()) {
          final source = utf8.decode(base64.decode(line.split('\t')[1]));
          expect(
            hasLegacyTable(source),
            previousTableDecision(source),
            reason: source,
          );
        }
      }
      final random = Random(1234);
      const tokens = [
        'a',
        '|',
        '-',
        ':',
        ' ',
        '\t',
        '\r',
        '\n',
        '\u00a0',
        '\u2028',
        '🙂',
        '\\',
      ];
      for (var i = 0; i < 10000; i++) {
        final source = List.generate(
          random.nextInt(80),
          (_) => tokens[random.nextInt(tokens.length)],
        ).join();
        expect(
          hasLegacyTable(source),
          previousTableDecision(source),
          reason: source,
        );
      }
    },
  );
}

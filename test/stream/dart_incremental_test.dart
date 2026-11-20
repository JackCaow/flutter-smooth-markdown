import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/markdown_parser.dart'
    show DartStreamParser;
import 'package:flutter_test/flutter_test.dart';

Object json(List<MarkdownNode> nodes) => nodes.map((n) => n.toJson()).toList();

void main() {
  final batch = MarkdownParser(backend: MarkdownParserBackend.legacyDart);
  const committed = 'one\n\ntwo\n\nthree\n\nfour\n\n';

  test(
    'Dart incremental matches its batch parser at every UTF16 fixture prefix',
    () {
      var count = 0;
      for (final file in ['commonmark-0.31.2.tsv', 'gfm-extensions.tsv']) {
        for (final line in File(
          'rust-core/tests/fixtures/$file',
        ).readAsLinesSync()) {
          final fields = line.split('\t');
          final source = utf8.decode(base64.decode(fields[1]));
          final stream = DartStreamParser();
          try {
            for (var end = 0; end <= source.length; end++) {
              final prefix = committed + source.substring(0, end);
              expect(
                json(stream.update(prefix)),
                json(batch.parse(prefix)),
                reason: '$file fixture ${fields[0]}, UTF16 prefix $end',
              );
            }
          } finally {
            stream.dispose();
          }
          count++;
        }
      }
      expect(count, 676);
    },
  );

  test(
    'Dart retains identity, rolls back two blocks, and resets edits/definitions',
    () {
      final stream = DartStreamParser();
      addTearDown(stream.dispose);
      const source = 'one\n\ntwo\n\nthree\n\nfour';
      final first = stream.update(source);
      final second = stream.update('$source more');
      expect(stream.lastRetainedBlocks, 2);
      expect(stream.lastParsedUnits, 'three\n\nfour more'.length);
      expect(identical(first[0], second[0]), isTrue);
      expect(identical(first[1], second[1]), isTrue);
      expect(identical(first[2], second[2]), isFalse);
      final same = stream.update('$source more');
      expect(stream.lastParsedUnits, 0);
      expect(identical(second.last, same.last), isTrue);
      for (final value in [
        '$source more\n\n[ref]',
        '$source more\n\n[ref]: /url',
        '$source more\n\n[ref]: /url\n\nnext',
        'é\n\nx',
        'e\u0301\n\nx',
        '',
        'replacement',
      ]) {
        expect(json(stream.update(value)), json(batch.parse(value)));
        if (value.contains(']:') || !value.startsWith(source)) {
          expect(stream.lastRetainedBlocks, 0);
        }
      }
      stream
        ..dispose()
        ..dispose();
      expect(() => stream.update('after disposal'), throwsStateError);
    },
  );

  test('Dart handles nested tails, empty lines, CRLF and split Unicode', () {
    const sources = [
      '中文🙂\r\n\r\n> quote\r\n> - [x] task\r\n\r\n\$\$\r\nx^2\r\n\$\$\r\n\r\nEnd[^a]\r\n\r\n[^a]: 中文\r\n    second line\r\n',
      'prior\n#plain\n\n```x`\n\n[link][a]\n\n> [a]: /url\n',
      '- item\n\n  continued\n\n- next\n\n    code\n\n    more\n',
      '| A | B |\n| -- | -- |\n| x | y |\n\nlast',
      '\n \n\t\n# h\n\n  one\n\n```dart\nx\n```\n\nend',
      '![image](image.png)\n\n[link](/url)\n\n**open',
    ];
    for (final source in sources) {
      final stream = DartStreamParser();
      try {
        for (var end = 0; end <= source.length; end++) {
          final prefix = committed + source.substring(0, end);
          expect(
            json(stream.update(prefix)),
            json(batch.parse(prefix)),
            reason: prefix,
          );
        }
      } finally {
        stream.dispose();
      }
    }
  });

  test(
    'existing batch parse errors remain errors and the session can recover',
    () {
      const invalidInLegacy = '# Header\r\n';
      final stream = DartStreamParser();
      addTearDown(stream.dispose);
      stream.update(committed);
      expect(() => batch.parse(invalidInLegacy), throwsFormatException);
      expect(() => stream.update(invalidInLegacy), throwsFormatException);
      expect(json(stream.update('recovered')), json(batch.parse('recovered')));
    },
  );

  test(
    'Dart incremental matches batch on generated append and replacement sequences',
    () {
      final random = Random(487);
      const tokens = [
        'text',
        '*',
        '**',
        '_',
        '~',
        '~~',
        '\\',
        '&amp;',
        '\n',
        ' ',
        '中',
        '🙂',
        '`',
        '[',
        ']',
        '(',
        ')',
        '<',
        '>',
        r'$',
        '!',
        ':',
        '#',
        '|',
        '-',
        '\t',
      ];
      for (var doc = 0; doc < 500; doc++) {
        final stream = DartStreamParser();
        var source = committed;
        try {
          for (var step = 0; step < 30; step++) {
            if (step == 15) {
              source = source.substring(0, random.nextInt(source.length + 1));
            }
            // Each intermediate immutable prefix is the actual parser input.
            // ignore: use_string_buffers
            source += tokens[random.nextInt(tokens.length)];
            expect(
              json(stream.update(source)),
              json(batch.parse(source)),
              reason: source,
            );
          }
        } finally {
          stream.dispose();
        }
      }
    },
  );
}

import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// Micro-benchmarks for the HTML parsing feature.
///
/// These tests print timing numbers for inspection and only assert very
/// generous bounds so they stay stable on slow CI machines. Run with:
/// `flutter test test/performance/html_parse_benchmark_test.dart`
void main() {
  const warmupIterations = 30;
  const iterations = 300;

  double benchmark(MarkdownParser parser, String markdown) {
    for (var i = 0; i < warmupIterations; i++) {
      parser.parse(markdown);
    }
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      parser.parse(markdown);
    }
    stopwatch.stop();
    return stopwatch.elapsedMicroseconds / iterations;
  }

  String buildTypicalDocument() {
    final buffer = StringBuffer();
    for (var i = 0; i < 40; i++) {
      buffer
        ..writeln('## Section $i')
        ..writeln()
        ..writeln('Paragraph $i with **bold**, *italic*, `code`, and a '
            '[link](https://example.com/$i) plus ~~strike~~ text.')
        ..writeln()
        ..writeln('- item one for $i')
        ..writeln('- item two for $i')
        ..writeln();
    }
    return buffer.toString();
  }

  String buildAngleBracketHeavyDocument() {
    final buffer = StringBuffer();
    for (var i = 0; i < 40; i++) {
      buffer
        ..writeln('Compare $i: a < b and 2<3 while x > y, generics like '
            'Map then i < j again, <3 hearts, and trailing < signs <.')
        ..writeln();
    }
    return buffer.toString();
  }

  String buildHtmlHeavyDocument() {
    final buffer = StringBuffer();
    for (var i = 0; i < 40; i++) {
      buffer
        ..writeln('Line $i: <b>bold</b> <u>under</u> <mark>mark</mark> '
            'H<sub>2</sub>O e=mc<sup>2</sup> <kbd>Ctrl</kbd> '
            '<span style="color:red">red</span><br>next')
        ..writeln()
        ..writeln('<div align="center">')
        ..writeln()
        ..writeln('block $i content')
        ..writeln()
        ..writeln('</div>')
        ..writeln();
    }
    return buffer.toString();
  }

  group('HTML parsing benchmarks', () {
    test('flag overhead on typical markdown without html tags', () {
      final document = buildTypicalDocument();
      final offTime = benchmark(MarkdownParser(), document);
      final onTime = benchmark(MarkdownParser(enableHtml: true), document);

      // ignore: avoid_print
      print('typical doc (${document.length} chars): '
          'off=${offTime.toStringAsFixed(1)}µs '
          'on=${onTime.toStringAsFixed(1)}µs '
          'ratio=${(onTime / offTime).toStringAsFixed(2)}x');

      // Enabling the flag on html-free content must not explode parse
      // time. Generous bound to avoid CI flakiness.
      expect(onTime, lessThan(offTime * 3 + 500));
    });

    test('angle bracket heavy text with html enabled', () {
      final document = buildAngleBracketHeavyDocument();
      final offTime = benchmark(MarkdownParser(), document);
      final onTime = benchmark(MarkdownParser(enableHtml: true), document);

      // ignore: avoid_print
      print('angle-bracket doc (${document.length} chars): '
          'off=${offTime.toStringAsFixed(1)}µs '
          'on=${onTime.toStringAsFixed(1)}µs '
          'ratio=${(onTime / offTime).toStringAsFixed(2)}x');

      expect(onTime, lessThan(offTime * 5 + 1000));
    });

    test('html heavy document parse cost', () {
      final document = buildHtmlHeavyDocument();
      final onTime = benchmark(MarkdownParser(enableHtml: true), document);

      // ignore: avoid_print
      print('html-heavy doc (${document.length} chars): '
          'on=${onTime.toStringAsFixed(1)}µs');

      // Absolute sanity bound only — the feature itself is the cost.
      expect(onTime, lessThan(50000));
    });

    test('pathological inputs stay linear-ish', () {
      final parser = MarkdownParser(enableHtml: true);
      final cases = <String, String>{
        'unterminated long tag': '<a href="${'x' * 100000}',
        'angle bracket spam': 'x<' * 50000,
        'deep nesting': '${'<b>' * 5000}core${'</b>' * 5000}',
        'unclosed tag chain': 'a<int> b<int> c<int> ' * 2000,
      };

      for (final entry in cases.entries) {
        final stopwatch = Stopwatch()..start();
        final nodes = parser.parse(entry.value);
        stopwatch.stop();

        // ignore: avoid_print
        print('pathological "${entry.key}" '
            '(${entry.value.length} chars): '
            '${stopwatch.elapsedMilliseconds}ms');

        expect(nodes, isNotEmpty, reason: entry.key);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(2000),
          reason: 'pathological input must not explode: ${entry.key}',
        );
      }
    });

    test('streaming style incremental re-parse cost', () {
      final parser = MarkdownParser(enableHtml: true);
      const chunk = 'streamed <b>bold segment with <u>nested under</u> '
          'and trailing text ';
      final buffer = StringBuffer();

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        buffer.write(chunk);
        // Each tick re-parses the whole accumulated buffer, matching
        // StreamMarkdown's behavior with unclosed tags mid-stream.
        parser.parse(buffer.toString());
      }
      stopwatch.stop();

      // ignore: avoid_print
      print('streaming 50 re-parses (final ${buffer.length} chars): '
          '${stopwatch.elapsedMilliseconds}ms total');

      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });
}

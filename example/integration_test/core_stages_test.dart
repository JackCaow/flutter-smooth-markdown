import 'package:flutter/foundation.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/rust/diagnostics.dart';
import 'package:flutter_smooth_markdown/src/parser/parser_compatibility.dart';
import 'package:flutter_smooth_markdown/src/rust/platform.dart' as native;
import 'package:flutter_smooth_markdown_example/large_document_sample.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const section = mixedMarkdownSection;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test('measure native parse stages without UI scheduling', () {
    expect(kProfileMode, isTrue);
    expect(MarkdownCore.isNative, isTrue);
    final result = <String, Object>{};
    for (final count in [1, 40, 160]) {
      final source = section * count;
      for (var i = 0; i < 5; i++) {
        profileNativeParse(source);
      }
      final samples = [for (var i = 0; i < 61; i++) profileNativeParse(source)];
      result['sections_$count'] = {
        for (final key in samples.first.keys)
          key: ([for (final sample in samples) sample[key]!]..sort())[30],
      };
    }
    final rust = MarkdownParser(backend: MarkdownParserBackend.rust);
    final dart = MarkdownParser(backend: MarkdownParserBackend.legacyDart);
    final comparisons = <String, Object>{};
    for (final count in [40, 160]) {
      final source = section * count;
      final operations = <String, void Function()>{
        'compatibility_check': () {
          requiresLegacyMarkdown(source);
        },
        'direct_native': () {
          native.parseNative(source);
        },
        'public_rust': () {
          rust.parse(source);
        },
        'legacy_dart': () {
          dart.parse(source);
        },
      };
      final samples = {for (final key in operations.keys) key: <double>[]};
      for (final op in operations.values) {
        for (var i = 0; i < 5; i++) {
          op();
        }
      }
      // Interleave sample groups so the public/direct difference is measured
      // in the same process and thermal conditions, not inferred across runs.
      for (var sample = 0; sample < 9; sample++) {
        for (final entry in operations.entries) {
          final watch = Stopwatch()..start();
          for (var i = 0; i < 12; i++) {
            entry.value();
          }
          samples[entry.key]!.add(watch.elapsedMicroseconds / 12);
        }
      }
      comparisons['sections_$count'] = {
        for (final entry in samples.entries)
          entry.key: {
            'median_us': (entry.value.toList()..sort())[4],
            'samples_us': entry.value,
          },
      };
    }
    binding.reportData = {
      'stages': result,
      'comparisons': comparisons,
      'profile_mode': kProfileMode,
    };
    // Also leave a machine-readable copy if a platform teardown is interrupted.
    // ignore: avoid_print
    print('CORE_STAGE_RESULT=$result');
  });
}

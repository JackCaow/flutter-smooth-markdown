import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/markdown_parser.dart'
    show DartStreamParser;
import 'package:flutter_smooth_markdown/src/rust/diagnostics.dart';
import 'package:flutter_smooth_markdown/src/rust/platform.dart' as native;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'core_stages_test.dart' show section;

int _observedBlocks = 0;
int get observedBlocks => _observedBlocks;
void consume(List<MarkdownNode> nodes) {
  _observedBlocks += nodes.length;
}

Object json(List<MarkdownNode> nodes) => nodes.map((n) => n.toJson()).toList();

Map<String, Object> measurePaired(Map<String, void Function()> operations) {
  for (final op in operations.values) {
    for (var i = 0; i < 5; i++) {
      op();
    }
  }
  final entries = operations.entries.toList();
  final samples = {for (final key in operations.keys) key: <double>[]};
  for (var sample = 0; sample < 9; sample++) {
    // Rotate order: don't always measure one engine first after warmup/GC.
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[(sample + i) % entries.length];
      final watch = Stopwatch()..start();
      for (var loop = 0; loop < 2; loop++) {
        entry.value();
      }
      samples[entry.key]!.add(watch.elapsedMicroseconds / 2);
    }
  }
  return {
    for (final entry in samples.entries)
      entry.key: {
        'median_us': (entry.value.toList()..sort())[4],
        'p90_us': (entry.value.toList()..sort())[8],
        'samples_us': entry.value,
        'iterations': 2,
      }
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test('same two-block tail strategy, Dart versus Rust', () {
    expect(kProfileMode, isTrue);
    expect(MarkdownCore.isNative, isTrue);
    final dart = MarkdownParser(backend: MarkdownParserBackend.legacyDart);
    final rust = MarkdownParser(backend: MarkdownParserBackend.rust);
    const streamingSection = '## Stream reply\n\n'
        'A paragraph with **marks**, [link](/guide), 中文🙂.\n\n'
        '- First item\n- Second item\n\n'
        '```dart\nint count(String name) => name.length;\n```\n\n';
    final cases = <String, ({String source, int stride})>{
      'short_message': (
        source: 'Hello **world**, this is a short reply with `code` and 中文🙂.',
        stride: 6
      ),
      'stream_14k_chunks256': (source: streamingSection * 100, stride: 256),
      // Publish complete sections so table eligibility is identical at every
      // publication; both engines retain/parse exactly the same source ranges.
      'mixed_43k_sections': (source: section * 160, stride: section.length),
      'single_paragraph_50k': (
        source: 'A long paragraph with **marks** and 中文🙂. ' * 1200,
        stride: 512
      ),
      'global_definitions': (
        source: '[site][ref]\n\n[ref]: /target\n\n${streamingSection * 40}',
        stride: 256
      ),
    };
    final results = <String, Object>{};
    for (final entry in cases.entries) {
      final source = entry.value.source;
      final prefixes = [
        for (var end = entry.value.stride;
            end < source.length;
            end += entry.value.stride)
          source.substring(0, end),
        source
      ];
      final work = profileNativeStreamWork(prefixes);
      final dartWork = <int>[], dartRetained = <int>[];
      final d = DartStreamParser();
      final r = native.createNativeStream()!;
      try {
        for (final prefix in prefixes) {
          expect(json(d.update(prefix)), json(dart.parse(prefix)),
              reason: 'Dart ${entry.key}');
          expect(json(r.update(prefix)), json(rust.parse(prefix)),
              reason: 'Rust ${entry.key}');
          dartWork.add(d.lastParsedUnits);
          dartRetained.add(d.lastRetainedBlocks);
        }
      } finally {
        d.dispose();
        r.dispose();
      }
      // Exact work equality is a condition of this comparison, not a label.
      expect(dartWork, work['parsed_utf16_units'],
          reason: '${entry.key} parsed ranges');
      expect(dartRetained, work['retained_blocks'],
          reason: '${entry.key} retained blocks');
      final operations = <String, void Function()>{
        'dart_batch': () {
          for (final prefix in prefixes) {
            consume(dart.parse(prefix));
          }
        },
        'rust_batch': () {
          for (final prefix in prefixes) {
            consume(rust.parse(prefix));
          }
        },
        'dart_incremental': () {
          final stream = DartStreamParser();
          try {
            for (final prefix in prefixes) {
              consume(stream.update(prefix));
            }
          } finally {
            stream.dispose();
          }
        },
        'rust_incremental': () {
          final stream = native.createNativeStream()!;
          try {
            for (final prefix in prefixes) {
              consume(stream.update(prefix));
            }
          } finally {
            stream.dispose();
          }
        },
      };
      results[entry.key] = {
        'source_utf16_units': source.length,
        'publications': prefixes.length,
        'stride_utf16_units': entry.value.stride,
        'same_parsed_ranges': true,
        'same_retained_blocks': true,
        'batch_total_parsed_units':
            prefixes.fold<int>(0, (sum, p) => sum + p.length),
        'incremental_total_parsed_units':
            dartWork.fold<int>(0, (sum, n) => sum + n),
        'parsed_units_by_publication': dartWork,
        'rust_transferred_input_units':
            work['input_utf16_units']!.fold<int>(0, (sum, n) => sum + n),
        'retained_blocks_by_publication': dartRetained,
        'timings': measurePaired(operations),
      };
    }
    expect(_observedBlocks, greaterThan(0));
    binding.reportData = {
      'incremental_comparison': results,
      'metadata': {
        'profile_mode': kProfileMode,
        'platform': Platform.operatingSystem,
        'os': Platform.operatingSystemVersion,
        'rust_opt_level': '3',
        'rust_compact_ast': true,
        'rust_transport':
            'suffix input, scoped buffer decode, shared immutable node pages',
        'rust_snapshot_page_nodes': 128,
        'rollback_top_level_blocks': 2,
        'definition_policy':
            'full parse after ]:, until non-append replacement',
        'same_source_ranges_verified': true,
        'own_batch_ast_verified_at_every_publication': true,
        'session_creation_disposal_and_result_flattening_included': true,
        'warmup_sequences': 5,
        'sample_groups': 9,
        'iterations_per_group': 2,
        'observed_blocks': _observedBlocks,
      }
    };
  });
}

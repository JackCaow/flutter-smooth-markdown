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
import 'incremental_performance_test.dart'
    show consume, json, measurePaired, observedBlocks;
import 'support/flat_native_stream.dart';

Iterable<String> prefixes(String source) sync* {
  for (var end = section.length; end < source.length; end += section.length) {
    yield source.substring(0, end);
  }
  yield source;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test('435k sustained stream, identical lazy prefixes and parsed ranges', () {
    expect(kProfileMode, isTrue);
    expect(MarkdownCore.isNative, isTrue);
    final source = section * 1600;
    final work = profileNativeStreamWork(prefixes(source));
    final d = DartStreamParser(), r = native.createNativeStream()!;
    final old = FlatNativeStream();
    final dartBatch = MarkdownParser(backend: MarkdownParserBackend.legacyDart);
    final rustBatch = MarkdownParser(backend: MarkdownParserBackend.rust);
    var publication = 0;
    try {
      for (final prefix in prefixes(source)) {
        final dn = d.update(prefix), rn = r.update(prefix);
        final oldNodes = old.update(prefix);
        expect(d.lastParsedUnits, work['parsed_utf16_units']![publication]);
        expect(d.lastRetainedBlocks, work['retained_blocks']![publication]);
        // Batch controls at checkpoints keep validation outside timing without
        // parsing 348 million source units once per backend on every run.
        if (publication == 0 ||
            publication == 1 ||
            publication == 319 ||
            publication == 1599) {
          expect(json(dn), json(dartBatch.parse(prefix)));
          expect(json(rn), json(rustBatch.parse(prefix)));
          expect(json(oldNodes), json(rn));
        }
        publication++;
      }
    } finally {
      d.dispose();
      r.dispose();
      old.dispose();
    }
    final timings = measurePaired({
      'rust_flat_baseline': () {
        final session = FlatNativeStream();
        try {
          for (final prefix in prefixes(source)) {
            consume(session.update(prefix));
          }
        } finally {
          session.dispose();
        }
      },
      'dart_incremental': () {
        final session = DartStreamParser();
        try {
          for (final prefix in prefixes(source)) {
            consume(session.update(prefix));
          }
        } finally {
          session.dispose();
        }
      },
      'rust_incremental': () {
        final session = native.createNativeStream()!;
        try {
          for (final prefix in prefixes(source)) {
            consume(session.update(prefix));
          }
        } finally {
          session.dispose();
        }
      },
    });
    expect(observedBlocks, greaterThan(0));
    binding.reportData = {
      'sustained_comparison': {
        'source_utf16_units': source.length,
        'publications': publication,
        'stride_utf16_units': section.length,
        'incremental_total_parsed_units': work['parsed_utf16_units']!.fold<int>(
          0,
          (sum, n) => sum + n,
        ),
        'rust_transferred_input_units': work['input_utf16_units']!.fold<int>(
          0,
          (sum, n) => sum + n,
        ),
        'timings': timings,
      },
      'metadata': {
        'profile_mode': kProfileMode,
        'platform': Platform.operatingSystem,
        'os': Platform.operatingSystemVersion,
        'all_prefixes_preallocated': false,
        'prefix_generation_included_in_timing': true,
        'rollback_top_level_blocks': 2,
        'same_source_ranges_verified_at_every_publication': true,
        'own_batch_ast_checkpoints': [1, 2, 320, 1600],
        'session_creation_disposal_and_result_publication_included': true,
        'frozen_old_adapter_in_same_aot_process': true,
        'warmup_sequences': 5,
        'sample_groups': 9,
        'iterations_per_group': 2,
        'observed_blocks': observedBlocks,
      },
    };
  });
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/markdown_parser.dart'
    show DartStreamParser;
import 'package:flutter_smooth_markdown/src/rust/core_types.dart'
    show CoreStream;
import 'package:flutter_smooth_markdown/src/rust/diagnostics.dart';
import 'package:flutter_smooth_markdown/src/rust/platform.dart' as native;
import 'package:flutter_smooth_markdown/src/rust/stream_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'core_stages_test.dart' show section;
import 'support/eligibility_benchmark.dart';

void main() => registerAppendStageTest();

void registerAppendStageTest({bool compareEligibility = false}) {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test(
    'attribute 435k render-fixture appends before building any widgets',
    () async {
      expect(kProfileMode, isTrue);
      expect(MarkdownCore.isNative, isTrue);
      final source = section * 1600;
      const chunk = '\n\nrender update\n';
      final prefixes = [for (var i = 0; i <= 11; i++) source + chunk * i];
      final work = profileNativeStreamWork(prefixes);
      final plugins = benchmarkPlugins();
      final trials = <Map<String, Object>>[];
      // Discard a complete control pair before collecting balanced trial orders.
      for (var trial = 0; trial <= 8; trial++) {
        final order = trial.isOdd ? ['dart', 'rust'] : ['rust', 'dart'];
        for (final backend in order) {
          final checks = compareEligibility
              ? ['full', 'incremental']
              : ['full'];
          final fullFirst = (trial % 4 < 2) == (backend == 'rust');
          for (final check in fullFirst ? checks : checks.reversed) {
            final CoreStream session = backend == 'dart'
                ? DartStreamParser()
                : native.createNativeStream()!;
            final gate = StreamEligibility();
            final incremental = check == 'incremental';
            final checkUs = <double>[], updateUs = <double>[];
            final watch = Stopwatch()..start();
            try {
              for (var i = 0; i < prefixes.length; i++) {
                final prefix = prefixes[i];
                final start = watch.elapsedTicks;
                final eligible = incremental
                    ? gate.checkAppend(prefix, plugins)
                    : canParseIncrementally(prefix, plugins);
                final checked = watch.elapsedTicks;
                final nodes = session.update(prefix);
                final updated = watch.elapsedTicks;
                expect(eligible, isTrue);
                expect(nodes.last, isA<MarkdownNode>());
                if (session is DartStreamParser) {
                  expect(
                    session.lastParsedUnits,
                    work['parsed_utf16_units']![i],
                  );
                  expect(
                    session.lastRetainedBlocks,
                    work['retained_blocks']![i],
                  );
                }
                if (i > 3) {
                  checkUs.add((checked - start) * 1e6 / watch.frequency);
                  updateUs.add((updated - checked) * 1e6 / watch.frequency);
                }
              }
            } finally {
              session.dispose();
            }
            // Let the platform handle input between independent sessions. This
            // yield is outside all measured intervals.
            await Future<void>.delayed(Duration.zero);
            if (trial > 0) {
              trials.add({
                'trial': trial,
                'backend': backend,
                if (compareEligibility) 'eligibility_mode': check,
                'eligibility_us': checkUs,
                'session_update_us': updateUs,
              });
            }
          }
        }
      }
      binding.reportData = {
        'render_append_stages': trials,
        if (compareEligibility) 'compare_stream_eligibility': true,
        'stage_clock_frequency_hz': Stopwatch().frequency,
        'prefill_utf16_units': source.length,
        'appended_utf16_units': chunk.length,
        'measured_reparsed_utf16_units': work['parsed_utf16_units']!.sublist(4),
        'measured_retained_blocks': work['retained_blocks']!.sublist(4),
        'profile_mode': kProfileMode,
        'platform': Platform.operatingSystemVersion,
      };
    },
  );
}

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

const _publications = 1600;

Iterable<String> _prefixes(String document) sync* {
  for (
    var end = section.length;
    end <= document.length;
    end += section.length
  ) {
    yield document.substring(0, end);
  }
}

// Run checks and verify parser work before collecting frames. Keep observers
// and clocks out of the production widget and its measured UI thread work.
List<Map<String, Object>> _measureChecks(String document) {
  final work = profileNativeStreamWork(_prefixes(document));
  final results = <Map<String, Object>>[];
  for (final backend in [
    MarkdownParserBackend.legacyDart,
    MarkdownParserBackend.rust,
  ]) {
    final registry = benchmarkPlugins();
    final gate = StreamEligibility();
    final CoreStream session = backend == MarkdownParserBackend.legacyDart
        ? DartStreamParser()
        : native.createNativeStream()!;
    final fullTicks = <int>[], incrementalTicks = <int>[];
    final watch = Stopwatch()..start();
    try {
      var i = 0;
      for (final prefix in _prefixes(document)) {
        // Alternate which check sees the freshly prepared prefix first.
        for (final full
            in i.isEven == (backend == MarkdownParserBackend.rust)
                ? [true, false]
                : [false, true]) {
          final start = watch.elapsedTicks;
          final eligible = full
              ? canParseIncrementally(prefix, registry)
              : gate.checkAppend(prefix, registry);
          final ticks = watch.elapsedTicks - start;
          (full ? fullTicks : incrementalTicks).add(ticks);
          expect(eligible, isTrue);
        }
        final nodes = session.update(prefix);
        expect(nodes.isNotEmpty, isTrue);
        if (session is DartStreamParser) {
          expect(session.lastParsedUnits, work['parsed_utf16_units']![i]);
          expect(session.lastRetainedBlocks, work['retained_blocks']![i]);
        }
        i++;
      }
      expect(i, _publications);
    } finally {
      session.dispose();
    }
    results.add({
      'backend': backend.name,
      'full_ticks': fullTicks,
      'incremental_ticks': incrementalTicks,
    });
  }
  return results;
}

Future<Map<String, Object>> _render(
  IntegrationTestWidgetsFlutterBinding binding,
  MarkdownParserBackend backend, {
  required bool full,
}) async {
  final controller = StreamController<String>();
  final contentKey = GlobalKey();
  final timings = <FrameTiming>[], marked = <int>[];
  final onDraw = binding.platformDispatcher.onDrawFrame!;
  Completer<void>? publication;
  void record(List<FrameTiming> frames) => timings.addAll(frames);
  binding.platformDispatcher.onDrawFrame = () {
    final element = contentKey.currentContext;
    final pending = publication;
    if (pending != null &&
        !pending.isCompleted &&
        element is Element &&
        element.dirty) {
      marked.add(developer.Timeline.now);
      pending.complete();
    }
    onDraw();
  };
  binding.addTimingsCallback(record);
  try {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreamMarkdown(
              key: contentKey,
              stream: controller.stream,
              config: MarkdownConfig(parserBackend: backend),
              plugins: benchmarkPlugins(fullCheck: full),
              useEnhancedComponents: true,
            ),
          ),
        ),
      ),
    );
    await binding.endOfFrame.timeout(const Duration(seconds: 20));
    for (var i = 0; i < _publications; i++) {
      publication = Completer<void>();
      controller.add(section);
      await publication.future.timeout(const Duration(seconds: 20));
      // Queue the next chunk only after the current publication's frame.
      // The widget's normal 50 ms throttle determines the pace.
      publication = null;
      if ((i + 1) % 400 == 0) {
        debugPrint(
          'SUSTAINED_RENDER ${backend.name} full=$full ${i + 1}/$_publications',
        );
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 1200));
  } finally {
    binding.removeTimingsCallback(record);
    binding.platformDispatcher.onDrawFrame = onDraw;
    runApp(const SizedBox.shrink());
    await binding.endOfFrame.timeout(const Duration(seconds: 20));
    await controller.close();
  }
  expect(marked.length, _publications);
  final frames = <FrameTiming>[];
  for (final frame in timings) {
    if (frames.length == marked.length) break;
    final timestamp = marked[frames.length];
    if (frame.timestampInMicroseconds(FramePhase.buildStart) <= timestamp &&
        timestamp <= frame.timestampInMicroseconds(FramePhase.buildFinish)) {
      frames.add(frame);
    }
  }
  expect(
    frames.length,
    _publications,
    reason: 'Each publication must have its own engine frame',
  );
  return {
    'backend': backend.name,
    'gate': full ? 'full' : 'incremental',
    'build_us': [
      for (final frame in frames) frame.buildDuration.inMicroseconds,
    ],
    'raster_us': [
      for (final frame in frames) frame.rasterDuration.inMicroseconds,
    ],
    'total_span_us': [
      for (final frame in frames) frame.totalSpan.inMicroseconds,
    ],
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final cases = {
    'dart-incremental': (MarkdownParserBackend.legacyDart, false),
    'rust-incremental': (MarkdownParserBackend.rust, false),
    'rust-full': (MarkdownParserBackend.rust, true),
    'dart-full': (MarkdownParserBackend.legacyDart, true),
  };
  final cell = Platform.environment['SMOOTH_RENDER_CELL'];
  testWidgets(
    'render every update from empty to 435k ($cell)',
    (_) async {
      expect(kProfileMode, isTrue);
      expect(MarkdownCore.isNative, isTrue);
      expect(
        cases.containsKey(cell),
        isTrue,
        reason: 'Set SMOOTH_RENDER_CELL to one of ${cases.keys.join(', ')}',
      );
      final (backend, full) = cases[cell]!;
      final source = section * _publications;
      final checks = _measureChecks(source);
      final frame = await _render(binding, backend, full: full);
      binding.reportData = {
        'sustained_render_cell': cell,
        'sustained_render_eligibility': [frame],
        'check_samples': checks,
        'ticks_per_second': Stopwatch().frequency,
        'document_utf16_units': source.length,
        'chunk_utf16_units': section.length,
        'publications_per_cell': _publications,
        'platform': Platform.operatingSystemVersion,
        'profile_mode': kProfileMode,
      };
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

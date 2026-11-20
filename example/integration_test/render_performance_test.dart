import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/markdown_parser.dart'
    show DartStreamParser;
import 'package:flutter_smooth_markdown/src/rust/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'core_stages_test.dart' show section;
import 'support/legacy_stream_markdown.dart';
import 'support/eligibility_benchmark.dart';

Map<String, Object> summarize(List<FrameTiming> frames) {
  Map<String, Object> distribution(List<double> values) {
    final sorted = values.toList()..sort();
    return {
      'median_ms': sorted[sorted.length ~/ 2],
      'p95_ms': sorted[((sorted.length - 1) * .95).ceil()],
      'max_ms': sorted.last,
      'over_16_67ms': values.where((v) => v > 1000 / 60).length,
      'over_8_33ms': values.where((v) => v > 1000 / 120).length,
      'samples_ms': values,
    };
  }

  return {
    'content_frames': frames.length,
    'build_layout': distribution([
      for (final f in frames) f.buildDuration.inMicroseconds / 1000,
    ]),
    'raster': distribution([
      for (final f in frames) f.rasterDuration.inMicroseconds / 1000,
    ]),
    'total_span': distribution([
      for (final f in frames) f.totalSpan.inMicroseconds / 1000,
    ]),
  };
}

void main() => registerRenderFrameTest();

void registerRenderFrameTest({
  bool compareEligibility = false,
  String? measuredLayout,
  int prefillParts = 1,
  int? trials,
}) {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    // Live widget tests normally consume physical touches to search the tree
    // for suggested finders. Real gestures must reach the benchmark widget.
    ..shouldPropagateDevicePointerEvents = true
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'actual stream rendering frames with matched publications',
    (_) async {
      expect(kProfileMode, isTrue);
      expect(MarkdownCore.isNative, isTrue);
      final plugins = benchmarkPlugins();
      final fullCheckPlugins = benchmarkPlugins(fullCheck: true);
      final layouts = measuredLayout != null
          ? [measuredLayout]
          : compareEligibility
          ? ['paged', 'sliver']
          : ['legacy', 'paged', 'sliver'];
      final trialCount = trials ?? (compareEligibility ? 4 : 3);
      final results = <Map<String, Object>>[];
      final errors = <String>[];
      final previousError = FlutterError.onError;
      final originalDraw = binding.platformDispatcher.onDrawFrame;
      FlutterError.onError = (details) {
        errors.add(details.exceptionAsString());
        previousError?.call(details);
      };
      try {
        for (var trial = 1; trial <= trialCount; trial++) {
          for (final count in compareEligibility ? [1600] : [12, 160, 1600]) {
            final source = section * count;
            const publications = 8;
            expect(source.length % prefillParts, 0);
            final partLength = source.length ~/ prefillParts;
            final prefixes = [
              for (var part = 1; part <= prefillParts; part++)
                source.substring(0, part * partLength),
              for (var i = 1; i <= publications + 3; i++)
                '$source${'\n\nrender update\n' * i}',
            ];
            // Verify parsing policy outside the timed frames.
            final nativeWork = profileNativeStreamWork(prefixes);
            final dart = DartStreamParser();
            try {
              for (var i = 0; i < prefixes.length; i++) {
                dart.update(prefixes[i]);
                expect(
                  dart.lastParsedUnits,
                  nativeWork['parsed_utf16_units']![i],
                );
                expect(
                  dart.lastRetainedBlocks,
                  nativeWork['retained_blocks']![i],
                );
              }
            } finally {
              dart.dispose();
            }
            for (final backend
                in trial.isOdd
                    ? [
                        MarkdownParserBackend.legacyDart,
                        MarkdownParserBackend.rust,
                      ]
                    : [
                        MarkdownParserBackend.rust,
                        MarkdownParserBackend.legacyDart,
                      ]) {
              for (final mode in trial.isOdd ? layouts : layouts.reversed) {
                final checks = compareEligibility
                    ? ['full', 'incremental']
                    : ['current'];
                // Counterbalance each layout's adjacent before/after runs.
                final fullFirst =
                    (trial <= (trialCount ~/ 2)) ==
                    (backend == MarkdownParserBackend.rust);
                for (final check in fullFirst ? checks : checks.reversed) {
                  final registry = check == 'full' ? fullCheckPlugins : plugins;
                  final controller = StreamController<String>();
                  final contentKey = GlobalKey();
                  final scroll = ScrollController(keepScrollOffset: false);
                  final timings = <FrameTiming>[];
                  final marked = <int>[];
                  final measuredOffsets = <double>[];
                  double? verifiedDragOffset;
                  Completer<void>? layout;
                  var measuring = false;
                  void mark(int timestamp) {
                    if (measuring) {
                      marked.add(timestamp);
                      measuredOffsets.add(scroll.offset);
                    }
                    if (layout != null && !layout!.isCompleted) {
                      layout!.complete();
                    }
                  }

                  void record(List<FrameTiming> frames) =>
                      timings.addAll(frames);
                  Future<void> publish(String chunk) async {
                    layout = Completer<void>();
                    controller.add(chunk);
                    await layout!.future.timeout(
                      const Duration(seconds: 20),
                      onTimeout: () => throw StateError(
                        'No content layout: ensure the profile app is visible',
                      ),
                    );
                    layout = null;
                    // Both backends receive the same pacing above the 50ms throttle.
                    await Future<void>.delayed(
                      const Duration(milliseconds: 90),
                    );
                  }

                  binding.platformDispatcher.onDrawFrame = () {
                    final element = contentKey.currentContext;
                    if (layout != null && element is Element && element.dirty) {
                      mark(developer.Timeline.now);
                    }
                    originalDraw?.call();
                  };
                  final Widget body;
                  final config = MarkdownConfig(parserBackend: backend);
                  if (mode == 'sliver') {
                    body = CustomScrollView(
                      controller: scroll,
                      slivers: [
                        StreamMarkdown.sliver(
                          key: contentKey,
                          stream: controller.stream,
                          plugins: registry,
                          useEnhancedComponents: true,
                          config: config,
                        ),
                      ],
                    );
                  } else {
                    final content = mode == 'legacy'
                        ? LegacyStreamMarkdown(
                            key: contentKey,
                            stream: controller.stream,
                            plugins: registry,
                            useEnhancedComponents: true,
                            config: config,
                          )
                        : StreamMarkdown(
                            key: contentKey,
                            stream: controller.stream,
                            plugins: registry,
                            useEnhancedComponents: true,
                            config: config,
                          );
                    body = SingleChildScrollView(
                      controller: scroll,
                      child: content,
                    );
                  }
                  runApp(MaterialApp(home: Scaffold(body: body)));
                  // Allow the stream listener and initial empty layout to attach.
                  await binding.endOfFrame.timeout(const Duration(seconds: 20));
                  final initialWatch = Stopwatch()..start();
                  for (
                    var start = 0;
                    start < source.length;
                    start += partLength
                  ) {
                    await publish(source.substring(start, start + partLength));
                  }
                  final initialWallUs = initialWatch.elapsedMicroseconds;
                  if (const bool.fromEnvironment('VERIFY_DEVICE_SCROLL') &&
                      results.isEmpty) {
                    final moved = Completer<double>();
                    final startOffset = scroll.offset;
                    void observeDrag() {
                      if (!moved.isCompleted &&
                          (scroll.offset - startOffset).abs() > 16) {
                        moved.complete(scroll.offset);
                      }
                    }

                    scroll.addListener(observeDrag);
                    try {
                      debugPrint(
                        'DEVICE_SCROLL_READY mode=$mode units=${source.length}',
                      );
                      verifiedDragOffset = await moved.future.timeout(
                        const Duration(seconds: 45),
                      );
                      // Wait for the finger to lift, then cancel any ballistic scroll.
                      await Future<void>.delayed(
                        const Duration(milliseconds: 700),
                      );
                    } finally {
                      scroll.removeListener(observeDrag);
                    }
                  }
                  if (scroll.offset != 0 ||
                      scroll.position.isScrollingNotifier.value) {
                    scroll.jumpTo(0);
                  }
                  for (var warm = 0; warm < 3; warm++) {
                    await publish('\n\nrender update\n');
                  }
                  await Future<void>.delayed(
                    const Duration(milliseconds: 1200),
                  );
                  binding.addTimingsCallback(record);
                  measuring = true;
                  try {
                    for (var i = 0; i < publications; i++) {
                      await publish('\n\nrender update\n');
                    }
                    measuring = false;
                    // FrameTiming batches are delivered after raster completion.
                    await Future<void>.delayed(
                      const Duration(milliseconds: 1200),
                    );
                  } finally {
                    binding.removeTimingsCallback(record);
                  }
                  final content = timings
                      .where(
                        (frame) => marked.any(
                          (timestamp) =>
                              frame.timestampInMicroseconds(
                                    FramePhase.buildStart,
                                  ) <=
                                  timestamp &&
                              timestamp <=
                                  frame.timestampInMicroseconds(
                                    FramePhase.buildFinish,
                                  ),
                        ),
                      )
                      .toList();
                  debugPrint(
                    'RENDER_TIMESTAMPS marked=${marked.take(3).toList()} '
                    'engine=${timings.take(3).map((f) => f.timestampInMicroseconds(FramePhase.vsyncStart)).toList()} '
                    'all=${timings.length}',
                  );
                  expect(marked.length, publications);
                  expect(
                    content.length,
                    publications,
                    reason: 'Only actual content layout frames are accepted',
                  );
                  results.add({
                    'trial': trial,
                    'backend': backend.name,
                    'layout_mode': mode,
                    if (compareEligibility) 'eligibility_mode': check,
                    'prefill_utf16_units': source.length,
                    'publications': publications,
                    'initial_wall_us_including_90ms_pacing': initialWallUs,
                    'all_frame_timings': timings.length,
                    'content_build_timestamps_us': marked,
                    'content_scroll_offsets': measuredOffsets,
                    if (verifiedDragOffset != null)
                      'verified_drag_offset': verifiedDragOffset,
                    ...summarize(content),
                  });
                  debugPrint(
                    'RENDER_RESULT trial=$trial units=${source.length} '
                    'backend=${backend.name} mode=$mode check=$check ${summarize(content)}',
                  );
                  runApp(const SizedBox.shrink());
                  await binding.endOfFrame.timeout(const Duration(seconds: 20));
                  scroll.dispose();
                  await controller.close();
                  binding.platformDispatcher.onDrawFrame = originalDraw;
                }
              }
            }
          }
        }
        expect(errors, isEmpty);
        final view = binding.platformDispatcher.views.first;
        binding.reportData = {
          if (compareEligibility) ...?binding.reportData,
          'render_comparison': results,
          'metadata': {
            'profile_mode': kProfileMode,
            'platform': Platform.operatingSystem,
            'os': Platform.operatingSystemVersion,
            'physical_size': [
              view.physicalSize.width,
              view.physicalSize.height,
            ],
            'device_pixel_ratio': view.devicePixelRatio,
            'same_incremental_ranges_and_retention_verified': true,
            'same_inactive_ai_registry': true,
            'same_highlighter_and_committed_widget_cache': true,
            'content_frame_selection':
                'dirty stream element at engine draw-frame entry, inside build interval',
            'publication_pacing_ms_after_layout': 90,
            'prefill_and_three_warmup_updates_excluded': true,
            'prefill_publications': prefillParts,
            'trials_per_backend_per_size': trialCount,
            if (compareEligibility)
              'full_check_control':
                  'Same widget, layout and plugins; registry subclass uses the production full-scan fallback.',
            'scroll_position':
                'reset to top after prefill; actual offset recorded for each content frame',
            'no_parser_only_timings_in_frame_comparison': true,
          },
        };
      } finally {
        FlutterError.onError = previousError;
        binding.platformDispatcher.onDrawFrame = originalDraw;
        runApp(const SizedBox.shrink());
      }
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/rust/platform.dart' as native;
import 'package:flutter_smooth_markdown/src/parser/markdown_parser.dart'
    show DartStreamParser;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../lib/code_diff_demo.dart';

const _section = '''## **Shared** Markdown

A paragraph with **strong**, *emphasis*, `inline code`, [a link](/guide), 中文和 emoji 🙂.

- First item
- Second item
  - Nested item

| Name | Count |
| :--- | ---: |
| Alpha | 12 |
| Beta | 34 |

```dart
int greet(String name) => name.length;
```

''';

Map<String, Object> _measure(void Function() operation, int iterations) {
  for (var i = 0; i < 5; i++) {
    operation();
  }
  final samples = <double>[];
  for (var sample = 0; sample < 9; sample++) {
    final watch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      operation();
    }
    watch.stop();
    samples.add(watch.elapsedMicroseconds / iterations);
  }
  samples.sort();
  return {
    'median_us': samples[4],
    'p90_us': samples[8],
    'iterations': iterations,
    'samples': samples
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('same-input parser, stream and frame measurements',
      (tester) async {
    expect(kProfileMode, isTrue, reason: 'Run this benchmark with --profile');
    expect(MarkdownCore.isNative, isTrue);
    final rust = MarkdownParser(backend: MarkdownParserBackend.rust);
    final dart = MarkdownParser(backend: MarkdownParserBackend.legacyDart);
    final cases = <String, String>{
      'small_message':
          'Hello **world**, this is a short reply with `code` and 中文🙂.',
      'mixed_document_12k': _section * 40,
      'mixed_document_48k': _section * 160,
      'single_paragraph_48k':
          'A long paragraph with **marks** and 中文🙂. ' * 1200,
    };
    final parses = <String, Object>{};
    for (final entry in cases.entries) {
      final iterations = entry.value.length < 1000 ? 500 : 12;
      parses[entry.key] = {
        'utf16_units': entry.value.length,
        'rust_ffi_decode_adapt': _measure(() {
          rust.parse(entry.value);
        }, iterations),
        'legacy_dart': _measure(() {
          dart.parse(entry.value);
        }, iterations),
      };
    }
    final streamSource = ('## Stream reply\n\n'
            'A paragraph with **marks**, [link](/guide), 中文🙂.\n\n'
            '- First item\n- Second item\n\n'
            '```dart\nint count(String name) => name.length;\n```\n\n') *
        100;
    final prefixes = [
      for (var i = 256; i < streamSource.length; i += 256)
        streamSource.substring(0, i),
      streamSource
    ];
    final streams = <String, Object>{
      'utf16_units': streamSource.length,
      'publications': prefixes.length,
      'rust_batch': _measure(() {
        for (final prefix in prefixes) {
          rust.parse(prefix);
        }
      }, 2),
      'dart_batch': _measure(() {
        for (final prefix in prefixes) {
          dart.parse(prefix);
        }
      }, 2),
      'dart_incremental': _measure(() {
        final stream = DartStreamParser();
        try {
          for (final prefix in prefixes) {
            stream.update(prefix);
          }
        } finally {
          stream.dispose();
        }
      }, 2),
      'rust_incremental': _measure(() {
        final stream = native.createNativeStream()!;
        try {
          for (final prefix in prefixes) {
            stream.update(prefix);
          }
        } finally {
          stream.dispose();
        }
      }, 2),
    };
    // Both render paths use the same Rust highlighter, so this comparison
    // changes parser backend only; it does not conflate parser and theme work.
    final state = ValueNotifier(
        (source: _section * 12, backend: MarkdownParserBackend.legacyDart));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: ValueListenableBuilder(
          valueListenable: state,
          builder: (context, value, child) => SmoothMarkdown(
                data: value.source,
                enableCache: false,
                useEnhancedComponents: true,
                config: MarkdownConfig(parserBackend: value.backend),
              )),
    ))));
    await tester.pumpAndSettle();
    for (final backend in [
      MarkdownParserBackend.legacyDart,
      MarkdownParserBackend.rust
    ]) {
      state.value = (source: _section * 12, backend: backend);
      await tester.pumpAndSettle();
      final frames = <FrameTiming>[];
      void record(List<FrameTiming> values) => frames.addAll(values);
      await Future<void>.delayed(const Duration(seconds: 2));
      binding.addTimingsCallback(record);
      try {
        for (var i = 0; i < 40; i++) {
          state.value =
              (source: '${_section * 12}\nframe $i', backend: backend);
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      } finally {
        binding.removeTimingsCallback(record);
      }
      expect(frames, isNotEmpty);
      final builds = frames
          .map((f) => f.buildDuration.inMicroseconds / 1000)
          .toList()
        ..sort();
      final rasters = frames
          .map((f) => f.rasterDuration.inMicroseconds / 1000)
          .toList()
        ..sort();
      binding.reportData ??= {};
      binding.reportData!['frames_${backend.name}'] = {
        'frame_count': frames.length,
        'median_build_ms': builds[builds.length ~/ 2],
        'p95_build_ms': builds[((builds.length - 1) * 0.95).ceil()],
        'average_build_ms': builds.reduce((a, b) => a + b) / builds.length,
        'median_raster_ms': rasters[rasters.length ~/ 2],
        'p95_raster_ms': rasters[((rasters.length - 1) * 0.95).ceil()],
        'average_raster_ms': rasters.reduce((a, b) => a + b) / rasters.length,
        'build_over_16_7ms': builds.where((value) => value > 16.7).length,
      };
    }
    // Real StreamMarkdown path, including the AI registry and valid tables.
    // Both backends receive identical chunks at >50ms throttle intervals.
    final aiPlugins = ParserPluginRegistry()
      ..register(const ThinkingPlugin())
      ..register(const ArtifactPlugin())
      ..register(const ToolCallPlugin());
    for (final backend in [
      MarkdownParserBackend.legacyDart,
      MarkdownParserBackend.rust
    ]) {
      final controller = StreamController<String>();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: StreamMarkdown(
            stream: controller.stream,
            plugins: aiPlugins,
            useEnhancedComponents: true,
            config: MarkdownConfig(parserBackend: backend)),
      ))));
      controller.add(_section * 12);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      await tester.pumpAndSettle();
      final frames = <FrameTiming>[];
      void record(List<FrameTiming> values) => frames.addAll(values);
      await Future<void>.delayed(const Duration(seconds: 2));
      binding.addTimingsCallback(record);
      try {
        for (var i = 0; i < 40; i++) {
          controller.add('\n\nframe $i');
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 70));
        }
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      } finally {
        binding.removeTimingsCallback(record);
      }
      expect(frames, isNotEmpty);
      final builds = frames
          .map((f) => f.buildDuration.inMicroseconds / 1000)
          .toList()
        ..sort();
      final rasters = frames
          .map((f) => f.rasterDuration.inMicroseconds / 1000)
          .toList()
        ..sort();
      binding.reportData ??= {};
      binding.reportData!['stream_frames_${backend.name}'] = {
        'frame_count': frames.length,
        'median_build_ms': builds[builds.length ~/ 2],
        'p95_build_ms': builds[((builds.length - 1) * 0.95).ceil()],
        'average_build_ms': builds.reduce((a, b) => a + b) / builds.length,
        'median_raster_ms': rasters[rasters.length ~/ 2],
        'p95_raster_ms': rasters[((rasters.length - 1) * 0.95).ceil()],
        'publications': 40,
        'ai_registry': true,
      };
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.close();
    }
    binding.reportData ??= {};
    binding.reportData!['metadata'] = {
      'profile_mode': kProfileMode,
      'physical_size': [
        tester.view.physicalSize.width,
        tester.view.physicalSize.height
      ],
      'device_pixel_ratio': tester.view.devicePixelRatio,
      'transport': 'direct-flutter-ast',
      'rust_opt_level': '3',
      'rust_compact_ast': true,
      'rust_transport': 'suffix/scoped/flat',
      'stream_widget_backends_incremental': ['legacyDart', 'rust'],
      'stream_widget_cache_policy':
          'same identity cache and invalidation for both backends',
      'platform': Platform.operatingSystem,
      'os': Platform.operatingSystemVersion,
      'render_utf16_units': (_section * 12).length,
      'note':
          'Single device, warm parses, no cache; parse includes FFI/decoding/Flutter adaptation. Frame tests use the same highlighter.',
    };
    binding.reportData!['parses'] = parses;
    binding.reportData!['streams'] = streams;
    await tester.pumpWidget(const MaterialApp(home: CodeDiffDemo()));
    await tester.pumpAndSettle();
    state.dispose();
  });
}

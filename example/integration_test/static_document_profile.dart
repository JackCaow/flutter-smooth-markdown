import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import 'core_stages_test.dart' show section;

/// Run as an ordinary profile app. One cell per process avoids sharing caches.
Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final outputDir =
      Platform.environment['SMOOTH_RESULT_DIR'] ??
      (Platform.isIOS
          ? '${Directory.systemTemp.parent.path}/Documents'
          : Directory.systemTemp.path);
  final choice = File('$outputDir/static-cell.txt');
  final cell =
      Platform.environment['SMOOTH_STATIC_CELL'] ??
      (choice.existsSync()
          ? choice.readAsStringSync().trim()
          : const String.fromEnvironment(
              'STATIC_CELL',
              defaultValue: 'sliver-rust',
            ));
  if (!kProfileMode ||
      !{'box-dart', 'box-rust', 'sliver-dart', 'sliver-rust'}.contains(cell)) {
    throw StateError('Expected a profile build and a valid STATIC_CELL');
  }
  final source = section * 1600;
  final backend = cell.endsWith('rust')
      ? MarkdownParserBackend.rust
      : MarkdownParserBackend.legacyDart;
  final config = MarkdownConfig(parserBackend: backend);
  final controller = ScrollController();
  final report = <String, Object?>{
    'cell': cell,
    'started_utc': DateTime.now().toUtc().toIso8601String(),
    'source_utf16': source.length,
    'native_available': MarkdownCore.isNative,
    'device_pixel_ratio':
        binding.platformDispatcher.views.first.devicePixelRatio,
    'display_refresh_hz':
        binding.platformDispatcher.views.first.display.refreshRate,
  };
  final result = File('$outputDir/static-$cell.json');
  void save(String stage) {
    report['stage'] = stage;
    final tmp = File('${result.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(report), flush: true);
    tmp.renameSync(result.path);
  }

  final frames = <FrameTiming>[];
  final screen = ValueNotifier<Widget>(
    const Center(child: Text('435k · preparing')),
  );
  VoidCallback? onDraw;
  final firstContent = Completer<int>();
  // This fixture has five top-level blocks per repeated section. The preview
  // publishes fewer entries than the completed 8,000-block index.
  const fullBlockCount = 1600 * 5;
  final fullIndex = Completer<int>();
  int? firstBlockCount;
  int? fullBlockCountObserved;
  SliverMultiBoxAdaptorElement? visibleList(Element root) {
    if (root is SliverMultiBoxAdaptorElement && root.widget is SliverList) {
      return root;
    }
    SliverMultiBoxAdaptorElement? match;
    root.visitChildElements((child) {
      match ??= visibleList(child);
    });
    return match;
  }

  var watching = false;
  void record(List<FrameTiming> batch) => frames.addAll(batch);
  Map<String, int>? mountedWindow(RenderSliverMultiBoxAdaptor? list) {
    if (list == null || list.firstChild == null || list.lastChild == null) {
      return null;
    }
    return {
      'first': list.indexOf(list.firstChild!),
      'last': list.indexOf(list.lastChild!),
      'count': list.childCount,
    };
  }

  bool containsHeading(RenderObject object) {
    if (object is RenderParagraph &&
        object.hasSize &&
        object.text.toPlainText().contains('Shared')) {
      final dy = object.localToGlobal(Offset.zero).dy;
      return dy >= 0 &&
          dy <
              binding.platformDispatcher.views.first.physicalSize.height /
                  binding.platformDispatcher.views.first.devicePixelRatio;
    }
    var found = false;
    object.visitChildren((child) {
      if (!found) found = containsHeading(child);
    });
    return found;
  }

  try {
    save('starting');
    if (source.length != 435200 ||
        (backend == MarkdownParserBackend.rust && !MarkdownCore.isNative)) {
      throw StateError('Unexpected input length or unavailable Rust library');
    }
    runApp(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<Widget>(
            valueListenable: screen,
            builder: (_, child, _) => child,
          ),
        ),
      ),
    );
    await binding.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    SmoothMarkdown.clearCache();
    onDraw = binding.platformDispatcher.onDrawFrame!;
    binding.addTimingsCallback(record);
    binding.platformDispatcher.onDrawFrame = () {
      final marker = developer.Timeline.now;
      onDraw!();
      if (watching &&
          !firstContent.isCompleted &&
          containsHeading(RendererBinding.instance.renderViews.first)) {
        firstBlockCount = cell.startsWith('box')
            ? null
            : visibleList(binding.rootElement!)?.estimatedChildCount;
        firstContent.complete(marker);
      }
      if (watching && firstContent.isCompleted && !fullIndex.isCompleted) {
        final box = cell.startsWith('box');
        final count = box
            ? null
            : visibleList(binding.rootElement!)?.estimatedChildCount;
        if (box || count == fullBlockCount) {
          fullBlockCountObserved = count;
          fullIndex.complete(marker);
        }
      }
    };
    final block = cell.startsWith('box')
        ? SliverToBoxAdapter(
            child: SmoothMarkdown(
              data: source,
              config: config,
              useEnhancedComponents: true,
            ),
          )
        : SmoothMarkdown.sliver(
            data: source,
            config: config,
            useEnhancedComponents: true,
          );
    save('opening');
    watching = true;
    final requested = developer.Timeline.now;
    screen.value = CustomScrollView(
      controller: controller,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [block],
    );
    final marker = await firstContent.future.timeout(
      const Duration(seconds: 90),
    );
    final uiFirst = developer.Timeline.now;
    report['request_to_first_ui_draw_us'] = uiFirst - requested;
    report['initial_max_extent'] = controller.position.maxScrollExtent;
    report['rss_after_open_bytes'] = ProcessInfo.currentRss;
    report['first_index_block_count'] = firstBlockCount;
    save('opened');
    final fullMarker = await fullIndex.future.timeout(
      const Duration(seconds: 60),
    );
    watching = false;
    report['fully_indexed_block_count'] = fullBlockCountObserved;
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    final initial = frames.singleWhere(
      (f) =>
          f.timestampInMicroseconds(FramePhase.buildStart) <= marker &&
          f.timestampInMicroseconds(FramePhase.buildFinish) >= marker,
    );
    final completeFrame = frames.singleWhere(
      (f) =>
          f.timestampInMicroseconds(FramePhase.buildStart) <= fullMarker &&
          f.timestampInMicroseconds(FramePhase.buildFinish) >= fullMarker,
    );
    report['request_to_full_index_raster_us'] =
        completeFrame.timestampInMicroseconds(FramePhase.rasterFinish) -
        requested;
    report['first_frame'] = [
      initial.buildDuration.inMicroseconds,
      initial.rasterDuration.inMicroseconds,
      initial.totalSpan.inMicroseconds,
    ];
    report['request_to_first_content_raster_us'] =
        initial.timestampInMicroseconds(FramePhase.rasterFinish) - requested;
    // Reset after the preview is replaced and suppress incidental touch
    // input so each cold process starts the trajectory from the same row.
    controller.jumpTo(0);
    await binding.endOfFrame;
    final indexBefore = visibleList(binding.rootElement!)?.renderObject;
    final firstChild = indexBefore?.firstChild;
    report['mounted_before'] = mountedWindow(indexBefore);
    report['viewport_logical_px'] = controller.position.viewportDimension;
    final startOffset = controller.offset;
    final start = developer.Timeline.now;
    // Drive identical scroll positions from vsync time. Variable child heights
    // can change maxScrollExtent during a lazy scroll; the input trajectory
    // stays fixed independently of the current estimate.
    final scrollComplete = Completer<void>();
    final ticker = Ticker((elapsed) {
      final progress = (elapsed.inMicroseconds / 1600000).clamp(0.0, 1.0);
      controller.jumpTo(startOffset + 2400 * progress);
      if (progress == 1 && !scrollComplete.isCompleted) {
        scrollComplete.complete();
      }
    });
    ticker.start();
    try {
      await scrollComplete.future.timeout(const Duration(seconds: 10));
    } finally {
      ticker.dispose();
    }
    await binding.endOfFrame;
    final end = developer.Timeline.now;
    final endOffset = controller.offset;
    if (endOffset - startOffset < 2399) {
      throw StateError('Scroll did not reach target: $endOffset');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    report['mounted_after'] = mountedWindow(
      visibleList(binding.rootElement!)?.renderObject,
    );
    report['original_first_child_detached'] = firstChild == null
        ? null
        : !firstChild.attached;
    final scrollFrames = frames.where((f) {
      final t = f.timestampInMicroseconds(FramePhase.buildStart);
      return t >= start && t <= end;
    }).toList();
    if (scrollFrames.length < 5) {
      throw StateError('Only ${scrollFrames.length} matched scroll frames');
    }
    report['scroll_offsets'] = [startOffset, endOffset];
    report['scroll_elapsed_us'] = end - start;
    report['scroll_frames_us'] = [
      for (final f in scrollFrames)
        [
          f.buildDuration.inMicroseconds,
          f.rasterDuration.inMicroseconds,
          f.totalSpan.inMicroseconds,
          f.timestampInMicroseconds(FramePhase.rasterFinish) - start,
        ],
    ];
    report['rss_after_scroll_bytes'] = ProcessInfo.currentRss;
    save('complete');
  } catch (e, stack) {
    report['error'] = '$e\n$stack';
    save('error');
  } finally {
    if (onDraw != null) binding.platformDispatcher.onDrawFrame = onDraw;
    binding.removeTimingsCallback(record);
  }
  runApp(
    MaterialApp(
      home: Scaffold(body: Center(child: Text('$cell · ${report['stage']}'))),
    ),
  );
}

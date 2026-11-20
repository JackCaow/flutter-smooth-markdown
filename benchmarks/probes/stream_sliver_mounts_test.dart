// Run from the package root with flutter test benchmarks/probes/stream_sliver_mounts_test.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/markdown_parser.dart';
import 'package:flutter_smooth_markdown/src/renderer/stream_block_cache.dart';
import 'package:flutter_smooth_markdown/src/rust/core_types.dart';
import 'package:flutter_smooth_markdown/src/rust/platform.dart' as core;
import 'package:flutter_test/flutter_test.dart';

// The fixture lives in the example app, which depends on the root package.
// ignore: avoid_relative_lib_imports
import '../../example/lib/large_document_sample.dart';

// The box implementation still owns the original 32-block pages. Adapt its
// immutable directory exactly like the previous streaming sliver delegate.
class _PreviousPages extends StreamBlockCache {
  @override
  Widget layout(
    Widget Function(MarkdownNode) build,
    double spacing, {
    required bool sliver,
  }) {
    final column = super.layout(build, spacing, sliver: false) as Column;
    final pages = column.children;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, index) => pages[index],
        childCount: pages.length,
        addRepaintBoundaries: false,
      ),
    );
  }
}

void main() {
  testWidgets('435k streaming sliver mounted blocks before and after scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    final source = buildLargeDocumentSample();
    const chunk = '\n\nrender update\n';
    expect(source.length, 435200);
    expect(chunk.length, 16);
    expect(MarkdownCore.isNative, isTrue);
    final rows = <Map<String, Object>>[];

    for (final backend in [
      MarkdownParserBackend.legacyDart,
      MarkdownParserBackend.rust,
    ]) {
      for (final previous in [true, false]) {
        final config = MarkdownConfig(parserBackend: backend);
        final controller = StreamController<String>.broadcast();
        final scroll = ScrollController();
        final cache = _PreviousPages();
        final parser = backend == MarkdownParserBackend.legacyDart
            ? DartStreamParser()
            : core.createNativeStream()! as RetainedCoreStream;
        final prefix = ValueNotifier('');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                key: UniqueKey(),
                controller: scroll,
                cacheExtent: 250,
                slivers: [
                  if (previous)
                    ValueListenableBuilder<String>(
                      valueListenable: prefix,
                      builder: (context, text, _) {
                        final nodes = parser.update(text);
                        cache.updateNodes(nodes, parser.retainedNodeCount);
                        return SmoothMarkdown(
                          data: text,
                          config: config,
                        ).renderSliverNodes(context, nodes, blockCache: cache);
                      },
                    )
                  else
                    StreamMarkdown.sliver(
                      stream: controller.stream,
                      config: config,
                    ),
                ],
              ),
            ),
          ),
        );
        Future<void> publish(String delta) async {
          prefix.value += delta;
          controller.add(delta);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 70));
          await tester.pumpAndSettle();
        }

        void record(String stage) {
          final mounted = tester.allWidgets;
          final blockCount = previous
              ? mounted
                    .where(
                      (w) => w.runtimeType.toString() == '_StreamBlockPage',
                    )
                    .fold(
                      0,
                      (n, w) => n + ((w as dynamic).nodes as List).length,
                    )
              : mounted
                    .where((w) => w.runtimeType.toString() == '_ViewportBlock')
                    .length;
          final paragraphs = tester.allRenderObjects
              .whereType<RenderParagraph>()
              .toSet();
          final visible = <String>[];
          for (final paragraph in paragraphs) {
            final y = paragraph.localToGlobal(Offset.zero).dy;
            if (y >= 0 && y < 874) {
              visible.add(
                '${y.toStringAsFixed(1)} ${paragraph.text.toPlainText()}',
              );
            }
          }
          rows.add({
            'backend': backend.name,
            'layout': previous ? '32-block pages' : 'per-block sliver',
            'stage': stage,
            'scroll_offset': scroll.offset,
            'mounted_ast_blocks': blockCount,
            'mounted_render_paragraphs': paragraphs.length,
            'screen_lines': visible,
          });
          expect(blockCount, greaterThan(0));
          expect(tester.takeException(), isNull);
        }

        await publish(source);
        record('prefill');
        await publish(chunk);
        record('after_append');
        scroll.jumpTo(2400);
        await tester.pumpAndSettle();
        record('scroll_2400');
        scroll.jumpTo(12000);
        await tester.pumpAndSettle();
        record('scroll_12000');
        await publish(chunk);
        record('scrolled_append');
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.close();
        scroll.dispose();
        prefix.dispose();
        parser.dispose();
      }
    }
    for (final before in rows.where((r) => r['layout'] == '32-block pages')) {
      final after = rows.singleWhere(
        (r) =>
            r['layout'] == 'per-block sliver' &&
            r['stage'] == before['stage'] &&
            r['backend'] == before['backend'],
      );
      expect(after['screen_lines'], before['screen_lines']);
      expect(
        after['mounted_ast_blocks'] as int,
        lessThan(before['mounted_ast_blocks'] as int),
      );
    }
    final evidence = {
      'method':
          'macOS Flutter widget test. Previous renderer uses retained 32-block page widgets from the unchanged box path with the previous sliver delegate. Current renderer uses public StreamMarkdown.sliver. Counts mounted AST blocks and RenderParagraph objects after a settled frame. Visible paragraph texts and y positions match for each paired stage. No frame timing or RSS measurement.',
      'viewport_logical': [402, 874],
      'cache_extent': 250,
      'prefill_utf16': source.length,
      'append_utf16': chunk.length,
      'rows': rows,
    };
    final output = Platform.environment['SMOOTH_MOUNT_REPORT'];
    if (output != null) {
      File(output).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(evidence)}\n',
      );
    }
  });
}

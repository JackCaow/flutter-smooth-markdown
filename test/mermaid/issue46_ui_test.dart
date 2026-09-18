import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/mermaid/layout/dagre_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'issue46_ui_fixtures.dart';

class RecordingPainter extends FlowchartPainter {
  RecordingPainter({required super.diagram, required super.style});
  final labels = <String, Rect>{};
  final colors = <String, Color?>{};
  final arrowAngles = <Offset, double>{};

  @override
  void drawArrowHead(Canvas canvas, Offset position, double angle,
      ArrowType type, Paint paint) {
    arrowAngles[position] = angle;
    super.drawArrowHead(canvas, position, angle, type, paint);
  }

  @override
  void drawText(
      Canvas canvas, String text, Offset position, TextStyle textStyle,
      {TextAlign align = TextAlign.center,
      Color? backgroundColor,
      double? maxWidth}) {
    final painter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: maxWidth ?? double.infinity);
    labels[text] = Rect.fromCenter(
        center: position, width: painter.width + 8, height: painter.height + 4);
    colors[text] = textStyle.color;
    painter.dispose();
    super.drawText(canvas, text, position, textStyle,
        align: align, backgroundColor: backgroundColor, maxWidth: maxWidth);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final direction in ['TB', 'BT', 'LR', 'RL']) {
    for (final fixture in {
      'long': uiLongState,
      'self': uiSelfState,
      'siblings': uiSelfSiblings,
      'er': uiEr
    }.entries) {
      test('${fixture.key} labels fit and avoid nodes ($direction)', () {
        final code =
            fixture.value.replaceFirst('\n', '\ndirection $direction\n');
        final graph = const MermaidParser().parse(code)!;
        const style = MermaidStyle();
        final size = const DagreLayout()
            .computeLayout(graph, style, const Size(800, 600));
        final painter = RecordingPainter(diagram: graph, style: style);
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), size);
        recorder.endRecording().dispose();
        for (final edge in graph.edges.where((edge) => edge.from == edge.to)) {
          final node = graph.getNode(edge.from)!;
          final horizontal = direction == 'LR' || direction == 'RL';
          final end = horizontal
              ? Offset(node.x + node.width * .7, node.y)
              : Offset(node.x + node.width, node.y + node.height * .7);
          final expected =
              horizontal ? math.atan2(45, -25) : math.atan2(-25, -45);
          expect(painter.arrowAngles[end], closeTo(expected, .01));
        }
        for (final edge in graph.edges.where((edge) => edge.label != null)) {
          final rect = painter.labels[edge.label]!;
          expect((Offset.zero & size).contains(rect.topLeft), isTrue,
              reason: edge.label);
          expect((Offset.zero & size).contains(rect.bottomRight), isTrue,
              reason: edge.label);
          for (final node in graph.nodes) {
            expect(
                rect.overlaps(
                    Rect.fromLTWH(node.x, node.y, node.width, node.height)),
                isFalse,
                reason: '${edge.label} overlaps ${node.id}');
          }
          if (fixture.key == 'er') {
            // The two connector endpoints share an axis in this fixture.
            final source = graph.getNode(edge.from)!;
            final target = graph.getNode(edge.to)!;
            final vertical = direction == 'TB' || direction == 'BT';
            final markerLane = vertical
                ? Rect.fromLTRB(source.x + source.width / 2 - 8, 0,
                    source.x + source.width / 2 + 8, size.height)
                : Rect.fromLTRB(0, source.y + source.height / 2 - 8, size.width,
                    source.y + source.height / 2 + 8);
            expect(rect.overlaps(markerLane), isFalse);
            expect(target, isNotNull);
          }
        }
      });
    }
  }

  test('dark edge labels have readable contrast', () {
    final graph = const MermaidParser().parse(uiDarkState)!;
    final style = MermaidStyle.dark();
    final size =
        const DagreLayout().computeLayout(graph, style, const Size(800, 600));
    final painter = RecordingPainter(diagram: graph, style: style);
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
    final foreground = painter.colors['支付成功']!.computeLuminance();
    final background = Color(style.backgroundColor).computeLuminance();
    expect((foreground + .05) / (background + .05), greaterThan(4.5));
  });

  final samples = {
    'long-state': (uiLongState, const MermaidStyle()),
    'dark-state': (uiDarkState, MermaidStyle.dark()),
    'dark-subgraph': (uiDarkSubgraph, MermaidStyle.dark()),
    'er-labels': (uiEr, const MermaidStyle()),
    'self-state': (uiSelfState, const MermaidStyle()),
    'self-siblings': (uiSelfSiblings, const MermaidStyle()),
  };
  for (final sample in samples.entries) {
    testWidgets('${sample.key} reviewed visual regression', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: RepaintBoundary(
        key: const ValueKey('review'),
        child: ColoredBox(
            color: Colors.white,
            child: InteractiveMermaidDiagram(
                code: sample.value.$1, style: sample.value.$2, minScale: .1)),
      )));
      await tester.pumpAndSettle();
      await expectLater(find.byKey(const ValueKey('review')),
          matchesGoldenFile('goldens/review-${sample.key}.png'));
    });
  }
}

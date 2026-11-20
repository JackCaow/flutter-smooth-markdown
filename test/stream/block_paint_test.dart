import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/renderer/stream_block_cache.dart';
import 'package:flutter_test/flutter_test.dart';

class _PaintBox extends LeafRenderObjectWidget {
  const _PaintBox(this.paints, this.id);
  final Map<String, int> paints;
  final String id;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _PaintCounter(paints, id);
}

class _PaintCounter extends RenderBox {
  _PaintCounter(this.paints, this.id);
  final Map<String, int> paints;
  final String id;
  @override
  void performLayout() => size = constraints.constrain(const Size(400, 20));
  @override
  void paint(PaintingContext context, Offset offset) {
    paints.update(id, (value) => value + 1, ifAbsent: () => 1);
    context.canvas.drawRect(offset & size, Paint()..color = Colors.blue);
  }
}

void main() {
  testWidgets(
    'tail updates retain prefix paint layers; resizing refreshes them',
    (tester) async {
      final cache = StreamBlockCache();
      final paints = <String, int>{};
      var nodes = <MarkdownNode>[for (var i = 0; i < 96; i++) TextNode('$i')];
      Widget tree(double width) => Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: cache.layout(
                (node) => _PaintBox(paints, (node as TextNode).content),
                16,
                sliver: false,
              ),
            ),
          ),
        ),
      );
      cache.updateNodes(nodes, 0);
      await tester.pumpWidget(tree(400));
      final before = paints['0'];
      expect(before, 1);
      nodes = [
        ...nodes.take(94),
        TextNode('new94'),
        TextNode('new95'),
        TextNode('new96'),
      ];
      cache.updateNodes(nodes, 94);
      await tester.pumpWidget(tree(400));
      expect(
        paints['0'],
        before,
        reason: 'Stable pages must not repaint their descendants',
      );
      await tester.pumpWidget(tree(200));
      expect(paints['0'], greaterThan(before!));
      cache.clear();
      expect(cache.owns(nodes), isFalse);
      expect(cache, isEmpty);
    },
  );
}

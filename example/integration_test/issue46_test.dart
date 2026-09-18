import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/mermaid/issue46_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final sample in issue46Samples.entries) {
    testWidgets('issue46 ${sample.key}: inline, interactive and Markdown',
        (tester) async {
      final errors = <String>[];
      Widget page(Widget child) => MaterialApp(
          home: Scaffold(
              appBar: AppBar(title: Text('Issue 46: ${sample.key}')),
              body: SafeArea(child: child)));
      await tester.pumpWidget(
          page(MermaidDiagram(code: sample.value, onError: errors.add)));
      await tester.pumpAndSettle();
      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
          page(InteractiveMermaidDiagram(code: sample.value, minScale: 0.1)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<FlowchartPainter>()
          .single;
      final nodes = painter.diagram.nodes;
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        expect(node.width, greaterThan(0));
        expect(node.height, greaterThan(0));
        for (var j = i + 1; j < nodes.length; j++) {
          final other = nodes[j];
          expect(
              Rect.fromLTWH(node.x, node.y, node.width, node.height).overlaps(
                  Rect.fromLTWH(other.x, other.y, other.width, other.height)),
              isFalse);
        }
      }
      // Optional screenshots for flutter drive's host-side callback.
      if (const bool.fromEnvironment('ISSUE46_SCREENSHOTS')) {
        if (Theme.of(tester.element(find.byType(Scaffold))).platform ==
            TargetPlatform.android) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
        }
        await binding.takeScreenshot('issue46-${sample.key}');
      }
      await tester.drag(find.byType(InteractiveViewer), const Offset(25, 30));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(page(SingleChildScrollView(
          child: SmoothMarkdown(
        data: '```mermaid\n${sample.value}\n```',
        plugins: ParserPluginRegistry()..register(const MermaidPlugin()),
        builderRegistry: BuilderRegistry()
          ..register('mermaid', const EnhancedMermaidBuilder()),
      ))));
      await tester.pumpAndSettle();
      expect(find.byType(MermaidDiagram), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/mermaid/issue46_ui_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final samples = <String, (String, MermaidStyle)>{
    'long-state': (uiLongState, const MermaidStyle()),
    'dark-state': (uiDarkState, MermaidStyle.dark()),
    'dark-subgraph': (uiDarkSubgraph, MermaidStyle.dark()),
    'er-labels': (uiEr, const MermaidStyle()),
    'self-state': (uiSelfState, const MermaidStyle()),
  };
  for (final sample in samples.entries) {
    testWidgets(sample.key, (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        appBar: AppBar(title: Text('UI review: ${sample.key}')),
        body: SafeArea(
            child: InteractiveMermaidDiagram(
                code: sample.value.$1, style: sample.value.$2, minScale: .1)),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('ISSUE46_SCREENSHOTS')) {
        if (Theme.of(tester.element(find.byType(Scaffold))).platform ==
            TargetPlatform.android) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
        }
        await binding.takeScreenshot('review-${sample.key}');
      }
    });
  }
}

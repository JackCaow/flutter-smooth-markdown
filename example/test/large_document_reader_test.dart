import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown_example/large_document_reader.dart';
import 'package:flutter_smooth_markdown_example/large_document_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'opens the full sample and can replace it with clipboard Markdown',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      var requests = 0;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          requests++;
          return {'text': '# Imported document\n\nContent from the clipboard.'};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: LargeDocumentReader(title: 'Long document reader'),
        ),
      );
      final markdown = find.byType(SmoothMarkdown);
      expect(tester.widget<SmoothMarkdown>(markdown).data.length, 435200);
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(requests, 0);
      await tester.tap(find.byTooltip('Open from clipboard'));
      await tester.pump();
      expect(requests, 1);
      expect(
        find.text('Imported document', findRichText: true),
        findsOneWidget,
      );
      expect(tester.widget<SmoothMarkdown>(markdown).enableCache, isFalse);
      await tester.tap(find.byTooltip('Reopen sample'));
      await tester.pump();
      expect(
        tester.widget<SmoothMarkdown>(markdown).data,
        buildLargeDocumentSample(),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

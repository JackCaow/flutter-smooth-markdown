import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'diff snippets remain visible until unified hunks are available',
    (tester) async {
      Future<void> show(String patch) => tester.pumpWidget(
        MaterialApp(
          home: MarkdownDiffView(patch: patch, language: 'dart'),
        ),
      );
      await show('-old\n+new');
      expect(find.textContaining('-old', findRichText: true), findsOneWidget);
      expect(find.textContaining('+new', findRichText: true), findsOneWidget);
      await show('--- a/test.dart\n+++ b/test.dart');
      expect(
        find.textContaining('+++ b/test.dart', findRichText: true),
        findsOneWidget,
      );
      await show('--- a/test.dart\n+++ b/test.dart\n@@ -1 +1 @@\n-old\n+new\n');
      expect(find.byType(MarkdownCodeView), findsNothing);
      expect(find.textContaining('new', findRichText: true), findsOneWidget);
    },
  );
  testWidgets(
    'source and diff viewers fit a narrow viewport and update their input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MarkdownCodeView(
                    code:
                        '/* comment\nend */\n${'const longName = 123; ' * 30}',
                    language: 'dart',
                  ),
                  const MarkdownDiffView(
                    patch: '@@ -1 +1 @@\n-int before = 1;\n+int after = 2;\n',
                    language: 'dart',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(SelectionArea), findsNWidgets(2));
      expect(
        find.textContaining('int after', findRichText: true),
        findsOneWidget,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: MarkdownDiffView(
            patch: '@@ -2 +2 @@\n-old\n+replacement\n',
            language: 'dart',
            selectable: false,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('replacement', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('semantic theme preserves defaults when adding an override', () {
    final theme = MarkdownSyntaxTheme.fromBrightness(Brightness.light).copyWith(
      styles: {
        MarkdownHighlightKind.variableParameter: const TextStyle(
          color: Colors.pink,
        ),
      },
    );
    expect(
      theme.styleFor(MarkdownHighlightKind.variableParameter)!.color,
      Colors.pink,
    );
    expect(theme.styleFor(MarkdownHighlightKind.keywordControl), isNotNull);
  });
}

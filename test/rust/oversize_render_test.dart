import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/rust/core_types.dart'
    show maxNativeSourceUnits;
import 'package:flutter_smooth_markdown/widgets/markdown_code_view.dart'
    show CodeRowsView;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final body = 'a' * (maxNativeSourceUnits - 1) + '🙂';

  testWidgets('automatic oversized fences keep all code in both builders', (
    tester,
  ) async {
    expect(body.length, maxNativeSourceUnits + 1);
    final document = '```dart\n$body\n```';
    for (final enhanced in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: SmoothMarkdown(
            data: document,
            enableCache: false,
            useEnhancedComponents: enhanced,
          ),
        ),
        // Exercise the parser, builder and text spans without benchmarking
        // Flutter's glyph layout for an eight-million-character line.
        phase: EnginePhase.build,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widgetList<RichText>(find.byType(RichText))
            .any((widget) => widget.text.toPlainText() == body),
        isTrue,
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'oversized source lines preserve content, tab width and line endings',
    () {
      final source = '$body\r\n\tend\r\n\n';
      expect(MarkdownCore.highlightedCode(source, language: 'dart'), isEmpty);
      for (final width in [0, 2]) {
        final lines = MarkdownCore.highlightedLines(
          source,
          language: 'dart',
          tabWidth: width,
        );
        expect(lines.length, 3);
        expect(lines.first.text == body, isTrue);
        expect(lines[1].text, width == 0 ? '\tend' : '  end');
        expect(lines.last.text, isEmpty);
        expect(lines.every((line) => line.tokens.isEmpty), isTrue);
      }
      expect(
        () => MarkdownCore.highlightedLines(
          source,
          language: 'dart',
          tabWidth: 17,
        ),
        throwsRangeError,
      );
    },
  );

  testWidgets('oversized diffs keep unified hunks and their code rows', (
    tester,
  ) async {
    final patch = 'diff --git a/$body b/test\n@@ -3 +5 @@\n-old\n+\tnew\n';
    final rows = MarkdownCore.highlightedDiff(patch, language: 'dart');
    expect(rows.map((row) => row.kind), [
      MarkdownDiffKind.hunk,
      MarkdownDiffKind.removed,
      MarkdownDiffKind.added,
    ]);
    expect(rows[1].oldLineNumber, 3);
    expect(rows[2].newLineNumber, 5);
    expect(rows[2].line.text, '    new');
    expect(rows.every((row) => row.line.tokens.isEmpty), isTrue);
    expect(
      () => MarkdownCore.highlightedDiff(patch, language: 'dart', tabWidth: -1),
      throwsRangeError,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MarkdownDiffView(patch: patch, language: 'dart'),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('    new', findRichText: true), findsOneWidget);
  });

  testWidgets('oversized diff snippets keep their original source rows', (
    tester,
  ) async {
    final patch = '-old\n+$body';
    await tester.pumpWidget(
      MaterialApp(
        home: MarkdownDiffView(patch: patch, language: 'dart'),
      ),
      phase: EnginePhase.build,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(MarkdownCodeView), findsOneWidget);
    final rows = tester.widget<CodeRowsView>(find.byType(CodeRowsView)).rows;
    expect(rows.first.line.text, '-old');
    expect(rows.last.line.text == '+$body', isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

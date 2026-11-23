import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

const _patch = '''@@ -7,4 +23,3 @@
 context
-old red value
-old spare
+new red value
 tail
@@ -41,0 +96,1 @@
+inserted
\\ No newline at end of file
''';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  for (final layout in MarkdownDiffLayout.values) {
    testWidgets('${layout.name} builds viewport rows of a 4000-line patch', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final patch = [
        '@@ -1,4000 +1,4000 @@',
        for (var i = 1; i <= 4000; i++) ' unchanged line $i',
      ].join('\n');
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            controller: controller,
            slivers: [
              const SliverToBoxAdapter(child: Text('Review')),
              MarkdownDiffView.sliver(
                patch: patch,
                language: 'text',
                layout: layout,
              ),
            ],
          ),
        ),
      );
      final visible = find.textContaining('unchanged line', findRichText: true);
      expect(visible.evaluate().length, inInclusiveRange(1, 130));
      expect(
        find.text('unchanged line 3999', findRichText: true),
        findsNothing,
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.text('unchanged line 3999', findRichText: true),
        findsWidgets,
      );
      expect(find.text('unchanged line 1', findRichText: true), findsNothing);
      expect(visible.evaluate().length, inInclusiveRange(1, 130));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'side-by-side aligns only same-hunk change runs and keeps metadata once',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const CustomScrollView(
            slivers: [
              MarkdownDiffView.sliver(
                patch: _patch,
                language: 'dart',
                layout: MarkdownDiffLayout.sideBySide,
              ),
            ],
          ),
        ),
      );
      final old = find.text('old red value', findRichText: true);
      final added = find.text('new red value', findRichText: true);
      final spare = find.text('old spare', findRichText: true);
      final inserted = find.text('inserted', findRichText: true);
      expect(tester.getTopLeft(old).dy, tester.getTopLeft(added).dy);
      expect(tester.getTopLeft(old).dx, lessThan(tester.getTopLeft(added).dx));
      expect(
        tester.getTopLeft(spare).dy,
        greaterThan(tester.getTopLeft(old).dy),
      );
      expect(tester.getTopLeft(inserted).dx, tester.getTopLeft(added).dx);
      expect(find.bySemanticsLabel(RegExp('Original line 8')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Modified line 24')), findsOneWidget);
      expect(find.text('context', findRichText: true), findsNWidgets(2));
      expect(find.text('tail', findRichText: true), findsNWidgets(2));
      expect(
        find.text('@@ -41,0 +96,1 @@', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('No newline at end of file', findRichText: true),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inline split preserves multiline selection and syntax theme', (
    tester,
  ) async {
    const theme = MarkdownSyntaxTheme(
      addedChangeBackground: Colors.green,
      removedChangeBackground: Colors.red,
    );
    await tester.pumpWidget(
      _app(
        const SingleChildScrollView(
          child: MarkdownDiffView(
            patch: _patch,
            language: 'dart',
            layout: MarkdownDiffLayout.sideBySide,
            syntaxTheme: theme,
          ),
        ),
      ),
    );
    expect(find.byType(SelectionArea), findsOneWidget);
    for (final (text, color) in [
      ('old red value', Colors.red),
      ('new red value', Colors.green),
    ]) {
      final widget = tester.widget<Text>(
        find.byWidgetPredicate(
          (candidate) =>
              candidate is Text && candidate.textSpan?.toPlainText() == text,
        ),
      );
      final span = widget.textSpan! as TextSpan;
      expect(
        span.children!.any((s) => s.style?.backgroundColor == color),
        isTrue,
      );
    }
    await tester.pumpWidget(
      _app(
        const CustomScrollView(
          slivers: [
            MarkdownDiffView.sliver(
              patch: _patch,
              language: 'text',
              layout: MarkdownDiffLayout.sideBySide,
              selectable: true,
            ),
          ],
        ),
      ),
    );
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.byType(SliverToBoxAdapter), findsOneWidget);
  });

  testWidgets(
    'EOF annotations preserve replacement alignment and hunk boundaries',
    (tester) async {
      const note = r'\ No newline at end of file';
      const patch =
          '@@ -1,2 +1,2 @@\n-first\n-last\n$note\n+one\n+two\n$note\n'
          '@@ -9 +10 @@\n-later\n+newer';
      Future<void> show(MarkdownDiffLayout layout) => tester.pumpWidget(
        _app(
          CustomScrollView(
            slivers: [
              MarkdownDiffView.sliver(
                patch: patch,
                language: 'text',
                layout: layout,
              ),
            ],
          ),
        ),
      );
      double top(String text) =>
          tester.getTopLeft(find.text(text, findRichText: true)).dy;
      await show(MarkdownDiffLayout.sideBySide);
      expect(top('first'), top('one'));
      expect(top('last'), top('two'));
      expect(top('later'), top('newer'));
      final notes = find.textContaining('No newline', findRichText: true);
      expect(notes, findsNWidgets(2));
      expect(tester.getTopLeft(notes.first).dy, greaterThan(top('last')));
      expect(tester.getTopLeft(notes.last).dy, lessThan(top('later')));
      await show(MarkdownDiffLayout.unified);
      expect(tester.getTopLeft(notes.first).dy, lessThan(top('one')));
      expect(tester.getTopLeft(notes.last).dy, greaterThan(top('two')));
    },
  );

  testWidgets(
    'lazy split preserves raw snippets and updates source and layout',
    (tester) async {
      Future<void> show(String patch, MarkdownDiffLayout layout) =>
          tester.pumpWidget(
            _app(
              CustomScrollView(
                slivers: [
                  MarkdownDiffView.sliver(
                    patch: patch,
                    language: 'text',
                    layout: layout,
                    showLineNumbers: false,
                  ),
                ],
              ),
            ),
          );
      await show('-pending\n+unified', MarkdownDiffLayout.sideBySide);
      expect(find.text('-pending', findRichText: true), findsOneWidget);
      expect(find.text('+unified', findRichText: true), findsOneWidget);
      expect(find.text('1'), findsNothing);
      await show(_patch, MarkdownDiffLayout.sideBySide);
      expect(find.text('context', findRichText: true), findsNWidgets(2));
      await show(_patch, MarkdownDiffLayout.unified);
      expect(find.text('context', findRichText: true), findsOneWidget);
      await show('', MarkdownDiffLayout.sideBySide);
      expect(find.text('context', findRichText: true), findsNothing);
    },
  );
}

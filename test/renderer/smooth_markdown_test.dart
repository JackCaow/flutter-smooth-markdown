import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// Custom finder that finds RichText widgets containing the specified text
Finder findRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is RichText) {
        final textSpan = widget.text;
        return textSpan.toPlainText().contains(text);
      }
      return false;
    },
    description: 'RichText containing "$text"',
  );
}

Color? findRichTextColorContaining(WidgetTester tester, String text) {
  for (final element in findRichTextContaining(text).evaluate()) {
    final widget = element.widget;
    if (widget is RichText) {
      final color = _spanColorContaining(widget.text, text);
      if (color != null) return color;
    }
  }
  return null;
}

Color? _spanColorContaining(InlineSpan span, String text) {
  if (span is TextSpan) {
    if ((span.text?.contains(text) ?? false) && span.style?.color != null) {
      return span.style!.color;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      final color = _spanColorContaining(child, text);
      if (color != null) return color;
    }
    if (span.toPlainText().contains(text)) {
      return span.style?.color;
    }
  }
  return null;
}

void main() {
  group('SmoothMarkdown Widget Tests', () {
    testWidgets('should render simple text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: 'Hello World',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('Hello World'), findsOneWidget);
    });

    testWidgets('defaults to the surrounding dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: SmoothMarkdown(
              data: 'Hello World',
              useRepaintBoundary: false,
              enableCache: false,
            ),
          ),
        ),
      );

      final color = findRichTextColorContaining(tester, 'Hello World');

      expect(color, isNotNull);
      expect(color!.computeLuminance(), greaterThan(0.5));
    });

    testWidgets('should render header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '# Header 1',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('Header 1'), findsOneWidget);
    });

    testWidgets('should render bold text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '**Bold text**',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('Bold text'), findsOneWidget);
    });

    testWidgets('should render italic text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '*Italic text*',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('Italic text'), findsOneWidget);
    });

    testWidgets('should render inline code', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: 'Code: `var x = 1;`',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('Code:'), findsOneWidget);
      expect(findRichTextContaining('var x = 1;'), findsOneWidget);
    });

    testWidgets('should render hard line breaks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: 'First\\\nSecond',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('First\nSecond'), findsOneWidget);
    });

    testWidgets('enhanced components should render math nodes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: r'Inline $x^2$.'
                '\n\n'
                r'$$'
                '\nE = mc^2\n'
                r'$$',
            useEnhancedComponents: true,
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Unknown node type'), findsNothing);
    });

    testWidgets('should render code block', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '''
```dart
void main() {
  print('Hello');
}
```
''',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(find.textContaining('void main()'), findsOneWidget);
    });

    testWidgets('should render list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '''
- Item 1
- Item 2
- Item 3
''',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('Item 1'), findsOneWidget);
      expect(findRichTextContaining('Item 2'), findsOneWidget);
      expect(findRichTextContaining('Item 3'), findsOneWidget);
      expect(find.text('• '), findsNWidgets(3));
    });

    testWidgets('should render ordered list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '''
1. First
2. Second
3. Third
''',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('First'), findsOneWidget);
      expect(findRichTextContaining('Second'), findsOneWidget);
      expect(findRichTextContaining('Third'), findsOneWidget);
      expect(find.text('1. '), findsOneWidget);
      expect(find.text('2. '), findsOneWidget);
      expect(find.text('3. '), findsOneWidget);
    });

    testWidgets('should render task list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '''
- [x] Completed task
- [ ] Pending task
''',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('Completed task'), findsOneWidget);
      expect(findRichTextContaining('Pending task'), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    });

    testWidgets('should render blockquote', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '> This is a quote',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('This is a quote'), findsOneWidget);
    });

    testWidgets('should render horizontal rule', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '''
Text above

---

Text below
''',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('Text above'), findsOneWidget);
      expect(findRichTextContaining('Text below'), findsOneWidget);
    });

    testWidgets('should render link', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '[Click here](https://example.com)',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('Click here'), findsOneWidget);
    });

    testWidgets('should call onTapLink callback', (tester) async {
      String? tappedUrl;

      await tester.pumpWidget(
        MaterialApp(
          home: SmoothMarkdown(
            data: '[Link](https://example.com)',
            useRepaintBoundary: false,
            enableCache: false,
            onTapLink: (url) {
              tappedUrl = url;
            },
          ),
        ),
      );

      await tester.tap(findRichTextContaining('Link'));
      expect(tappedUrl, 'https://example.com');
    });

    testWidgets('should use custom style sheet', (tester) async {
      const customStyleSheet = MarkdownStyleSheet(
        h1Style: TextStyle(fontSize: 48),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '# Big Header',
            styleSheet: customStyleSheet,
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('Big Header'), findsOneWidget);
      final richTextWidget =
          tester.widget<RichText>(findRichTextContaining('Big Header'));
      final textSpan = richTextWidget.text as TextSpan;
      expect(textSpan.style?.fontSize, 48);
    });

    testWidgets('should render complex markdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '''
# Title

This is a paragraph with **bold** and *italic* text.

## List

- Item 1
- Item 2

```dart
void main() {
  print('Hello');
}
```

> Quote
''',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      expect(findRichTextContaining('Title'), findsOneWidget);
      expect(findRichTextContaining('bold'), findsOneWidget);
      expect(findRichTextContaining('italic'), findsOneWidget);
      expect(findRichTextContaining('List'), findsOneWidget);
      expect(findRichTextContaining('Item 1'), findsOneWidget);
      expect(findRichTextContaining('Quote'), findsOneWidget);
    });

    testWidgets('should use custom code builder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SmoothMarkdown(
            data: '```dart\ncode\n```',
            useRepaintBoundary: false,
            enableCache: false,
            codeBuilder: (code, language) {
              return Text('Custom: $code ($language)');
            },
          ),
        ),
      );

      expect(find.textContaining('Custom: code'), findsOneWidget);
    });

    testWidgets('should expose only the first code info token as language',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SmoothMarkdown(
            data: '```dart title=main.dart\ncode\n```',
            useRepaintBoundary: false,
            enableCache: false,
            codeBuilder: (code, language) {
              return Text('Custom: $code ($language)');
            },
          ),
        ),
      );

      expect(find.text('Custom: code (dart)'), findsOneWidget);
    });

    testWidgets('should use custom image builder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SmoothMarkdown(
            data: '![Alt](image.png)',
            useRepaintBoundary: false,
            enableCache: false,
            imageBuilder: (url, alt, title) {
              return Text('Image: $url');
            },
          ),
        ),
      );

      // Image is rendered via WidgetSpan inside RichText
      expect(findRichTextContaining('Image: image.png'), findsOneWidget);
    });

    testWidgets('should handle empty markdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      // Should not throw any errors
      expect(find.byType(SmoothMarkdown), findsOneWidget);
    });

    testWidgets('should handle whitespace-only markdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SmoothMarkdown(
            data: '   \n\n   ',
            useRepaintBoundary: false,
            enableCache: false,
          ),
        ),
      );

      // Should not throw any errors
      expect(find.byType(SmoothMarkdown), findsOneWidget);
    });
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/src/config/markdown_config.dart';
import 'package:flutter_smooth_markdown/widgets/stream_markdown.dart';
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

void main() {
  group('StreamMarkdown Widget Tests', () {
    testWidgets('should show loading widget when stream has no data',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
            loadingWidget: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show SizedBox.shrink when no loadingWidget provided',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('should render content after stream emits text',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
          ),
        ),
      );

      controller.add('Hello World');
      // Pump to process the stream event and trigger setState
      await tester.pump();
      // Pump again to allow throttle timer to fire if needed
      await tester.pump(const Duration(milliseconds: 100));

      expect(findRichTextContaining('Hello World'), findsOneWidget);
    });

    testWidgets('should accumulate multiple stream chunks', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
          ),
        ),
      );

      controller.add('# Title\n\n');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(findRichTextContaining('Title'), findsOneWidget);

      controller.add('Some **bold** text');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both the title and the new text should be present
      expect(findRichTextContaining('Title'), findsOneWidget);
      expect(findRichTextContaining('bold'), findsOneWidget);
    });

    testWidgets('should show error widget via errorBuilder on stream error',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
            errorBuilder: (error) => Text('Error: $error'),
          ),
        ),
      );

      controller.addError('something went wrong');
      await tester.pump();

      expect(find.text('Error: something went wrong'), findsOneWidget);
    });

    testWidgets('should reset content when stream changes via didUpdateWidget',
        (tester) async {
      final controller1 = StreamController<String>();
      final controller2 = StreamController<String>();
      addTearDown(controller1.close);
      addTearDown(controller2.close);

      // Build with the first stream
      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller1.stream,
          ),
        ),
      );

      // Emit content on first stream
      controller1.add('First stream content');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(findRichTextContaining('First stream content'), findsOneWidget);

      // Switch to second stream
      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller2.stream,
          ),
        ),
      );

      // Old content should be gone (shows loading/empty state)
      expect(
          findRichTextContaining('First stream content'), findsNothing);

      // Emit on the new stream
      controller2.add('Second stream content');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(findRichTextContaining('Second stream content'), findsOneWidget);
    });

    testWidgets('should dispose subscription without errors', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
          ),
        ),
      );

      controller.add('Some text');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Remove the widget from the tree, triggering dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(),
        ),
      );

      // Adding to the stream after dispose should not throw
      controller.add('After dispose');
      await tester.pump();

      // No errors means disposal was clean
      expect(find.byType(StreamMarkdown), findsNothing);
    });

    testWidgets('should render markdown syntax correctly', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
          ),
        ),
      );

      controller.add('# Header\n\n- Item 1\n- Item 2');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(findRichTextContaining('Header'), findsOneWidget);
      expect(findRichTextContaining('Item 1'), findsOneWidget);
      expect(findRichTextContaining('Item 2'), findsOneWidget);
    });
  });

  group('HTML tail withholding', () {
    testWidgets(
        'does not swallow partial tag when HTML is disabled (default) '
        '(regression: `lead <font colo`)', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          // No config -> enableHtml defaults to false.
          home: StreamMarkdown(stream: controller.stream),
        ),
      );

      controller.add('lead <font colo');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The partial tag is ordinary prose and must render verbatim rather
      // than being withheld up to the last `<`.
      expect(findRichTextContaining('lead'), findsOneWidget);
      expect(findRichTextContaining('font colo'), findsOneWidget);
    });

    testWidgets(
        'does not swallow a trailing single `<` when HTML is disabled',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(stream: controller.stream),
        ),
      );

      controller.add('count is 5 <');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // A bare trailing `<` must not be dropped from the rendered text.
      expect(findRichTextContaining('5 <'), findsOneWidget);
    });

    testWidgets(
        'does not swallow `<` followed by letters in prose when HTML is '
        'disabled', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(stream: controller.stream),
        ),
      );

      controller.add('see <bold formatting here');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Even a `<` directly followed by letters renders as literal prose.
      expect(findRichTextContaining('<bold'), findsOneWidget);
      expect(findRichTextContaining('formatting'), findsOneWidget);
    });

    testWidgets('still withholds a partial tag when HTML is enabled',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
            config: const MarkdownConfig(enableHtml: true),
          ),
        ),
      );

      controller.add('lead <font colo');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // While the `<font ...` tag is still split across chunks, it is
      // withheld so the partial tag is not flashed as literal text.
      expect(findRichTextContaining('font colo'), findsNothing);
      expect(findRichTextContaining('lead'), findsOneWidget);

      // Complete the tag in the next chunk; now it parses and renders.
      controller.add('r="red">done</font>');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(findRichTextContaining('done'), findsOneWidget);
    });

    testWidgets(
        'does not withhold text after inline code containing `<` '
        '(regression: Use `List<T` here.)', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
            config: const MarkdownConfig(enableHtml: true),
          ),
        ),
      );

      // The `<` sits inside a closed inline code span, so it is literal code
      // rather than the start of an unclosed HTML tag. The whole line must
      // render immediately, and the stream stays open.
      controller.add('Use `List<T` here.');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(findRichTextContaining('List<T'), findsOneWidget);
      expect(findRichTextContaining('here.'), findsOneWidget);
    });

    testWidgets('does not withhold text after a fenced code block with `<`',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
            config: const MarkdownConfig(enableHtml: true),
          ),
        ),
      );

      // `<T` has no closing `>`, but it lives inside a fenced code block, so
      // it must not be treated as an unclosed tag that swallows the code and
      // the closing fence.
      controller.add('```dart\nList<T items;\n```');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('List<T items;'), findsOneWidget);
    });

    testWidgets('still withholds an unclosed tag after inline code',
        (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: StreamMarkdown(
            stream: controller.stream,
            config: const MarkdownConfig(enableHtml: true),
          ),
        ),
      );

      controller.add('Use `List<T` here. <font colo');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The code renders, while the genuinely unclosed `<font` tag is still
      // withheld until its `>` arrives.
      expect(findRichTextContaining('List<T'), findsOneWidget);
      expect(findRichTextContaining('here.'), findsOneWidget);
      expect(findRichTextContaining('font colo'), findsNothing);

      controller.add('r="red">done</font>');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(findRichTextContaining('done'), findsOneWidget);
      expect(findRichTextContaining('List<T'), findsOneWidget);
    });
  });
}

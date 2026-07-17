import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/image_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final styleSheet = MarkdownStyleSheet.light();
  const renderContext = MarkdownRenderContext();

  Finder findRichTextContaining(String text) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(text),
    );
  }

  Finder findAnyTextContaining(String text) {
    return find.byWidgetPredicate(
      (widget) =>
          (widget is Text && (widget.data?.contains(text) ?? false)) ||
          (widget is RichText && widget.text.toPlainText().contains(text)),
    );
  }

  group('UnderlineBuilder', () {
    const builder = UnderlineBuilder();

    test('builds only underline nodes', () {
      expect(builder.canBuild(const UnderlineNode([TextNode('u')])), isTrue);
      expect(builder.canBuild(const TextNode('u')), isFalse);
    });

    testWidgets('applies underline decoration', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: builder.build(
          const UnderlineNode([TextNode('under')]),
          styleSheet,
          renderContext,
        ),
      ));
      final text = tester.widget<Text>(find.text('under'));
      expect(text.style?.decoration, TextDecoration.underline);
    });
  });

  group('HighlightBuilder', () {
    const builder = HighlightBuilder();

    test('builds only highlight nodes', () {
      expect(builder.canBuild(const HighlightNode([TextNode('m')])), isTrue);
      expect(builder.canBuild(const BoldNode([TextNode('m')])), isFalse);
    });

    testWidgets('applies background highlight color', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: builder.build(
          const HighlightNode([TextNode('marked')]),
          styleSheet,
          renderContext,
        ),
      ));
      final text = tester.widget<Text>(find.text('marked'));
      expect(text.style?.backgroundColor, isNotNull);
    });
  });

  group('SubscriptBuilder and SuperscriptBuilder', () {
    testWidgets('superscript shifts content upward', (tester) async {
      const builder = SuperscriptBuilder();
      await tester.pumpWidget(MaterialApp(
        home: builder.build(
          const SuperscriptNode([TextNode('2')]),
          styleSheet,
          renderContext,
        ),
      ));
      final transform = tester.widget<Transform>(find.byType(Transform));
      expect(transform.transform.getTranslation().y, lessThan(0));
    });

    testWidgets('subscript shifts content downward', (tester) async {
      const builder = SubscriptBuilder();
      await tester.pumpWidget(MaterialApp(
        home: builder.build(
          const SubscriptNode([TextNode('2')]),
          styleSheet,
          renderContext,
        ),
      ));
      final transform = tester.widget<Transform>(find.byType(Transform));
      expect(transform.transform.getTranslation().y, greaterThan(0));
    });

    testWidgets('scales sub and sup text below base size', (tester) async {
      const builder = SuperscriptBuilder();
      await tester.pumpWidget(MaterialApp(
        home: builder.build(
          const SuperscriptNode([TextNode('2')]),
          styleSheet,
          renderContext,
        ),
      ));
      final text = tester.widget<Text>(find.text('2'));
      final baseSize = styleSheet.textStyle?.fontSize ?? 16;
      expect(text.style?.fontSize, lessThan(baseSize));
    });
  });

  group('KbdBuilder', () {
    const builder = KbdBuilder();

    test('builds only kbd nodes', () {
      expect(builder.canBuild(const KbdNode([TextNode('K')])), isTrue);
      expect(builder.canBuild(const TextNode('K')), isFalse);
    });

    testWidgets('renders bordered container around key text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: builder.build(
          const KbdNode([TextNode('Ctrl')]),
          styleSheet,
          renderContext,
        ),
      ));
      expect(find.text('Ctrl'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
    });
  });

  group('StyledSpanBuilder', () {
    const builder = StyledSpanBuilder();

    testWidgets('applies parsed color and font size', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: builder.build(
          const StyledSpanNode(
            children: [TextNode('styled')],
            color: 0xFFFF0000,
            fontSize: 20,
          ),
          styleSheet,
          renderContext,
        ),
      ));
      final text = tester.widget<Text>(find.text('styled'));
      expect(text.style?.color, const Color(0xFFFF0000));
      expect(text.style?.fontSize, 20);
    });

    testWidgets('leaves unset style properties null for inheritance',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: builder.build(
          const StyledSpanNode(
            children: [TextNode('styled')],
            color: 0xFF0000FF,
          ),
          styleSheet,
          renderContext,
        ),
      ));
      final text = tester.widget<Text>(find.text('styled'));
      expect(text.style?.fontSize, isNull);
      expect(text.style?.backgroundColor, isNull);
    });
  });

  group('HtmlBlockBuilder', () {
    const builder = HtmlBlockBuilder();

    test('builds only html block nodes', () {
      expect(
        builder.canBuild(const HtmlBlockNode(tag: 'div', children: [])),
        isTrue,
      );
      expect(builder.canBuild(const TextNode('x')), isFalse);
    });

    testWidgets('renders content without alignment wrapper by default',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: builder.build(
          const HtmlBlockNode(tag: 'div', children: [TextNode('plain')]),
          styleSheet,
          renderContext,
        ),
      ));
      expect(find.text('plain'), findsOneWidget);
      expect(find.byType(Align), findsNothing);
    });

    testWidgets('wraps centered blocks in an alignment widget', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: builder.build(
          const HtmlBlockNode(
            tag: 'center',
            children: [TextNode('centered')],
            align: HtmlBlockAlignment.center,
          ),
          styleSheet,
          renderContext,
        ),
      ));
      expect(find.byType(Align), findsOneWidget);
      expect(find.byType(IntrinsicWidth), findsOneWidget);
    });
  });

  group('ImageBuilder dimensions', () {
    testWidgets('constrains size from width and height', (tester) async {
      const builder = ImageBuilder();
      await tester.pumpWidget(MaterialApp(
        home: builder.build(
          const ImageNode(
            url: 'assets/missing.png',
            alt: 'a',
            width: 64,
            height: 32,
          ),
          styleSheet,
          renderContext,
        ),
      ));
      final sized = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 64,
        ),
      );
      expect(sized.height, 32);
    });
  });

  group('builder registration coverage', () {
    const htmlFixture = '<u>u</u> <mark>m</mark> <sub>s</sub> '
        '<sup>p</sup> <kbd>K</kbd> '
        '<span style="color:red">c</span> <b>b</b><br>x\n\n'
        '<center>centered</center>\n\n'
        '<div align="right">right</div>\n\n'
        '<hr>';

    Widget wrap(Widget child) {
      return MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );
    }

    testWidgets('default registry renders every html node type',
        (tester) async {
      await tester.pumpWidget(wrap(const SmoothMarkdown(
        data: htmlFixture,
        config: MarkdownConfig(enableHtml: true),
        enableCache: false,
        useRepaintBoundary: false,
      )));
      expect(findAnyTextContaining('Unknown node type'), findsNothing);
      expect(findRichTextContaining('centered'), findsOneWidget);
    });

    testWidgets('enhanced registry renders every html node type',
        (tester) async {
      await tester.pumpWidget(wrap(const SmoothMarkdown(
        data: htmlFixture,
        config: MarkdownConfig(enableHtml: true),
        useEnhancedComponents: true,
        enableCache: false,
        useRepaintBoundary: false,
      )));
      expect(findAnyTextContaining('Unknown node type'), findsNothing);
    });

    testWidgets('html stays literal without config', (tester) async {
      await tester.pumpWidget(wrap(const SmoothMarkdown(
        data: '<mark>m</mark>',
        enableCache: false,
        useRepaintBoundary: false,
      )));
      expect(findRichTextContaining('<mark>m</mark>'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/src/config/style_sheet.dart';
import 'package:flutter_smooth_markdown/src/parser/ast/markdown_node.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/blockquote_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/code_block_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/hard_break_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/header_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/horizontal_rule_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/image_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/inline_code_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/link_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/list_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/paragraph_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/text_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/builders/text_style_builder.dart';
import 'package:flutter_smooth_markdown/src/renderer/markdown_renderer.dart';
import 'package:flutter_smooth_markdown/src/renderer/widget_builder.dart';
import 'package:flutter_test/flutter_test.dart';

Finder findRichTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is RichText) {
        return widget.text.toPlainText().contains(text);
      }
      return false;
    },
    description: 'RichText containing "$text"',
  );
}

void main() {
  group('Widget Builder Tests', () {
    late MarkdownStyleSheet styleSheet;
    late MarkdownRenderContext context;

    setUp(() {
      styleSheet = MarkdownStyleSheet.light();
      context = const MarkdownRenderContext();
    });

    group('TextBuilder', () {
      test('should accept TextNode', () {
        const builder = TextBuilder();
        const node = TextNode('test');
        expect(builder.canBuild(node), true);
      });

      test('should reject other nodes', () {
        const builder = TextBuilder();
        const node = HeaderNode(level: 1, content: 'Test');
        expect(builder.canBuild(node), false);
      });

      testWidgets('should build text widget', (tester) async {
        const builder = TextBuilder();
        const node = TextNode('Hello World');

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('Hello World'), findsOneWidget);
      });
    });

    group('HeaderBuilder', () {
      test('should accept HeaderNode', () {
        const builder = HeaderBuilder();
        const node = HeaderNode(level: 1, content: 'Test');
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build header widget', (tester) async {
        const builder = HeaderBuilder();
        const node = HeaderNode(level: 1, content: 'Test Header');

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('Test Header'), findsOneWidget);
      });
    });

    group('ParagraphBuilder', () {
      test('should accept ParagraphNode', () {
        const builder = ParagraphBuilder();
        const node = ParagraphNode(<MarkdownNode>[]);
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build paragraph widget', (tester) async {
        const builder = ParagraphBuilder();
        const node = ParagraphNode(<MarkdownNode>[
          TextNode('Test paragraph'),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('Test paragraph'), findsOneWidget);
      });
    });

    group('BoldBuilder', () {
      test('should accept BoldNode', () {
        const builder = BoldBuilder();
        const node = BoldNode(<MarkdownNode>[]);
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build bold widget', (tester) async {
        const builder = BoldBuilder();
        const node = BoldNode(<MarkdownNode>[
          TextNode('Bold text'),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('Bold text'), findsOneWidget);
      });
    });

    group('ItalicBuilder', () {
      test('should accept ItalicNode', () {
        const builder = ItalicBuilder();
        const node = ItalicNode(<MarkdownNode>[]);
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build italic widget', (tester) async {
        const builder = ItalicBuilder();
        const node = ItalicNode(<MarkdownNode>[
          TextNode('Italic text'),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('Italic text'), findsOneWidget);
      });
    });

    group('StrikethroughBuilder', () {
      test('should accept StrikethroughNode', () {
        const builder = StrikethroughBuilder();
        const node = StrikethroughNode(<MarkdownNode>[]);
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build strikethrough widget', (tester) async {
        const builder = StrikethroughBuilder();
        const node = StrikethroughNode(<MarkdownNode>[
          TextNode('Strikethrough text'),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('Strikethrough text'), findsOneWidget);
      });
    });

    group('InlineCodeBuilder', () {
      test('should accept InlineCodeNode', () {
        const builder = InlineCodeBuilder();
        const node = InlineCodeNode('test');
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build inline code widget', (tester) async {
        const builder = InlineCodeBuilder();
        const node = InlineCodeNode('var x = 1;');

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('var x = 1;'), findsOneWidget);
      });
    });

    group('HardBreakBuilder', () {
      test('should accept HardBreakNode', () {
        const builder = HardBreakBuilder();
        const node = HardBreakNode();
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build newline text widget', (tester) async {
        const builder = HardBreakBuilder();
        const node = HardBreakNode();

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('\n'), findsOneWidget);
      });
    });

    group('CodeBlockBuilder', () {
      test('should accept CodeBlockNode', () {
        const builder = CodeBlockBuilder();
        const node = CodeBlockNode(code: 'test');
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build code block widget', (tester) async {
        const builder = CodeBlockBuilder();
        const node = CodeBlockNode(code: 'print("Hello");', language: 'dart');

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('print("Hello");'), findsOneWidget);
      });

      testWidgets('should use custom code builder', (tester) async {
        const builder = CodeBlockBuilder();
        const node = CodeBlockNode(code: 'test code', language: 'js');
        final customContext = MarkdownRenderContext(
          codeBuilder: (code, language) => Text('Custom: $code'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, customContext),
          ),
        );

        expect(find.text('Custom: test code'), findsOneWidget);
      });
    });

    group('BlockquoteBuilder', () {
      test('should accept BlockquoteNode', () {
        const builder = BlockquoteBuilder();
        const node = BlockquoteNode(<MarkdownNode>[]);
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build blockquote widget', (tester) async {
        const builder = BlockquoteBuilder();
        const node = BlockquoteNode(<MarkdownNode>[
          ParagraphNode(<MarkdownNode>[TextNode('Quote text')]),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('Quote text'), findsOneWidget);
      });
    });

    group('ListBuilder', () {
      test('should accept ListNode', () {
        const builder = ListBuilder();
        const node = ListNode(items: <ListItemNode>[]);
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build unordered list', (tester) async {
        const builder = ListBuilder();
        const node = ListNode(items: <ListItemNode>[
          ListItemNode(children: <MarkdownNode>[TextNode('Item 1')]),
          ListItemNode(children: <MarkdownNode>[TextNode('Item 2')]),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        expect(find.text('• '), findsNWidgets(2));
      });

      testWidgets('should build ordered list', (tester) async {
        const builder = ListBuilder();
        const node = ListNode(
          ordered: true,
          startIndex: 1,
          items: <ListItemNode>[
            ListItemNode(children: <MarkdownNode>[TextNode('First')]),
            ListItemNode(children: <MarkdownNode>[TextNode('Second')]),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('First'), findsOneWidget);
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('1. '), findsOneWidget);
        expect(find.text('2. '), findsOneWidget);
      });

      testWidgets('should build task list', (tester) async {
        const builder = ListBuilder();
        const node = ListNode(items: <ListItemNode>[
          ListItemNode(
              children: <MarkdownNode>[TextNode('Task 1')], checked: true),
          ListItemNode(
              children: <MarkdownNode>[TextNode('Task 2')], checked: false),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('Task 1'), findsOneWidget);
        expect(find.text('Task 2'), findsOneWidget);
        expect(find.byIcon(Icons.check_box), findsOneWidget);
        expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
      });

      testWidgets('should build nested unordered list', (tester) async {
        const builder = ListBuilder();
        const node = ListNode(items: <ListItemNode>[
          ListItemNode(
            children: <MarkdownNode>[
              TextNode('Parent'),
              ListNode(
                items: <ListItemNode>[
                  ListItemNode(children: <MarkdownNode>[TextNode('Child')]),
                  ListItemNode(children: <MarkdownNode>[TextNode('Sibling')]),
                ],
              ),
            ],
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('Parent'), findsOneWidget);
        expect(find.text('Child'), findsOneWidget);
        expect(find.text('Sibling'), findsOneWidget);
        expect(find.text('• '), findsNWidgets(3));
      });
    });

    group('HorizontalRuleBuilder', () {
      test('should accept HorizontalRuleNode', () {
        const builder = HorizontalRuleBuilder();
        const node = HorizontalRuleNode();
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build horizontal rule widget', (tester) async {
        const builder = HorizontalRuleBuilder();
        const node = HorizontalRuleNode();

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
      });
    });

    group('LinkBuilder', () {
      test('should accept LinkNode', () {
        const builder = LinkBuilder();
        const node =
            LinkNode(url: 'https://example.com', children: <MarkdownNode>[]);
        expect(builder.canBuild(node), true);
      });

      testWidgets('should build link widget', (tester) async {
        const builder = LinkBuilder();
        const node = LinkNode(
          url: 'https://example.com',
          children: <MarkdownNode>[TextNode('Click here')],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, context),
          ),
        );

        expect(find.text('Click here'), findsOneWidget);
      });

      testWidgets('should call onTapLink callback', (tester) async {
        const builder = LinkBuilder();
        const node = LinkNode(
          url: 'https://example.com',
          children: <MarkdownNode>[TextNode('Link')],
        );

        String? tappedUrl;
        final callbackContext = MarkdownRenderContext(
          onTapLink: (url) {
            tappedUrl = url;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, callbackContext),
          ),
        );

        await tester.tap(find.text('Link'));
        expect(tappedUrl, 'https://example.com');
      });
    });

    group('ImageBuilder', () {
      test('should accept ImageNode', () {
        const builder = ImageBuilder();
        const node = ImageNode(url: 'test.png', alt: '');
        expect(builder.canBuild(node), true);
      });

      testWidgets('should use custom image builder', (tester) async {
        const builder = ImageBuilder();
        const node = ImageNode(url: 'test.png', alt: 'Alt text');
        final customContext = MarkdownRenderContext(
          imageBuilder: (url, alt, title) => Text('Image: $url'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: builder.build(node, styleSheet, customContext),
          ),
        );

        expect(find.text('Image: test.png'), findsOneWidget);
      });
    });

    group('BuilderRegistry', () {
      test('defaults should register core builders', () {
        final registry = BuilderRegistry.defaults();
        const coreNodeTypes = [
          'text',
          'header',
          'paragraph',
          'code_block',
          'blockquote',
          'list',
          'table',
          'horizontal_rule',
          'inline_code',
          'hard_break',
          'inline_math',
          'block_math',
          'footnote_reference',
          'footnote_definition',
          'details',
          'bold',
          'italic',
          'strikethrough',
          'link',
          'image',
        ];

        for (final nodeType in coreNodeTypes) {
          expect(
            registry.hasBuilder(nodeType),
            isTrue,
            reason: 'Expected a default builder for $nodeType',
          );
        }
      });

      testWidgets('defaults should render core nodes without unknown fallback',
          (tester) async {
        final renderer = MarkdownRenderer(
          builderRegistry: BuilderRegistry.defaults(),
        );
        const nodes = <MarkdownNode>[
          HeaderNode(level: 1, content: 'Registry heading'),
          ParagraphNode(<MarkdownNode>[
            TextNode('Registry paragraph with '),
            InlineMathNode('x^2'),
          ]),
          ListNode(
            items: <ListItemNode>[
              ListItemNode(
                children: <MarkdownNode>[TextNode('Registry list item')],
              ),
            ],
          ),
          CodeBlockNode(code: 'final answer = 42;', language: 'dart'),
          BlockMathNode('E = mc^2'),
          TableNode(
            headers: <List<MarkdownNode>>[
              <MarkdownNode>[TextNode('Registry column')],
            ],
            alignments: <TableAlignment?>[TableAlignment.left],
            rows: <TableRowNode>[
              TableRowNode(
                <List<MarkdownNode>>[
                  <MarkdownNode>[TextNode('Registry cell')],
                ],
              ),
            ],
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: renderer.render(nodes),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Unknown node type'), findsNothing);
        expect(findRichTextContaining('Unknown:'), findsNothing);
        expect(find.text('Registry heading'), findsOneWidget);
        expect(
          findRichTextContaining('Registry paragraph with '),
          findsOneWidget,
        );
        expect(findRichTextContaining('Registry list item'), findsOneWidget);
        expect(find.text('final answer = 42;'), findsOneWidget);
        expect(find.byType(Table), findsOneWidget);
        expect(findRichTextContaining('Registry column'), findsOneWidget);
        expect(findRichTextContaining('Registry cell'), findsOneWidget);
      });

      test('should register and retrieve builders', () {
        final registry = BuilderRegistry();
        const builder = TextBuilder();

        registry.register('text', builder);
        expect(registry.getBuilder('text'), builder);
      });

      test('should return null for unregistered builders', () {
        final registry = BuilderRegistry();
        expect(registry.getBuilder('unknown'), isNull);
      });

      test('should find builder for node type', () {
        final registry = BuilderRegistry()
          ..register('text', const TextBuilder())
          ..register('header', const HeaderBuilder());
        const textBuilder = TextBuilder();
        const headerBuilder = HeaderBuilder();

        const textNode = TextNode('test');
        expect(registry.findBuilder(textNode), textBuilder);

        const headerNode = HeaderNode(level: 1, content: 'Test');
        expect(registry.findBuilder(headerNode), headerBuilder);
      });

      test('should return null when no builder found', () {
        final registry = BuilderRegistry();
        const node = TextNode('test');
        expect(registry.findBuilder(node), isNull);
      });
    });
  });
}

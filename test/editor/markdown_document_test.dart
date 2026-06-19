import 'package:flutter/widgets.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void _expectUniqueDocumentIds(MarkdownDocument document) {
  final blockIds = <String>[];
  final listItemIds = <String>[];

  void collectIds(List<MarkdownBlock> blocks) {
    for (final block in blocks) {
      blockIds.add(block.id);
      if (block is MarkdownBlockquoteBlock) {
        collectIds(block.blocks);
      } else if (block is MarkdownListBlock) {
        for (final item in block.items) {
          listItemIds.add(item.id);
          collectIds(item.blocks);
        }
      }
    }
  }

  collectIds(document.blocks);
  expect(blockIds.toSet().length, blockIds.length);
  expect(listItemIds.toSet().length, listItemIds.length);
}

void main() {
  group('MarkdownDocumentCodec', () {
    test('parses Scratch-style markdown into editable blocks', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse('''
# Scratch **Editor**

This has [[Daily|today]], [site](https://example.com), `code`, and \$x^2\$.

- [x] Toolbar commands
- [ ] Table controls

```mermaid
graph TD
  A --> B
```

\$\$
E = mc^2
\$\$

| Name | Value |
| :--- | ---: |
| A | 1 |
''');

      expect(document.blocks, hasLength(6));
      expect(document.blocks[0], isA<MarkdownHeadingBlock>());
      expect(document.blocks[1], isA<MarkdownParagraphBlock>());

      final paragraph = document.blocks[1] as MarkdownParagraphBlock;
      expect(paragraph.children, contains(isA<MarkdownWikilink>()));
      final wikilink = paragraph.children.whereType<MarkdownWikilink>().single;
      expect(wikilink.target, 'Daily|today');
      expect(paragraph.children, contains(isA<MarkdownLink>()));
      expect(paragraph.children, contains(isA<MarkdownInlineCode>()));
      expect(paragraph.children, contains(isA<MarkdownInlineMath>()));

      final list = document.blocks[2] as MarkdownListBlock;
      expect(list.kind, MarkdownListKind.task);
      expect(list.items.first.checked, isTrue);
      expect(list.items.last.checked, isFalse);

      expect(document.blocks[3], isA<MarkdownMermaidBlock>());
      expect((document.blocks[3] as MarkdownMermaidBlock).fence, '```');
      expect(document.blocks[4], isA<MarkdownBlockMathBlock>());
      expect(document.blocks[5], isA<MarkdownTableBlock>());
    });

    test('parses Scratch single-line block math input rule shape', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse(r'$$E = mc^2$$');

      expect(document.blocks, hasLength(1));
      final block = document.blocks.single as MarkdownBlockMathBlock;
      expect(block.latex, 'E = mc^2');
      expect(document.toMarkdown(), r'$$' '\nE = mc^2\n' r'$$');
    });

    test('keeps wikilinks with closing brackets plain like Scratch', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse('See [[A]B]] and [[Daily]]');

      final paragraph = document.blocks.single as MarkdownParagraphBlock;

      expect(paragraph.children.whereType<MarkdownWikilink>(), hasLength(1));
      expect(
        paragraph.children.whereType<MarkdownWikilink>().single.target,
        'Daily',
      );
      expect(paragraph.plainText, 'See [[A]B]] and Daily');
      expect(document.toMarkdown(), r'See \[\[A\]B\]\] and [[Daily]]');
    });

    test('normalizes ragged tables into rectangular editable tables', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse('''
| A | B |
| --- | --- | --- |
| 1 |
| 2 | 3 | 4 |
''');

      final table = document.blocks.single as MarkdownTableBlock;

      expect(table.columnCount, 2);
      expect(table.alignments, hasLength(2));
      expect(table.rows, hasLength(2));
      expect(table.rows[0], hasLength(2));
      expect(table.rows[0][0].single.plainText, '1');
      expect(table.rows[0][1].single.plainText, '');
      expect(table.rows[1], hasLength(2));
      expect(table.rows[1][0].single.plainText, '2');
      expect(table.rows[1][1].single.plainText, '3');
      expect(
        document.toMarkdown(),
        '| A | B |\n'
        '| --- | --- |\n'
        '| 1 |  |\n'
        '| 2 | 3 |',
      );
    });

    test('parses nested markdown lists into editable list blocks', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse('''
- parent
  - child
  - sibling
- next
''');

      expect(document.blocks, hasLength(1));
      final list = document.blocks.single as MarkdownListBlock;
      expect(list.items, hasLength(2));
      expect(list.items.first.blocks.last, isA<MarkdownListBlock>());

      final nested = list.items.first.blocks.last as MarkdownListBlock;
      expect(nested.items, hasLength(2));
      expect(nested.items.first.plainText, 'child');
      expect(document.toMarkdown(), '- parent\n  - child\n  - sibling\n- next');
    });

    test('preserves ordered list start indexes through editable round trip',
        () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse('5. five\n6. six');

      final list = document.blocks.single as MarkdownListBlock;
      expect(list.kind, MarkdownListKind.ordered);
      expect(list.startIndex, 5);
      expect(document.toMarkdown(), '5. five\n6. six');

      final reparsed = codec.parse(document.toMarkdown());
      final reparsedList = reparsed.blocks.single as MarkdownListBlock;
      expect(reparsedList.startIndex, 5);
      expect(reparsed.toMarkdown(), '5. five\n6. six');
    });

    test('splits mixed task and bullet list blocks like Scratch', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse('''
- [x] Done
- Plain
''');

      expect(document.blocks, hasLength(2));

      final taskList = document.blocks[0] as MarkdownListBlock;
      expect(taskList.kind, MarkdownListKind.task);
      expect(taskList.items.single.checked, isTrue);
      expect(taskList.items.single.plainText, 'Done');

      final bulletList = document.blocks[1] as MarkdownListBlock;
      expect(bulletList.kind, MarkdownListKind.bullet);
      expect(bulletList.items.single.plainText, 'Plain');
      expect(document.toMarkdown(), '- [x] Done\n\n- Plain');
    });

    test('splits nested mixed task and bullet child lists like Scratch', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse('''
- [x] Done
  - Plain child
  - [ ] Task child
- Plain
''');

      expect(document.blocks, hasLength(2));

      final taskList = document.blocks[0] as MarkdownListBlock;
      expect(taskList.kind, MarkdownListKind.task);
      expect(taskList.items.single.checked, isTrue);
      expect(taskList.items.single.blocks, hasLength(3));

      final nestedBullet = taskList.items.single.blocks[1] as MarkdownListBlock;
      expect(nestedBullet.kind, MarkdownListKind.bullet);
      expect(nestedBullet.items.single.plainText, 'Plain child');

      final nestedTask = taskList.items.single.blocks[2] as MarkdownListBlock;
      expect(nestedTask.kind, MarkdownListKind.task);
      expect(nestedTask.items.single.checked, isFalse);
      expect(nestedTask.items.single.plainText, 'Task child');

      final bulletList = document.blocks[1] as MarkdownListBlock;
      expect(bulletList.kind, MarkdownListKind.bullet);
      expect(bulletList.items.single.plainText, 'Plain');
      expect(
        document.toMarkdown(),
        '- [x] Done\n'
        '  - Plain child\n'
        '  - [ ] Task child\n\n'
        '- Plain',
      );
    });

    test('keeps paren-numbered lines as paragraphs like Scratch', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse('1) not ordered\n2) still text');

      expect(document.blocks, hasLength(1));
      expect(document.blocks.single, isA<MarkdownParagraphBlock>());
      expect(document.blocks.single.plainText, '1) not ordered\n2) still text');
      expect(document.toMarkdown(), '1) not ordered\n2) still text');
    });

    test('escapes plain text markdown markers for model round-trip', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [
              MarkdownText(
                '- not list\n'
                '+ not list\n'
                '1. not ordered\n'
                '# not heading\n'
                '> not quote\n'
                '---\n'
                '*literal*\n'
                '_literal_\n'
                '~~literal~~',
              ),
            ],
          ),
        ],
      );

      final markdown = document.toMarkdown();

      expect(
        markdown,
        r'\- not list'
        '\n'
        r'\+ not list'
        '\n'
        r'1\. not ordered'
        '\n'
        r'\# not heading'
        '\n'
        r'\> not quote'
        '\n'
        r'\---'
        '\n'
        r'\*literal\*'
        '\n'
        r'\_literal\_'
        '\n'
        r'\~\~literal\~\~',
      );

      final reparsed = MarkdownDocumentCodec().parse(markdown);
      expect(reparsed.blocks, hasLength(1));
      expect(reparsed.blocks.single, isA<MarkdownParagraphBlock>());
      expect(
        reparsed.blocks.single.plainText,
        '- not list\n'
        '+ not list\n'
        '1. not ordered\n'
        '# not heading\n'
        '> not quote\n'
        '---\n'
        '*literal*\n'
        '_literal_\n'
        '~~literal~~',
      );

      final paragraph = reparsed.blocks.single as MarkdownParagraphBlock;
      expect(paragraph.children.whereType<MarkdownStrong>(), isEmpty);
      expect(paragraph.children.whereType<MarkdownEmphasis>(), isEmpty);
      expect(paragraph.children.whereType<MarkdownStrikethrough>(), isEmpty);
      expect(paragraph.children.whereType<MarkdownInlineMath>(), isEmpty);
    });

    test('serializes document model back to markdown', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownHeadingBlock(
            id: 'h',
            level: 1,
            children: [
              MarkdownText('Scratch '),
              MarkdownStrong([MarkdownText('Editor')]),
            ],
          ),
          MarkdownParagraphBlock(
            id: 'p',
            children: [
              MarkdownText('See '),
              MarkdownWikilink(target: 'Daily Notes|today'),
              MarkdownText(' and '),
              MarkdownLink(
                url: 'https://example.com',
                children: [MarkdownText('site')],
              ),
              MarkdownText('.'),
            ],
          ),
          MarkdownMermaidBlock(
            id: 'm',
            code: 'graph TD\n  A --> B',
          ),
        ],
      );

      expect(
        document.toMarkdown(),
        '# Scratch **Editor**\n\n'
        'See [[Daily Notes|today]] and [site](https://example.com).\n\n'
        '```mermaid\n'
        'graph TD\n'
        '  A --> B\n'
        '```',
      );
    });

    test('normalizes non-breaking spaces during markdown serialization', () {
      final nonBreakingSpace = String.fromCharCode(0x00A0);
      final document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [
              MarkdownText('A&nbsp;B&#160;C${nonBreakingSpace}D'),
            ],
          ),
          MarkdownTableBlock(
            id: 'table',
            headers: const [
              [MarkdownText('Name&nbsp;Value')],
            ],
            alignments: const [null],
            rows: [
              [
                [MarkdownText('One${nonBreakingSpace}Two')],
              ],
            ],
          ),
        ],
      );

      expect(
        document.toMarkdown(),
        'A B C D\n\n'
        '| Name Value |\n'
        '| --- |\n'
        '| One Two |',
      );
    });

    test('escapes table cell pipes during markdown serialization', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownTableBlock(
            id: 'table',
            headers: [
              [MarkdownText('Name | Value')],
            ],
            alignments: [null],
            rows: [
              [
                [
                  MarkdownText('A | B and '),
                  MarkdownStrong([MarkdownText('C | D')]),
                ],
              ],
            ],
          ),
        ],
      );

      final markdown = document.toMarkdown();

      expect(
        markdown,
        '| Name \\| Value |\n'
        '| --- |\n'
        '| A \\| B and **C \\| D** |',
      );

      final reparsed = MarkdownDocumentCodec().parse(markdown);
      final table = reparsed.blocks.single as MarkdownTableBlock;
      expect(table.headers.single.single.plainText, 'Name | Value');
      expect(table.rows.single.single.map((node) => node.plainText).join(),
          'A | B and C | D');
    });

    test('parses standalone images as editable image blocks', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse('![Diagram](assets/diagram(1).png)');

      expect(document.blocks.single, isA<MarkdownImageBlock>());
      final image = document.blocks.single as MarkdownImageBlock;
      expect(image.url, 'assets/diagram(1).png');
      expect(image.alt, 'Diagram');
      expect(document.toMarkdown(), '![Diagram](assets/diagram(1).png)');
    });

    test('preserves tilde fenced code blocks in editable documents', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse('~~~dart\nvoid main() {}\n~~~');

      expect(document.blocks.single, isA<MarkdownCodeBlock>());
      final block = document.blocks.single as MarkdownCodeBlock;
      expect(block.language, 'dart');
      expect(block.fence, '~~~');
      expect(document.toMarkdown(), '~~~dart\nvoid main() {}\n~~~');
    });

    test('preserves code fence info strings in editable documents', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse(
        '```dart title=main.dart linenos\n'
        'void main() {}\n'
        '```',
      );

      expect(document.blocks.single, isA<MarkdownCodeBlock>());
      final block = document.blocks.single as MarkdownCodeBlock;
      expect(block.language, 'dart');
      expect(block.info, 'dart title=main.dart linenos');
      expect(
        document.toMarkdown(),
        '```dart title=main.dart linenos\n'
        'void main() {}\n'
        '```',
      );
    });

    test('preserves tilde fenced Mermaid blocks in editable documents', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse(
        '~~~mermaid theme=dark\n'
        'flowchart TD\n'
        '  A --> B\n'
        '~~~',
      );

      expect(document.blocks.single, isA<MarkdownMermaidBlock>());
      final block = document.blocks.single as MarkdownMermaidBlock;
      expect(block.theme, 'dark');
      expect(block.fence, '~~~');
      expect(block.info, 'mermaid theme=dark');
      expect(
        document.toMarkdown(),
        '~~~mermaid theme=dark\n'
        'flowchart TD\n'
        '  A --> B\n'
        '~~~',
      );
    });

    test('preserves extra Mermaid fence info in editable documents', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse(
        '```mermaid theme=dark title=flow\n'
        'flowchart TD\n'
        '  A --> B\n'
        '```',
      );

      expect(document.blocks.single, isA<MarkdownMermaidBlock>());
      final block = document.blocks.single as MarkdownMermaidBlock;
      expect(block.theme, 'dark');
      expect(block.info, 'mermaid theme=dark title=flow');
      expect(
        document.toMarkdown(),
        '```mermaid theme=dark title=flow\n'
        'flowchart TD\n'
        '  A --> B\n'
        '```',
      );
    });

    test('parses hard breaks into editable inline nodes', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse('First\\\nSecond');

      expect(document.blocks.single, isA<MarkdownParagraphBlock>());
      final paragraph = document.blocks.single as MarkdownParagraphBlock;
      expect(paragraph.children, hasLength(3));
      expect(paragraph.children[0], isA<MarkdownText>());
      expect(paragraph.children[1], isA<MarkdownHardBreak>());
      expect(paragraph.children[2], isA<MarkdownText>());
      expect(paragraph.plainText, 'First\nSecond');
      expect(document.toMarkdown(), 'First  \nSecond');
    });

    test('parses YAML frontmatter only at the document start', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse(
        '---\n'
        'title: Daily\n'
        'tags:\n'
        '  - scratch\n'
        '---\n'
        '\n'
        '# Body',
      );

      expect(document.blocks, hasLength(2));
      expect(document.blocks.first, isA<MarkdownFrontmatterBlock>());
      final frontmatter = document.blocks.first as MarkdownFrontmatterBlock;
      expect(frontmatter.content, 'title: Daily\ntags:\n  - scratch');
      expect(document.blocks.last, isA<MarkdownHeadingBlock>());
      expect(
        document.toMarkdown(),
        '---\n'
        'title: Daily\n'
        'tags:\n'
        '  - scratch\n'
        '---\n'
        '\n'
        '# Body',
      );
    });

    test('does not parse later horizontal rules as frontmatter', () {
      final codec = MarkdownDocumentCodec();
      final document = codec.parse(
        '# Body\n'
        '\n'
        '---\n'
        '\n'
        'Tail',
      );

      expect(document.blocks, hasLength(3));
      expect(document.blocks, isNot(contains(isA<MarkdownFrontmatterBlock>())));
      expect(document.blocks[1], isA<MarkdownHorizontalRuleBlock>());
    });

    test('preserves unsupported custom block markdown during round trip', () {
      final registry = ParserPluginRegistry()
        ..register(const _CustomBlockPlugin());
      final codec = MarkdownDocumentCodec(plugins: registry);
      const customBlock = ':::custom id=42\n'
          'Raw *stars* [link](https://example.com)\n'
          '\n'
          '- plugin-owned list item\n'
          ':::';
      const markdown = 'Intro **strong**\n\n'
          '$customBlock\n\n'
          'Outro';

      final document = codec.parse(markdown);

      expect(document.blocks, hasLength(3));
      expect(document.blocks[1], isA<MarkdownRawBlock>());
      final rawBlock = document.blocks[1] as MarkdownRawBlock;
      expect(rawBlock.markdown, customBlock);
      expect(rawBlock.toMarkdown(), customBlock);
      expect(codec.serialize(document), markdown);
    });

    test('serializes raw blocks without markdown normalization', () {
      const rawMarkdown = '<custom>&nbsp;*literal*</custom>';
      const document = MarkdownDocument(
        blocks: [
          MarkdownRawBlock(id: 'raw', markdown: rawMarkdown),
        ],
      );

      expect(document.toMarkdown(), rawMarkdown);
    });

    test('keeps raw custom block intact after editing another paragraph', () {
      final registry = ParserPluginRegistry()
        ..register(const _CustomBlockPlugin());
      final codec = MarkdownDocumentCodec(plugins: registry);
      const customBlock = ':::custom id=42\n'
          'Raw *stars* [link](https://example.com)\n'
          '\n'
          '- plugin-owned list item\n'
          ':::';
      const markdown = 'Intro\n\n'
          '$customBlock\n\n'
          'Outro';

      final document = codec.parse(markdown);
      final firstParagraph = document.blocks.first as MarkdownParagraphBlock;

      final edited = document.replaceBlock(
        firstParagraph.copyWith(
          children: const [MarkdownText('Changed')],
        ),
      );

      expect(edited.blocks[1], isA<MarkdownRawBlock>());
      expect((edited.blocks[1] as MarkdownRawBlock).markdown, customBlock);
      expect(
        edited.toMarkdown(),
        'Changed\n\n'
        '$customBlock\n\n'
        'Outro',
      );
    });
  });

  group('MarkdownDocumentEditor', () {
    test('updates frontmatter content through the document model', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownFrontmatterBlock(
              id: 'frontmatter',
              content: 'title: Old',
            ),
            MarkdownParagraphBlock(
              id: 'body',
              children: [MarkdownText('Body')],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      editor.updateFrontmatter('frontmatter', 'title: New');

      expect(
        editor.document.toMarkdown(),
        '---\n'
        'title: New\n'
        '---\n'
        '\n'
        'Body',
      );
    });

    test('plain text newline edits become hard break nodes', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownParagraphBlock(
              id: 'p',
              children: [MarkdownText('FirstSecond')],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      final replaced = editor.replaceTextBlockText('p', 'First\nSecond');

      expect(replaced, isTrue);
      final paragraph = editor.document.blocks.single as MarkdownParagraphBlock;
      expect(paragraph.children, hasLength(3));
      expect(paragraph.children[1], isA<MarkdownHardBreak>());
      expect(editor.document.toMarkdown(), 'First  \nSecond');
    });

    test('converts typed markdown prefixes into semantic blocks', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.applyInputRules(
        blockId: 'p',
        text: '### ',
        selectionOffset: 4,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'p');
      expect(editor.document.blocks.single, isA<MarkdownHeadingBlock>());
      expect((editor.document.blocks.single as MarkdownHeadingBlock).level, 3);
      expect(editor.document.toMarkdown(), '###');
    });

    test('converts task markdown prefix into a task list', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.applyInputRules(
        blockId: 'p',
        text: '- [x] ',
        selectionOffset: 6,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'p-item-0-p');
      final block = editor.document.blocks.single;
      expect(block, isA<MarkdownListBlock>());
      final list = block as MarkdownListBlock;
      expect(list.kind, MarkdownListKind.task);
      expect(list.items.single.checked, isTrue);
      expect(editor.document.toMarkdown(), '- [x]');
    });

    for (final marker in ['- ', '* ', '+ ', '  * ']) {
      test('converts Scratch bullet marker "$marker" into a bullet list', () {
        const document = MarkdownDocument(
          blocks: [
            MarkdownParagraphBlock(
              id: 'p',
              children: [MarkdownText('')],
            ),
          ],
        );
        final editor = MarkdownDocumentEditor(document);
        addTearDown(editor.dispose);

        final result = editor.applyInputRules(
          blockId: 'p',
          text: marker,
          selectionOffset: marker.length,
        );

        expect(result, isNotNull);
        expect(result!.activeBlockId, 'p-item-0-p');
        final block = editor.document.blocks.single;
        expect(block, isA<MarkdownListBlock>());
        final list = block as MarkdownListBlock;
        expect(list.kind, MarkdownListKind.bullet);
        expect(editor.document.toMarkdown(), '-');
      });
    }

    for (final entry in {
      '[ ] ': false,
      '[x] ': true,
      '[X] ': true,
      '  [x] ': true,
    }.entries) {
      test('converts Scratch task marker "${entry.key}" inside a list item',
          () {
        const document = MarkdownDocument(
          blocks: [
            MarkdownListBlock(
              id: 'list',
              kind: MarkdownListKind.bullet,
              items: [
                MarkdownListItem(
                  id: 'item',
                  blocks: [
                    MarkdownParagraphBlock(
                      id: 'item-p',
                      children: [MarkdownText('')],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        final editor = MarkdownDocumentEditor(document);
        addTearDown(editor.dispose);

        final result = editor.applyInputRules(
          blockId: 'item-p',
          text: entry.key,
          selectionOffset: entry.key.length,
        );

        expect(result, isNotNull);
        expect(result!.activeBlockId, 'item-p');
        final block = editor.document.blocks.single;
        expect(block, isA<MarkdownListBlock>());
        final list = block as MarkdownListBlock;
        expect(list.kind, MarkdownListKind.task);
        expect(list.items.single.checked, entry.value);
        expect(list.items.single.plainText, '');
        expect(editor.document.toMarkdown(), entry.value ? '- [x]' : '- [ ]');
      });
    }

    test('keeps top-level Scratch task item marker as paragraph text', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.applyInputRules(
        blockId: 'p',
        text: '[x] ',
        selectionOffset: 4,
      );

      expect(result, isNull);
      expect(editor.document.blocks.single, isA<MarkdownParagraphBlock>());
      expect(editor.document.toMarkdown(), '');
    });

    test('converts dot numbered prefix into an ordered list', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.applyInputRules(
        blockId: 'p',
        text: '3. ',
        selectionOffset: 3,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'p-item-0-p');
      final block = editor.document.blocks.single;
      expect(block, isA<MarkdownListBlock>());
      final list = block as MarkdownListBlock;
      expect(list.kind, MarkdownListKind.ordered);
      expect(list.startIndex, 3);
      expect(editor.document.toMarkdown(), '3.');
    });

    test('joins continuous ordered input with previous list like Scratch', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.ordered,
            items: [
              MarkdownListItem(
                id: 'item-1',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-1-p',
                    children: [MarkdownText('one')],
                  ),
                ],
              ),
            ],
          ),
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.applyInputRules(
        blockId: 'p',
        text: '2. ',
        selectionOffset: 3,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'p-item-0-p');
      expect(editor.document.blocks, hasLength(1));
      final list = editor.document.blocks.single as MarkdownListBlock;
      expect(list.id, 'list');
      expect(list.items, hasLength(2));
      expect(editor.document.toMarkdown(), '1. one\n2.');
    });

    test('keeps non-continuous ordered input as a new list like Scratch', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.ordered,
            items: [
              MarkdownListItem(
                id: 'item-1',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-1-p',
                    children: [MarkdownText('one')],
                  ),
                ],
              ),
            ],
          ),
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.applyInputRules(
        blockId: 'p',
        text: '3. ',
        selectionOffset: 3,
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(2));
      final nextList = editor.document.blocks.last as MarkdownListBlock;
      expect(nextList.startIndex, 3);
      expect(editor.document.toMarkdown(), '1. one\n\n3.');
    });

    test('joins bullet input with previous bullet list like Scratch', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item-1',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-1-p',
                    children: [MarkdownText('one')],
                  ),
                ],
              ),
            ],
          ),
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.applyInputRules(
        blockId: 'p',
        text: '- ',
        selectionOffset: 2,
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(1));
      final list = editor.document.blocks.single as MarkdownListBlock;
      expect(list.items, hasLength(2));
      expect(editor.document.toMarkdown(), '- one\n-');
    });

    test('joins blockquote input with previous quote like Scratch', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownBlockquoteBlock(
            id: 'quote',
            blocks: [
              MarkdownParagraphBlock(
                id: 'quote-p',
                children: [MarkdownText('one')],
              ),
            ],
          ),
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.applyInputRules(
        blockId: 'p',
        text: '> ',
        selectionOffset: 2,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'p-quote-p');
      expect(editor.document.blocks, hasLength(1));
      final quote = editor.document.blocks.single as MarkdownBlockquoteBlock;
      expect(quote.blocks, hasLength(2));
      expect(editor.document.toMarkdown(), '> one\n>\n>');
    });

    test('joins wrapping input with previous sibling inside a list item', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-p',
                    children: [MarkdownText('parent')],
                  ),
                  MarkdownListBlock(
                    id: 'nested',
                    kind: MarkdownListKind.bullet,
                    items: [
                      MarkdownListItem(
                        id: 'nested-item',
                        blocks: [
                          MarkdownParagraphBlock(
                            id: 'nested-item-p',
                            children: [MarkdownText('child')],
                          ),
                        ],
                      ),
                    ],
                  ),
                  MarkdownParagraphBlock(
                    id: 'p',
                    children: [MarkdownText('')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.applyInputRules(
        blockId: 'p',
        text: '- ',
        selectionOffset: 2,
      );

      expect(result, isNotNull);
      final list = editor.document.blocks.single as MarkdownListBlock;
      final nested = list.items.single.blocks[1] as MarkdownListBlock;
      expect(nested.items, hasLength(2));
      expect(
        editor.document.toMarkdown(),
        '- parent\n'
        '  - child\n'
        '  -',
      );
    });

    test('does not convert paren numbered prefix like Scratch', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.applyInputRules(
        blockId: 'p',
        text: '1) ',
        selectionOffset: 3,
      );

      expect(result, isNull);
      expect(editor.document.blocks.single, isA<MarkdownParagraphBlock>());
      expect(editor.document.toMarkdown(), '');
    });

    for (final marker in ['---', '*** ', '___ ', '\u2014-']) {
      test('converts Scratch horizontal rule input "$marker"', () {
        const document = MarkdownDocument(
          blocks: [
            MarkdownParagraphBlock(
              id: 'p',
              children: [MarkdownText('')],
            ),
          ],
        );
        final editor = MarkdownDocumentEditor(document);
        addTearDown(editor.dispose);

        final result = editor.applyInputRules(
          blockId: 'p',
          text: marker,
          selectionOffset: marker.length,
        );

        expect(result, isNotNull);
        expect(result!.activeBlockId, 'p-after-hr');
        expect(editor.document.blocks, hasLength(2));
        expect(
            editor.document.blocks.first, isA<MarkdownHorizontalRuleBlock>());
        expect(editor.document.blocks.last, isA<MarkdownParagraphBlock>());
        expect(editor.document.toMarkdown(), '---');
      });
    }

    test('keeps the paragraph after a nested horizontal rule active', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-p',
                    children: [MarkdownText('')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.applyInputRules(
        blockId: 'item-p',
        text: '---',
        selectionOffset: 3,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'item-p-after-hr');
      final list = editor.document.blocks.single as MarkdownListBlock;
      final itemBlocks = list.items.single.blocks;
      expect(itemBlocks, hasLength(2));
      expect(itemBlocks.first, isA<MarkdownHorizontalRuleBlock>());
      expect(itemBlocks.last, isA<MarkdownParagraphBlock>());
      expect(editor.document.toMarkdown(), '- ---');
    });

    for (final marker in ['``` ', '```dart ', '~~~ ', '~~~mermaid ']) {
      test('converts Scratch code fence input "$marker"', () {
        const document = MarkdownDocument(
          blocks: [
            MarkdownParagraphBlock(
              id: 'p',
              children: [MarkdownText('')],
            ),
          ],
        );
        final editor = MarkdownDocumentEditor(document);
        addTearDown(editor.dispose);

        final result = editor.applyInputRules(
          blockId: 'p',
          text: marker,
          selectionOffset: marker.length,
        );

        expect(result, isNotNull);
        final block = editor.document.blocks.single;
        if (marker.contains('mermaid')) {
          expect(block, isA<MarkdownMermaidBlock>());
          expect((block as MarkdownMermaidBlock).fence, '~~~');
          expect(editor.document.toMarkdown(), '~~~mermaid\n\n~~~');
        } else {
          expect(block, isA<MarkdownCodeBlock>());
          final code = block as MarkdownCodeBlock;
          expect(code.fence, marker.startsWith('~~~') ? '~~~' : '```');
          expect(code.language, marker.contains('dart') ? 'dart' : '');
        }
      });
    }

    for (final marker in ['```', '~~~', '```dart title=main.dart ']) {
      test('does not convert non-TipTap code fence input "$marker"', () {
        const document = MarkdownDocument(
          blocks: [
            MarkdownParagraphBlock(
              id: 'p',
              children: [MarkdownText('')],
            ),
          ],
        );
        final editor = MarkdownDocumentEditor(document);
        addTearDown(editor.dispose);

        final result = editor.applyInputRules(
          blockId: 'p',
          text: marker,
          selectionOffset: marker.length,
        );

        expect(result, isNull);
        expect(editor.document.blocks.single, isA<MarkdownParagraphBlock>());
      });
    }

    for (final marker in [r'$$', r'$$   $$']) {
      test('keeps empty Scratch block math input "$marker" as text', () {
        const document = MarkdownDocument(
          blocks: [
            MarkdownParagraphBlock(
              id: 'p',
              children: [MarkdownText('')],
            ),
          ],
        );
        final editor = MarkdownDocumentEditor(document);
        addTearDown(editor.dispose);

        final result = editor.applyInputRules(
          blockId: 'p',
          text: marker,
          selectionOffset: marker.length,
        );

        expect(result, isNull);
        expect(editor.document.blocks.single, isA<MarkdownParagraphBlock>());
        expect(editor.document.toMarkdown(), '');
      });
    }

    for (final marker in ['> ', '  > ']) {
      test('keeps nested quote paragraph active after "$marker" input rule',
          () {
        const document = MarkdownDocument(
          blocks: [
            MarkdownParagraphBlock(
              id: 'p',
              children: [MarkdownText('')],
            ),
          ],
        );
        final editor = MarkdownDocumentEditor(document);
        addTearDown(editor.dispose);

        final result = editor.applyInputRules(
          blockId: 'p',
          text: marker,
          selectionOffset: marker.length,
        );

        expect(result, isNotNull);
        expect(result!.activeBlockId, 'p-quote-p');
        final block = editor.document.blocks.single;
        expect(block, isA<MarkdownBlockquoteBlock>());
        expect(editor.document.toMarkdown(), '>');
      });
    }

    test('replaces a top-level block with parsed markdown blocks', () {
      final controller = MarkdownEditorController(
        text: 'placeholder\n\nTail',
      );
      addTearDown(controller.dispose);

      final blockId = controller.document.blocks.first.id;
      final parsed = controller.replaceBlockWithMarkdown(
        blockId,
        '# Pasted\n\n'
        '- [x] Task\n\n'
        '```dart\n'
        'void main() {}\n'
        '```',
      );

      expect(parsed, isNotNull);
      expect(controller.document.blocks[0], isA<MarkdownHeadingBlock>());
      expect(controller.document.blocks[1], isA<MarkdownListBlock>());
      expect(controller.document.blocks[2], isA<MarkdownCodeBlock>());
      expect(controller.document.blocks[3].plainText, 'Tail');
      expect(
        controller.text,
        '# Pasted\n\n'
        '- [x] Task\n\n'
        '```dart\n'
        'void main() {}\n'
        '```\n\n'
        'Tail',
      );
    });

    test('retags parsed block ids when replacing a block', () {
      final controller = MarkdownEditorController(text: 'Alpha\n\nBeta');
      addTearDown(controller.dispose);

      final beta = controller.document.blocks[1];
      final parsed = controller.replaceBlockWithMarkdown(
        beta.id,
        '# Pasted\n\n'
        '- Item',
      );

      expect(parsed, isNotNull);
      _expectUniqueDocumentIds(controller.document);

      final insertedHeading = controller.document.blocks[1];
      expect(insertedHeading, isA<MarkdownHeadingBlock>());
      expect(
        controller.documentEditor.replaceTextBlockText(
          insertedHeading.id,
          'Changed',
        ),
        isTrue,
      );
      expect(controller.text, 'Alpha\n\n# Changed\n\n- Item');
    });

    test('replaces a nested blockquote block with parsed markdown blocks', () {
      final controller = MarkdownEditorController(
        text: '> placeholder\n\nTail',
      );
      addTearDown(controller.dispose);

      final blockquote =
          controller.document.blocks.first as MarkdownBlockquoteBlock;
      final childId = blockquote.blocks.first.id;
      final parsed = controller.replaceBlockWithMarkdown(
        childId,
        '# Pasted\n\n'
        '- [x] Task',
      );

      expect(parsed, isNotNull);
      final updated =
          controller.document.blocks.first as MarkdownBlockquoteBlock;
      expect(updated.blocks[0], isA<MarkdownHeadingBlock>());
      expect(updated.blocks[1], isA<MarkdownListBlock>());
      expect(controller.document.blocks[1].plainText, 'Tail');
      expect(
        controller.text,
        '> # Pasted\n'
        '>\n'
        '> - [x] Task\n\n'
        'Tail',
      );
    });

    test('replaces a nested list item block with parsed markdown blocks', () {
      final controller = MarkdownEditorController(
        text: '- placeholder\n- Tail',
      );
      addTearDown(controller.dispose);

      final list = controller.document.blocks.first as MarkdownListBlock;
      final childId = list.items.first.blocks.first.id;
      final parsed = controller.replaceBlockWithMarkdown(
        childId,
        'Pasted\n\n'
        '- [x] Task',
      );

      expect(parsed, isNotNull);
      final updated = controller.document.blocks.first as MarkdownListBlock;
      expect(updated.items.first.blocks[0], isA<MarkdownParagraphBlock>());
      expect(updated.items.first.blocks[1], isA<MarkdownListBlock>());
      expect(updated.items.last.plainText, 'Tail');
      expect(
        controller.text,
        '- Pasted\n'
        '  - [x] Task\n'
        '- Tail',
      );
    });

    test('inserts parsed blocks into a text range like TipTap paste', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('Before after')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.replaceTextRangeWithBlocks(
        'p',
        const TextRange.collapsed(7),
        const [
          MarkdownHeadingBlock(
            id: 'heading',
            level: 1,
            children: [MarkdownText('Pasted')],
          ),
        ],
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(3));
      expect(editor.document.blocks[0].plainText, 'Before ');
      expect(editor.document.blocks[1], isA<MarkdownHeadingBlock>());
      expect(editor.document.blocks[2].plainText, 'after');
      expect(
        editor.document.toMarkdown(),
        'Before \n\n'
        '# Pasted\n\n'
        'after',
      );
      expect(result!.selectionOffset, 'Before \n\n# Pasted'.length);
    });

    test('retags parsed block ids when inserting blocks into a text range', () {
      final controller = MarkdownEditorController(text: 'Alpha\n\nBeta');
      addTearDown(controller.dispose);

      final beta = controller.document.blocks[1];
      final parsed = MarkdownDocumentCodec().parse(
        '# Pasted\n\n'
        '- Item',
      );
      final result = controller.documentEditor.replaceTextRangeWithBlocks(
        beta.id,
        TextRange(start: 0, end: beta.plainText.length),
        parsed.blocks,
      );

      expect(result, isNotNull);
      _expectUniqueDocumentIds(controller.document);

      final insertedHeading = controller.document.blocks[1];
      expect(insertedHeading, isA<MarkdownHeadingBlock>());
      expect(
        controller.documentEditor.replaceTextBlockText(
          insertedHeading.id,
          'Changed',
        ),
        isTrue,
      );
      expect(controller.text, 'Alpha\n\n# Changed\n\n- Item');
    });

    test('copies a top-level cross-block selection as markdown', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p1',
            children: [MarkdownText('Alpha')],
          ),
          MarkdownParagraphBlock(
            id: 'p2',
            children: [MarkdownText('Beta')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final copied = editor.copySelectionAsMarkdown(
        const MarkdownDocumentSelection(
          anchor: MarkdownDocumentPosition(blockId: 'p1', offset: 1),
          focus: MarkdownDocumentPosition(blockId: 'p2', offset: 3),
        ),
      );

      expect(copied, 'lpha\n\nBet');
    });

    test('deletes a cross-block selection and joins endpoint text', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p1',
            children: [MarkdownText('Hello ')],
          ),
          MarkdownParagraphBlock(
            id: 'p2',
            children: [MarkdownText('world!')],
          ),
          MarkdownParagraphBlock(
            id: 'p3',
            children: [MarkdownText('Keep')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.deleteSelection(
        const MarkdownDocumentSelection(
          anchor: MarkdownDocumentPosition(blockId: 'p1', offset: 3),
          focus: MarkdownDocumentPosition(blockId: 'p2', offset: 5),
        ),
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'p1');
      expect(result.selectionOffset, 3);
      expect(
        editor.document.toMarkdown(),
        'Hel!\n\n'
        'Keep',
      );

      expect(editor.undo(), isTrue);
      expect(editor.document.toMarkdown(), document.toMarkdown());
    });

    test('does not delete across unsupported top-level block types', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p1',
            children: [MarkdownText('Before')],
          ),
          MarkdownImageBlock(
            id: 'image',
            url: 'assets/diagram.png',
            alt: 'Diagram',
          ),
          MarkdownParagraphBlock(
            id: 'p2',
            children: [MarkdownText('After')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      const selection = MarkdownDocumentSelection(
        anchor: MarkdownDocumentPosition(blockId: 'p1', offset: 2),
        focus: MarkdownDocumentPosition(blockId: 'p2', offset: 3),
      );

      expect(editor.copySelectionAsMarkdown(selection), isNull);
      expect(editor.deleteSelection(selection), isNull);
      expect(
        editor.replaceSelectionWithBlocks(
          selection,
          const [
            MarkdownParagraphBlock(
              id: 'replacement',
              children: [MarkdownText('Replacement')],
            ),
          ],
        ),
        isNull,
      );
      expect(
        editor.applyInlineCommandToSelection(
          selection,
          MarkdownEditorCommand.bold,
        ),
        isFalse,
      );
      expect(
        editor.applyBlockCommandToSelection(
          selection,
          MarkdownEditorCommand.unorderedList,
        ),
        isFalse,
      );
      expect(editor.document.toMarkdown(), document.toMarkdown());
    });

    test('replaces a cross-block selection with parsed blocks', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p1',
            children: [MarkdownText('BeforeX')],
          ),
          MarkdownParagraphBlock(
            id: 'p2',
            children: [MarkdownText('YAfter')],
          ),
          MarkdownParagraphBlock(
            id: 'p3',
            children: [MarkdownText('Tail')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.replaceSelectionWithBlocks(
        const MarkdownDocumentSelection(
          anchor: MarkdownDocumentPosition(blockId: 'p1', offset: 6),
          focus: MarkdownDocumentPosition(blockId: 'p2', offset: 1),
        ),
        const [
          MarkdownHeadingBlock(
            id: 'inserted-heading',
            level: 1,
            children: [MarkdownText('Inserted')],
          ),
          MarkdownParagraphBlock(
            id: 'inserted-body',
            children: [MarkdownText('Body')],
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'p2');
      expect(result.selectionOffset, 0);
      expect(
        editor.document.toMarkdown(),
        'Before\n\n'
        '# Inserted\n\n'
        'Body\n\n'
        'After\n\n'
        'Tail',
      );
    });

    test('applies inline commands across top-level text blocks', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p1',
            children: [MarkdownText('Alpha')],
          ),
          MarkdownParagraphBlock(
            id: 'p2',
            children: [MarkdownText('Beta')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final changed = editor.applyInlineCommandToSelection(
        const MarkdownDocumentSelection(
          anchor: MarkdownDocumentPosition(blockId: 'p1', offset: 0),
          focus: MarkdownDocumentPosition(blockId: 'p2', offset: 4),
        ),
        MarkdownEditorCommand.bold,
      );

      expect(changed, isTrue);
      expect(editor.document.toMarkdown(), '**Alpha**\n\n**Beta**');
    });

    test('wraps selected top-level blocks into one bullet list', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p1',
            children: [MarkdownText('One')],
          ),
          MarkdownParagraphBlock(
            id: 'p2',
            children: [MarkdownText('Two')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final changed = editor.applyBlockCommandToSelection(
        const MarkdownDocumentSelection(
          anchor: MarkdownDocumentPosition(blockId: 'p1', offset: 0),
          focus: MarkdownDocumentPosition(blockId: 'p2', offset: 3),
        ),
        MarkdownEditorCommand.unorderedList,
      );

      expect(changed, isTrue);
      expect(editor.document.toMarkdown(), '- One\n- Two');
    });

    test('wraps selected top-level blocks into one blockquote', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p1',
            children: [MarkdownText('One')],
          ),
          MarkdownParagraphBlock(
            id: 'p2',
            children: [MarkdownText('Two')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final changed = editor.applyBlockCommandToSelection(
        const MarkdownDocumentSelection(
          anchor: MarkdownDocumentPosition(blockId: 'p1', offset: 0),
          focus: MarkdownDocumentPosition(blockId: 'p2', offset: 3),
        ),
        MarkdownEditorCommand.blockquote,
      );

      expect(changed, isTrue);
      expect(
        editor.document.toMarkdown(),
        '> One\n'
        '>\n'
        '> Two',
      );
    });

    test('splits a top-level paragraph at the caret', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('HelloWorld')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.splitBlockAt(
        blockId: 'p',
        selectionOffset: 5,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'p-split');
      expect(editor.document.blocks, hasLength(2));
      expect(editor.document.blocks[0].plainText, 'Hello');
      expect(editor.document.blocks[1].plainText, 'World');
      expect(editor.document.toMarkdown(), 'Hello\n\nWorld');
    });

    test('continues a split heading as a paragraph', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownHeadingBlock(
            id: 'h',
            level: 2,
            children: [MarkdownText('TitleBody')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.splitBlockAt(
        blockId: 'h',
        selectionOffset: 5,
      );

      expect(result, isNotNull);
      expect(editor.document.blocks[0], isA<MarkdownHeadingBlock>());
      expect(editor.document.blocks[1], isA<MarkdownParagraphBlock>());
      expect(editor.document.toMarkdown(), '## Title\n\nBody');
    });

    test('splits a task list item into a new unchecked item', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.task,
            items: [
              MarkdownListItem(
                id: 'item',
                checked: true,
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-p',
                    children: [MarkdownText('firstsecond')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.splitBlockAt(
        blockId: 'item-p',
        selectionOffset: 5,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'item-p-split');
      final list = editor.document.blocks.single as MarkdownListBlock;
      expect(list.items, hasLength(2));
      expect(list.items.first.checked, isTrue);
      expect(list.items.last.checked, isFalse);
      expect(editor.document.toMarkdown(), '- [x] first\n- [ ] second');
    });

    test('exits a list from an empty list item', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item-1',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-1-p',
                    children: [MarkdownText('first')],
                  ),
                ],
              ),
              MarkdownListItem(
                id: 'item-2',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-2-p',
                    children: [MarkdownText('')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.splitBlockAt(
        blockId: 'item-2-p',
        selectionOffset: 0,
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(2));
      expect(editor.document.blocks.first, isA<MarkdownListBlock>());
      expect(editor.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(editor.document.toMarkdown(), '- first');
    });

    test('splits a nested list item inside its nested list', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'parent',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'parent-p',
                    children: [MarkdownText('parent')],
                  ),
                  MarkdownListBlock(
                    id: 'nested',
                    kind: MarkdownListKind.bullet,
                    items: [
                      MarkdownListItem(
                        id: 'child',
                        blocks: [
                          MarkdownParagraphBlock(
                            id: 'child-p',
                            children: [MarkdownText('childnext')],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.splitBlockAt(
        blockId: 'child-p',
        selectionOffset: 5,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'child-p-split');
      expect(
        editor.document.toMarkdown(),
        '- parent\n  - child\n  - next',
      );
    });

    test('enter on an empty nested list item outdents it one level', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'parent',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'parent-p',
                    children: [MarkdownText('parent')],
                  ),
                  MarkdownListBlock(
                    id: 'nested',
                    kind: MarkdownListKind.bullet,
                    items: [
                      MarkdownListItem(
                        id: 'empty',
                        blocks: [
                          MarkdownParagraphBlock(
                            id: 'empty-p',
                            children: [MarkdownText('')],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.splitBlockAt(
        blockId: 'empty-p',
        selectionOffset: 0,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'empty-p');
      expect(editor.document.toMarkdown(), '- parent\n-');
    });

    test('indents a list item into the previous item', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item-1',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-1-p',
                    children: [MarkdownText('parent')],
                  ),
                ],
              ),
              MarkdownListItem(
                id: 'item-2',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-2-p',
                    children: [MarkdownText('child')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.indentListItemContainingBlock(
        blockId: 'item-2-p',
        selectionOffset: 2,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'item-2-p');
      expect(result.selectionOffset, 2);
      final list = editor.document.blocks.single as MarkdownListBlock;
      expect(list.items, hasLength(1));
      expect(list.items.single.blocks.last, isA<MarkdownListBlock>());
      expect(editor.document.toMarkdown(), '- parent\n  - child');
    });

    test('does not indent the first list item', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item-1',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-1-p',
                    children: [MarkdownText('first')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.indentListItemContainingBlock(
        blockId: 'item-1-p',
        selectionOffset: 1,
      );

      expect(result, isNull);
      expect(editor.document.toMarkdown(), '- first');
    });

    test('outdents a nested list item into the outer list', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item-1',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-1-p',
                    children: [MarkdownText('parent')],
                  ),
                  MarkdownListBlock(
                    id: 'nested',
                    kind: MarkdownListKind.bullet,
                    items: [
                      MarkdownListItem(
                        id: 'item-2',
                        blocks: [
                          MarkdownParagraphBlock(
                            id: 'item-2-p',
                            children: [MarkdownText('child')],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.outdentListItemContainingBlock(
        blockId: 'item-2-p',
        selectionOffset: 3,
      );

      expect(result, isNotNull);
      final list = editor.document.blocks.single as MarkdownListBlock;
      expect(list.items, hasLength(2));
      expect(list.items.first.blocks, hasLength(1));
      expect(editor.document.toMarkdown(), '- parent\n- child');
    });

    test('outdents a top-level list item into a paragraph block', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item-1',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-1-p',
                    children: [MarkdownText('first')],
                  ),
                ],
              ),
              MarkdownListItem(
                id: 'item-2',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-2-p',
                    children: [MarkdownText('second')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.outdentListItemContainingBlock(
        blockId: 'item-2-p',
        selectionOffset: 0,
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(2));
      expect(editor.document.blocks.first, isA<MarkdownListBlock>());
      expect(editor.document.blocks.last, isA<MarkdownParagraphBlock>());
      expect(editor.document.toMarkdown(), '- first\n\nsecond');
    });

    test('backspace at paragraph start merges with previous text block', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'a',
            children: [MarkdownText('Hello')],
          ),
          MarkdownParagraphBlock(
            id: 'b',
            children: [MarkdownText('World')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.deleteBackwardAt(
        blockId: 'b',
        selectionOffset: 0,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'a');
      expect(result.selectionOffset, 5);
      expect(editor.document.blocks, hasLength(1));
      expect(editor.document.toMarkdown(), 'HelloWorld');
    });

    test('backspace at list item start merges with previous item', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.task,
            items: [
              MarkdownListItem(
                id: 'item-1',
                checked: true,
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-1-p',
                    children: [MarkdownText('first')],
                  ),
                ],
              ),
              MarkdownListItem(
                id: 'item-2',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-2-p',
                    children: [MarkdownText('second')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.deleteBackwardAt(
        blockId: 'item-2-p',
        selectionOffset: 0,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'item-1-p');
      expect(result.selectionOffset, 5);
      final list = editor.document.blocks.single as MarkdownListBlock;
      expect(list.items, hasLength(1));
      expect(list.items.single.checked, isTrue);
      expect(editor.document.toMarkdown(), '- [x] firstsecond');
    });

    test('backspace at nested list item start merges with previous nested item',
        () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'parent',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'parent-p',
                    children: [MarkdownText('parent')],
                  ),
                  MarkdownListBlock(
                    id: 'nested',
                    kind: MarkdownListKind.bullet,
                    items: [
                      MarkdownListItem(
                        id: 'child-1',
                        blocks: [
                          MarkdownParagraphBlock(
                            id: 'child-1-p',
                            children: [MarkdownText('child')],
                          ),
                        ],
                      ),
                      MarkdownListItem(
                        id: 'child-2',
                        blocks: [
                          MarkdownParagraphBlock(
                            id: 'child-2-p',
                            children: [MarkdownText('next')],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.deleteBackwardAt(
        blockId: 'child-2-p',
        selectionOffset: 0,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'child-1-p');
      expect(result.selectionOffset, 5);
      expect(editor.document.toMarkdown(), '- parent\n  - childnext');
    });

    test('backspace at first nested list item start outdents it', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'parent',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'parent-p',
                    children: [MarkdownText('parent')],
                  ),
                  MarkdownListBlock(
                    id: 'nested',
                    kind: MarkdownListKind.bullet,
                    items: [
                      MarkdownListItem(
                        id: 'child',
                        blocks: [
                          MarkdownParagraphBlock(
                            id: 'child-p',
                            children: [MarkdownText('child')],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.deleteBackwardAt(
        blockId: 'child-p',
        selectionOffset: 0,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'child-p');
      expect(editor.document.toMarkdown(), '- parent\n- child');
    });

    test('backspace at first list item start exits the list', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item-1',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-1-p',
                    children: [MarkdownText('first')],
                  ),
                ],
              ),
              MarkdownListItem(
                id: 'item-2',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-2-p',
                    children: [MarkdownText('second')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.deleteBackwardAt(
        blockId: 'item-1-p',
        selectionOffset: 0,
      );

      expect(result, isNotNull);
      expect(result!.activeBlockId, 'item-1-p');
      expect(editor.document.blocks, hasLength(2));
      expect(editor.document.blocks.first, isA<MarkdownParagraphBlock>());
      expect(editor.document.blocks.last, isA<MarkdownListBlock>());
      expect(editor.document.toMarkdown(), 'first\n\n- second');
    });

    test('applies inline commands to semantic inline nodes', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [
              MarkdownText('hello '),
              MarkdownStrong([MarkdownText('world')]),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      editor
        ..applyInlineCommand(
          'p',
          const TextRange(start: 0, end: 5),
          MarkdownEditorCommand.bold,
        )
        ..applyInlineCommand(
          'p',
          const TextRange(start: 6, end: 11),
          MarkdownEditorCommand.link,
        )
        ..applyInlineCommand(
          'p',
          const TextRange(start: 0, end: 5),
          MarkdownEditorCommand.image,
        );

      expect(
        editor.document.toMarkdown(),
        '![hello](image-url) [**world**](https://example.com)',
      );
    });

    test('applies inline commands inside table cells', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownTableBlock(
              id: 'table',
              headers: [
                [MarkdownText('A')],
              ],
              alignments: [null],
              rows: [
                [
                  [
                    MarkdownText('Open '),
                    MarkdownLink(
                      url: 'https://example.com',
                      children: [MarkdownText('site')],
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      final applied = editor.applyTableCellInlineCommand(
        blockId: 'table',
        rowIndex: 0,
        columnIndex: 0,
        range: const TextRange(start: 5, end: 9),
        command: MarkdownEditorCommand.bold,
      );

      expect(applied, isTrue);
      expect(
        editor.document.toMarkdown(),
        '| A |\n'
        '| --- |\n'
        '| Open **[site](https://example.com)** |',
      );

      final linked = editor.applyTableCellInlineCommand(
        blockId: 'table',
        rowIndex: 0,
        columnIndex: 0,
        range: const TextRange(start: 0, end: 4),
        command: MarkdownEditorCommand.link,
      );

      expect(linked, isTrue);
      expect(
        editor.document.toMarkdown(),
        '| A |\n'
        '| --- |\n'
        '| [Open](https://example.com) **[site](https://example.com)** |',
      );
    });

    test('edits and removes existing links in text blocks', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownParagraphBlock(
              id: 'p',
              children: [
                MarkdownText('Open '),
                MarkdownStrong([
                  MarkdownLink(
                    url: 'https://old.example',
                    children: [MarkdownText('site')],
                  ),
                ]),
                MarkdownText(' now'),
              ],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      final link = editor.linkAtTextRange(
        'p',
        const TextRange.collapsed(6),
      );

      expect(link, isNotNull);
      expect(link!.url, 'https://old.example');
      expect(link.text, 'site');
      expect(link.range, const TextRange(start: 5, end: 9));

      final updated = editor.updateLinkAtTextRange(
        'p',
        const TextRange.collapsed(6),
        url: 'https://new.example',
      );

      expect(updated, isTrue);
      expect(
        editor.document.toMarkdown(),
        'Open **[site](https://new.example)** now',
      );

      final removed = editor.unlinkAtTextRange(
        'p',
        const TextRange.collapsed(6),
      );

      expect(removed, isTrue);
      expect(editor.document.toMarkdown(), 'Open **site** now');
    });

    test('edits and removes existing links in table cells', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownTableBlock(
              id: 'table',
              headers: [
                [MarkdownText('A')],
              ],
              alignments: [null],
              rows: [
                [
                  [
                    MarkdownText('Open '),
                    MarkdownLink(
                      url: 'https://old.example',
                      children: [MarkdownText('site')],
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      final link = editor.tableCellLinkAtRange(
        blockId: 'table',
        rowIndex: 0,
        columnIndex: 0,
        range: const TextRange.collapsed(7),
      );

      expect(link, isNotNull);
      expect(link!.url, 'https://old.example');
      expect(link.range, const TextRange(start: 5, end: 9));

      final updated = editor.updateTableCellLinkAtRange(
        blockId: 'table',
        rowIndex: 0,
        columnIndex: 0,
        range: const TextRange.collapsed(7),
        url: 'https://new.example',
      );

      expect(updated, isTrue);
      expect(
        editor.document.toMarkdown(),
        '| A |\n'
        '| --- |\n'
        '| Open [site](https://new.example) |',
      );

      final removed = editor.unlinkTableCellAtRange(
        blockId: 'table',
        rowIndex: 0,
        columnIndex: 0,
        range: const TextRange.collapsed(7),
      );

      expect(removed, isTrue);
      expect(
        editor.document.toMarkdown(),
        '| A |\n'
        '| --- |\n'
        '| Open site |',
      );
    });

    test('replaces text ranges with inline nodes', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownParagraphBlock(
              id: 'p',
              children: [MarkdownText('Open [site](https://example.com)')],
            ),
            MarkdownTableBlock(
              id: 'table',
              headers: [
                [MarkdownText('A')],
              ],
              alignments: [null],
              rows: [
                [
                  [MarkdownText('[docs](https://example.com/docs)')],
                ],
              ],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      final paragraphReplaced = editor.replaceTextRangeWithInlineNodes(
        'p',
        const TextRange(start: 5, end: 32),
        [
          const MarkdownLink(
            url: 'https://example.com',
            children: [MarkdownText('site')],
          ),
        ],
      );
      final cellReplaced = editor.replaceTableCellRangeWithInlineNodes(
        blockId: 'table',
        rowIndex: 0,
        columnIndex: 0,
        range: const TextRange(start: 0, end: 33),
        replacement: [
          const MarkdownLink(
            url: 'https://example.com/docs',
            children: [MarkdownText('docs')],
          ),
        ],
      );

      expect(paragraphReplaced, isTrue);
      expect(cellReplaced, isTrue);
      expect(
        editor.document.toMarkdown(),
        'Open [site](https://example.com)\n\n'
        '| A |\n'
        '| --- |\n'
        '| [docs](https://example.com/docs) |',
      );
      final paragraph = editor.document.blocks.first as MarkdownParagraphBlock;
      expect(paragraph.children, contains(isA<MarkdownLink>()));
      final table = editor.document.blocks.last as MarkdownTableBlock;
      expect(table.rows.single.single, contains(isA<MarkdownLink>()));

      final strongReplaced = editor.replaceTextRangeWithInlineNodes(
        'p',
        const TextRange(start: 5, end: 9),
        [
          const MarkdownStrong([MarkdownText('site')]),
        ],
      );

      expect(strongReplaced, isTrue);
      expect(
        editor.document.toMarkdown(),
        'Open **site**\n\n'
        '| A |\n'
        '| --- |\n'
        '| [docs](https://example.com/docs) |',
      );
    });

    test('replaces a text range inside a semantic text block', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('/hea')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final replaced = editor.replaceTextRange(
        'p',
        const TextRange(start: 0, end: 4),
        '',
      );
      editor.applyBlockCommand('p', MarkdownEditorCommand.heading1);

      expect(replaced, isTrue);
      expect(editor.document.blocks.single, isA<MarkdownHeadingBlock>());
      expect(editor.document.toMarkdown(), '#');
    });

    test('replaces selected text with a block math node', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('before latex after')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.replaceTextRangeWithBlockMath(
        'p',
        const TextRange(start: 6, end: 13),
        latex: r'a^2 + b^2 = c^2',
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(3));
      expect(editor.document.blocks[0], isA<MarkdownParagraphBlock>());
      expect(editor.document.blocks[1], isA<MarkdownBlockMathBlock>());
      expect(editor.document.blocks[2], isA<MarkdownParagraphBlock>());
      expect(result!.blockId, editor.document.blocks[1].id);
      expect(result.activeBlockId, editor.document.blocks[2].id);
      expect(
        editor.document.toMarkdown(),
        'before\n\n'
        r'$$'
        '\n'
        r'a^2 + b^2 = c^2'
        '\n'
        r'$$'
        '\n\n'
        'after',
      );
    });

    test('inserts selected block math inside a blockquote like TipTap', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownBlockquoteBlock(
            id: 'quote',
            blocks: [
              MarkdownParagraphBlock(
                id: 'p',
                children: [MarkdownText('before latex after')],
              ),
            ],
          ),
          MarkdownParagraphBlock(
            id: 'tail',
            children: [MarkdownText('Tail')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.replaceTextRangeWithBlockMath(
        'p',
        const TextRange(start: 7, end: 12),
        latex: r'x^2',
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(3));
      final quote = editor.document.blocks[0] as MarkdownBlockquoteBlock;
      expect(quote.blocks, hasLength(3));
      expect(quote.blocks[0].plainText, 'before ');
      expect(quote.blocks[1], isA<MarkdownBlockMathBlock>());
      expect(quote.blocks[2].plainText, ' after');
      expect(editor.document.blocks[1], isA<MarkdownParagraphBlock>());
      expect(editor.document.blocks[1].plainText, '');
      expect(result!.activeBlockId, editor.document.blocks[1].id);
      expect(editor.document.blocks[2].plainText, 'Tail');
      expect(
        editor.document.toMarkdown(),
        '> before \n'
        '>\n'
        r'> $$'
        '\n'
        '> x^2\n'
        r'> $$'
        '\n'
        '>\n'
        '>  after\n\n'
        'Tail',
      );
    });

    test('inserts selected block math inside a list item like TipTap', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'p',
                    children: [MarkdownText('before latex after')],
                  ),
                ],
              ),
            ],
          ),
          MarkdownParagraphBlock(
            id: 'tail',
            children: [MarkdownText('Tail')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.replaceTextRangeWithBlockMath(
        'p',
        const TextRange(start: 7, end: 12),
        latex: r'x^2',
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(3));
      final list = editor.document.blocks[0] as MarkdownListBlock;
      expect(list.items.single.blocks, hasLength(3));
      expect(list.items.single.blocks[0].plainText, 'before ');
      expect(list.items.single.blocks[1], isA<MarkdownBlockMathBlock>());
      expect(list.items.single.blocks[2].plainText, ' after');
      expect(editor.document.blocks[1], isA<MarkdownParagraphBlock>());
      expect(editor.document.blocks[1].plainText, '');
      expect(result!.activeBlockId, editor.document.blocks[1].id);
      expect(editor.document.blocks[2].plainText, 'Tail');

      final markdown = editor.document.toMarkdown();
      expect(markdown, startsWith('- before '));
      expect(markdown, contains('  ' r'$$' '\n  x^2\n  ' r'$$'));
      expect(markdown, contains('after'));
      expect(markdown, endsWith('Tail'));
    });

    test('replaces selected text with a standalone image block', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('before image after')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.replaceTextRangeWithImageBlock(
        'p',
        const TextRange(start: 7, end: 12),
        url: 'assets/diagram.png',
        alt: 'Diagram',
        title: 'Architecture',
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(3));
      expect(editor.document.blocks[0], isA<MarkdownParagraphBlock>());
      expect(editor.document.blocks[1], isA<MarkdownImageBlock>());
      expect(editor.document.blocks[2], isA<MarkdownParagraphBlock>());
      expect(result!.blockId, editor.document.blocks[1].id);
      expect(result.activeBlockId, editor.document.blocks[2].id);
      expect(
        editor.document.toMarkdown(),
        'before \n\n'
        '![Diagram](assets/diagram.png "Architecture")\n\n'
        ' after',
      );
    });

    test('turns a full image input into editable blocks like TipTap', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('placeholder')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.replaceBlockWithImageInputRule(
        'p',
        url: 'image.png',
        alt: 'Diagram',
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(3));
      final before = editor.document.blocks[0] as MarkdownParagraphBlock;
      final image = editor.document.blocks[1] as MarkdownImageBlock;
      final after = editor.document.blocks[2] as MarkdownParagraphBlock;
      expect(before.id, 'p');
      expect(before.plainText, '');
      expect(image.url, 'image.png');
      expect(image.alt, 'Diagram');
      expect(after.plainText, '');
      expect(result!.blockId, image.id);
      expect(result.activeBlockId, after.id);
      expect(editor.document.toMarkdown(), '![Diagram](image.png)');
    });

    test('exits a list after nested block image input like TipTap', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.bullet,
            items: [
              MarkdownListItem(
                id: 'item',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'p',
                    children: [MarkdownText('Open')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final result = editor.replaceTextRangeWithImageBlock(
        'p',
        const TextRange(start: 5, end: 5),
        url: 'image.png',
        alt: 'Diagram',
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(2));
      final list = editor.document.blocks[0] as MarkdownListBlock;
      final afterList = editor.document.blocks[1] as MarkdownParagraphBlock;
      expect(list.items.single.blocks, hasLength(2));
      final before = list.items.single.blocks[0] as MarkdownParagraphBlock;
      final image = list.items.single.blocks[1] as MarkdownImageBlock;
      expect(before.plainText, 'Open');
      expect(image.url, 'image.png');
      expect(result!.activeBlockId, afterList.id);
      expect(afterList.plainText, '');
      expect(
        editor.document.toMarkdown(),
        '- Open\n'
        '  \n'
        '  ![Diagram](image.png)',
      );
    });

    test('replaces an empty document with image and trailing paragraph', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(blocks: []),
      );
      addTearDown(editor.dispose);

      final result = editor.replaceEmptyDocumentWithImageBlock(
        url: 'assets/empty.png',
        alt: 'Empty',
        title: 'Picked',
      );

      expect(result, isNotNull);
      expect(editor.document.blocks, hasLength(2));
      final image = editor.document.blocks[0] as MarkdownImageBlock;
      final after = editor.document.blocks[1] as MarkdownParagraphBlock;
      expect(image.url, 'assets/empty.png');
      expect(image.alt, 'Empty');
      expect(image.title, 'Picked');
      expect(after.plainText, '');
      expect(result!.blockId, image.id);
      expect(result.activeBlockId, after.id);
      expect(
        editor.document.toMarkdown(),
        '![Empty](assets/empty.png "Picked")',
      );
    });

    test('does not replace a non-empty document with an image', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownImageBlock(
              id: 'image',
              url: 'assets/existing.png',
              alt: '',
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      final result = editor.replaceEmptyDocumentWithImageBlock(
        url: 'assets/next.png',
        alt: 'Next',
      );

      expect(result, isNull);
      expect(editor.document.blocks, hasLength(1));
      expect(editor.document.toMarkdown(), '![](assets/existing.png)');
    });

    test('replaces a block with a custom table size', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [MarkdownText('table')],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      editor.replaceBlockWithTable('p', rows: 4, columns: 2);

      final table = editor.document.blocks.single as MarkdownTableBlock;
      expect(table.columnCount, 2);
      expect(table.rows, hasLength(3));
      expect(
        editor.document.toMarkdown(),
        '| Column | Column |\n'
        '| --- | --- |\n'
        '| Cell | Cell |\n'
        '| Cell | Cell |\n'
        '| Cell | Cell |',
      );
    });

    test('plain text edits preserve existing inline marks', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [
              MarkdownText('hello '),
              MarkdownStrong([MarkdownText('world')]),
              MarkdownText(' and '),
              MarkdownLink(
                url: 'https://example.com',
                children: [MarkdownText('site')],
              ),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final replaced = editor.replaceTextBlockText(
        'p',
        'hello brave world and site',
      );

      expect(replaced, isTrue);
      expect(
        editor.document.toMarkdown(),
        'hello brave **world** and [site](https://example.com)',
      );
    });

    test('plain text insertion inside a mark inherits that mark', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownParagraphBlock(
            id: 'p',
            children: [
              MarkdownText('hello '),
              MarkdownStrong([MarkdownText('world')]),
            ],
          ),
        ],
      );
      final editor = MarkdownDocumentEditor(document);
      addTearDown(editor.dispose);

      final replaced = editor.replaceTextBlockText('p', 'hello worXld');

      expect(replaced, isTrue);
      expect(editor.document.toMarkdown(), 'hello **worXld**');
    });

    test('edits table structure without string manipulation', () {
      const table = MarkdownTableBlock(
        id: 'table',
        headers: [
          [MarkdownText('A')],
          [MarkdownText('B')],
        ],
        alignments: [null, MarkdownTableAlignment.right],
        rows: [
          [
            [MarkdownText('1')],
            [MarkdownText('2')],
          ],
        ],
      );
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(blocks: [table]),
      );
      addTearDown(editor.dispose);

      editor
        ..updateTable('table', (table) => table.insertColumnAfter(0))
        ..updateTable(
          'table',
          (table) => table.updateCell(
            rowIndex: 0,
            columnIndex: 1,
            children: const [MarkdownText('inserted')],
          ),
        )
        ..updateTable('table', (table) => table.insertRowAfter(0));

      final updated = editor.document.blocks.single as MarkdownTableBlock;
      expect(updated.columnCount, 3);
      expect(updated.rows, hasLength(2));
      expect(
        updated.toMarkdown(),
        '| A |  | B |\n'
        '| --- | --- | ---: |\n'
        '| 1 | inserted | 2 |\n'
        '|  |  |  |',
      );
    });

    test('toggles table header row and column semantics', () {
      const table = MarkdownTableBlock(
        id: 'table',
        headers: [
          [MarkdownText('A')],
          [MarkdownText('B')],
        ],
        alignments: [null, null],
        rows: [
          [
            [MarkdownText('1')],
            [MarkdownText('2')],
          ],
        ],
      );
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(blocks: [table]),
      );
      addTearDown(editor.dispose);

      editor
        ..toggleTableHeaderRow('table')
        ..toggleTableHeaderColumn('table');

      final updated = editor.document.blocks.single as MarkdownTableBlock;
      expect(updated.headerRow, isFalse);
      expect(updated.headerColumn, isTrue);
      expect(updated.toJson()['headerRow'], isFalse);
      expect(updated.toJson()['headerColumn'], isTrue);
      expect(
        updated.toMarkdown(),
        '| A | B |\n'
        '| --- | --- |\n'
        '| 1 | 2 |',
      );
    });

    test('inserts table rows and columns before active indexes', () {
      const table = MarkdownTableBlock(
        id: 'table',
        headers: [
          [MarkdownText('A')],
          [MarkdownText('B')],
        ],
        alignments: [null, MarkdownTableAlignment.right],
        rows: [
          [
            [MarkdownText('1')],
            [MarkdownText('2')],
          ],
        ],
      );
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(blocks: [table]),
      );
      addTearDown(editor.dispose);

      editor
        ..insertTableColumnBefore('table', 0)
        ..insertTableRowBefore('table', 0);

      expect(
        editor.document.toMarkdown(),
        '|  | A | B |\n'
        '| --- | --- | ---: |\n'
        '|  |  |  |\n'
        '|  | 1 | 2 |',
      );
    });

    test('deletes table blocks through the document model', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownParagraphBlock(
              id: 'before',
              children: [MarkdownText('Before')],
            ),
            MarkdownTableBlock(
              id: 'table',
              headers: [
                [MarkdownText('A')],
              ],
              alignments: [null],
              rows: [
                [
                  [MarkdownText('1')],
                ],
              ],
            ),
            MarkdownParagraphBlock(
              id: 'after',
              children: [MarkdownText('After')],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      editor.deleteTable('table');

      expect(editor.document.toMarkdown(), 'Before\n\nAfter');
      expect(editor.document.blockById('table'), isNull);
    });

    test('inserts and updates standalone image blocks', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownParagraphBlock(
              id: 'p',
              children: [MarkdownText('Intro')],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      final imageId = editor.insertImageBlockAfter(
        'p',
        url: 'assets/diagram.png',
        alt: 'Diagram',
      );

      expect(editor.document.blockById(imageId), isA<MarkdownImageBlock>());
      expect(
        editor.document.toMarkdown(),
        'Intro\n\n![Diagram](assets/diagram.png)',
      );

      editor.updateImageBlock(
        imageId,
        url: 'assets/updated.png',
        alt: 'Updated',
      );

      expect(
        editor.document.toMarkdown(),
        'Intro\n\n![Updated](assets/updated.png)',
      );
    });

    test('removes nested image blocks from containers', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownListBlock(
              id: 'list',
              kind: MarkdownListKind.bullet,
              items: [
                MarkdownListItem(
                  id: 'item',
                  blocks: [
                    MarkdownImageBlock(
                      id: 'list-image',
                      url: 'assets/list.png',
                      alt: 'List image',
                    ),
                  ],
                ),
              ],
            ),
            MarkdownBlockquoteBlock(
              id: 'quote',
              blocks: [
                MarkdownImageBlock(
                  id: 'quote-image',
                  url: 'assets/quote.png',
                  alt: 'Quote image',
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      editor
        ..removeBlock('list-image')
        ..removeBlock('quote-image');

      final list = editor.document.blocks.first as MarkdownListBlock;
      final quote = editor.document.blocks.last as MarkdownBlockquoteBlock;
      expect(list.items.single.blocks, isEmpty);
      expect(quote.blocks, isEmpty);
      expect(editor.document.toMarkdown(), '-\n\n>');
      expect(editor.document.blockById('list-image'), isNull);
      expect(editor.document.blockById('quote-image'), isNull);
    });

    test('updates table cell text through editor transaction helpers', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownTableBlock(
              id: 'table',
              headers: [
                [MarkdownText('A')],
                [MarkdownText('B')],
              ],
              alignments: [null, null],
              rows: [
                [
                  [MarkdownText('1')],
                  [MarkdownText('2')],
                ],
              ],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      editor
        ..updateTableCellText(
          blockId: 'table',
          rowIndex: 0,
          columnIndex: 1,
          text: 'updated',
        )
        ..insertTableColumnAfter('table', 0)
        ..insertTableRowAfter('table', 0);

      expect(
        editor.document.toMarkdown(),
        '| A |  | B |\n'
        '| --- | --- | --- |\n'
        '| 1 |  | updated |\n'
        '|  |  |  |',
      );
    });

    test('table cell text edits preserve inline marks', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownTableBlock(
              id: 'table',
              headers: [
                [MarkdownText('A')],
              ],
              alignments: [null],
              rows: [
                [
                  [
                    MarkdownText('hello '),
                    MarkdownStrong([MarkdownText('world')]),
                    MarkdownText(' and '),
                    MarkdownLink(
                      url: 'https://example.com',
                      children: [MarkdownText('site')],
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      final replaced = editor.replaceTableCellText(
        blockId: 'table',
        rowIndex: 0,
        columnIndex: 0,
        text: 'hello worXld and site',
      );

      expect(replaced, isTrue);
      expect(
        editor.document.toMarkdown(),
        '| A |\n'
        '| --- |\n'
        '| hello **worXld** and [site](https://example.com) |',
      );

      final table = editor.document.blocks.single as MarkdownTableBlock;
      final cell = table.rows.single.single;
      expect(cell, contains(isA<MarkdownStrong>()));
      expect(cell, contains(isA<MarkdownLink>()));
    });

    test('updates task list item checked state by item id', () {
      final editor = MarkdownDocumentEditor(
        const MarkdownDocument(
          blocks: [
            MarkdownListBlock(
              id: 'list',
              kind: MarkdownListKind.task,
              items: [
                MarkdownListItem(
                  id: 'item-1',
                  checked: false,
                  blocks: [
                    MarkdownParagraphBlock(
                      id: 'item-1-p',
                      children: [MarkdownText('first')],
                    ),
                  ],
                ),
                MarkdownListItem(
                  id: 'item-2',
                  checked: true,
                  blocks: [
                    MarkdownParagraphBlock(
                      id: 'item-2-p',
                      children: [MarkdownText('second')],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(editor.dispose);

      editor.updateListItemChecked('item-1', true);

      final list = editor.document.blocks.single as MarkdownListBlock;
      expect(list.items.first.checked, isTrue);
      expect(
        editor.document.toMarkdown(),
        '- [x] first\n'
        '- [x] second',
      );
    });

    test('replaces only the targeted nested list paragraph', () {
      const document = MarkdownDocument(
        blocks: [
          MarkdownListBlock(
            id: 'list',
            kind: MarkdownListKind.task,
            items: [
              MarkdownListItem(
                id: 'item-1',
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-1-p',
                    children: [MarkdownText('first')],
                  ),
                ],
              ),
              MarkdownListItem(
                id: 'item-2',
                checked: true,
                blocks: [
                  MarkdownParagraphBlock(
                    id: 'item-2-p',
                    children: [MarkdownText('second')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final updated = document.replaceBlock(
        const MarkdownParagraphBlock(
          id: 'item-2-p',
          children: [MarkdownText('done')],
        ),
      );

      expect(
        updated.toMarkdown(),
        '- [ ] first\n'
        '- [x] done',
      );
    });
  });
}

class _CustomBlockNode extends MarkdownNode {
  const _CustomBlockNode({
    required this.info,
    required this.content,
  });

  final String info;
  final String content;

  @override
  String get type => 'custom_block';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'info': info,
        'content': content,
      };

  @override
  _CustomBlockNode copyWith({
    String? info,
    String? content,
  }) {
    return _CustomBlockNode(
      info: info ?? this.info,
      content: content ?? this.content,
    );
  }
}

class _CustomBlockPlugin extends BlockParserPlugin {
  const _CustomBlockPlugin();

  @override
  String get id => 'test_custom_block';

  @override
  String get name => 'Test Custom Block';

  @override
  bool canParse(String line, List<String> lines, int index) {
    return line.trim().startsWith(':::custom');
  }

  @override
  BlockParseResult? parse(List<String> lines, int startIndex) {
    final firstLine = lines[startIndex].trim();
    if (!firstLine.startsWith(':::custom')) {
      return null;
    }

    final contentLines = <String>[];
    var index = startIndex + 1;
    while (index < lines.length) {
      if (lines[index].trim() == ':::') {
        break;
      }
      contentLines.add(lines[index]);
      index++;
    }

    return BlockParseResult(
      node: _CustomBlockNode(
        info: firstLine.substring(':::custom'.length).trim(),
        content: contentLines.join('\n'),
      ),
      linesConsumed:
          index < lines.length ? index - startIndex + 1 : index - startIndex,
    );
  }
}

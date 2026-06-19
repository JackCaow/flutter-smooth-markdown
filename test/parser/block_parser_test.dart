import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/block_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockParser Tests', () {
    late BlockParser parser;

    setUp(() {
      parser = BlockParser();
    });

    group('Header Parsing', () {
      test('should parse H1 header', () {
        final result = parser.parse('# Hello World');
        expect(result.length, 1);
        expect(result[0], isA<HeaderNode>());
        final header = result[0] as HeaderNode;
        expect(header.level, 1);
        expect(header.content, 'Hello World');
      });

      test('should parse H2-H6 headers', () {
        const markdown = '''
## H2 Header
### H3 Header
#### H4 Header
##### H5 Header
###### H6 Header
''';
        final result = parser.parse(markdown);
        expect(result.length, 5);

        for (var i = 0; i < 5; i++) {
          expect(result[i], isA<HeaderNode>());
          final header = result[i] as HeaderNode;
          expect(header.level, i + 2);
        }
      });

      test('should require space after #', () {
        final result = parser.parse('#NoSpace');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());
      });
    });

    group('Paragraph Parsing', () {
      test('should parse simple paragraph', () {
        final result = parser.parse('This is a paragraph.');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());
        final para = result[0] as ParagraphNode;
        expect(para.children.length, 1);
        expect((para.children[0] as TextNode).content, 'This is a paragraph.');
      });

      test('should parse multi-line paragraph', () {
        const markdown = '''
This is line one.
This is line two.
This is line three.
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());
      });

      test('should split paragraphs on empty lines', () {
        const markdown = '''
First paragraph.

Second paragraph.
''';
        final result = parser.parse(markdown);
        expect(result.length, 2);
        expect(result[0], isA<ParagraphNode>());
        expect(result[1], isA<ParagraphNode>());
      });
    });

    group('Code Block Parsing', () {
      test('should parse code block without language', () {
        const markdown = '''
```
const x = 10;
console.log(x);
```
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<CodeBlockNode>());
        final codeBlock = result[0] as CodeBlockNode;
        expect(codeBlock.language, null);
        expect(codeBlock.fence, '```');
        expect(codeBlock.code, 'const x = 10;\nconsole.log(x);');
      });

      test('should parse code block with language', () {
        const markdown = '''
```dart
void main() {
  print('Hello');
}
```
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<CodeBlockNode>());
        final codeBlock = result[0] as CodeBlockNode;
        expect(codeBlock.language, 'dart');
        expect(codeBlock.fence, '```');
        expect(codeBlock.code, "void main() {\n  print('Hello');\n}");
      });

      test('should preserve code fence info while exposing language token', () {
        const markdown = '''
```dart title=main.dart linenos
void main() {}
```
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<CodeBlockNode>());
        final codeBlock = result[0] as CodeBlockNode;
        expect(codeBlock.language, 'dart');
        expect(codeBlock.info, 'dart title=main.dart linenos');
        expect(codeBlock.fence, '```');
        expect(codeBlock.code, 'void main() {}');
      });

      test('should keep shorter backtick fence inside longer code block', () {
        const markdown = '''
````dart title=main.dart
before
```
after
````
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<CodeBlockNode>());
        final codeBlock = result[0] as CodeBlockNode;
        expect(codeBlock.language, 'dart');
        expect(codeBlock.info, 'dart title=main.dart');
        expect(codeBlock.fence, '````');
        expect(codeBlock.code, 'before\n```\nafter');
        expect(codeBlock.toJson()['fence'], '````');
        expect(codeBlock.toJson()['info'], 'dart title=main.dart');
      });

      test('should parse tilde code block with language', () {
        const markdown = '''
~~~dart
void main() {}
~~~
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<CodeBlockNode>());
        final codeBlock = result[0] as CodeBlockNode;
        expect(codeBlock.language, 'dart');
        expect(codeBlock.fence, '~~~');
        expect(codeBlock.code, 'void main() {}');
      });

      test('should keep shorter tilde fence inside longer code block', () {
        const markdown = '''
~~~~dart title=main.dart
before
~~~
after
~~~~
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<CodeBlockNode>());
        final codeBlock = result[0] as CodeBlockNode;
        expect(codeBlock.language, 'dart');
        expect(codeBlock.info, 'dart title=main.dart');
        expect(codeBlock.fence, '~~~~');
        expect(codeBlock.code, 'before\n~~~\nafter');
        expect(codeBlock.toJson()['fence'], '~~~~');
        expect(codeBlock.toJson()['info'], 'dart title=main.dart');
      });

      test('should handle unclosed code block', () {
        const markdown = '''
```javascript
const x = 10;
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<CodeBlockNode>());
        final codeBlock = result[0] as CodeBlockNode;
        expect(codeBlock.fence, '```');
      });
    });

    group('Blockquote Parsing', () {
      test('should parse simple blockquote', () {
        final result = parser.parse('> This is a quote');
        expect(result.length, 1);
        expect(result[0], isA<BlockquoteNode>());
        final quote = result[0] as BlockquoteNode;
        expect(quote.children.length, 1);
      });

      test('should parse multi-line blockquote', () {
        const markdown = '''
> Line one
> Line two
> Line three
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<BlockquoteNode>());
      });

      test('should parse nested blockquote elements', () {
        const markdown = '''
> # Header in quote
>
> Paragraph in quote
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<BlockquoteNode>());
        final quote = result[0] as BlockquoteNode;
        expect(quote.children.length, 2);
        expect(quote.children[0], isA<HeaderNode>());
        expect(quote.children[1], isA<ParagraphNode>());
      });
    });

    group('List Parsing', () {
      test('should parse unordered list with -', () {
        const markdown = '''
- Item 1
- Item 2
- Item 3
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<ListNode>());
        final list = result[0] as ListNode;
        expect(list.ordered, false);
        expect(list.items.length, 3);
      });

      test('should parse unordered list with *', () {
        const markdown = '''
* Item 1
* Item 2
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<ListNode>());
        final list = result[0] as ListNode;
        expect(list.ordered, false);
      });

      test('should parse ordered list', () {
        const markdown = '''
1. First
2. Second
3. Third
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<ListNode>());
        final list = result[0] as ListNode;
        expect(list.ordered, true);
        expect(list.items.length, 3);
        expect(list.startIndex, 1);
      });

      test('should parse task list', () {
        const markdown = '''
- [ ] Unchecked task
- [x] Checked task
- [X] Also checked
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<ListNode>());
        final list = result[0] as ListNode;
        expect(list.items[0].checked, false);
        expect(list.items[1].checked, true);
        expect(list.items[2].checked, true);
      });

      test('should split task and bullet list siblings', () {
        const markdown = '''
- [x] Done
- Plain
''';
        final result = parser.parse(markdown);
        expect(result, hasLength(2));

        final taskList = result[0] as ListNode;
        expect(taskList.items, hasLength(1));
        expect(taskList.items.single.checked, true);
        expect(
          (taskList.items.single.children.single as TextNode).content,
          'Done',
        );

        final bulletList = result[1] as ListNode;
        expect(bulletList.items, hasLength(1));
        expect(bulletList.items.single.checked, isNull);
        expect(
          (bulletList.items.single.children.single as TextNode).content,
          'Plain',
        );
      });

      test('should split bullet and task list siblings', () {
        const markdown = '''
- Plain
- [ ] Todo
''';
        final result = parser.parse(markdown);
        expect(result, hasLength(2));

        final bulletList = result[0] as ListNode;
        expect(bulletList.items.single.checked, isNull);
        expect(
          (bulletList.items.single.children.single as TextNode).content,
          'Plain',
        );

        final taskList = result[1] as ListNode;
        expect(taskList.items.single.checked, false);
        expect(
          (taskList.items.single.children.single as TextNode).content,
          'Todo',
        );
      });

      test('should split nested task and bullet child lists', () {
        const markdown = '''
- [x] Done
  - Plain child
  - [ ] Task child
- Plain
''';
        final result = parser.parse(markdown);
        expect(result, hasLength(2));

        final taskList = result[0] as ListNode;
        expect(taskList.items, hasLength(1));
        final taskItem = taskList.items.single;
        expect(taskItem.checked, true);
        expect(taskItem.children, hasLength(3));
        expect((taskItem.children[0] as TextNode).content, 'Done');

        final nestedBullet = taskItem.children[1] as ListNode;
        expect(nestedBullet.items.single.checked, isNull);
        expect(
          (nestedBullet.items.single.children.single as TextNode).content,
          'Plain child',
        );

        final nestedTask = taskItem.children[2] as ListNode;
        expect(nestedTask.items.single.checked, false);
        expect(
          (nestedTask.items.single.children.single as TextNode).content,
          'Task child',
        );

        final bulletList = result[1] as ListNode;
        expect(
          (bulletList.items.single.children.single as TextNode).content,
          'Plain',
        );
      });

      test('should handle list with custom start index', () {
        const markdown = '''
5. Fifth item
6. Sixth item
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<ListNode>());
        final list = result[0] as ListNode;
        expect(list.startIndex, 5);
      });

      test('should parse nested list indentation', () {
        const markdown = '''
- Parent
  - Child
  - Sibling
- Next
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<ListNode>());
        final list = result[0] as ListNode;
        expect(list.items, hasLength(2));
        expect(list.items.first.children.last, isA<ListNode>());

        final nested = list.items.first.children.last as ListNode;
        expect(nested.items, hasLength(2));
        expect(
          (nested.items.first.children.single as TextNode).content,
          'Child',
        );
      });

      test('should parse indented continuation paragraph in list item', () {
        const markdown = '''
- First
  continuation paragraph
- Next
''';
        final result = parser.parse(markdown);

        expect(result, hasLength(1));
        final list = result.single as ListNode;
        expect(list.items, hasLength(2));

        final first = list.items.first;
        expect(first.children, hasLength(2));
        expect((first.children[0] as TextNode).content, 'First');

        final continuation = first.children[1] as ParagraphNode;
        expect(
          (continuation.children.single as TextNode).content,
          'continuation paragraph',
        );
      });

      test('should keep loose indented continuation in list item', () {
        const markdown = '''
- First

  second paragraph
- Next
''';
        final result = parser.parse(markdown);

        expect(result, hasLength(1));
        final list = result.single as ListNode;
        expect(list.items, hasLength(2));

        final first = list.items.first;
        expect(first.children, hasLength(2));
        expect((first.children[0] as TextNode).content, 'First');

        final continuation = first.children[1] as ParagraphNode;
        expect(
          (continuation.children.single as TextNode).content,
          'second paragraph',
        );
      });
    });

    group('Horizontal Rule Parsing', () {
      test('should parse horizontal rule with ---', () {
        final result = parser.parse('---');
        expect(result.length, 1);
        expect(result[0], isA<HorizontalRuleNode>());
      });

      test('should parse horizontal rule with ***', () {
        final result = parser.parse('***');
        expect(result.length, 1);
        expect(result[0], isA<HorizontalRuleNode>());
      });

      test('should parse horizontal rule with ___', () {
        final result = parser.parse('___');
        expect(result.length, 1);
        expect(result[0], isA<HorizontalRuleNode>());
      });

      test('should require at least 3 characters', () {
        final result = parser.parse('--');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());
      });
    });

    group('Mixed Content Parsing', () {
      test('should parse mixed block elements', () {
        const markdown = '''
# Title

This is a paragraph.

## Subtitle

- List item 1
- List item 2

> A quote

```dart
void main() {}
```

---

Final paragraph.
''';
        final result = parser.parse(markdown);
        expect(result.length, 8);
        expect(result[0], isA<HeaderNode>());
        expect(result[1], isA<ParagraphNode>());
        expect(result[2], isA<HeaderNode>());
        expect(result[3], isA<ListNode>());
        expect(result[4], isA<BlockquoteNode>());
        expect(result[5], isA<CodeBlockNode>());
        expect(result[6], isA<HorizontalRuleNode>());
        expect(result[7], isA<ParagraphNode>());
      });
    });

    group('Table Parsing', () {
      test('should parse simple table', () {
        const markdown = '''
| Header 1 | Header 2 |
|----------|----------|
| Cell 1   | Cell 2   |
| Cell 3   | Cell 4   |
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<TableNode>());
        final table = result[0] as TableNode;
        expect(table.headers.length, 2);
        expect(table.rows.length, 2);
      });

      test('should parse table with alignment', () {
        const markdown = '''
| Left | Center | Right |
|:-----|:------:|------:|
| L1   | C1     | R1    |
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<TableNode>());
        final table = result[0] as TableNode;
        expect(table.alignments.length, 3);
        expect(table.alignments[0], TableAlignment.left);
        expect(table.alignments[1], TableAlignment.center);
        expect(table.alignments[2], TableAlignment.right);
      });

      test('should parse table with inline formatting', () {
        const markdown = '''
| Name | Description |
|------|-------------|
| **Bold** | *Italic* text |
| `code` | [link](url) |
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<TableNode>());
        final table = result[0] as TableNode;
        expect(table.rows.length, 2);
        // Check that cells contain parsed inline nodes
        expect(table.rows[0].cells[0].length, greaterThan(0));
      });

      test('should keep escaped pipes inside table cells', () {
        const markdown = r'''
| Name | Description |
|------|-------------|
| A \| B | C \| D |
''';
        final result = parser.parse(markdown);

        expect(result.length, 1);
        final table = result.single as TableNode;
        expect(table.rows.single.cells, hasLength(2));
        expect(
          (table.rows.single.cells[0].single as TextNode).content,
          'A | B',
        );
        expect(
          (table.rows.single.cells[1].single as TextNode).content,
          'C | D',
        );
      });

      test('should parse table with empty cells', () {
        const markdown = '''
| Col1 | Col2 |
|------|------|
|      | Data |
| Data |      |
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<TableNode>());
        final table = result[0] as TableNode;
        expect(table.rows.length, 2);
      });

      test('should parse table without outer pipes', () {
        const markdown = '''
Header 1 | Header 2
---------|----------
Cell 1   | Cell 2
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<TableNode>());
        final table = result[0] as TableNode;
        expect(table.headers.length, 2);
        expect(table.rows.length, 1);
      });

      test('should stop table at empty line', () {
        const markdown = '''
| Header |
|--------|
| Cell   |

Not a table
''';
        final result = parser.parse(markdown);
        expect(result.length, 2);
        expect(result[0], isA<TableNode>());
        expect(result[1], isA<ParagraphNode>());
      });

      test('should handle default alignment', () {
        const markdown = '''
| Col1 | Col2 |
|------|------|
| Data | Data |
''';
        final result = parser.parse(markdown);
        expect(result.length, 1);
        expect(result[0], isA<TableNode>());
        final table = result[0] as TableNode;
        // Default alignment should be null
        expect(table.alignments[0], isNull);
        expect(table.alignments[1], isNull);
      });
    });

    group('Edge Cases', () {
      test('should handle empty input', () {
        final result = parser.parse('');
        expect(result, isEmpty);
      });

      test('should handle only whitespace', () {
        final result = parser.parse('   \n  \n  ');
        expect(result, isEmpty);
      });

      test('should handle single line', () {
        final result = parser.parse('Single line');
        expect(result.length, 1);
        expect(result[0], isA<ParagraphNode>());
      });
    });
  });
}

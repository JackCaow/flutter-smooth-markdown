import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/rust/platform.dart' as core;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native tests exercise ABI 1 rather than a Dart fallback', () {
    expect(MarkdownCore.isNative, isTrue);
  });

  test('owned AST adapts reference links, Unicode, nested lists and GFM', () {
    final nodes = MarkdownParser(backend: MarkdownParserBackend.rust).parse(
      '# **中文🙂**\n\n[link][ref]\n\n[ref]: /path "title"\n\n'
      '- [x] done\n  - child\n\n| left | right |\n| :-- | --: |\n| a | b |',
    );
    final header = nodes.first as HeaderNode;
    expect(header.children!.single, isA<BoldNode>());
    final paragraph = nodes.whereType<ParagraphNode>().single;
    final link = paragraph.children.single as LinkNode;
    expect(link.url, '/path');
    expect(link.title, 'title');
    final list = nodes.whereType<ListNode>().single;
    expect(list.items.first.checked, isTrue);
    expect(list.items.first.children.whereType<ListNode>(), hasLength(1));
    final table = nodes.whereType<TableNode>().single;
    expect(table.alignments, [TableAlignment.left, TableAlignment.right]);
  });

  test('Rust hooks preserve plugin payloads and protect code and escapes', () {
    final plugins = ParserPluginRegistry()
      ..register(const MentionPlugin())
      ..register(const MermaidPlugin());
    final nodes = MarkdownParser(plugins: plugins).parse(
      'hello @alice and `@code` and \\@escaped\n\n```mermaid\ngraph TD\nA --> B\n```',
    );
    final paragraph = nodes.first as ParagraphNode;
    expect(paragraph.children.where((n) => n.type == 'mention'), hasLength(1));
    expect(paragraph.children.whereType<InlineCodeNode>().single.code, '@code');
    expect(nodes.last.type, 'mermaid');
  });

  test('custom inline plugins retain priority over built-in code spans', () {
    final parser = MarkdownParser(
      plugins: ParserPluginRegistry()..register(const _CodeOverride()),
    );
    final inline = parser.parseInlineOnly('`cmd`').single as TextNode;
    expect(inline.content, 'custom command');
    final paragraph = parser.parse('`cmd`').single as ParagraphNode;
    expect((paragraph.children.single as TextNode).content, 'custom command');
  });

  test('propagates a custom parser callback failure', () {
    final plugins = ParserPluginRegistry()..register(const _ThrowingPlugin());
    expect(
      () => MarkdownParser(plugins: plugins).parse('@broken'),
      throwsStateError,
    );
    expect(MarkdownParser().parse('still works'), hasLength(1));
  });

  test('inline entry point does not promote fragments to block syntax', () {
    final nodes = MarkdownParser().parseInlineOnly('# heading *emphasis*');
    expect(nodes.whereType<HeaderNode>(), isEmpty);
    expect(nodes.whereType<ItalicNode>(), hasLength(1));
  });

  test('legacy backend remains an explicit migration path', () {
    expect(
      MarkdownParser(
        backend: MarkdownParserBackend.legacyDart,
      ).parse('1) prose').single,
      isA<ParagraphNode>(),
    );
    expect(
      MarkdownParser(
        backend: MarkdownParserBackend.rust,
      ).parse('1) list').single,
      isA<ListNode>(),
    );
    expect(
      const MarkdownConfig()
          .copyWith(parserBackend: MarkdownParserBackend.legacyDart)
          .parserBackend,
      MarkdownParserBackend.legacyDart,
    );
  });

  test('highlighting has semantic names and UTF16 source offsets', () {
    const source = '// 🙂\nint greet(String name) { return name.length; }';
    final tokens = MarkdownCore.highlightedCode(source, language: 'main.dart');
    expect(
      tokens
          .where((t) => t.kind == MarkdownHighlightKind.functionDefinition)
          .map((t) => source.substring(t.start, t.end)),
      contains('greet'),
    );
    expect(
      tokens
          .where((t) => t.kind == MarkdownHighlightKind.variableParameter)
          .map((t) => source.substring(t.start, t.end)),
      contains('name'),
    );
    var end = 0;
    for (final token in tokens) {
      expect(token.start, greaterThanOrEqualTo(end));
      expect(token.end, lessThanOrEqualTo(source.length));
      end = token.end;
    }
    expect(MarkdownCore.normalizedCodeLanguage('App.tsx'), 'tsx');
    expect(MarkdownCore.normalizedCodeLanguage('unknown-language'), '');
    expect(
      MarkdownCore.highlightedCode('x', language: 'unknown-language'),
      isEmpty,
    );
  });

  test(
    'line highlighting preserves multiline state and expands tab offsets',
    () {
      final lines = MarkdownCore.highlightedLines(
        '/* start\n\tstill comment */\nconst n = 1;\n',
        language: 'dart',
      );
      expect(lines, hasLength(3));
      expect(lines[1].text, '    still comment */');
      expect(lines[1].tokens.first.kind, MarkdownHighlightKind.comment);
      expect(lines[1].tokens.last.end, lines[1].text.length);
      expect(
        () =>
            MarkdownCore.highlightedLines('x', language: 'dart', tabWidth: 17),
        throwsRangeError,
      );
    },
  );

  test('diff carries both number columns, changes, hunks and file notes', () {
    const patch =
        'diff --git a/a.dart b/a.dart\n--- a/a.dart\n+++ b/a.dart\n'
        '@@ -10,3 +20,3 @@ greet\n const a = 1;\n-const n = 2;\n+const n = 3;\n tail();\n'
        '\\ No newline at end of file\n';
    final rows = MarkdownCore.highlightedDiff(patch, language: 'dart');
    expect(rows.map((r) => r.kind), [
      MarkdownDiffKind.hunk,
      MarkdownDiffKind.context,
      MarkdownDiffKind.removed,
      MarkdownDiffKind.added,
      MarkdownDiffKind.context,
      MarkdownDiffKind.note,
    ]);
    expect(rows[1].oldLineNumber, 10);
    expect(rows[1].newLineNumber, 20);
    expect(rows[2].oldLineNumber, 11);
    expect(rows[2].newLineNumber, isNull);
    expect(rows[3].newLineNumber, 21);
    expect(rows[4].oldLineNumber, 12);
    expect(rows[4].newLineNumber, 22);
    expect(
      rows[2].line.text.substring(
        rows[2].changedStart!,
        rows[2].changedStart! + rows[2].changedLength!,
      ),
      '2',
    );
    expect(rows[3].line.tokens, isNotEmpty);
  });

  test(
    'HTML export uses shared CommonMark and escapes raw HTML by default',
    () {
      expect(
        MarkdownCore.exportHtml('[link][x]\n\n[x]: /url'),
        '<p><a href="/url">link</a></p>\n',
      );
      expect(
        MarkdownCore.exportHtml('<script>alert(1)</script>'),
        contains('&lt;script&gt;'),
      );
    },
  );

  test(
    'stream retention counts Rust blocks rather than adapted list groups',
    () {
      const source =
          '- [x] task\n- bullet\n\nfirst\n\nsecond\n\nthird\n\nfourth';
      final session = core.createNativeStream()!;
      try {
        for (var i = 0; i <= source.length; i++) {
          final prefix = source.substring(0, i);
          expect(
            session.update(prefix).map((n) => n.toJson()).toList(),
            core.parseNative(prefix)!.map((n) => n.toJson()).toList(),
            reason: 'prefix $i',
          );
        }
      } finally {
        session.dispose();
      }
    },
  );

  test('stream matches batch at every UTF16 prefix, references and edits', () {
    const source =
        '# 中文🙂\n\nfirst *em*\n\n- one\n- two\n\n[ref][x]\n\n[x]: /url\n';
    final session = core.createNativeStream()!;
    try {
      for (var i = 0; i <= source.length; i++) {
        final prefix = source.substring(0, i);
        expect(
          session.update(prefix).map((n) => n.toJson()).toList(),
          core.parseNative(prefix)!.map((n) => n.toJson()).toList(),
          reason: 'UTF16 prefix $i',
        );
      }
      expect(
        session.update('edited').map((n) => n.toJson()).toList(),
        MarkdownParser().parse('edited').map((n) => n.toJson()).toList(),
      );
    } finally {
      session.dispose();
      session.dispose();
    }
    expect(() => session.update('closed'), throwsStateError);
  });
}

class _ThrowingPlugin extends InlineParserPlugin {
  const _ThrowingPlugin();
  @override
  String get id => 'throws';
  @override
  String get name => 'Throws';
  @override
  String get triggerCharacter => '@';
  @override
  bool canParse(String text, int index) => true;
  @override
  InlineParseResult? parse(String text, int startIndex) =>
      throw StateError('plugin failure');
}

class _CodeOverride extends InlineParserPlugin {
  const _CodeOverride();
  @override
  String get id => 'code-override';
  @override
  String get name => 'Code override';
  @override
  String get triggerCharacter => '`';
  @override
  bool canParse(String text, int index) => text.startsWith('`cmd`', index);
  @override
  InlineParseResult? parse(String text, int index) =>
      const InlineParseResult(node: TextNode('custom command'), consumed: 5);
}

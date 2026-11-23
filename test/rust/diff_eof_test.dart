import 'package:flutter/foundation.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const note = r'\ No newline at end of file';
  const header = '@@ -10,2 +20,2 @@';
  const old = '-old */';
  const added = '+new */';

  for (final (oldNote, newNote) in [
    (false, false),
    (true, false),
    (false, true),
    (true, true),
  ]) {
    test(
      'diff preserves highlighting with EOF notes old=$oldNote new=$newNote',
      () {
        expect(MarkdownCore.isNative, !kIsWeb);
        final rows = MarkdownCore.highlightedDiff(
          [
            header,
            ' /* comment',
            old,
            if (oldNote) note,
            added,
            if (newNote) note,
          ].join('\n'),
          language: 'dart',
        );
        expect(rows.map((r) => r.kind), [
          MarkdownDiffKind.hunk,
          MarkdownDiffKind.context,
          MarkdownDiffKind.removed,
          if (oldNote) MarkdownDiffKind.note,
          MarkdownDiffKind.added,
          if (newNote) MarkdownDiffKind.note,
        ]);
        for (final row in rows.where((r) => r.kind == MarkdownDiffKind.note)) {
          expect(row.line.text, endsWith('No newline at end of file'));
          expect(
            (row.oldLineNumber, row.newLineNumber, row.changedStart),
            (null, null, null),
          );
          expect(row.line.tokens, isEmpty);
        }
        final removed = rows.singleWhere(
          (r) => r.kind == MarkdownDiffKind.removed,
        );
        final inserted = rows.singleWhere(
          (r) => r.kind == MarkdownDiffKind.added,
        );
        expect((removed.oldLineNumber, removed.newLineNumber), (11, null));
        expect((inserted.oldLineNumber, inserted.newLineNumber), (null, 21));
        for (final row in [removed, inserted]) {
          expect((row.changedStart, row.changedLength), (0, 3));
          final token = row.line.tokens.single;
          expect(
            (token.kind, token.start, token.end),
            (MarkdownHighlightKind.comment, 0, row.line.text.length),
          );
        }
      },
    );
  }

  test(
    'multiple replacements keep their order on either side of an EOF note',
    () {
      final rows = MarkdownCore.highlightedDiff(
        [
          '@@ -1,2 +1,3 @@',
          '-a = 1',
          '-b = 2',
          note,
          '+a = 3',
          '+b = 4',
          '+extra',
          note,
        ].join('\n'),
        language: 'dart',
      );
      final changes = [
        for (final row in rows)
          if (row.kind == MarkdownDiffKind.removed ||
              row.kind == MarkdownDiffKind.added)
            (row.line.text, row.changedStart, row.changedLength),
      ];
      expect(changes, [
        ('a = 1', 4, 1),
        ('b = 2', 4, 1),
        ('a = 3', 4, 1),
        ('b = 4', 4, 1),
        ('extra', null, null),
      ]);
    },
  );

  test('EOF notes keep replacements and lexer state within their own hunk', () {
    final rows = MarkdownCore.highlightedDiff(
      [
        '@@ -1,1 +0,0 @@',
        '-/* open',
        note,
        '@@ -5,0 +5,1 @@',
        '+/* another open',
        note,
        'diff --git a/b.dart b/b.dart',
        '--- a/b.dart',
        '+++ b/b.dart',
        '@@ -1,0 +1,1 @@',
        '+const x = 1;',
      ].join('\n'),
      language: 'dart',
    );
    for (final row in rows) {
      expect(row.changedStart, isNull);
    }
    final number = rows.last.line.tokens.singleWhere(
      (t) => t.kind == MarkdownHighlightKind.number,
    );
    expect(rows.last.line.text.substring(number.start, number.end), '1');
  });
}

import 'package:highlight/highlight.dart' as dart_highlight;

import 'core_types.dart';

String fallbackLanguage(String language) {
  final file = language.trim().toLowerCase().split('/').last;
  final special = switch (file) {
    'dockerfile' || 'containerfile' => 'dockerfile',
    'makefile' || 'gnumakefile' => 'makefile',
    '.env' || '.envrc' || '.bashrc' || '.zshrc' || '.profile' || '.bash_profile' => 'shell',
    '.gitignore' || '.dockerignore' || '.gitattributes' || '.editorconfig' => 'ini',
    'cargo.lock' || 'pipfile' || 'poetry.lock' => 'toml',
    'gemfile' || 'rakefile' || 'podfile' => 'ruby',
    _ => null,
  };
  if (special != null) return special;
  if (file.startsWith('dockerfile.') || file.endsWith('.dockerfile')) return 'dockerfile';
  if (file.startsWith('.env.')) return 'shell';
  final name = file.split(RegExp(r'[\s,{]')).first.split('.').last;
  return switch (name) {
    'js' || 'mjs' || 'cjs' || 'javascript' || 'node' || 'jsx' => 'javascript',
    'ts' || 'mts' || 'cts' || 'typescript' => 'typescript',
    'tsx' => 'tsx',
    'kt' || 'kts' || 'kotlin' => 'kotlin',
    'groovy' || 'gradle' || 'gvy' => 'groovy',
    'scala' || 'sc' || 'sbt' => 'scala',
    'c' || 'h' => 'c',
    'cc' || 'cpp' || 'c++' || 'cxx' || 'hpp' || 'hh' || 'hxx' || 'ino' => 'cpp',
    'm' || 'mm' || 'objc' || 'objective-c' || 'objectivec' => 'objective-c',
    'cs' || 'c#' || 'csharp' => 'csharp',
    'go' || 'golang' => 'go',
    'rs' || 'rust' => 'rust',
    'py' || 'pyi' || 'python' || 'python3' || 'py3' => 'python',
    'rb' || 'ruby' || 'rake' || 'gemspec' => 'ruby',
    'php' || 'phtml' => 'php',
    'sql' || 'mysql' || 'pgsql' || 'postgres' || 'postgresql' || 'sqlite' || 'plsql' => 'sql',
    'graphql' || 'gql' => 'graphql',
    'proto' || 'protobuf' => 'protobuf',
    'json' || 'jsonc' || 'json5' || 'webmanifest' || 'babelrc' || 'eslintrc' => 'json',
    'yaml' || 'yml' => 'yaml',
    'ini' || 'cfg' || 'conf' || 'properties' || 'env' || 'dotenv' || 'editorconfig' || 'gitconfig' => 'ini',
    'md' || 'markdown' || 'mdx' || 'mkd' => 'markdown',
    'html' || 'htm' || 'xhtml' => 'html',
    'xml' || 'svg' || 'plist' || 'xsd' || 'xsl' || 'storyboard' || 'xib' || 'csproj' || 'pom' => 'xml',
    'scss' || 'sass' => 'scss',
    'sh' || 'bash' || 'zsh' || 'fish' || 'ksh' || 'shell' || 'shellscript' || 'console' || 'shellsession' || 'command' => 'shell',
    'dockerfile' || 'docker' || 'containerfile' => 'dockerfile',
    'makefile' || 'make' || 'mk' || 'mak' => 'makefile',
    'patch' || 'diff' => 'diff',
    'swift' || 'java' || 'dart' || 'lua' || 'r' || 'zig' || 'toml' ||
    'vue' || 'svelte' || 'css' || 'less' => name,
    _ => '',
  };
}

List<MarkdownHighlightToken> fallbackCode(String source, String language) {
  final tokens = <MarkdownHighlightToken>[];
  var offset = 0;
  void visit(List<dart_highlight.Node> nodes, MarkdownHighlightKind inherited) {
    for (final node in nodes) {
      final kind = switch (node.className) {
        'keyword' => MarkdownHighlightKind.keyword,
        'built_in' || 'type' => MarkdownHighlightKind.typeBuiltin,
        'string' => MarkdownHighlightKind.string,
        'comment' => MarkdownHighlightKind.comment,
        'number' => MarkdownHighlightKind.number,
        'literal' => MarkdownHighlightKind.boolean,
        'title' => MarkdownHighlightKind.functionDefinition,
        'function' => MarkdownHighlightKind.function,
        'attr' || 'attribute' => MarkdownHighlightKind.attribute,
        'tag' || 'name' => MarkdownHighlightKind.tag,
        'variable' || 'params' => MarkdownHighlightKind.variableParameter,
        _ => inherited,
      };
      if (node.value != null) {
        final length = node.value!.length;
        if (kind != MarkdownHighlightKind.none && length != 0) {
          tokens.add(
            MarkdownHighlightToken(start: offset, length: length, kind: kind),
          );
        }
        offset += length;
      } else {
        visit(node.children ?? [], kind);
      }
    }
  }

  final result = dart_highlight.highlight.parse(
    source,
    language: switch (fallbackLanguage(language)) { 'tsx' => 'typescript', 'shell' => 'bash', '' => 'plaintext', final name => name },
  );
  visit(result.nodes ?? [], MarkdownHighlightKind.none);
  return List.unmodifiable(tokens);
}

List<MarkdownHighlightedLine> fallbackLines(
  String source,
  String language,
  int tabWidth,
) {
  if (tabWidth < 0 || tabWidth > 16) {
    throw RangeError.range(tabWidth, 0, 16, 'tabWidth');
  }
  final tokens = fallbackCode(source, language);
  final raw = source.endsWith('\n')
      ? source.substring(0, source.length - 1)
      : source;
  var offset = 0;
  return List.unmodifiable(
    raw.split('\n').map((text) {
      final physicalLength = text.length;
      if (text.endsWith('\r')) text = text.substring(0, text.length - 1);
      final expanded = StringBuffer();
      final positions = <int>[0];
      for (final unit in text.codeUnits) {
        expanded.write(
          unit == 9 && tabWidth > 0
              ? ' ' * tabWidth
              : String.fromCharCode(unit),
        );
        positions.add(expanded.length);
      }
      final lineTokens = <MarkdownHighlightToken>[];
      for (final token in tokens) {
        final start = (token.start - offset).clamp(0, text.length);
        final end = (token.end - offset).clamp(0, text.length);
        if (end > start) {
          lineTokens.add(
            MarkdownHighlightToken(
              start: positions[start],
              length: positions[end] - positions[start],
              kind: token.kind,
            ),
          );
        }
      }
      offset += physicalLength + 1;
      return MarkdownHighlightedLine(
        text: expanded.toString(),
        tokens: List.unmodifiable(lineTokens),
      );
    }),
  );
}

List<MarkdownDiffRow> fallbackDiff(
  String patch,
  String language,
  int tabWidth,
) {
  final rows = <MarkdownDiffRow>[];
  var oldLine = 0, newLine = 0, oldRemaining = 0, newRemaining = 0;
  for (final raw in patch.split(RegExp(r'\r?\n'))) {
    final hunk = RegExp(
      r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',
    ).firstMatch(raw);
    if (hunk != null) {
      oldLine = int.parse(hunk[1]!);
      newLine = int.parse(hunk[3]!);
      oldRemaining = int.parse(hunk[2] ?? '1');
      newRemaining = int.parse(hunk[4] ?? '1');
      rows.add(
        MarkdownDiffRow(
          kind: MarkdownDiffKind.hunk,
          line: MarkdownHighlightedLine(text: raw, tokens: const []),
        ),
      );
    } else if (raw.startsWith(r'\ ') ||
        raw.startsWith('Binary files ') ||
        raw.contains('file mode 120000')) {
      rows.add(
        MarkdownDiffRow(
          kind: MarkdownDiffKind.note,
          line: MarkdownHighlightedLine(text: raw, tokens: const []),
        ),
      );
    } else if (raw.isNotEmpty && (oldRemaining > 0 || newRemaining > 0)) {
      final kind = switch (raw[0]) {
        '+' => MarkdownDiffKind.added,
        '-' => MarkdownDiffKind.removed,
        ' ' => MarkdownDiffKind.context,
        _ => null,
      };
      if (kind == null) continue;
      final oldNumber = kind != MarkdownDiffKind.added ? oldLine++ : null;
      final newNumber = kind != MarkdownDiffKind.removed ? newLine++ : null;
      if (oldNumber != null) oldRemaining--;
      if (newNumber != null) newRemaining--;
      rows.add(
        MarkdownDiffRow(
          kind: kind,
          line: MarkdownHighlightedLine(
            text: raw.substring(1),
            tokens: const [],
          ),
          oldLineNumber: oldNumber,
          newLineNumber: newNumber,
        ),
      );
    }
  }
  // Highlight each hunk's complete old and new sides, preserving lexer state.
  var begin = 0;
  while (begin < rows.length) {
    var end = begin + 1;
    while (end < rows.length && rows[end].kind != MarkdownDiffKind.hunk) {
      end++;
    }
    for (final oldSide in [false, true]) {
      final indices = [
        for (var i = begin; i < end; i++)
          if (rows[i].kind == MarkdownDiffKind.context ||
              rows[i].kind ==
                  (oldSide ? MarkdownDiffKind.removed : MarkdownDiffKind.added))
            i,
      ];
      final lines = fallbackLines(
        indices.map((i) => rows[i].line.text).join('\n') + '\n',
        language,
        tabWidth,
      );
      for (var n = 0; n < indices.length; n++) {
        final i = indices[n], row = rows[i];
        if (oldSide && row.kind != MarkdownDiffKind.removed) continue;
        rows[i] = MarkdownDiffRow(
          kind: row.kind,
          line: lines[n],
          oldLineNumber: row.oldLineNumber,
          newLineNumber: row.newLineNumber,
        );
      }
    }
    begin = end;
  }
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].kind != MarkdownDiffKind.removed ||
        (i > 0 && rows[i - 1].kind == MarkdownDiffKind.removed)) {
      continue;
    }
    var added = i;
    while (added < rows.length &&
        rows[added].kind == MarkdownDiffKind.removed) {
      added++;
    }
    var end = added;
    while (end < rows.length && rows[end].kind == MarkdownDiffKind.added) {
      end++;
    }
    for (var n = 0; n < added - i && n < end - added; n++) {
      final a = rows[i + n].line.text, b = rows[added + n].line.text;
      var start = 0, suffix = 0;
      while (start < a.length &&
          start < b.length &&
          a.codeUnitAt(start) == b.codeUnitAt(start)) {
        start++;
      }
      while (suffix < a.length - start &&
          suffix < b.length - start &&
          a.codeUnitAt(a.length - suffix - 1) ==
              b.codeUnitAt(b.length - suffix - 1)) {
        suffix++;
      }
      for (final index in [i + n, added + n]) {
        final row = rows[index];
        rows[index] = MarkdownDiffRow(
          kind: row.kind,
          line: row.line,
          oldLineNumber: row.oldLineNumber,
          newLineNumber: row.newLineNumber,
          changedStart: start,
          changedLength: row.line.text.length - start - suffix,
        );
      }
    }
  }
  return List.unmodifiable(rows);
}

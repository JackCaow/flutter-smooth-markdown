import 'dart:convert';

/// Converts Markdown source to a readable plain-text representation.
///
/// This mirrors Scratch's copy-as-plain-text behavior: Markdown structure is
/// stripped outside fenced code blocks, while code block content is preserved.
String markdownToPlainText(String markdown) {
  var inCodeBlock = false;
  final plainLines = <String>[];

  for (final line in markdown.split(RegExp(r'\r?\n'))) {
    var text = line;

    if (RegExp(r'^\s*(```|~~~)').hasMatch(text)) {
      inCodeBlock = !inCodeBlock;
      plainLines.add('');
      continue;
    }

    if (!inCodeBlock) {
      text = text
          .replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '')
          .replaceFirst(RegExp(r'^\s{0,3}>\s?'), '')
          .replaceFirst(RegExp(r'^\s*([-*+]\s+|\d+\.\s+)'), '')
          .replaceFirst(RegExp(r'^\[[ xX]\]\s+'), '')
          .replaceFirst(RegExp(r'^\s*([*-]){3,}\s*$'), '');
      text = _replaceAllMapped(text, RegExp(r'!\[(.*?)\]\([^)]*\)'), 1);
      text = _replaceAllMapped(text, RegExp(r'\[(.+?)\]\([^)]*\)'), 1);
      text = _replaceAllMapped(text, RegExp(r'`([^`]+)`'), 1);
      text = _replaceAllMapped(text, RegExp(r'\*\*(.+?)\*\*'), 1);
      text = _replaceUnderscoreDelimiterPairs(
        text,
        '__',
        (content) => content,
      );
      text = _replaceAllMapped(text, RegExp(r'\*(.+?)\*'), 1);
      text = _replaceUnderscoreDelimiterPairs(
        text,
        '_',
        (content) => content,
      );
      text = _replaceAllMapped(text, RegExp(r'~~(.+?)~~'), 1);
    }

    plainLines.add(text);
  }

  return plainLines
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trimRight();
}

String _replaceAllMapped(String text, RegExp pattern, int group) {
  return text.replaceAllMapped(pattern, (match) => match.group(group) ?? '');
}

const _markdownEscapableChars = r'\`*_{}[]()#+-.!~$|>';

_FrontmatterExport? _consumeFrontmatter(String markdown) {
  final match = RegExp(
    '^(?:\uFEFF)?---[ \\t]*\\r?\\n'
    '([\\s\\S]*?\\r?\\n)?'
    '---[ \\t]*(?:\\r?\\n|\$)',
  ).firstMatch(markdown);
  if (match == null) return null;

  final content = (match.group(1) ?? '').replaceFirst(
    RegExp(r'\r?\n$'),
    '',
  );
  return _FrontmatterExport(
    content: content,
    body: markdown.substring(match.end),
  );
}

/// Converts Markdown source to a compact HTML fragment for copy/export actions.
///
/// The editor keeps Markdown as its source of truth. This helper provides a
/// dependency-free HTML representation for the editor's copy menu.
String markdownToHtml(String markdown) {
  if (markdown.trim().isEmpty) return '';

  final frontmatter = _consumeFrontmatter(markdown);
  final lines = (frontmatter?.body ?? markdown).split(RegExp(r'\r?\n'));
  final buffer = StringBuffer();

  if (frontmatter != null) {
    buffer.writeln(
      '<pre data-frontmatter="" class="frontmatter"><code>${htmlEscape.convert(frontmatter.content)}</code></pre>',
    );
  }

  buffer.write(_markdownLinesToHtml(lines));
  return buffer.toString().trimRight();
}

String _markdownLinesToHtml(List<String> lines) {
  final buffer = StringBuffer();
  var index = 0;

  while (index < lines.length) {
    final line = lines[index];
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      index++;
      continue;
    }

    final fenceMatch = RegExp(r'^(```|~~~)\s*(.*)$').firstMatch(trimmed);
    if (fenceMatch != null) {
      final fence = fenceMatch.group(1)!;
      final info = fenceMatch.group(2)!.trim();
      final language = info.isEmpty ? '' : info.split(RegExp(r'\s+')).first;
      final codeLines = <String>[];
      index++;
      while (index < lines.length && !lines[index].trim().startsWith(fence)) {
        codeLines.add(lines[index]);
        index++;
      }
      if (index < lines.length) index++;

      final classAttribute = language.isEmpty
          ? ''
          : ' class="language-${_escapeAttribute(language)}"';
      buffer.writeln(
        '<pre><code$classAttribute>${htmlEscape.convert(codeLines.join('\n'))}</code></pre>',
      );
      continue;
    }

    final singleLineBlockMathMatch = _singleLineBlockMathMatch(trimmed);
    if (singleLineBlockMathMatch != null) {
      buffer.writeln(_blockMathHtml(singleLineBlockMathMatch.group(1)!.trim()));
      index++;
      continue;
    }

    if (trimmed == r'$$') {
      final mathLines = <String>[];
      index++;
      while (index < lines.length && lines[index].trim() != r'$$') {
        mathLines.add(lines[index]);
        index++;
      }
      if (index < lines.length) index++;
      buffer.writeln(_blockMathHtml(mathLines.join('\n').trim()));
      continue;
    }

    final blockImageMatch = _blockImageMatch(trimmed);
    if (blockImageMatch != null) {
      buffer.writeln(
        _imageHtml(
          src: blockImageMatch.group(2)!,
          alt: blockImageMatch.group(1)!,
          title: blockImageMatch.group(3),
        ),
      );
      index++;
      continue;
    }

    final headingMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(trimmed);
    if (headingMatch != null) {
      final level = headingMatch.group(1)!.length;
      buffer.writeln(
        '<h$level>${_inlineMarkdownToHtml(headingMatch.group(2)!)}</h$level>',
      );
      index++;
      continue;
    }

    if (_isThematicBreak(trimmed)) {
      buffer.writeln('<hr>');
      index++;
      continue;
    }

    if (_isTableStart(lines, index)) {
      index = _writeTableHtml(lines, index, buffer);
      continue;
    }

    if (_isDetailsStart(trimmed)) {
      index = _writeDetailsHtml(lines, index, buffer);
      continue;
    }

    if (_parseHtmlListLine(line) != null) {
      index = _writeListHtml(lines, index, buffer);
      continue;
    }

    if (trimmed.startsWith('>')) {
      final quoteLines = <String>[];
      while (index < lines.length && lines[index].trimLeft().startsWith('>')) {
        quoteLines.add(
          lines[index].trimLeft().replaceFirst(RegExp(r'^>\s?'), ''),
        );
        index++;
      }
      final quoteHtml = _markdownLinesToHtml(quoteLines);
      buffer.writeln(
        '<blockquote>$quoteHtml</blockquote>',
      );
      continue;
    }

    final paragraphLines = <String>[];
    while (index < lines.length &&
        lines[index].trim().isNotEmpty &&
        !_isSpecialBlockStart(lines, index)) {
      paragraphLines.add(lines[index]);
      index++;
    }
    buffer.writeln(
      '<p>${_paragraphMarkdownToHtml(paragraphLines)}</p>',
    );
  }

  return buffer.toString().trimRight();
}

bool _isSpecialBlockStart(List<String> lines, int index) {
  final trimmed = lines[index].trim();
  return RegExp(r'^(```|~~~)').hasMatch(trimmed) ||
      _singleLineBlockMathMatch(trimmed) != null ||
      trimmed == r'$$' ||
      _blockImageMatch(trimmed) != null ||
      RegExp(r'^(#{1,6})\s+').hasMatch(trimmed) ||
      _isThematicBreak(trimmed) ||
      _isTableStart(lines, index) ||
      _isDetailsStart(trimmed) ||
      _parseHtmlListLine(lines[index]) != null ||
      trimmed.startsWith('>');
}

bool _isThematicBreak(String trimmed) {
  return RegExp(r'^([-*_])(?:\s*\1){2,}$').hasMatch(trimmed);
}

RegExpMatch? _singleLineBlockMathMatch(String trimmed) {
  return RegExp(r'^\$\$([^$]+)\$\$$').firstMatch(trimmed);
}

RegExpMatch? _blockImageMatch(String trimmed) {
  return RegExp(
    r'''^!\[([^\]\n]*)\]\(([^)\s]+)(?:\s+["'](.+?)["'])?\)$''',
  ).firstMatch(trimmed);
}

String _paragraphMarkdownToHtml(List<String> lines) {
  final buffer = StringBuffer();
  var previousLineEndedWithHardBreak = false;

  for (final line in lines) {
    final segment = _paragraphLineSegment(line);
    if (buffer.isNotEmpty && !previousLineEndedWithHardBreak) {
      buffer.write(' ');
    }
    buffer.write(_inlineMarkdownToHtml(segment.markdown.trim()));
    if (segment.hardBreak) {
      buffer.write('<br>');
    }
    previousLineEndedWithHardBreak = segment.hardBreak;
  }

  return buffer.toString();
}

_ParagraphLineSegment _paragraphLineSegment(String line) {
  final rightTrimmed = line.trimRight();
  if (rightTrimmed.endsWith(r'\')) {
    return _ParagraphLineSegment(
      rightTrimmed.substring(0, rightTrimmed.length - 1),
      hardBreak: true,
    );
  }

  if (RegExp(r' {2,}$').hasMatch(line)) {
    return _ParagraphLineSegment(rightTrimmed, hardBreak: true);
  }

  return _ParagraphLineSegment(line, hardBreak: false);
}

int _writeListHtml(List<String> lines, int index, StringBuffer buffer) {
  final first = _parseHtmlListLine(lines[index]);
  if (first == null) return index;
  return _writeListLevelHtml(lines, index, buffer, first.indent, first.kind);
}

int _writeListLevelHtml(
  List<String> lines,
  int index,
  StringBuffer buffer,
  int indent,
  _HtmlListKind kind,
) {
  final first = _parseHtmlListLine(lines[index]);
  if (first == null) return index;

  final listTag = kind == _HtmlListKind.ordered ? 'ol' : 'ul';
  final startAttribute =
      kind == _HtmlListKind.ordered && first.orderNumber != null
          ? first.orderNumber == 1
              ? ''
              : ' start="${first.orderNumber}"'
          : '';
  final taskAttribute =
      kind == _HtmlListKind.task ? ' data-type="taskList"' : '';

  buffer.writeln('<$listTag$startAttribute$taskAttribute>');

  while (index < lines.length) {
    final item = _parseHtmlListLine(lines[index]);
    if (item == null || item.indent < indent) break;
    if (item.indent > indent) break;
    if (item.kind != kind) break;

    _writeListItemOpening(buffer, item);
    index++;

    while (index < lines.length) {
      final nested = _parseHtmlListLine(lines[index]);
      if (nested == null || nested.indent <= indent) break;
      index = _writeListLevelHtml(
        lines,
        index,
        buffer,
        nested.indent,
        nested.kind,
      );
    }

    _writeListItemClosing(buffer, item);
  }

  buffer.writeln('</$listTag>');
  return index;
}

void _writeListItemOpening(StringBuffer buffer, _HtmlListLine item) {
  final content = _inlineMarkdownToHtml(item.content);
  if (item.kind == _HtmlListKind.task) {
    final checkedAttribute = item.checked ? ' checked="checked"' : '';
    buffer.write(
      '<li data-checked="${item.checked}" data-type="taskItem"><label><input type="checkbox"$checkedAttribute><span></span></label><div><p>$content</p>',
    );
    return;
  }

  buffer.write('<li><p>$content</p>');
}

void _writeListItemClosing(StringBuffer buffer, _HtmlListLine item) {
  if (item.kind == _HtmlListKind.task) {
    buffer.writeln('</div></li>');
    return;
  }

  buffer.writeln('</li>');
}

_HtmlListLine? _parseHtmlListLine(String line) {
  final match = RegExp(
    r'^([ \t]*)(?:([-*+])|(\d+)[.)])\s+(.*)$',
  ).firstMatch(line);
  if (match == null) return null;

  final marker = match.group(2);
  final orderNumber = int.tryParse(match.group(3) ?? '');
  var content = match.group(4) ?? '';
  final taskMatch = RegExp(r'^\[([ xX])\]\s*(.*)$').firstMatch(content);
  final kind = taskMatch != null
      ? _HtmlListKind.task
      : orderNumber == null
          ? _HtmlListKind.bullet
          : _HtmlListKind.ordered;

  var checked = false;
  if (taskMatch != null) {
    checked = taskMatch.group(1)!.trim().isNotEmpty;
    content = taskMatch.group(2) ?? '';
  }

  final indent = match.group(1)!.replaceAll('\t', '  ').length;
  return _HtmlListLine(
    indent: indent,
    kind: kind,
    content: content,
    checked: checked,
    orderNumber: marker == null ? orderNumber : null,
  );
}

bool _isTableStart(List<String> lines, int index) {
  if (index + 1 >= lines.length) return false;
  final header = lines[index].trim();
  final separator = lines[index + 1].trim();
  return _hasUnescapedPipe(header) &&
      RegExp(r'^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?$')
          .hasMatch(separator);
}

int _writeTableHtml(List<String> lines, int index, StringBuffer buffer) {
  final headers = _splitTableCells(lines[index]);
  final alignments = _parseTableAlignments(lines[index + 1]);
  index += 2;

  final columnCount = headers.length;
  buffer
    ..writeln(
      '<table class="not-prose" style="min-width: ${columnCount * 25}px">',
    )
    ..writeln('<colgroup>');
  for (var column = 0; column < columnCount; column += 1) {
    buffer.writeln('<col style="min-width: 25px">');
  }
  buffer
    ..writeln('</colgroup>')
    ..writeln('<tbody>')
    ..writeln('<tr>');
  for (var column = 0; column < columnCount; column += 1) {
    _writeTableCellHtml(
      buffer,
      'th',
      headers[column],
      _tableAlignmentAt(alignments, column),
    );
  }
  buffer.writeln('</tr>');

  final rows = <List<String>>[];
  while (index < lines.length && _hasUnescapedPipe(lines[index].trim())) {
    rows.add(_splitTableCells(lines[index]));
    index++;
  }

  for (final row in rows) {
    buffer.writeln('<tr>');
    final cells = _normalizedTableRowCells(row, columnCount);
    for (var column = 0; column < columnCount; column += 1) {
      _writeTableCellHtml(
        buffer,
        'td',
        cells[column],
        _tableAlignmentAt(alignments, column),
      );
    }
    buffer.writeln('</tr>');
  }

  buffer
    ..writeln('</tbody>')
    ..writeln('</table>');
  return index;
}

List<String> _normalizedTableRowCells(List<String> row, int columnCount) {
  return [
    for (var column = 0; column < columnCount; column += 1)
      column < row.length ? row[column] : '',
  ];
}

void _writeTableCellHtml(
  StringBuffer buffer,
  String tag,
  String markdown,
  _HtmlTableAlignment? alignment,
) {
  final styleAttribute =
      alignment == null ? '' : ' style="text-align: ${alignment.name}"';
  buffer.writeln(
    '<$tag colspan="1" rowspan="1"><p$styleAttribute>${_inlineMarkdownToHtml(markdown)}</p></$tag>',
  );
}

List<_HtmlTableAlignment?> _parseTableAlignments(String line) {
  return [
    for (final marker in _splitTableCells(line)) _parseTableAlignment(marker),
  ];
}

_HtmlTableAlignment? _parseTableAlignment(String marker) {
  final trimmed = marker.trim();
  final startsWithColon = trimmed.startsWith(':');
  final endsWithColon = trimmed.endsWith(':');

  if (startsWithColon && endsWithColon) return _HtmlTableAlignment.center;
  if (endsWithColon) return _HtmlTableAlignment.right;
  if (startsWithColon) return _HtmlTableAlignment.left;
  return null;
}

_HtmlTableAlignment? _tableAlignmentAt(
  List<_HtmlTableAlignment?> alignments,
  int column,
) {
  return column < alignments.length ? alignments[column] : null;
}

List<String> _splitTableCells(String line) {
  final trimmed = _trimTableBoundaryPipes(line.trim());
  final cells = <String>[];
  final buffer = StringBuffer();

  for (var i = 0; i < trimmed.length; i += 1) {
    final char = trimmed[i];
    if (char == '|' && !_isEscaped(trimmed, i)) {
      cells.add(_unescapeTableCellPipes(buffer.toString().trim()));
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }

  cells.add(_unescapeTableCellPipes(buffer.toString().trim()));
  return cells;
}

bool _hasUnescapedPipe(String line) {
  for (var i = 0; i < line.length; i += 1) {
    if (line[i] == '|' && !_isEscaped(line, i)) return true;
  }
  return false;
}

String _trimTableBoundaryPipes(String line) {
  var start = 0;
  var end = line.length;
  if (line.startsWith('|')) start = 1;
  if (end > start && line[end - 1] == '|' && !_isEscaped(line, end - 1)) {
    end -= 1;
  }
  return line.substring(start, end);
}

bool _isEscaped(String text, int index) {
  var slashCount = 0;
  var cursor = index - 1;
  while (cursor >= 0 && text[cursor] == r'\') {
    slashCount += 1;
    cursor -= 1;
  }
  return slashCount.isOdd;
}

String _unescapeTableCellPipes(String text) {
  return text.replaceAll(r'\|', '|');
}

bool _isDetailsStart(String trimmed) {
  final lower = trimmed.toLowerCase();
  return lower == '<details>' || lower == '<details open>';
}

int _writeDetailsHtml(List<String> lines, int index, StringBuffer buffer) {
  final isOpen = lines[index].trim().toLowerCase() == '<details open>';
  final summary = StringBuffer();
  final contentLines = <String>[];
  var foundSummary = false;
  var inSummary = false;
  index++;

  while (index < lines.length) {
    final line = lines[index];
    final trimmedLower = line.trim().toLowerCase();

    if (!inSummary && trimmedLower == '</details>') {
      index++;
      break;
    }

    if (!inSummary && trimmedLower.startsWith('<summary>')) {
      foundSummary = true;
      final summaryContent = line.trim().substring('<summary>'.length);
      final closeIndex = summaryContent.toLowerCase().indexOf('</summary>');
      if (closeIndex == -1) {
        _appendSummaryLine(summary, summaryContent.trim());
        inSummary = true;
      } else {
        _appendSummaryLine(
          summary,
          summaryContent.substring(0, closeIndex).trim(),
        );
      }
      index++;
      continue;
    }

    if (inSummary) {
      final closeIndex = line.toLowerCase().indexOf('</summary>');
      final summaryLine =
          closeIndex == -1 ? line.trim() : line.substring(0, closeIndex).trim();
      _appendSummaryLine(summary, summaryLine);
      if (closeIndex != -1) inSummary = false;
      index++;
      continue;
    }

    if (foundSummary) {
      contentLines.add(line);
    }
    index++;
  }

  final openAttribute = isOpen ? ' open=""' : '';
  buffer
    ..writeln('<details$openAttribute>')
    ..writeln(
        '<summary>${_inlineMarkdownToHtml(summary.toString())}</summary>');

  final contentHtml = _markdownLinesToHtml(contentLines);
  if (contentHtml.isNotEmpty) {
    buffer.writeln(contentHtml);
  }

  buffer.writeln('</details>');
  return index;
}

void _appendSummaryLine(StringBuffer summary, String line) {
  if (line.isEmpty) return;
  if (summary.isNotEmpty) summary.write(' ');
  summary.write(line);
}

String _inlineMarkdownToHtml(String text) {
  final protectedHtml = <String>[];

  String protect(String value) {
    final token = '{{SMHTML${protectedHtml.length}}}';
    protectedHtml.add(value);
    return token;
  }

  var html = htmlEscape.convert(
    _protectInlineCodeAndEscapes(text, protect),
  );

  html = html.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\(([^)\s]+)(?:\s+&quot;(.+?)&quot;)?\)'),
    (match) {
      return protect(
        _imageHtml(
          src: match.group(2)!,
          alt: match.group(1)!,
          title: match.group(3),
          attributesEscaped: true,
        ),
      );
    },
  );
  html = html.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\(([^)\s]+)(?:\s+&quot;(.+?)&quot;)?\)'),
    (match) {
      return protect(
        _linkHtml(
          href: match.group(2)!,
          label: _inlineMarkdownToHtml(_decodeHtmlEntities(match.group(1)!)),
          title: match.group(3),
          attributesEscaped: true,
        ),
      );
    },
  );
  html = html.replaceAllMapped(
    RegExp(r'\[\[([^\]]+?)\]\]'),
    (match) {
      final target = match.group(1)!;
      return protect(_wikilinkHtml(target, target));
    },
  );
  html = html.replaceAllMapped(
    RegExp(r'\$([^$]+)\$'),
    (match) => protect(_inlineMathHtml(match.group(1)!)),
  );
  html = html.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'),
    (match) => '<strong>${match.group(1)}</strong>',
  );
  html = html.replaceAllMapped(
    RegExp(r'~~(.+?)~~'),
    (match) => '<s>${match.group(1)}</s>',
  );
  html = _replaceUnderscoreDelimiterPairs(
    html,
    '__',
    (content) => '<strong>$content</strong>',
  );
  html = html.replaceAllMapped(
    RegExp(r'\*(.+?)\*'),
    (match) => '<em>${match.group(1)}</em>',
  );
  html = _replaceUnderscoreDelimiterPairs(
    html,
    '_',
    (content) => '<em>$content</em>',
  );

  for (var i = protectedHtml.length - 1; i >= 0; i -= 1) {
    html = html.replaceAll('{{SMHTML$i}}', protectedHtml[i]);
  }

  return html;
}

String _protectInlineCodeAndEscapes(
  String text,
  String Function(String html) protect,
) {
  final buffer = StringBuffer();
  var index = 0;

  while (index < text.length) {
    final char = text[index];

    if (char == r'\' &&
        index + 1 < text.length &&
        _markdownEscapableChars.contains(text[index + 1])) {
      buffer.write(protect(htmlEscape.convert(text[index + 1])));
      index += 2;
      continue;
    }

    if (char == '`') {
      final close = text.indexOf('`', index + 1);
      if (close != -1) {
        final code = text.substring(index + 1, close);
        buffer.write(protect('<code>${htmlEscape.convert(code)}</code>'));
        index = close + 1;
        continue;
      }
    }

    buffer.write(char);
    index += 1;
  }

  return buffer.toString();
}

String _escapeAttribute(String value) {
  return htmlEscape.convert(value).replaceAll('&#47;', '/');
}

String _attributeValue(String value, {required bool alreadyEscaped}) {
  return _escapeAttribute(
    alreadyEscaped ? _decodeHtmlEntities(value) : value,
  );
}

String _wikilinkHtml(String target, String label) {
  return '<span data-wikilink="" data-note-title="${_escapeAttribute(target)}">$label</span>';
}

String _blockMathHtml(String latex) {
  return '<div data-latex="${_escapeAttribute(latex)}" data-type="block-math"></div>';
}

String _inlineMathHtml(String latex) {
  return '<span data-latex="${_escapeAttribute(latex)}" data-type="inline-math"></span>';
}

String _imageHtml({
  required String src,
  required String alt,
  String? title,
  bool attributesEscaped = false,
}) {
  final escapedSrc = _urlAttributeValue(
    src,
    alreadyEscaped: attributesEscaped,
  );
  final escapedAlt = _attributeValue(alt, alreadyEscaped: attributesEscaped);
  final titleAttribute = title == null
      ? ''
      : ' title="${_attributeValue(title, alreadyEscaped: attributesEscaped)}"';
  return '<img src="$escapedSrc" alt="$escapedAlt"$titleAttribute>';
}

String _linkHtml({
  required String href,
  required String label,
  String? title,
  bool attributesEscaped = false,
}) {
  final escapedHref = _urlAttributeValue(
    href,
    alreadyEscaped: attributesEscaped,
  );
  final titleAttribute = title == null
      ? ''
      : ' title="${_attributeValue(title, alreadyEscaped: attributesEscaped)}"';
  return '<a target="_blank" rel="noopener noreferrer nofollow" class="underline cursor-pointer" href="$escapedHref"$titleAttribute>$label</a>';
}

String _urlAttributeValue(String value, {required bool alreadyEscaped}) {
  final url = alreadyEscaped ? _decodeHtmlEntities(value) : value;
  final trimmed = url.trim();
  if (!_isAllowedExportUrl(trimmed)) return '';
  return _escapeAttribute(trimmed);
}

bool _isAllowedExportUrl(String url) {
  final compact = url.replaceAll(RegExp(r'[\u0000-\u0020]+'), '');
  if (compact.isEmpty) return false;

  final schemeMatch = RegExp(
    r'^([a-zA-Z][a-zA-Z0-9+.-]*):',
  ).firstMatch(compact);
  if (schemeMatch == null) return true;

  return switch (schemeMatch.group(1)!.toLowerCase()) {
    'http' || 'https' || 'mailto' || 'tel' => true,
    _ => false,
  };
}

String _decodeHtmlEntities(String value) {
  return value.replaceAllMapped(
    RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);'),
    (match) {
      final entity = match.group(1)!;
      final lowerEntity = entity.toLowerCase();
      switch (lowerEntity) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }

      final isHex = lowerEntity.startsWith('#x');
      final digits =
          isHex ? lowerEntity.substring(2) : lowerEntity.substring(1);
      final codePoint = int.tryParse(digits, radix: isHex ? 16 : 10);
      if (codePoint == null || codePoint <= 0 || codePoint > 0x10FFFF) {
        return match.group(0)!;
      }
      return String.fromCharCode(codePoint);
    },
  );
}

String _replaceUnderscoreDelimiterPairs(
  String text,
  String delimiter,
  String Function(String content) replacement,
) {
  final buffer = StringBuffer();
  var index = 0;

  while (index < text.length) {
    final open = text.indexOf(delimiter, index);
    if (open == -1) {
      buffer.write(text.substring(index));
      break;
    }

    final contentStart = open + delimiter.length;
    if (_isWordCharBefore(text, open)) {
      buffer.write(text.substring(index, contentStart));
      index = contentStart;
      continue;
    }

    final close = _findClosingUnderscoreDelimiter(
      text,
      delimiter,
      contentStart,
    );
    if (close == -1) {
      buffer.write(text.substring(index));
      break;
    }

    buffer
      ..write(text.substring(index, open))
      ..write(replacement(text.substring(contentStart, close)));
    index = close + delimiter.length;
  }

  return buffer.toString();
}

int _findClosingUnderscoreDelimiter(
  String text,
  String delimiter,
  int start,
) {
  var close = text.indexOf(delimiter, start);
  while (close != -1) {
    if (close > start && !_isWordCharAfter(text, close + delimiter.length)) {
      return close;
    }
    close = text.indexOf(delimiter, close + delimiter.length);
  }
  return -1;
}

bool _isWordCharBefore(String text, int index) {
  if (index <= 0) return false;
  return _isWordChar(text.codeUnitAt(index - 1));
}

bool _isWordCharAfter(String text, int index) {
  if (index >= text.length) return false;
  return _isWordChar(text.codeUnitAt(index));
}

bool _isWordChar(int codeUnit) {
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x5F;
}

class _FrontmatterExport {
  const _FrontmatterExport({
    required this.content,
    required this.body,
  });

  final String content;
  final String body;
}

class _ParagraphLineSegment {
  const _ParagraphLineSegment(this.markdown, {required this.hardBreak});

  final String markdown;
  final bool hardBreak;
}

enum _HtmlListKind {
  bullet,
  ordered,
  task,
}

enum _HtmlTableAlignment {
  left,
  center,
  right,
}

class _HtmlListLine {
  const _HtmlListLine({
    required this.indent,
    required this.kind,
    required this.content,
    required this.checked,
    required this.orderNumber,
  });

  final int indent;
  final _HtmlListKind kind;
  final String content;
  final bool checked;
  final int? orderNumber;
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:super_clipboard/super_clipboard.dart' as clip;

import '../parser/html/html_utils.dart';
import 'document/markdown_document.dart';

/// A bitmap read during an explicit editor paste action.
class MarkdownClipboardImage {
  const MarkdownClipboardImage(this.bytes, {required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// Representations offered by a pasteboard or a host-provided clipboard reader.
class MarkdownClipboardContent {
  const MarkdownClipboardContent({this.html, this.plainText, this.image});

  final String? html;
  final String? plainText;
  final MarkdownClipboardImage? image;
}

/// Returns an asset path or URL for a pasted bitmap. Returning null cancels it.
typedef MarkdownPasteImageCallback =
    FutureOr<String?> Function(MarkdownClipboardImage image);

/// Reads supported representations in response to an explicit paste gesture.
Future<MarkdownClipboardContent?> readMarkdownClipboard([
  clip.ClipboardReader? eventReader,
]) async {
  try {
    final reader = eventReader ?? await clip.SystemClipboard.instance?.read();
    if (reader != null) {
      final html = await reader.readValue(clip.Formats.htmlText);
      final plain = await reader.readValue(clip.Formats.plainText);
      // A copied page can expose both markup and a bitmap thumbnail. Keep the
      // document unless the HTML represents only the copied image.
      if (html != null && html.isNotEmpty && !_onlyImage(html)) {
        return MarkdownClipboardContent(html: html, plainText: plain);
      }
      for (final (format, mime) in [
        (clip.Formats.png, 'image/png'),
        (clip.Formats.jpeg, 'image/jpeg'),
        (clip.Formats.gif, 'image/gif'),
        (clip.Formats.webp, 'image/webp'),
      ]) {
        if (!reader.canProvide(format)) continue;
        final result = Completer<Uint8List>();
        final progress = reader.getFile(format, (file) async {
          try {
            result.complete(await file.readAll());
          } catch (error, stack) {
            result.completeError(error, stack);
          }
        }, onError: result.completeError);
        if (progress == null) continue;
        final bytes = await result.future;
        if (bytes.isNotEmpty) {
          return MarkdownClipboardContent(
            image: MarkdownClipboardImage(bytes, mimeType: mime),
            html: html,
            plainText: plain,
          );
        }
      }
      if (html != null || plain != null) {
        return MarkdownClipboardContent(html: html, plainText: plain);
      }
    }
  } on Exception {
    // Native clipboard adapters and browser permissions may be unavailable.
  }
  final text = await Clipboard.getData(Clipboard.kTextPlain);
  return text == null ? null : MarkdownClipboardContent(plainText: text.text);
}

bool _onlyImage(String html) {
  if (!RegExp(r'<img\b', caseSensitive: false).hasMatch(html)) return false;
  final fragment = html_parser.parseFragment(html);
  return fragment.querySelector('img') != null &&
      fragment.text?.trim().isEmpty == true;
}

/// Converts a clipboard payload to Markdown, preserving a plain-text-only paste verbatim.
Future<String?> clipboardContentToMarkdown(
  MarkdownClipboardContent content, {
  MarkdownPasteImageCallback? onPasteImage,
  bool preferPlainText = false,
}) async {
  if (preferPlainText) {
    final plain = content.plainText;
    if (plain != null) return plain;
    final html = content.html;
    if (html != null && html.isNotEmpty) {
      final literal = _literalHtmlText(html);
      if (literal.isNotEmpty || content.image == null) return literal;
    }
  }
  final image = content.image;
  if (image != null) {
    final target = onPasteImage == null
        ? Uri.dataFromBytes(image.bytes, mimeType: image.mimeType).toString()
        : await onPasteImage(image);
    if (target == null || target.isEmpty) return null;
    return '![Image](${_destination(target)})';
  }
  final html = content.html;
  if (html != null && html.isNotEmpty) {
    final markdown = htmlToPastedMarkdown(html);
    if (markdown.isNotEmpty) return markdown;
  }
  return content.plainText;
}

String _destination(String value) => value
    .replaceAll(' ', '%20')
    .replaceAll('(', '%28')
    .replaceAll(')', '%29')
    .replaceAll('\n', '%0A')
    .replaceAll('\r', '%0D');

/// Converts common clipboard HTML into editable Markdown without executing markup.
String htmlToPastedMarkdown(String html) {
  return _children(_clipboardFragment(html)).trim();
}

DocumentFragment _clipboardFragment(String html) {
  final fragment = html_parser.parseFragment(html);
  for (final element in fragment.querySelectorAll(
    'script,style,head,noscript,template,iframe,object',
  )) {
    element.remove();
  }
  return fragment;
}

// Keep whitespace from highlighted code spans, and recover lines from editors
// that copy a div per line or use br instead of newlines.
String _literalHtmlText(String html) {
  final result = StringBuffer();
  var pendingBreak = false;
  var endsInNewline = true;
  void write(String text) {
    if (text.isEmpty) return;
    if (pendingBreak && !endsInNewline && !text.startsWith('\n')) {
      result.write('\n');
    }
    result.write(text);
    pendingBreak = false;
    endsInNewline = text.endsWith('\n');
  }

  void visit(Node node) {
    if (node is Text) {
      write(node.data);
      return;
    }
    if (node is! Element) return;
    if (node.localName == 'br') {
      if (pendingBreak && !endsInNewline) result.write('\n');
      write('\n');
      return;
    }
    final block = const {'div', 'p', 'pre', 'li'}.contains(node.localName);
    if (block) pendingBreak = true;
    for (final child in node.nodes) {
      visit(child);
    }
    if (block) pendingBreak = true;
  }

  for (final child in _clipboardFragment(html).nodes) {
    visit(child);
  }
  return result.toString();
}

String _children(Node node) {
  final result = StringBuffer();
  var pendingBreaks = 0;
  for (final child in node.nodes) {
    final text = _markdown(child);
    if (text.isEmpty) continue;
    if (pendingBreaks > 0 && text.trim().isEmpty && !text.contains('\n')) {
      continue;
    }
    var start = 0;
    while (start < text.length && text.codeUnitAt(start) == 10) {
      start++;
    }
    if (start == text.length) {
      pendingBreaks += start;
      continue;
    }
    var end = text.length;
    while (text.codeUnitAt(end - 1) == 10) {
      end--;
    }
    result
      ..write('\n' * (pendingBreaks > start ? pendingBreaks : start))
      ..write(text.substring(start, end));
    pendingBreaks = text.length - end;
  }
  result.write('\n' * pendingBreaks);
  return result.toString();
}

String _escape(String text) => MarkdownText(
  text,
).toMarkdown().replaceAll(r'$', r'\$').replaceAll('<', r'\<');
String _mark(String text, String delimiter) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return text;
  final start = text.indexOf(trimmed);
  return text.replaceRange(
    start,
    start + trimmed.length,
    '$delimiter$trimmed$delimiter',
  );
}

String _block(String text) => '\n\n${text.trim()}\n\n';
String _fence(String s, int minimum) {
  var length = minimum;
  for (final match in RegExp('`+').allMatches(s)) {
    if (match.end - match.start >= length) length = match.end - match.start + 1;
  }
  return '`' * length;
}

String _markdown(Node node) {
  if (node is Text) {
    return _escape(node.data.replaceAll(RegExp(r'[\t\r\n ]+'), ' '));
  }
  if (node is! Element) return '';
  final tag = node.localName;
  if (tag == 'pre') {
    final fence = _fence(node.text, 3);
    return _block(
      '$fence\n${node.text.replaceFirst(RegExp(r'\n$'), '')}\n$fence',
    );
  }
  if (tag == 'code') {
    final fence = _fence(node.text, 1);
    final pad = node.text.startsWith('`') || node.text.endsWith('`') ? ' ' : '';
    return '$fence$pad${node.text}$pad$fence';
  }
  if (tag == 'ul' || tag == 'ol') {
    var index = int.tryParse(node.attributes['start'] ?? '') ?? 1;
    final items = <String>[];
    for (final child in node.children.where(
      (child) => child.localName == 'li',
    )) {
      final marker = tag == 'ul' ? '- ' : '${index++}. ';
      final item = _children(child).trim().replaceAll(RegExp(r'\n{2,}'), '\n');
      items.add(marker + item.replaceAll('\n', '\n${' ' * marker.length}'));
    }
    return _block(items.join('\n'));
  }
  if (tag == 'table') {
    final rows = node
        .querySelectorAll('tr')
        .map(
          (row) => row.children
              .where((cell) => cell.localName == 'td' || cell.localName == 'th')
              .map(
                (cell) => _children(
                  cell,
                ).trim().replaceAll('|', r'\|').replaceAll(RegExp(r'\n+'), ' '),
              )
              .toList(),
        )
        .where((row) => row.isNotEmpty)
        .toList();
    if (rows.isEmpty) return '';
    final cols = rows.fold(
      0,
      (int max, row) => row.length > max ? row.length : max,
    );
    String line(List<String> cells) =>
        '| ${cells.followedBy(List.filled(cols - cells.length, '')).join(' | ')} |';
    return _block(
      [
        line(rows.first),
        line(List.filled(cols, '---')),
        ...rows.skip(1).map(line),
      ].join('\n'),
    );
  }
  final value = _children(node);
  if (tag != null && RegExp(r'^h[1-6]$').hasMatch(tag)) {
    return _block('${'#' * int.parse(tag[1])} ${value.trim()}');
  }
  switch (tag) {
    case 'span':
      final style = (node.attributes['style'] ?? '').toLowerCase();
      var styled = value;
      if (RegExp(r'font-weight:\s*(bold|[6-9]00)').hasMatch(style)) {
        styled = _mark(styled, '**');
      }
      if (RegExp(r'font-style:\s*italic').hasMatch(style)) {
        styled = _mark(styled, '*');
      }
      if (style.contains('line-through')) styled = _mark(styled, '~~');
      return styled;
    case 'p':
    case 'div':
    case 'section':
    case 'article':
      return _block(value);
    case 'br':
      return '  \n';
    case 'hr':
      return _block('---');
    case 'blockquote':
      return _block(value.trim().split('\n').map((s) => '> $s').join('\n'));
    case 'b':
    case 'strong':
      return _mark(value, '**');
    case 'i':
    case 'em':
      return _mark(value, '*');
    case 's':
    case 'strike':
    case 'del':
      return _mark(value, '~~');
    case 'a':
      final href = node.attributes['href'] ?? '';
      return isSafeHtmlUrl(href) ? '[$value](${_destination(href)})' : value;
    case 'img':
      final src = node.attributes['src'] ?? '';
      final alt = _escape(node.attributes['alt'] ?? '');
      return isSafeHtmlImageSrc(src) || _bitmapDataUrl.hasMatch(src)
          ? '![$alt](${_destination(src)})'
          : alt;
    default:
      return value;
  }
}

final _bitmapDataUrl = RegExp(
  r'^data:image/(png|jpeg|gif|webp);base64,',
  caseSensitive: false,
);

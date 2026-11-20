import '../rust/core_types.dart' show maxNativeSourceUnits;
import 'parser_backend.dart';

/// Pick the backend using the complete document length, including when a
/// static reader renders a stable prefix while the complete AST is loading.
MarkdownParserBackend backendForSourceLength(
  MarkdownParserBackend requested,
  int sourceUnits,
) =>
    requested == MarkdownParserBackend.automatic &&
        sourceUnits > maxNativeSourceUnits
    ? MarkdownParserBackend.legacyDart
    : requested;

// Shared compatibility decision for batch and incremental paths. Keep this
// independent of widgets and native transport so Web follows the same policy.
// ECMAScript RegExp \s, as used by the previous delimiter expression. Keep
// this separate from String.trim (which also accepts U+0085).
bool _delimiterSpace(int unit) =>
    unit == 32 ||
    (unit >= 9 && unit <= 13) ||
    unit == 0xa0 ||
    unit == 0x1680 ||
    (unit >= 0x2000 && unit <= 0x200a) ||
    unit == 0x2028 ||
    unit == 0x2029 ||
    unit == 0x202f ||
    unit == 0x205f ||
    unit == 0x3000 ||
    unit == 0xfeff;

// Equivalent to ^\s*\|?\s*:?-+:?\s*(?:\|\s*:?-+:?\s*)*\|?\s*$.
// Work on a range so ordinary pipe-containing rows allocate no substrings.
int _delimiterCells(String source, int at, int end) {
  while (at < end && _delimiterSpace(source.codeUnitAt(at))) {
    at++;
  }
  if (at < end && source.codeUnitAt(at) == 124) {
    at++;
  }
  var cells = 0;
  while (true) {
    while (at < end && _delimiterSpace(source.codeUnitAt(at))) {
      at++;
    }
    if (at < end && source.codeUnitAt(at) == 58) {
      at++;
    }
    final dashStart = at;
    while (at < end && source.codeUnitAt(at) == 45) {
      at++;
    }
    if (at == dashStart) return -1;
    if (at < end && source.codeUnitAt(at) == 58) {
      at++;
    }
    while (at < end && _delimiterSpace(source.codeUnitAt(at))) {
      at++;
    }
    cells++;
    if (at == end) return cells;
    if (source.codeUnitAt(at++) != 124) return -1;
    while (at < end && _delimiterSpace(source.codeUnitAt(at))) {
      at++;
    }
    if (at == end) return cells;
  }
}

bool hasLegacyDetails(String source) =>
    source.contains('<') && source.toLowerCase().contains('<details');

bool requiresLegacyMarkdown(String source) =>
    hasLegacyDetails(source) || hasLegacyTable(source);

int _headerCells(String line) {
  final text = line.trim();
  if (text.length <= 1) return 1;
  var count = 1;
  var escaped = false;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit == 92) {
      escaped = !escaped;
      continue;
    }
    if (unit == 124 && !escaped && i > 0 && i < text.length - 1) count++;
    escaped = false;
  }
  return count;
}

bool hasLegacyTable(String source) => _hasLegacyTable(source, 0, source.length);

bool _hasLegacyTable(String source, int start, int end) {
  var pipe = source.indexOf('|', start);
  // Only a line following a pipe-containing line can be a legacy delimiter.
  // Avoid splitting/copying every prose and code line in the document.
  while (pipe >= 0 && pipe < end) {
    final headerEnd = source.indexOf('\n', pipe);
    if (headerEnd < 0 || headerEnd >= end) return false;
    final nextEnd = source.indexOf('\n', headerEnd + 1);
    final delimiterCells = _delimiterCells(
      source,
      headerEnd + 1,
      nextEnd < 0 || nextEnd > end ? end : nextEnd,
    );
    if (delimiterCells >= 0) {
      final headerStart = source.lastIndexOf('\n', pipe) + 1;
      if (_headerCells(source.substring(headerStart, headerEnd)) !=
          delimiterCells) {
        return true;
      }
    }
    pipe = source.indexOf('|', headerEnd + 1);
  }
  return false;
}

/// Tracks ragged tables through successive append-only source snapshots.
/// Closed delimiter rows are final. An open one can become valid, ragged or
/// ordinary text again as more characters arrive.
class StreamTableCheck {
  int _lineStart = 0;
  int? _headerWidth;
  bool _closedMismatch = false;
  final _delimiter = _OpenDelimiter();

  bool checkAppend(String source, int start) {
    if (_closedMismatch) return true;
    final firstNewline = source.indexOf('\n', start);
    if (firstNewline < 0) {
      if (_headerWidth != null)
        _delimiter.consume(source, start, source.length);
      return _mismatch;
    }

    // Finish the line that was open at the last publication. Its previous
    // header may precede this append, so its delimiter state spans both calls.
    if (_headerWidth != null) _delimiter.consume(source, start, firstNewline);
    final lastNewline = source.lastIndexOf('\n');
    if (_mismatch ||
        (firstNewline != lastNewline &&
            _hasLegacyTable(source, _lineStart, lastNewline))) {
      _closedMismatch = true;
      return true;
    }

    // Only the final closed line can be the header for the new open line.
    final headerStart = firstNewline == lastNewline
        ? _lineStart
        : source.lastIndexOf('\n', lastNewline - 1) + 1;
    final pipe = source.indexOf('|', headerStart);
    _headerWidth = pipe >= 0 && pipe < lastNewline
        ? _headerCells(source.substring(headerStart, lastNewline))
        : null;
    _lineStart = lastNewline + 1;
    _delimiter.reset();
    if (_headerWidth != null) {
      _delimiter.consume(source, _lineStart, source.length);
    }
    return _mismatch;
  }

  bool get _mismatch =>
      _headerWidth != null &&
      _delimiter.cells >= 0 &&
      _delimiter.cells != _headerWidth;
}

enum _DelimiterPart {
  start,
  afterPipe,
  openingColon,
  dashes,
  afterCell,
  invalid,
}

/// Incremental counterpart of _delimiterCells, including optional outer pipes.
/// Only a line following a possible header needs these transitions.
class _OpenDelimiter {
  var _part = _DelimiterPart.start;
  int _count = 0;

  void reset() {
    _part = _DelimiterPart.start;
    _count = 0;
  }

  int get cells => switch (_part) {
    _DelimiterPart.dashes ||
    _DelimiterPart.afterCell ||
    _DelimiterPart.afterPipe when _count > 0 => _count,
    _ => -1,
  };

  void consume(String source, int start, int end) {
    if (_part == _DelimiterPart.invalid) return;
    var i = start;
    for (; i < end; i++) {
      final unit = source.codeUnitAt(i);
      if (unit == 45) {
        if (_part == _DelimiterPart.dashes) continue;
        if (_part == _DelimiterPart.afterCell) break;
        _part = _DelimiterPart.dashes;
        _count++;
      } else if (unit == 58) {
        if (_part == _DelimiterPart.dashes) {
          _part = _DelimiterPart.afterCell;
        } else if (_part == _DelimiterPart.start ||
            _part == _DelimiterPart.afterPipe) {
          _part = _DelimiterPart.openingColon;
        } else {
          break;
        }
      } else if (unit == 124) {
        if (_part == _DelimiterPart.afterPipe ||
            _part == _DelimiterPart.openingColon) {
          break;
        }
        _part = _DelimiterPart.afterPipe;
      } else if (_delimiterSpace(unit) &&
          _part != _DelimiterPart.openingColon) {
        if (_part == _DelimiterPart.dashes) _part = _DelimiterPart.afterCell;
      } else {
        break;
      }
    }
    if (i < end) _part = _DelimiterPart.invalid;
  }
}

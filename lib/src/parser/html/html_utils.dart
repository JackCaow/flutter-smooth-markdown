/// Utilities for lexing and sanitizing whitelisted HTML tags.
///
/// These helpers are pure Dart (no Flutter imports) so the parser layer
/// stays platform independent and isolate friendly.
library;

/// Maximum number of characters a single HTML tag may span.
///
/// Lexing gives up beyond this bound to avoid quadratic scans on
/// pathological input such as a `<a href="...` with no closing bracket.
const int maxHtmlTagLength = 512;

/// HTML void tags that never have a matching closing tag.
const Set<String> htmlVoidTags = {'br', 'hr', 'img'};

/// URL schemes allowed for HTML `href`/`src` attributes.
const Set<String> _allowedUrlSchemes = {'http', 'https', 'mailto', 'tel'};

/// Bounds for accepted CSS font sizes in logical pixels.
const double _minFontSize = 4;
const double _maxFontSize = 128;

/// Pixel sizes for the legacy `<font size="1..7">` scale.
const List<double> _legacyFontSizes = [10, 13, 16, 18, 24, 32, 48];

/// Named CSS colors accepted by [parseHtmlColor] (ARGB values).
const Map<String, int> _namedColors = {
  'aqua': 0xFF00FFFF,
  'black': 0xFF000000,
  'blue': 0xFF0000FF,
  'brown': 0xFFA52A2A,
  'cyan': 0xFF00FFFF,
  'fuchsia': 0xFFFF00FF,
  'gold': 0xFFFFD700,
  'gray': 0xFF808080,
  'green': 0xFF008000,
  'grey': 0xFF808080,
  'indigo': 0xFF4B0082,
  'lime': 0xFF00FF00,
  'magenta': 0xFFFF00FF,
  'maroon': 0xFF800000,
  'navy': 0xFF000080,
  'olive': 0xFF808000,
  'orange': 0xFFFFA500,
  'pink': 0xFFFFC0CB,
  'purple': 0xFF800080,
  'red': 0xFFFF0000,
  'silver': 0xFFC0C0C0,
  'teal': 0xFF008080,
  'violet': 0xFFEE82EE,
  'white': 0xFFFFFFFF,
  'yellow': 0xFFFFFF00,
};

/// A single lexed HTML tag such as `<img src="a.png">` or `</div>`.
class HtmlTag {
  /// Creates a new lexed HTML tag.
  const HtmlTag({
    required this.name,
    required this.attributes,
    required this.isClosing,
    required this.isSelfClosing,
    required this.end,
  });

  /// The lowercased tag name (for example `div` or `br`).
  final String name;

  /// Attributes with lowercased names; first occurrence wins.
  ///
  /// Valueless boolean attributes map to an empty string.
  final Map<String, String> attributes;

  /// Whether this is a closing tag (`</name>`).
  final bool isClosing;

  /// Whether this tag is explicitly self-closed (`<name ... />`).
  final bool isSelfClosing;

  /// Index into the source text just past the closing `>`.
  final int end;
}

/// Lexes a single HTML tag starting at `text[start]` (which must be `<`).
///
/// Returns `null` when the text at [start] is not a syntactically valid
/// tag — for example `<3`, `< b>`, an unterminated quote, or a tag
/// longer than [maxHtmlTagLength]. Callers treat `null` as literal text.
HtmlTag? lexHtmlTag(String text, int start) {
  final limit = text.length < start + maxHtmlTagLength
      ? text.length
      : start + maxHtmlTagLength;
  var i = start;
  if (i >= limit || text[i] != '<') return null;
  i++;

  var isClosing = false;
  if (i < limit && text[i] == '/') {
    isClosing = true;
    i++;
  }

  // Tag name: [a-zA-Z][a-zA-Z0-9-]*
  if (i >= limit || !_isAsciiLetter(text.codeUnitAt(i))) return null;
  final nameStart = i;
  i++;
  while (i < limit && _isNameChar(text.codeUnitAt(i))) {
    i++;
  }
  final name = text.substring(nameStart, i).toLowerCase();

  final attributes = <String, String>{};
  while (true) {
    i = _skipWhitespace(text, i, limit);
    if (i >= limit) return null;

    final char = text[i];
    if (char == '>' || char == '/') {
      final isSelfClosing = char == '/';
      if (isSelfClosing && (i + 1 >= limit || text[i + 1] != '>')) {
        return null;
      }
      return HtmlTag(
        name: name,
        attributes: attributes,
        isClosing: isClosing,
        isSelfClosing: isSelfClosing,
        end: i + (isSelfClosing ? 2 : 1),
      );
    }

    // Attribute name: [a-zA-Z][a-zA-Z0-9-]*
    if (!_isAsciiLetter(text.codeUnitAt(i))) return null;
    final attrNameStart = i;
    i++;
    while (i < limit && _isNameChar(text.codeUnitAt(i))) {
      i++;
    }
    final attrName = text.substring(attrNameStart, i).toLowerCase();

    i = _skipWhitespace(text, i, limit);
    var value = '';
    if (i < limit && text[i] == '=') {
      i++;
      i = _skipWhitespace(text, i, limit);
      if (i >= limit) return null;
      final quote = text[i];
      if (quote == '"' || quote == "'") {
        i++;
        final valueStart = i;
        while (i < limit && text[i] != quote) {
          i++;
        }
        if (i >= limit) return null; // Unterminated quote
        value = text.substring(valueStart, i);
        i++;
      } else {
        final valueStart = i;
        while (
            i < limit && !_isWhitespace(text.codeUnitAt(i)) && text[i] != '>') {
          i++;
        }
        value = text.substring(valueStart, i);
      }
    }
    attributes.putIfAbsent(attrName, () => value);
  }
}

/// Parses an HTML/CSS color value into an ARGB integer.
///
/// Accepts `#RGB`, `#RRGGBB`, and a set of common named colors.
/// Eight-digit hex is rejected because CSS (`#RRGGBBAA`) and Flutter
/// (`AARRGGBB`) disagree on channel order. Returns `null` when the
/// value is not recognized.
int? parseHtmlColor(String value) {
  final v = value.trim().toLowerCase();
  if (v.isEmpty) return null;

  if (v.startsWith('#')) {
    final hex = v.substring(1);
    if (hex.length == 3) {
      final expanded = hex.split('').map((c) => '$c$c').join();
      final parsed = int.tryParse(expanded, radix: 16);
      return parsed == null ? null : 0xFF000000 | parsed;
    }
    if (hex.length == 6) {
      final parsed = int.tryParse(hex, radix: 16);
      return parsed == null ? null : 0xFF000000 | parsed;
    }
    return null;
  }
  return _namedColors[v];
}

/// Parses a CSS `font-size` value into logical pixels.
///
/// Accepts `px`, `pt` (converted at 4/3), and bare numbers. Relative
/// units (`em`, `%`) and keywords are rejected, as are sizes outside
/// a safe display range. Returns `null` when not accepted.
double? parseHtmlFontSize(String value) {
  final v = value.trim().toLowerCase();
  if (v.isEmpty) return null;

  double? size;
  if (v.endsWith('px')) {
    size = double.tryParse(v.substring(0, v.length - 2).trim());
  } else if (v.endsWith('pt')) {
    final points = double.tryParse(v.substring(0, v.length - 2).trim());
    size = points == null ? null : points * 4 / 3;
  } else {
    size = double.tryParse(v);
  }

  if (size == null || size < _minFontSize || size > _maxFontSize) {
    return null;
  }
  return size;
}

/// Parses the legacy `<font size="1..7">` attribute into pixels.
///
/// Relative values such as `+2` and out-of-range numbers return `null`.
double? parseFontSizeAttr(String value) {
  final v = value.trim();
  if (v.isEmpty || v.startsWith('+') || v.startsWith('-')) return null;
  final scale = int.tryParse(v);
  if (scale == null || scale < 1 || scale > _legacyFontSizes.length) {
    return null;
  }
  return _legacyFontSizes[scale - 1];
}

/// Whether a URL from an HTML `href`/`src` attribute is safe to keep.
///
/// Scheme-less (relative, anchor, and protocol-relative) URLs are
/// allowed; absolute URLs must use http, https, mailto, or tel.
/// ASCII control characters and spaces are stripped before scheme
/// detection so obfuscations such as `java\tscript:` are caught.
bool isSafeHtmlUrl(String url) {
  final buffer = StringBuffer();
  for (final code in url.codeUnits) {
    if (code > 0x20) buffer.writeCharCode(code);
  }
  final cleaned = buffer.toString();
  if (cleaned.isEmpty) return false;

  for (var i = 0; i < cleaned.length; i++) {
    final char = cleaned[i];
    if (char == '/' || char == '?' || char == '#') {
      return true; // Path/query/fragment before any scheme.
    }
    if (char == ':') {
      final scheme = cleaned.substring(0, i).toLowerCase();
      return _allowedUrlSchemes.contains(scheme);
    }
  }
  return true; // No scheme at all.
}

/// Location of a matching HTML closing tag found by [findHtmlCloseTag].
class HtmlCloseTagLocation {
  /// Creates a new closing tag location.
  const HtmlCloseTagLocation({required this.start, required this.end});

  /// Index of the `<` of the closing tag.
  final int start;

  /// Index just past the `>` of the closing tag.
  final int end;
}

/// Finds the closing tag matching an already-consumed open [name] tag.
///
/// [from] is the index right after the open tag. A same-name nesting
/// counter ensures nested tags of the same name close at matching
/// depth. Returns `null` when no matching close tag exists in [text].
HtmlCloseTagLocation? findHtmlCloseTag(String text, int from, String name) {
  var nesting = 1;
  var i = from;
  while (i < text.length) {
    // 0x3C == '<'; codeUnitAt avoids a per-character string allocation
    // in this forward scan, which runs over the whole tag content.
    if (text.codeUnitAt(i) != 0x3C) {
      i++;
      continue;
    }
    final tag = lexHtmlTag(text, i);
    if (tag == null) {
      i++;
      continue;
    }
    if (tag.name == name) {
      if (tag.isClosing) {
        nesting--;
        if (nesting == 0) {
          return HtmlCloseTagLocation(start: i, end: tag.end);
        }
      } else if (!tag.isSelfClosing) {
        nesting++;
      }
    }
    i = tag.end;
  }
  return null;
}

/// Splits an inline CSS `style` attribute into property declarations.
///
/// Property names are lowercased and trimmed; values are trimmed with
/// their original casing preserved. Malformed declarations are skipped
/// and the first occurrence of a property wins.
Map<String, String> parseInlineCssDeclarations(String style) {
  final declarations = <String, String>{};
  for (final part in style.split(';')) {
    final colon = part.indexOf(':');
    if (colon <= 0) continue;
    final name = part.substring(0, colon).trim().toLowerCase();
    final value = part.substring(colon + 1).trim();
    if (name.isEmpty || value.isEmpty) continue;
    declarations.putIfAbsent(name, () => value);
  }
  return declarations;
}

/// Parses an HTML `width`/`height` attribute into logical pixels.
///
/// Accepts positive numbers with an optional `px` suffix, capped at a
/// sane upper bound. Percentages and other units return `null`.
double? parseHtmlDimension(String value) {
  var v = value.trim().toLowerCase();
  if (v.endsWith('px')) {
    v = v.substring(0, v.length - 2).trim();
  }
  final size = double.tryParse(v);
  if (size == null || size <= 0 || size > _maxDimension) return null;
  return size;
}

/// Upper bound for accepted image dimensions in logical pixels.
const double _maxDimension = 10000;

int _skipWhitespace(String text, int index, int limit) {
  var i = index;
  while (i < limit && _isWhitespace(text.codeUnitAt(i))) {
    i++;
  }
  return i;
}

bool _isWhitespace(int code) =>
    code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D;

bool _isAsciiLetter(int code) =>
    (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);

bool _isNameChar(int code) =>
    _isAsciiLetter(code) || (code >= 0x30 && code <= 0x39) || code == 0x2D;

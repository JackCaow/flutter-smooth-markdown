//! Data formats: JSON(C), YAML, TOML and INI-style files.

use super::{is_digit, is_space, Kind, Out, Src};

fn quoted(src: &Src, out: &mut Out, i: usize, end: usize, quote: u16, kind: Kind, escapes: bool) -> usize {
    let mut seg = i;
    let mut j = i + 1;
    while j < end {
        let c = src.at(j);
        if c == quote { j += 1; break }
        if c == '\n' as u16 { break }
        if escapes && c == '\\' as u16 {
            out.push(seg, j, kind);
            let e = if src.is(j + 1, 'u') { (j + 6).min(end) } else { (j + 2).min(end) };
            out.push(j, e, Kind::StringEscape);
            j = e;
            seg = j;
            continue;
        }
        j += 1;
    }
    out.push(seg, j.min(end), kind);
    j.min(end)
}

/// End of a bare scalar: stops at whitespace and flow punctuation.
fn bare_end(src: &Src, mut i: usize, end: usize) -> usize {
    while i < end && !is_space(src.at(i)) && !matches!(src.at(i) as u8, b',' | b']' | b'}' | b'[' | b'{') { i += 1 }
    i
}

fn scalar_kind(text: &str) -> Kind {
    match text {
        "true" | "false" | "True" | "False" | "TRUE" | "FALSE" | "yes" | "no" | "on" | "off" => Kind::Boolean,
        "null" | "Null" | "NULL" | "~" | "nil" => Kind::ConstantBuiltin,
        _ if looks_numeric(text) => Kind::Number,
        _ => Kind::String,
    }
}

fn looks_numeric(text: &str) -> bool {
    let t = text.strip_prefix(['-', '+']).unwrap_or(text);
    !t.is_empty() && (t.starts_with("0x") || t.starts_with("0o") || t == ".inf" || t == ".nan" || t == "inf" || t == "nan"
        || (t.as_bytes()[0].is_ascii_digit() && t.bytes().all(|b| b.is_ascii_digit() || matches!(b, b'.' | b'_' | b'e' | b'E' | b'-' | b'+' | b':' | b'T' | b'Z'))))
}

pub(crate) fn json(src: &Src, out: &mut Out, start: usize, end: usize) {
    let mut i = start;
    while i < end {
        let c = src.at(i);
        if is_space(c) { i += 1; continue }
        if src.starts(i, "//") { let j = src.line_end(i, end); out.push(i, j, Kind::Comment); i = j; continue }
        if src.starts(i, "/*") { let j = src.find(i + 2, end, "*/").map(|p| p + 2).unwrap_or(end); out.push(i, j, Kind::Comment); i = j; continue }
        match c as u8 {
            b'"' | b'\'' if c < 128 => {
                // A string followed by `:` is an object key.
                let probe = {
                    let mut tmp = Out::default();
                    quoted(src, &mut tmp, i, end, c, Kind::String, true)
                };
                let after = src.skip_space(probe, end);
                let kind = if src.is(after, ':') { Kind::PropertyKey } else { Kind::String };
                i = quoted(src, out, i, end, c, kind, true);
            }
            b'{' | b'}' | b'[' | b']' if c < 128 => { out.push(i, i + 1, Kind::PunctuationBracket); i += 1 }
            b',' | b':' if c < 128 => { out.push(i, i + 1, Kind::PunctuationDelimiter); i += 1 }
            _ if is_digit(c) || c == '-' as u16 => { let j = src.number_end(i + 1, end).max(i + 1); out.push(i, j, Kind::Number); i = j }
            _ => {
                let j = src.ident_end(i, end, &[]).max(i + 1);
                let word = src.ascii(i, j);
                let kind = match word.as_str() {
                    "true" | "false" => Kind::Boolean,
                    "null" => Kind::ConstantBuiltin,
                    "Infinity" | "NaN" => Kind::Number,
                    _ if src.is(src.skip_space(j, end), ':') => Kind::PropertyKey,
                    _ => Kind::None,
                };
                out.push(i, j, kind);
                i = j;
            }
        }
    }
}

pub(crate) fn yaml(src: &Src, out: &mut Out, start: usize, end: usize) {
    let mut line = start;
    // Indentation that ends a block scalar (`|` / `>`), when inside one.
    let mut block: Option<usize> = None;
    while line < end {
        let stop = src.line_end(line, end);
        let indent = src.skip_blank(line, stop) - line;
        if let Some(parent) = block {
            if src.skip_blank(line, stop) == stop || indent > parent {
                out.push(line + indent, stop, Kind::String);
                line = stop + 1;
                continue;
            }
            block = None;
        }
        let mut i = line + indent;
        if src.starts(i, "---") || src.starts(i, "...") { out.push(i, i + 3, Kind::PunctuationSpecial); line = stop + 1; continue }
        if src.is(i, '%') { out.push(i, stop, Kind::Preproc); line = stop + 1; continue }
        while src.is(i, '-') && (src.is(i + 1, ' ') || i + 1 == stop) {
            out.push(i, i + 1, Kind::PunctuationListMarker);
            i = src.skip_blank(i + 1, stop);
        }
        // `key:` at the start of the content.
        if let Some(colon) = yaml_key_end(src, i, stop) {
            let kind = Kind::PropertyKey;
            if src.is(i, '"') || src.is(i, '\'') { quoted(src, out, i, colon, src.at(i), kind, src.is(i, '"')); } else { out.push(i, colon, kind) }
            out.push(colon, colon + 1, Kind::PunctuationDelimiter);
            i = colon + 1;
        }
        yaml_value(src, out, i, stop, indent, &mut block);
        line = stop + 1;
    }
}

fn yaml_key_end(src: &Src, i: usize, stop: usize) -> Option<usize> {
    if src.is(i, '#') || src.is(i, '{') || src.is(i, '[') { return None }
    let mut j = i;
    if src.is(j, '"') || src.is(j, '\'') {
        let q = src.at(j);
        j += 1;
        while j < stop && src.at(j) != q { j += 1 }
        j += 1;
        return if src.is(j, ':') { Some(j) } else { None };
    }
    while j < stop {
        if src.is(j, ':') && (j + 1 == stop || matches!(src.at(j + 1), 0x20 | 0x09)) { return Some(j) }
        if src.is(j, '#') && j > i && matches!(src.at(j - 1), 0x20 | 0x09) { return None }
        j += 1;
    }
    None
}

fn yaml_value(src: &Src, out: &mut Out, mut i: usize, stop: usize, indent: usize, block: &mut Option<usize>) {
    while i < stop {
        let c = src.at(i);
        if matches!(c, 0x20 | 0x09) { i += 1; continue }
        match c as u8 {
            b'#' if c < 128 && (i == 0 || matches!(src.at(i - 1), 0x20 | 0x09 | 0x0A)) => { out.push(i, stop, Kind::Comment); return }
            b'"' if c < 128 => i = quoted(src, out, i, stop, c, Kind::String, true),
            b'\'' if c < 128 => i = quoted(src, out, i, stop, c, Kind::String, false),
            b'&' | b'*' if c < 128 => { let j = bare_end(src, i + 1, stop); out.push(i, j, Kind::Label); i = j }
            b'!' if c < 128 => { let j = bare_end(src, i + 1, stop); out.push(i, j, Kind::Type); i = j }
            b'|' | b'>' if c < 128 && src.skip_blank(src.ident_end(i + 1, stop, b"+-"), stop) == stop || (c < 128 && matches!(c as u8, b'|' | b'>') && src.is(src.skip_blank(i + 1, stop), '#')) => {
                out.push(i, src.ident_end(i + 1, stop, b"+-"), Kind::Operator);
                *block = Some(indent);
                i = src.ident_end(i + 1, stop, b"+-");
            }
            b'{' | b'}' | b'[' | b']' if c < 128 => { out.push(i, i + 1, Kind::PunctuationBracket); i += 1 }
            b',' if c < 128 => { out.push(i, i + 1, Kind::PunctuationDelimiter); i += 1 }
            _ => {
                // Flow mapping keys (`{ a: 1 }`) or a scalar running to the line end / flow delimiter.
                let j = bare_end(src, i, stop);
                if src.is(j, ':') || (src.is(j.saturating_sub(1), ':') && j > i + 1) {
                    let k = if src.is(j, ':') { j } else { j - 1 };
                    out.push(i, k, Kind::PropertyKey);
                    out.push(k, k + 1, Kind::PunctuationDelimiter);
                    i = k + 1;
                    continue;
                }
                let mut e = j;
                // Plain multi-word scalars continue to a comment or the line end.
                while e < stop && !src.is(e, '#') && !matches!(src.at(e) as u8, b',' | b']' | b'}') { e += 1 }
                while e > j && matches!(src.at(e - 1), 0x20 | 0x09) { e -= 1 }
                let text = src.ascii(i, e);
                out.push(i, e, scalar_kind(text.trim()));
                i = e;
            }
        }
    }
}

pub(crate) fn toml(src: &Src, out: &mut Out, start: usize, end: usize) {
    let mut i = start;
    let mut line_start = true;
    while i < end {
        let c = src.at(i);
        if c == '\n' as u16 { line_start = true; i += 1; continue }
        if is_space(c) { i += 1; continue }
        if c == '#' as u16 { let j = src.line_end(i, end); out.push(i, j, Kind::Comment); i = j; continue }
        if line_start && c == '[' as u16 {
            let double = src.is(i + 1, '[');
            let close = src.find(i, src.line_end(i, end), if double { "]]" } else { "]" }).map(|p| p + if double { 2 } else { 1 }).unwrap_or(src.line_end(i, end));
            let w = if double { 2 } else { 1 };
            out.push(i, i + w, Kind::PunctuationBracket);
            out.push(i + w, close - w, Kind::Namespace);
            out.push(close - w, close, Kind::PunctuationBracket);
            i = close;
            line_start = false;
            continue;
        }
        if line_start {
            // Dotted / quoted keys up to `=`.
            let eq = (i..src.line_end(i, end)).find(|&k| src.is(k, '='));
            if let Some(eq) = eq {
                let mut k = i;
                while k < eq {
                    if src.is(k, '"') || src.is(k, '\'') { k = quoted(src, out, k, eq, src.at(k), Kind::PropertyKey, src.is(k, '"')); continue }
                    if src.is(k, '.') { out.push(k, k + 1, Kind::PunctuationDelimiter); k += 1; continue }
                    if is_space(src.at(k)) { k += 1; continue }
                    let e = src.ident_end(k, eq, b"-").max(k + 1);
                    out.push(k, e, Kind::PropertyKey);
                    k = e;
                }
                out.push(eq, eq + 1, Kind::Operator);
                i = eq + 1;
                line_start = false;
                continue;
            }
        }
        line_start = false;
        i = toml_value(src, out, i, end);
    }
}

fn toml_value(src: &Src, out: &mut Out, i: usize, end: usize) -> usize {
    let c = src.at(i);
    if src.starts(i, "\"\"\"") || src.starts(i, "'''") {
        let q = if src.is(i, '"') { "\"\"\"" } else { "'''" };
        let j = src.find(i + 3, end, q).map(|p| p + 3).unwrap_or(end);
        out.push(i, j, Kind::String);
        return j;
    }
    match c as u8 {
        b'"' if c < 128 => quoted(src, out, i, end, c, Kind::String, true),
        b'\'' if c < 128 => quoted(src, out, i, end, c, Kind::String, false),
        b'[' | b']' | b'{' | b'}' if c < 128 => { out.push(i, i + 1, Kind::PunctuationBracket); i + 1 }
        b',' if c < 128 => { out.push(i, i + 1, Kind::PunctuationDelimiter); i + 1 }
        b'=' if c < 128 => { out.push(i, i + 1, Kind::Operator); i + 1 }
        _ => {
            let j = bare_end(src, i, end).max(i + 1);
            let text = src.ascii(i, j);
            if src.is(src.skip_blank(j, end), '=') {
                out.push(i, j, Kind::PropertyKey);
            } else {
                out.push(i, j, match scalar_kind(&text) { Kind::String => Kind::None, k => k });
            }
            j
        }
    }
}

pub(crate) fn ini(src: &Src, out: &mut Out, start: usize, end: usize) {
    let mut line = start;
    while line < end {
        let stop = src.line_end(line, end);
        let i = src.skip_blank(line, stop);
        if src.is(i, '#') || src.is(i, ';') || src.is(i, '!') {
            out.push(i, stop, Kind::Comment);
        } else if src.is(i, '[') {
            let close = src.find(i, stop, "]").map(|p| p + 1).unwrap_or(stop);
            out.push(i, i + 1, Kind::PunctuationBracket);
            out.push(i + 1, close - 1, Kind::Namespace);
            out.push(close - 1, close, Kind::PunctuationBracket);
        } else {
            let mut k = i;
            if src.starts(k, "export ") { out.push(k, k + 6, Kind::Keyword); k = src.skip_blank(k + 6, stop) }
            let sep = (k..stop).find(|&p| src.is(p, '=') || src.is(p, ':'));
            if let Some(sep) = sep {
                let mut key_end = sep;
                while key_end > k && matches!(src.at(key_end - 1), 0x20 | 0x09) { key_end -= 1 }
                out.push(k, key_end, Kind::PropertyKey);
                out.push(sep, sep + 1, Kind::Operator);
                let v = src.skip_blank(sep + 1, stop);
                if src.is(v, '"') || src.is(v, '\'') {
                    quoted(src, out, v, stop, src.at(v), Kind::String, src.is(v, '"'));
                } else {
                    // Trailing inline comments (` # note`) are common in .env files.
                    let comment = (v..stop).find(|&p| src.is(p, '#') && p > v && matches!(src.at(p - 1), 0x20 | 0x09));
                    let value_end = comment.unwrap_or(stop);
                    let text = src.ascii(v, value_end);
                    out.push(v, value_end, match scalar_kind(text.trim()) { Kind::String => Kind::String, k => k });
                    if let Some(c) = comment { out.push(c, stop, Kind::Comment) }
                }
            } else if k < stop {
                out.push(k, stop, Kind::None);
            }
        }
        line = stop + 1;
    }
}

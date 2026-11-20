//! Markdown source: block structure, inline marks and fenced code highlighted
//! in its own language.

use super::{highlight_range, Kind, Lang, Out, Src};

pub(crate) fn highlight(src: &Src, out: &mut Out, start: usize, end: usize, depth: usize) {
    let mut line = start;
    // YAML front matter.
    if src.starts(start, "---") && src.line_end(start, end) == start + 3 {
        let body = start + 4;
        let mut k = body;
        while k < end {
            let stop = src.line_end(k, end);
            if src.ascii(k, stop).trim_end() == "---" {
                out.push(start, start + 3, Kind::PunctuationSpecial);
                highlight_range(src, out, Lang::Yaml, body, k, depth + 1);
                out.push(k, stop, Kind::PunctuationSpecial);
                line = stop + 1;
                break;
            }
            k = stop + 1;
        }
    }
    while line < end {
        let stop = src.line_end(line, end);
        let i = src.skip_blank(line, stop);
        // Fenced code.
        if src.starts(i, "```") || src.starts(i, "~~~") {
            let marker = src.at(i);
            let mut n = i;
            while src.at(n) == marker { n += 1 }
            let fence = n - i;
            out.push(i, n, Kind::PunctuationSpecial);
            let info_end = src.skip_blank(n, stop);
            let lang_end = { let mut e = info_end; while e < stop && !matches!(src.at(e), 0x20 | 0x09 | 0x7B) { e += 1 } e };
            out.push(info_end, lang_end, Kind::Label);
            let language = src.ascii(info_end, lang_end);
            let body = (stop + 1).min(end);
            let mut close = body;
            let mut close_end = end;
            let mut found = false;
            while close < end {
                let s = src.line_end(close, end);
                let c = src.skip_blank(close, s);
                let mut m = c;
                while m < s && src.at(m) == marker { m += 1 }
                if m - c >= fence && src.skip_blank(m, s) == s { close_end = s; found = true; break }
                close = s + 1;
            }
            let body_end = if found { close } else { end };
            match Lang::resolve(&language) {
                Some(lang) if !language.is_empty() => highlight_range(src, out, lang, body, body_end, depth + 1),
                _ => out.push(body, body_end, Kind::TextLiteral),
            }
            if found {
                let c = src.skip_blank(close, close_end);
                out.push(c, close_end, Kind::PunctuationSpecial);
                line = close_end + 1;
            } else {
                line = end;
            }
            continue;
        }
        // Indented code (four spaces) after a blank line is common in docs; treat as literal.
        if i - line >= 4 && i < stop && previous_blank(src, line, start) {
            out.push(i, stop, Kind::TextLiteral);
            line = stop + 1;
            continue;
        }
        let mut k = i;
        // ATX headings.
        if src.is(k, '#') {
            let mut h = k;
            while src.is(h, '#') { h += 1 }
            if h - k <= 6 && (h == stop || src.is(h, ' ')) {
                out.push(k, h, Kind::PunctuationSpecial);
                out.push(h, stop, Kind::Title);
                line = stop + 1;
                continue;
            }
        }
        // Setext underline / thematic break.
        let trimmed = src.ascii(i, stop);
        let t = trimmed.trim_end();
        if t.len() >= 3 && (t.bytes().all(|b| b == b'=' ) || t.bytes().all(|b| b == b'-' || b == b' ') || t.bytes().all(|b| b == b'*' || b == b' ')) {
            out.push(i, stop, Kind::PunctuationSpecial);
            line = stop + 1;
            continue;
        }
        // Block quotes and list markers.
        while src.is(k, '>') { out.push(k, k + 1, Kind::PunctuationSpecial); k = src.skip_blank(k + 1, stop) }
        if (src.is(k, '-') || src.is(k, '*') || src.is(k, '+')) && src.is(k + 1, ' ') {
            out.push(k, k + 1, Kind::PunctuationListMarker);
            k += 2;
            if src.starts(k, "[ ]") || src.starts(k, "[x]") || src.starts(k, "[X]") { out.push(k, k + 3, Kind::PunctuationListMarker); k += 3 }
        } else {
            let mut d = k;
            while super::is_digit(src.at(d)) { d += 1 }
            if d > k && (src.is(d, '.') || src.is(d, ')')) && src.is(d + 1, ' ') { out.push(k, d + 1, Kind::PunctuationListMarker); k = d + 2 }
        }
        // Tables: pipes as delimiters.
        inline(src, out, k, stop, depth);
        line = stop + 1;
    }
}

fn previous_blank(src: &Src, line: usize, start: usize) -> bool {
    if line <= start { return true }
    let prev_end = line - 1;
    let prev_start = src.line_start(prev_end, start);
    src.skip_blank(prev_start, prev_end) == prev_end
}

fn inline(src: &Src, out: &mut Out, start: usize, end: usize, depth: usize) {
    let mut i = start;
    while i < end {
        let c = src.at(i);
        match c as u8 {
            b'\\' if c < 128 && i + 1 < end => { out.push(i, i + 2, Kind::StringEscape); i += 2 }
            b'`' if c < 128 => {
                let mut n = i;
                while src.is(n, '`') { n += 1 }
                let ticks: String = "`".repeat(n - i);
                let close = src.find(n, end, &ticks).map(|p| p + ticks.len()).unwrap_or(n);
                out.push(i, close, Kind::TextLiteral);
                i = close;
            }
            b'*' | b'_' if c < 128 => {
                let strong = src.at(i + 1) == c;
                let delim = if strong { 2 } else { 1 };
                let marker: String = std::iter::repeat(c as u8 as char).take(delim).collect();
                let intraword_underscore = c == '_' as u16 && i > start && super::is_ident_part(src.at(i - 1));
                match src.find(i + delim, end, &marker) {
                    Some(close) if close > i + delim && !intraword_underscore && !super::is_space(src.at(i + delim)) => {
                        out.push(i, close + delim, if strong { Kind::EmphasisStrong } else { Kind::Emphasis });
                        i = close + delim;
                    }
                    _ => i += delim,
                }
            }
            b'~' if c < 128 && src.is(i + 1, '~') => {
                let close = src.find(i + 2, end, "~~").map(|p| p + 2).unwrap_or(i + 2);
                out.push(i, close, Kind::Comment);
                i = close;
            }
            b'!' | b'[' if c < 128 => {
                let open = if c == '!' as u16 { i + 1 } else { i };
                if !src.is(open, '[') { i += 1; continue }
                match src.find(open + 1, end, "]") {
                    Some(close) if src.is(close + 1, '(') || src.is(close + 1, '[') => {
                        let paren = src.at(close + 1);
                        let closer = if paren == '(' as u16 { ")" } else { "]" };
                        let target_end = src.find(close + 2, end, closer).unwrap_or(end);
                        out.push(i, open + 1, Kind::PunctuationBracket);
                        out.push(open + 1, close, Kind::LinkText);
                        out.push(close, close + 2, Kind::PunctuationBracket);
                        out.push(close + 2, target_end, Kind::LinkUri);
                        out.push(target_end, (target_end + 1).min(end), Kind::PunctuationBracket);
                        i = (target_end + 1).min(end);
                    }
                    Some(close) if src.is(close + 1, ':') => {
                        // Reference definition `[id]: url`.
                        out.push(open, close + 2, Kind::LinkText);
                        let u = src.skip_blank(close + 2, end);
                        let ue = { let mut e = u; while e < end && !super::is_space(src.at(e)) { e += 1 } e };
                        out.push(u, ue, Kind::LinkUri);
                        i = ue;
                    }
                    _ => i += 1,
                }
            }
            b'<' if c < 128 => {
                // Autolinks and inline HTML.
                match src.find(i, end, ">") {
                    Some(close) if src.ascii(i + 1, close).contains("://") || src.ascii(i + 1, close).contains('@') => {
                        out.push(i, close + 1, Kind::LinkUri);
                        i = close + 1;
                    }
                    Some(close) if super::is_ident_start(src.at(i + 1)) || src.is(i + 1, '/') => {
                        highlight_range(src, out, Lang::Html(super::HtmlFlavor::Html), i, close + 1, depth + 1);
                        i = close + 1;
                    }
                    _ => i += 1,
                }
            }
            b'|' if c < 128 => { out.push(i, i + 1, Kind::PunctuationDelimiter); i += 1 }
            b'h' if c < 128 && (src.starts(i, "https://") || src.starts(i, "http://")) => {
                let mut e = i;
                while e < end && !super::is_space(src.at(e)) && !matches!(src.at(e) as u8, b')' | b'>') { e += 1 }
                out.push(i, e, Kind::LinkUri);
                i = e;
            }
            _ => i += 1,
        }
    }
}

//! Markup (HTML, XML, Vue, Svelte) and stylesheets (CSS, SCSS, Less).

use super::{highlight_range, is_digit, is_ident_part, is_ident_start, is_space, specs, CssFlavor, HtmlFlavor, Kind, Lang, Out, Src};

fn script_lang(src: &Src, attrs_start: usize, attrs_end: usize) -> Lang {
    let attrs = src.ascii(attrs_start, attrs_end).to_ascii_lowercase();
    if attrs.contains("lang=\"ts\"") || attrs.contains("lang='ts'") || attrs.contains("typescript") {
        Lang::Code(&specs::TYPESCRIPT)
    } else if attrs.contains("lang=\"tsx\"") {
        Lang::Code(&specs::TSX)
    } else if attrs.contains("application/json") || attrs.contains("importmap") {
        Lang::Json
    } else {
        Lang::Code(&specs::JAVASCRIPT)
    }
}

fn style_lang(src: &Src, attrs_start: usize, attrs_end: usize) -> Lang {
    let attrs = src.ascii(attrs_start, attrs_end).to_ascii_lowercase();
    if attrs.contains("scss") || attrs.contains("sass") { Lang::Css(CssFlavor::Scss) }
    else if attrs.contains("less") { Lang::Css(CssFlavor::Less) }
    else { Lang::Css(CssFlavor::Css) }
}

const EXPRESSION: Lang = Lang::Code(&specs::JAVASCRIPT);

pub(crate) fn html(src: &Src, out: &mut Out, flavor: HtmlFlavor, start: usize, end: usize, depth: usize) {
    let mut i = start;
    let mut text = start;
    while i < end {
        let c = src.at(i);
        // Template interpolation: Vue `{{ }}`, Svelte `{ }`.
        if (flavor == HtmlFlavor::Vue && src.starts(i, "{{")) || (flavor == HtmlFlavor::Svelte && c == '{' as u16) {
            out.push(text, i, Kind::None);
            let (open, close) = if flavor == HtmlFlavor::Vue { ("{{", "}}") } else { ("{", "}") };
            let stop = src.find(i + open.len(), end, close).unwrap_or(end);
            out.push(i, i + open.len(), Kind::PunctuationSpecial);
            let inner = i + open.len();
            // Svelte blocks: `{#if}`, `{:else}`, `{/each}`, `{@html}`.
            let mut k = inner;
            if flavor == HtmlFlavor::Svelte && matches!(src.at(k) as u8, b'#' | b':' | b'/' | b'@') {
                let w = src.ident_end(k + 1, stop, &[]);
                out.push(k, w, Kind::KeywordControl);
                k = w;
            }
            highlight_range(src, out, EXPRESSION, k, stop, depth + 1);
            out.push(stop, (stop + close.len()).min(end), Kind::PunctuationSpecial);
            i = (stop + close.len()).min(end);
            text = i;
            continue;
        }
        if c == '&' as u16 {
            let j = src.ident_end(i + 1, end, b"#");
            if src.is(j, ';') && j > i + 1 {
                out.push(text, i, Kind::None);
                out.push(i, j + 1, Kind::ConstantBuiltin);
                i = j + 1;
                text = i;
                continue;
            }
        }
        if c != '<' as u16 { i += 1; continue }
        out.push(text, i, Kind::None);
        if src.starts(i, "<!--") {
            let j = src.find(i + 4, end, "-->").map(|p| p + 3).unwrap_or(end);
            out.push(i, j, Kind::Comment);
            i = j;
        } else if src.starts(i, "<![CDATA[") {
            let j = src.find(i, end, "]]>").map(|p| p + 3).unwrap_or(end);
            out.push(i, i + 9, Kind::PunctuationBracket);
            out.push(i + 9, j.saturating_sub(3).max(i + 9), Kind::String);
            out.push(j.saturating_sub(3).max(i + 9), j, Kind::PunctuationBracket);
            i = j;
        } else if src.starts_ci(i, "<!doctype") || src.starts(i, "<?") {
            let close = if src.starts(i, "<?") { "?>" } else { ">" };
            let j = src.find(i, end, close).map(|p| p + close.len()).unwrap_or(end);
            out.push(i, j, if close == "?>" { Kind::Preproc } else { Kind::TagDoctype });
            i = j;
        } else if src.is(i + 1, '/') || is_ident_start(src.at(i + 1)) {
            i = tag(src, out, flavor, i, end, depth);
        } else {
            i += 1;
        }
        text = i;
    }
    out.push(text, end, Kind::None);
}

/// One opening or closing tag, plus the raw content of `<script>` / `<style>`.
fn tag(src: &Src, out: &mut Out, flavor: HtmlFlavor, i: usize, end: usize, depth: usize) -> usize {
    let closing = src.is(i + 1, '/');
    let name_start = i + if closing { 2 } else { 1 };
    out.push(i, name_start, Kind::PunctuationBracket);
    let name_end = src.ident_end(name_start, end, b"-:.");
    let name = src.ascii(name_start, name_end).to_ascii_lowercase();
    let component = flavor != HtmlFlavor::Xml && (super::is_upper(src.at(name_start)) || name.contains('.'));
    out.push(name_start, name_end, if component { Kind::TagComponent } else { Kind::Tag });
    let attrs_start = name_end;
    let mut j = name_end;
    loop {
        j = src.skip_space(j, end);
        if j >= end { return end }
        if src.starts(j, "/>") { out.push(j, j + 2, Kind::PunctuationBracket); return j + 2 }
        if src.is(j, '>') { out.push(j, j + 1, Kind::PunctuationBracket); j += 1; break }
        let a_end = {
            let mut k = j;
            while k < end && !is_space(src.at(k)) && !matches!(src.at(k) as u8, b'=' | b'>' | b'/') { k += 1 }
            k.max(j + 1)
        };
        let attr = src.ascii(j, a_end);
        out.push(j, a_end, Kind::Attribute);
        let mut k = src.skip_space(a_end, end);
        if src.is(k, '=') {
            out.push(k, k + 1, Kind::Operator);
            k = src.skip_space(k + 1, end);
            let q = src.at(k);
            let dynamic = flavor == HtmlFlavor::Vue && (attr.starts_with(':') || attr.starts_with('@') || attr.starts_with("v-") || attr.starts_with('#'));
            if q == '"' as u16 || q == '\'' as u16 {
                let close = (k + 1..end).find(|&p| src.at(p) == q).unwrap_or(end);
                if dynamic {
                    out.push(k, k + 1, Kind::String);
                    highlight_range(src, out, EXPRESSION, k + 1, close, depth + 1);
                    out.push(close, (close + 1).min(end), Kind::String);
                } else {
                    out.push(k, (close + 1).min(end), Kind::String);
                }
                k = (close + 1).min(end);
            } else if q == '{' as u16 && flavor != HtmlFlavor::Xml {
                let close = src.find(k, end, "}").unwrap_or(end);
                out.push(k, k + 1, Kind::PunctuationSpecial);
                highlight_range(src, out, EXPRESSION, k + 1, close, depth + 1);
                out.push(close, (close + 1).min(end), Kind::PunctuationSpecial);
                k = (close + 1).min(end);
            } else {
                let mut e = k;
                while e < end && !is_space(src.at(e)) && !src.is(e, '>') { e += 1 }
                out.push(k, e, Kind::String);
                k = e;
            }
        }
        j = k;
    }
    if closing || flavor == HtmlFlavor::Xml { return j }
    // Raw-text elements embed another language.
    let embedded = match name.as_str() {
        "script" => Some(script_lang(src, attrs_start, j)),
        "style" => Some(style_lang(src, attrs_start, j)),
        _ => None,
    };
    if let Some(lang) = embedded {
        let close_tag = format!("</{name}");
        let mut stop = j;
        while stop < end && !src.starts_ci(stop, &close_tag) { stop += 1 }
        highlight_range(src, out, lang, j, stop, depth + 1);
        return stop;
    }
    j
}

pub(crate) fn css(src: &Src, out: &mut Out, flavor: CssFlavor, start: usize, end: usize) {
    let mut i = start;
    // Inside a declaration block (`{ … }`) at the current nesting level?
    let mut blocks: Vec<bool> = Vec::new();
    let mut in_value = false;
    while i < end {
        let c = src.at(i);
        if is_space(c) { i += 1; continue }
        if src.starts(i, "/*") { let j = src.find(i + 2, end, "*/").map(|p| p + 2).unwrap_or(end); out.push(i, j, Kind::Comment); i = j; continue }
        if flavor != CssFlavor::Css && src.starts(i, "//") { let j = src.line_end(i, end); out.push(i, j, Kind::Comment); i = j; continue }
        if c == '"' as u16 || c == '\'' as u16 {
            let close = (i + 1..end).find(|&p| src.at(p) == c && !src.is(p - 1, '\\')).map(|p| p + 1).unwrap_or(end);
            out.push(i, close, Kind::String);
            i = close;
            continue;
        }
        match c as u8 {
            b'{' if c < 128 => { out.push(i, i + 1, Kind::PunctuationBracket); blocks.push(true); in_value = false; i += 1; continue }
            b'}' if c < 128 => { out.push(i, i + 1, Kind::PunctuationBracket); blocks.pop(); in_value = false; i += 1; continue }
            b';' if c < 128 => { out.push(i, i + 1, Kind::PunctuationDelimiter); in_value = false; i += 1; continue }
            b'@' if c < 128 => {
                let j = src.ident_end(i + 1, end, b"-");
                // Less variables (`@primary: …`) versus at-rules (`@media`).
                let variable = flavor == CssFlavor::Less && src.is(src.skip_blank(j, end), ':');
                out.push(i, j, if variable { Kind::VariableSpecial } else { Kind::Keyword });
                i = j;
                continue;
            }
            b'$' if c < 128 && flavor == CssFlavor::Scss => { let j = src.ident_end(i + 1, end, b"-"); out.push(i, j, Kind::VariableSpecial); i = j; continue }
            b'!' if c < 128 => { let j = src.ident_end(i + 1, end, &[]); out.push(i, j, Kind::Keyword); i = j; continue }
            _ => {}
        }
        let in_block = blocks.last().copied().unwrap_or(false);
        if in_block && !in_value && (is_ident_start(c) || c == '-' as u16) {
            // A declaration `prop: value;` unless this is a nested selector (`a:hover { … }`).
            let j = src.ident_end(i, end, b"-");
            let after = src.skip_blank(j, end);
            if src.is(after, ':') && !nested_selector(src, after, end) {
                out.push(i, j, if src.starts(i, "--") { Kind::VariableSpecial } else { Kind::Property });
                out.push(after, after + 1, Kind::PunctuationDelimiter);
                in_value = true;
                i = after + 1;
                continue;
            }
        }
        if in_value {
            i = css_value(src, out, i, end);
        } else {
            i = selector(src, out, i, end);
        }
    }
}

fn nested_selector(src: &Src, colon: usize, end: usize) -> bool {
    let mut k = colon + 1;
    while k < end {
        match src.at(k) as u8 {
            b';' | b'}' => return false,
            b'{' => return true,
            _ => k += 1,
        }
    }
    false
}

fn css_value(src: &Src, out: &mut Out, i: usize, end: usize) -> usize {
    let c = src.at(i);
    if c == '#' as u16 {
        let j = src.ident_end(i + 1, end, &[]);
        out.push(i, j, Kind::Constant);
        return j;
    }
    if is_digit(c) || (c == '.' as u16 && is_digit(src.at(i + 1))) || ((c == '-' as u16 || c == '+' as u16) && is_digit(src.at(i + 1))) {
        let mut j = i + 1;
        while j < end && (is_digit(src.at(j)) || src.is(j, '.')) { j += 1 }
        let unit = src.ident_end(j, end, b"%");
        out.push(i, j, Kind::Number);
        out.push(j, unit, Kind::Keyword);
        return unit.max(j);
    }
    if is_ident_start(c) || c == '-' as u16 {
        let j = src.ident_end(i, end, b"-").max(i + 1);
        let kind = if src.is(j, '(') { Kind::Function }
            else if src.starts(i, "--") { Kind::VariableSpecial }
            else { Kind::ConstantBuiltin };
        out.push(i, j, kind);
        // `url(...)` holds an unquoted string.
        if src.ascii(i, j) == "url" && src.is(j, '(') && !src.is(j + 1, '"') && !src.is(j + 1, '\'') {
            let close = src.find(j, end, ")").unwrap_or(end);
            out.push(j, j + 1, Kind::PunctuationBracket);
            out.push(j + 1, close, Kind::String);
            return close;
        }
        return j;
    }
    let kind = match c as u8 {
        b'(' | b')' | b'[' | b']' => Kind::PunctuationBracket,
        b',' => Kind::PunctuationDelimiter,
        b'+' | b'-' | b'*' | b'/' | b'=' | b'>' | b'<' => Kind::Operator,
        _ => Kind::None,
    };
    out.push(i, i + 1, kind);
    i + 1
}

fn selector(src: &Src, out: &mut Out, i: usize, end: usize) -> usize {
    let c = src.at(i);
    match c as u8 {
        b'.' if is_ident_start(src.at(i + 1)) || src.is(i + 1, '-') => { let j = src.ident_end(i + 1, end, b"-"); out.push(i, j, Kind::SelectorClass); j }
        b'#' if c < 128 => { let j = src.ident_end(i + 1, end, b"-"); out.push(i, j, Kind::SelectorId); j }
        b':' if c < 128 => {
            let s = if src.is(i + 1, ':') { i + 2 } else { i + 1 };
            let j = src.ident_end(s, end, b"-");
            out.push(i, j, Kind::SelectorPseudo);
            j
        }
        b'&' if c < 128 => { out.push(i, i + 1, Kind::Operator); i + 1 }
        b'[' if c < 128 => {
            let close = src.find(i, end, "]").map(|p| p + 1).unwrap_or(end);
            out.push(i, i + 1, Kind::PunctuationBracket);
            let eq = (i..close).find(|&p| src.is(p, '=')).unwrap_or(close - 1);
            out.push(i + 1, eq.min(close - 1), Kind::Attribute);
            out.push(eq.min(close - 1), close - 1, Kind::String);
            out.push(close - 1, close, Kind::PunctuationBracket);
            close
        }
        b'>' | b'+' | b'~' | b'*' | b',' if c < 128 => { out.push(i, i + 1, if c == ',' as u16 { Kind::PunctuationDelimiter } else { Kind::Operator }); i + 1 }
        b'(' | b')' if c < 128 => { out.push(i, i + 1, Kind::PunctuationBracket); i + 1 }
        _ if is_ident_part(c) || c == '-' as u16 || c == '%' as u16 => {
            let j = src.ident_end(i, end, b"-%").max(i + 1);
            let kind = if is_digit(c) { Kind::Number } else { Kind::Tag };
            out.push(i, j, kind);
            j
        }
        _ => i + 1,
    }
}

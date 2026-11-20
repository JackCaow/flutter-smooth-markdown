//! Source-preserving block scanner. Positions in the public tree are UTF-16 offsets.
use crate::ast::{utf16_len, Kind, Node, Options, Reference, References};
use crate::inline;

#[derive(Clone, Debug)]
struct Line {
    text: String,
    raw: String,
    start: u32,
    end: u32,
    projected: bool,
    lazy: bool,
    virtual_indent: u32,
}
impl Line {
    fn blank(&self) -> bool {
        self.text.bytes().all(horizontal)
    }
}
// A completed ordinary escaped bracket on the opener line is prose. An
// explicit math close, a standalone opener, and an unfinished payload remain
// math, so streaming can keep its existing mutable tail contract.
fn backslash_math_open(text: &str) -> bool {
    let body = text.trim_start();
    if !body.starts_with(r"\[") { return false; }
    let payload = &body[2..];
    if inline::math_closing(payload, r"\]").is_some() { return true; }
    let mut depth = 0usize;
    let mut escaped = false;
    for ch in payload.chars() {
        if escaped { escaped = false; continue; }
        match ch {
            '\\' => escaped = true,
            '[' => depth += 1,
            ']' if depth == 0 => return false,
            ']' => depth -= 1,
            _ => {}
        }
    }
    true
}
fn horizontal(c: u8) -> bool {
    c == b' ' || c == b'\t'
}
fn indent(s: &str) -> usize {
    let mut column = 0;
    for c in s.bytes() {
        match c {
            b' ' => column += 1,
            b'\t' => column += 4 - column % 4,
            _ => break,
        }
    }
    column
}
fn display_column(s: &str) -> usize {
    s.chars().fold(0, |column, c| {
        column + if c == '\t' { 4 - column % 4 } else { 1 }
    })
}
fn lines(source: &str) -> Vec<Line> {
    let mut result = Vec::new();
    let mut byte_start = 0;
    let mut offset = 0;
    while byte_start < source.len() {
        let body_end = source[byte_start..]
            .bytes()
            .position(|c| matches!(c, b'\r' | b'\n'))
            .map(|n| byte_start + n)
            .unwrap_or(source.len());
        let end = if source.as_bytes().get(body_end) == Some(&b'\r')
            && source.as_bytes().get(body_end + 1) == Some(&b'\n')
        {
            body_end + 2
        } else if body_end < source.len() {
            body_end + 1
        } else {
            body_end
        };
        let raw = &source[byte_start..end];
        let start = offset;
        offset += utf16_len(raw);
        result.push(Line {
            text: source[byte_start..body_end].to_owned(),
            raw: raw.to_owned(),
            start,
            end: offset,
            projected: false,
            lazy: false,
            virtual_indent: 0,
        });
        byte_start = end;
    }
    result
}

#[derive(Clone, Debug)]
struct Fence {
    marker: u8,
    count: usize,
    info: String,
    indentation: usize,
}
fn fence_open(s: &str) -> Option<Fence> {
    let body = s.trim_start_matches(' ');
    let indentation = s.len() - body.len();
    let marker = *body.as_bytes().first()?;
    if indentation > 3 || (marker != b'`' && marker != b'~') {
        return None;
    }
    let count = body.bytes().take_while(|c| *c == marker).count();
    let info = body[count..].trim_matches([' ', '\t']);
    if count < 3 || (marker == b'`' && info.contains('`')) {
        return None;
    }
    Some(Fence {
        marker,
        count,
        info: inline::decode_text(info),
        indentation,
    })
}
fn fence_close(s: &str, fence: &Fence) -> bool {
    let body = s.trim_start_matches(' ');
    if s.len() - body.len() > 3 {
        return false;
    }
    let count = body.bytes().take_while(|c| *c == fence.marker).count();
    count >= fence.count && body[count..].bytes().all(horizontal)
}
fn heading(s: &str) -> Option<(u32, usize, &str)> {
    let body = s.trim_start_matches(' ');
    let leading = s.len() - body.len();
    if leading > 3 {
        return None;
    }
    let count = body.bytes().take_while(|c| *c == b'#').count();
    if !(1..=6).contains(&count) || body.as_bytes().get(count).is_some_and(|c| !horizontal(*c)) {
        return None;
    }
    let rest = &body[count..];
    let trimmed = rest.trim_start_matches([' ', '\t']);
    let offset = leading + count + rest.len() - trimmed.len();
    let mut content = trimmed.trim_end_matches([' ', '\t']);
    let hashes = content.bytes().rev().take_while(|c| *c == b'#').count();
    if hashes == content.len() {
        content = ""
    } else if hashes > 0
        && content
            .as_bytes()
            .get(content.len() - hashes - 1)
            .is_some_and(|c| horizontal(*c))
    {
        content = content[..content.len() - hashes].trim_end_matches([' ', '\t']);
    }
    Some((count as u32, offset, content))
}
fn thematic(s: &str) -> bool {
    let body = s.trim_start_matches(' ');
    if s.len() - body.len() > 3 {
        return false;
    }
    let marker = match body.as_bytes().first() {
        Some(c @ (b'*' | b'-' | b'_')) => *c,
        _ => return false,
    };
    body.bytes().all(|c| c == marker || horizontal(c))
        && body.bytes().filter(|c| *c == marker).count() >= 3
}
fn setext(s: &str) -> Option<u32> {
    let body = s.trim_start_matches(' ');
    if s.len() - body.len() > 3 {
        return None;
    }
    let body = body.trim_end_matches([' ', '\t']);
    if !body.is_empty() && body.bytes().all(|c| c == b'=') {
        Some(1)
    } else if !body.is_empty() && body.bytes().all(|c| c == b'-') {
        Some(2)
    } else {
        None
    }
}
fn quote_prefix(s: &str) -> Option<usize> {
    let body = s.trim_start_matches(' ');
    let leading = s.len() - body.len();
    (leading <= 3 && body.starts_with('>')).then_some(leading + 1)
}
fn footnote(s: &str) -> Option<&str> {
    let body = s.trim_start_matches(' ');
    if s.len() - body.len() > 3 || !body.starts_with("[^") {
        return None;
    }
    let end = body.find("]: ").or_else(|| body.find("]:"))?;
    let content = &body[end + 2..];
    (end > 2 && !body[2..end].trim().is_empty()
        && content.starts_with([' ', '\t']) && !content.trim().is_empty())
        .then_some(&body[2..end])
}
#[derive(Clone, Debug)]
struct Marker {
    indentation: usize,
    prefix: usize,
    ordered: bool,
    number: u32,
    style: u8,
    overflow: usize,
}
fn list_marker(s: &str, maximum: usize) -> Option<Marker> {
    let body = s.trim_start_matches([' ', '\t']);
    let leading = s.len() - body.len();
    let indentation = indent(&s[..leading]);
    if indentation > maximum {
        return None;
    }
    let bytes = body.as_bytes();
    let first = *bytes.first()?;
    let (ordered, number, size, style) = if matches!(first, b'-' | b'+' | b'*') {
        (false, 1, 1, first)
    } else {
        let digits = bytes.iter().take_while(|c| c.is_ascii_digit()).count();
        if !(1..=9).contains(&digits) || !matches!(bytes.get(digits), Some(b'.' | b')')) {
            return None;
        }
        (
            true,
            body[..digits].parse().ok()?,
            digits + 1,
            bytes[digits],
        )
    };
    if bytes.get(size).is_some_and(|c| !horizontal(*c)) {
        return None;
    }
    let spaces = bytes[size..].iter().take_while(|c| horizontal(**c)).count();
    let column = display_column(&s[..leading]) + size;
    let width = bytes[size..size + spaces].iter().fold(column, |column, c| {
        column + if *c == b'\t' { 4 - column % 4 } else { 1 }
    }) - column;
    let overflow = width > 4;
    let consumed = if overflow || size + spaces == body.len() {
        spaces.min(1)
    } else {
        spaces
    };
    Some(Marker {
        indentation,
        prefix: leading + size + consumed,
        ordered,
        number,
        style,
        overflow: if overflow { width - 1 } else { 0 },
    })
}
#[derive(Clone)]
enum HtmlEnd {
    Blank,
    Marker(String, bool),
}
impl HtmlEnd {
    fn matches(&self, s: &str) -> bool {
        match self {
            Self::Blank => s.bytes().all(horizontal),
            Self::Marker(marker, insensitive) => {
                if *insensitive {
                    s.to_ascii_lowercase().contains(marker)
                } else {
                    s.contains(marker)
                }
            }
        }
    }
}
fn html_end(s: &str, interrupt: bool) -> Option<HtmlEnd> {
    let body = s.trim_start_matches(' ');
    if s.len() - body.len() > 3 || !body.starts_with('<') {
        return None;
    }
    let lower = body.to_ascii_lowercase();
    for tag in ["script", "pre", "style", "textarea"] {
        let prefix = format!("<{tag}");
        if lower.starts_with(&prefix)
            && lower
                .as_bytes()
                .get(prefix.len())
                .is_none_or(|c| horizontal(*c) || *c == b'>')
        {
            return Some(HtmlEnd::Marker(format!("</{tag}>"), true));
        }
    }
    if body.starts_with("<!--") {
        return Some(HtmlEnd::Marker("-->".into(), false));
    }
    if body.starts_with("<?") {
        return Some(HtmlEnd::Marker("?>".into(), false));
    }
    if body.starts_with("<![CDATA[") {
        return Some(HtmlEnd::Marker("]]>".into(), false));
    }
    if body
        .as_bytes()
        .get(2)
        .is_some_and(|c| c.is_ascii_uppercase())
        && body.starts_with("<!")
    {
        return Some(HtmlEnd::Marker(">".into(), false));
    }
    let after = lower.trim_start_matches('<').trim_start_matches('/');
    let size = after
        .bytes()
        .take_while(|c| c.is_ascii_alphanumeric())
        .count();
    let tag = &after[..size];
    const BLOCKS: &[&str] = &[
        "address",
        "article",
        "aside",
        "base",
        "basefont",
        "blockquote",
        "body",
        "caption",
        "center",
        "col",
        "colgroup",
        "dd",
        "details",
        "dialog",
        "dir",
        "div",
        "dl",
        "dt",
        "fieldset",
        "figcaption",
        "figure",
        "footer",
        "form",
        "frame",
        "frameset",
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "head",
        "header",
        "hr",
        "html",
        "iframe",
        "legend",
        "li",
        "link",
        "main",
        "menu",
        "menuitem",
        "nav",
        "noframes",
        "ol",
        "optgroup",
        "option",
        "p",
        "param",
        "search",
        "section",
        "summary",
        "table",
        "tbody",
        "td",
        "tfoot",
        "th",
        "thead",
        "title",
        "tr",
        "track",
        "ul",
    ];
    if BLOCKS.contains(&tag)
        && after
            .as_bytes()
            .get(size)
            .is_none_or(|c| horizontal(*c) || matches!(*c, b'/' | b'>'))
    {
        return Some(HtmlEnd::Blank);
    }
    if !interrupt && valid_complete_tag(body) {
        return Some(HtmlEnd::Blank);
    }
    None
}
fn valid_complete_tag(s: &str) -> bool {
    let bytes = s.as_bytes();
    let mut i = 1;
    let closing = bytes.get(i) == Some(&b'/');
    if closing {
        i += 1
    }
    if !bytes.get(i).is_some_and(u8::is_ascii_alphabetic) {
        return false;
    }
    while bytes
        .get(i)
        .is_some_and(|c| c.is_ascii_alphanumeric() || *c == b'-')
    {
        i += 1
    }
    if closing {
        while bytes.get(i).is_some_and(|c| horizontal(*c)) {
            i += 1
        }
        return bytes.get(i) == Some(&b'>') && bytes[i + 1..].iter().all(|c| horizontal(*c));
    }
    loop {
        let before = i;
        while bytes.get(i).is_some_and(|c| horizontal(*c)) {
            i += 1
        }
        if bytes.get(i) == Some(&b'/') {
            i += 1;
        }
        if bytes.get(i) == Some(&b'>') {
            return bytes[i + 1..].iter().all(|c| horizontal(*c));
        }
        if before == i
            || !bytes
                .get(i)
                .is_some_and(|c| c.is_ascii_alphabetic() || matches!(*c, b'_' | b':'))
        {
            return false;
        }
        i += 1;
        while bytes
            .get(i)
            .is_some_and(|c| c.is_ascii_alphanumeric() || matches!(*c, b'_' | b':' | b'.' | b'-'))
        {
            i += 1
        }
        while bytes.get(i).is_some_and(|c| horizontal(*c)) {
            i += 1
        }
        if bytes.get(i) != Some(&b'=') {
            continue;
        }
        i += 1;
        while bytes.get(i).is_some_and(|c| horizontal(*c)) {
            i += 1
        }
        if matches!(bytes.get(i), Some(b'\'' | b'"')) {
            let quote = bytes[i];
            i += 1;
            while bytes.get(i).is_some_and(|c| *c != quote) {
                i += 1
            }
            if bytes.get(i) != Some(&quote) {
                return false;
            };
            i += 1;
        } else {
            let start = i;
            while bytes.get(i).is_some_and(|c| {
                !horizontal(*c) && !matches!(*c, b'>' | b'\'' | b'"' | b'=' | b'<' | b'`')
            }) {
                i += 1
            }
            if start == i {
                return false;
            }
        }
    }
}
fn table_spans(s: &str) -> Vec<(usize, usize)> {
    let mut spans = Vec::new();
    let mut start = 0;
    let mut slashes = 0;
    for (i, c) in s.bytes().enumerate() {
        if c == b'|' && slashes % 2 == 0 {
            spans.push((start, i));
            start = i + 1
        }
        slashes = if c == b'\\' { slashes + 1 } else { 0 };
    }
    spans.push((start, s.len()));
    for span in &mut spans {
        while span.0 < span.1 && horizontal(s.as_bytes()[span.0]) {
            span.0 += 1
        }
        while span.0 < span.1 && horizontal(s.as_bytes()[span.1 - 1]) {
            span.1 -= 1
        }
    }
    if spans.len() > 1 && spans.first().is_some_and(|s| s.0 == s.1) {
        spans.remove(0);
    }
    if spans.len() > 1 && spans.last().is_some_and(|s| s.0 == s.1) {
        spans.pop();
    }
    spans
}
fn table_alignments(lines: &[Line], index: usize) -> Option<Vec<Option<String>>> {
    if index + 1 >= lines.len() || !lines[index].text.contains('|') {
        return None;
    }
    let cells = table_spans(&lines[index + 1].text);
    if cells.is_empty() || cells.len() != table_spans(&lines[index].text).len() {
        return None;
    }
    let mut alignments = Vec::new();
    for (start, end) in cells {
        let cell = &lines[index + 1].text[start..end];
        let middle = cell.strip_prefix(':').unwrap_or(cell);
        let middle = middle.strip_suffix(':').unwrap_or(middle);
        if middle.is_empty() || !middle.bytes().all(|c| c == b'-') {
            return None;
        }
        alignments.push(if cell.starts_with(':') && cell.ends_with(':') {
            Some("center".into())
        } else if cell.starts_with(':') {
            Some("left".into())
        } else if cell.ends_with(':') {
            Some("right".into())
        } else {
            None
        });
    }
    Some(alignments)
}
fn interrupt(lines: &[Line], index: usize) -> bool {
    let text = &lines[index].text;
    heading(text).is_some()
        || fence_open(text).is_some()
        || thematic(text)
        || quote_prefix(text).is_some()
        || html_end(text, true).is_some()
        || list_marker(text, 3)
            .is_some_and(|m| text.len() > m.prefix && (!m.ordered || m.number == 1))
}
fn project(line: &Line, width: usize) -> Line {
    let mut removed = 0;
    let mut bytes: usize = 0;
    for c in line.text.bytes() {
        if removed >= width || !horizontal(c) {
            break;
        }
        removed += if c == b'\t' { 4 - removed % 4 } else { 1 };
        bytes += 1;
    }
    let leading = line.text.bytes().take_while(|c| horizontal(*c)).count();
    let residual = indent(&line.text).saturating_sub(width);
    let body = format!("{}{}", " ".repeat(residual), &line.text[leading..]);
    let physical_removed = bytes.saturating_sub(line.virtual_indent as usize);
    let physical_remaining =
        leading.saturating_sub(line.virtual_indent as usize + physical_removed);
    let start = line.start + physical_removed as u32;
    Line {
        raw: format!(
            "{}{}",
            body,
            if line.raw.ends_with(['\r', '\n']) {
                "\n"
            } else {
                ""
            }
        ),
        text: body,
        start,
        end: line.end,
        projected: true,
        lazy: false,
        virtual_indent: residual.saturating_sub(physical_remaining) as u32,
    }
}
fn project_quote(line: &Line) -> Line {
    let Some(prefix) = quote_prefix(&line.text) else {
        let mut value = line.clone();
        value.projected = true;
        value.lazy = true;
        return value;
    };
    let mut body = &line.text[prefix..];
    let mut offset = prefix;
    let mut column = prefix;
    let mut virtual_indent = line.virtual_indent;
    let mut expanded = String::new();
    if let Some(c) = body.as_bytes().first().copied().filter(|c| horizontal(*c)) {
        body = &body[1..];
        offset += 1;
        let width = if c == b'\t' { 4 - column % 4 } else { 1 };
        column += width;
        expanded.push_str(&" ".repeat(width - 1));
        virtual_indent += (width - 1) as u32;
    }
    let mut initial = true;
    for c in body.chars() {
        if c == '\t' && initial {
            let width = 4 - column % 4;
            expanded.push_str(&" ".repeat(width));
            virtual_indent += (width - 1) as u32;
            column += width
        } else {
            expanded.push(c);
            if c == ' ' {
                column += 1
            } else {
                initial = false
            }
        }
    }
    Line {
        raw: format!(
            "{}{}",
            expanded,
            if line.raw.ends_with(['\r', '\n']) {
                "\n"
            } else {
                ""
            }
        ),
        text: expanded,
        start: line.start + offset as u32,
        end: line.end,
        projected: true,
        lazy: false,
        virtual_indent,
    }
}
fn quote_paragraph(body: &str) -> bool {
    let mut body = body;
    while let Some(prefix) = quote_prefix(body) {
        body = &body[prefix..];
    }
    if let Some(marker) = list_marker(body, 3) {
        body = &body[marker.prefix..];
        while let Some(prefix) = quote_prefix(body) {
            body = &body[prefix..];
        }
    }
    if body.trim().is_empty() || indent(body) >= 4 {
        return false;
    }
    !interrupt(
        &[Line {
            text: body.into(),
            raw: body.into(),
            start: 0,
            end: utf16_len(body),
            projected: false,
            lazy: false,
            virtual_indent: 0,
        }],
        0,
    )
}

struct Scanner<'a> {
    utf16: Vec<u16>,
    options: Options,
    hooks: Option<&'a dyn crate::hooks::Hooks>,
    hooks_before_fences: bool,
    block_contexts: std::cell::RefCell<Vec<(usize,usize,Vec<Vec<u16>>)>>,
}
impl Scanner<'_> {
    fn custom_block(&self, lines: &[Line], index: usize) -> Option<crate::hooks::Match> {
        if indent(&lines[index].text) >= 4 { return None; }
        let hooks = self.hooks?;
        let contexts = self.block_contexts.borrow();
        let context = contexts.iter().rev().find(|c| c.0 == lines.as_ptr() as usize && c.1 == lines.len())?;
        let found = hooks.block(&context.2,index,lines[index].start.saturating_sub(lines[index].virtual_indent))?;
        (found.id > 0 && found.consumed > 0 && found.consumed as usize <= lines.len()-index).then_some(found)
    }
    fn custom_node(&self,lines: &[Line],index: usize) -> Option<(Node,usize)> {
        let matched=self.custom_block(lines,index)?;let end=index+matched.consumed as usize;
        let mut node=self.node(Kind::Custom,lines,index,end);node.label=matched.id.to_string();
        node.literal=Some(lines[index..end].iter().map(|l|l.raw.as_str()).collect());Some((node,end))
    }
    fn interrupt(&self, lines: &[Line], index: usize) -> bool {
        interrupt(lines,index) || self.custom_block(lines,index).is_some()
    }
    fn spelling(&self, start: u32, end: u32) -> String {
        let start = (start as usize).min(self.utf16.len());
        let end = (end as usize).min(self.utf16.len()).max(start);
        String::from_utf16_lossy(&self.utf16[start..end])
    }
    fn node(&self, kind: Kind, lines: &[Line], first: usize, end: usize) -> Node {
        let start = lines[first].start;
        let end = lines[end - 1].end;
        Node::new(
            kind,
            self.spelling(start, end),
            start,
            end.saturating_sub(start),
        )
    }
    fn scan(&self, lines: &[Line], references: &References, depth: usize) -> Vec<Node> {
        let mut result = Vec::new();
        self.scan_into(lines, references, depth, |node| result.push(node));
        result
    }
    fn scan_into(&self, lines: &[Line], references: &References, depth: usize, mut emit: impl FnMut(Node)) {
        if lines.is_empty() {
            return;
        }
        // Keep room for host callback/context frames on small native worker stacks.
        if depth >= 64 {
            emit(self.node(Kind::Raw, lines, 0, lines.len())); return;
        }
        if self.hooks.is_some() {
            self.block_contexts.borrow_mut().push((lines.as_ptr() as usize,lines.len(),lines.iter().map(|l|l.text.encode_utf16().collect()).collect()));
        }
        if let Some(h)=self.hooks {
            let contexts=self.block_contexts.borrow();
            h.begin_block(&contexts.last().unwrap().2);
        }
        let _scope=crate::hooks::BlockScope(self.hooks);
        let mut index = 0;
        while index < lines.len() {
            if lines[index].blank() {
                index += 1;
                continue;
            }
            let first = index;
            let text = &lines[index].text;
            if let (Some(def), _) = (reference_definition(&lines[index..]), ()) {
                if !self.options.extensions || !def.label.starts_with('^') {
                    index = (index + def.lines).min(lines.len());
                    let mut node = self.node(Kind::ReferenceDefinition, lines, first, index);
                    node.label = def.label;
                    node.destination = def.destination;
                    node.title = def.title;
                    emit(node);
                    continue;
                }
            }
            if self.hooks_before_fences {
                if let Some((node,end)) = self.custom_node(lines,index) {
                    emit(node);index=end;continue;
                }
            }
            if let Some(fence) = fence_open(text) {
                index += 1;
                let mut content = Vec::new();
                while index < lines.len() && !fence_close(&lines[index].text, &fence) {
                    content.push(remove_code_indent(&lines[index].text, fence.indentation));
                    index += 1;
                }
                let has_closing = index < lines.len();
                if has_closing {
                    index += 1
                }
                let mut node = self.node(Kind::FencedCode, lines, first, index);
                node.info = fence.info;
                let mut literal = content.join("\n");
                if !content.is_empty()
                    && (has_closing || lines[index - 1].raw.ends_with(['\r', '\n']))
                {
                    literal.push('\n')
                }
                node.literal = Some(literal);
                emit(node);
                continue;
            }
            if !self.hooks_before_fences {
                if let Some((node,end)) = self.custom_node(lines,index) {
                    emit(node);index=end;continue;
                }
            }
            if self.options.extensions {
                if let Some(label) = footnote(text) {
                    index += 1;
                    while index < lines.len() {
                        if !lines[index].blank() && indent(&lines[index].text) >= 4 {
                            index += 1;
                        } else if lines[index].blank() {
                            let mut continuation = index;
                            while continuation < lines.len() && lines[continuation].blank() { continuation += 1; }
                            if continuation < lines.len() && indent(&lines[continuation].text) >= 4 {
                                index = continuation;
                            } else { break; }
                        } else { break; }
                    }
                    let mut node = self.node(Kind::FootnoteDefinition, lines, first, index);
                    node.label = label.into();
                    let opening = lines[first].text.trim_start();
                    let body_start = opening.find("]:").unwrap() + 2;
                    let mut body = opening[body_start..].trim_start_matches([' ', '\t']).to_owned();
                    for line in &lines[first+1..index] {
                        body.push('\n');
                        body.push_str(&remove_code_indent(&line.text,4));
                    }
                    node.literal = Some(body.trim().to_owned());
                    // Project only the definition prefix/continuation indentation. Children
                    // keep positions in the original document and share its reference pass.
                    let first_line = &lines[first];
                    let content = opening[body_start..].trim_start_matches([' ', '\t']);
                    let prefix_bytes = first_line.text.len() - content.len();
                    let body_line = Line {
                        text: content.to_owned(),
                        raw: format!("{}{}", content, if first_line.raw.ends_with(['\r','\n']) { "\n" } else { "" }),
                        start: (first_line.start + utf16_len(&first_line.text[..prefix_bytes]))
                            .saturating_sub(first_line.virtual_indent),
                        end: first_line.end,
                        projected: true,
                        lazy: false,
                        virtual_indent: 0,
                    };
                    let mut contents = vec![body_line];
                    contents.extend(lines[first+1..index].iter().map(|line| project(line,4)));
                    node.children = self.scan(&contents, references, depth+1);
                    emit(node);
                    continue;
                }
            }
            if self.options.extensions && indent(text) < 4
                && (text.trim_start().starts_with("$$") || backslash_math_open(text))
            {
                let closing = if text.trim_start().starts_with("$$") { "$$" } else { r"\]" };
                index += 1;
                let mut body = lines[first].text.trim_start()[2..].to_owned();
                // Keep an unclosed streaming block in the mutable tail.
                while inline::math_closing(&body, closing).is_none() && index < lines.len() {
                    body.push('\n');
                    body.push_str(&lines[index].text);
                    index += 1;
                }
                let mut node = self.node(Kind::BlockMath, lines, first, index);
                let close = inline::math_closing(&body, closing);
                let mut trailing = None;
                if closing == r"\]" && close.is_some() {
                    let last = &lines[index - 1];
                    let prefix = if index == first + 1 { last.text.len() - last.text.trim_start().len() + 2 } else { 0 };
                    let end = prefix + inline::math_closing(&last.text[prefix..], closing).unwrap() + 2;
                    let source_end = (last.start + utf16_len(&last.text[..end])).saturating_sub(last.virtual_indent);
                    node.source = self.spelling(node.span.start, source_end);
                    node.span.len = source_end.saturating_sub(node.span.start);
                    if !last.text[end..].trim().is_empty() {
                        let line = Line { text: last.text[end..].to_owned(), raw: last.raw[end..].to_owned(),
                            start: source_end, end: last.end, projected: last.projected, lazy: false, virtual_indent: 0 };
                        let mut paragraph = Node::new(Kind::Paragraph, self.spelling(source_end, last.end), source_end, last.end - source_end);
                        paragraph.children = self.paragraph(&[line], references, false);
                        trailing = Some(paragraph);
                    }
                }
                if let Some(end) = close { body.truncate(end); }
                node.literal = Some(body.trim().to_owned());
                emit(node);
                if let Some(paragraph) = trailing { emit(paragraph); }
                continue;
            }
            if let (Some((level, prefix, body)), _) = (heading(text), ()) {
                let mut node = self.node(Kind::Heading, lines, first, first + 1);
                node.level = level;
                node.children = inline::parse_with_hooks(
                    body,
                    (lines[first].start + utf16_len(&text[..prefix]))
                        .saturating_sub(lines[first].virtual_indent),
                    references,
                    self.options,
                    self.hooks,
                );
                emit(node);
                index += 1;
                continue;
            }
            if thematic(text) {
                emit(self.node(Kind::ThematicBreak, lines, first, first + 1));
                index += 1;
                continue;
            }
            if self.options.gfm {
                if let Some(alignments) = table_alignments(lines, index) {
                    index += 2;
                    while index < lines.len() && !lines[index].blank() && !self.interrupt(lines, index) {
                        index += 1
                    }
                    let mut node = self.node(Kind::Table, lines, first, index);
                    for row_index in std::iter::once(first).chain(first + 2..index) {
                        let row = &lines[row_index];
                        let mut row_node =
                            Node::new(Kind::TableRow, &row.text, row.start, utf16_len(&row.text));
                        for (start, end) in
                            table_spans(&row.text).into_iter().take(alignments.len())
                        {
                            let offset = (row.start + utf16_len(&row.text[..start]))
                                .saturating_sub(row.virtual_indent);
                            let body = &row.text[start..end];
                            let mut cell =
                                Node::new(Kind::TableCell, body, offset, utf16_len(body));
                            cell.children = inline::parse_with_hooks(body, offset, references, self.options, self.hooks);
                            normalize_table_code(&mut cell);
                            row_node.children.push(cell);
                        }
                        while row_node.children.len() < alignments.len() {
                            row_node.children.push(Node::new(
                                Kind::TableCell,
                                "",
                                (row.start + utf16_len(&row.text))
                                    .saturating_sub(row.virtual_indent),
                                0,
                            ))
                        }
                        node.children.push(row_node);
                    }
                    node.alignments = alignments;
                    emit(node);
                    continue;
                }
            }
            if list_marker(text, 3).is_some() {
                let (node, next) = self.list(lines, index, references, depth);
                emit(node);
                index = next;
                continue;
            }
            if quote_prefix(text).is_some() {
                let prefix = quote_prefix(text).unwrap();
                let mut continuing = quote_paragraph(&text[prefix..]);
                index += 1;
                while index < lines.len() {
                    if let Some(prefix) = quote_prefix(&lines[index].text) {
                        continuing = quote_paragraph(&lines[index].text[prefix..]);
                        index += 1
                    } else if continuing && !lines[index].blank() && !self.interrupt(lines, index) {
                        index += 1
                    } else {
                        break;
                    }
                }
                let projected: Vec<Line> = lines[first..index].iter().map(project_quote).collect();
                let mut node = self.node(Kind::BlockQuote, lines, first, index);
                node.children = self.scan(&projected, references, depth + 1);
                emit(node);
                continue;
            }
            if indent(text) >= 4 {
                index += 1;
                while index < lines.len()
                    && (lines[index].blank() || indent(&lines[index].text) >= 4)
                {
                    index += 1
                }
                while index > first + 1 && lines[index - 1].blank() {
                    index -= 1
                }
                let mut node = self.node(Kind::IndentedCode, lines, first, index);
                let mut literal = lines[first..index]
                    .iter()
                    .map(|line| remove_code_indent(&line.text, 4))
                    .collect::<Vec<_>>()
                    .join("\n");
                if lines[index - 1].raw.ends_with(['\r', '\n']) {
                    literal.push('\n')
                }
                node.literal = Some(literal);
                emit(node);
                continue;
            }
            if let Some(end) = html_end(text, false) {
                index += 1;
                if !end.matches(text) {
                    while index < lines.len() {
                        if end.matches(&lines[index].text) {
                            if matches!(end, HtmlEnd::Marker(..)) {
                                index += 1
                            }
                            break;
                        }
                        index += 1;
                    }
                }
                let mut node = self.node(Kind::HtmlBlock, lines, first, index);
                node.literal = Some(
                    lines[first..index]
                        .iter()
                        .map(|line| line.raw.replace("\r\n", "\n").replace('\r', "\n"))
                        .collect::<String>(),
                );
                emit(node);
                continue;
            }
            index += 1;
            while index < lines.len()
                && !lines[index].blank()
                && !(self.options.extensions &&
                    ((indent(&lines[index].text) < 4 && (lines[index].text.trim_start().starts_with("$$") || backslash_math_open(&lines[index].text))) || footnote(&lines[index].text).is_some()))
                && (lines[index].lazy
                    || (setext(&lines[index].text).is_none() && !self.interrupt(lines, index)))
            {
                index += 1
            }
            if index < lines.len() && !lines[index].lazy {
                if let Some(level) = setext(&lines[index].text) {
                    let mut node = self.node(Kind::Heading, lines, first, index + 1);
                    node.level = level;
                    node.children = self.paragraph(&lines[first..index], references, true);
                    emit(node);
                    index += 1;
                    continue;
                }
            }
            let mut node = self.node(Kind::Paragraph, lines, first, index);
            node.children = self.paragraph(&lines[first..index], references, false);
            emit(node);
        }
        if self.hooks.is_some() { self.block_contexts.borrow_mut().pop(); }
    }
    fn paragraph(&self, lines: &[Line], refs: &References, setext: bool) -> Vec<Node> {
        if lines.is_empty() {
            return Vec::new();
        }
        let first = &lines[0];
        if lines.iter().all(|line| !line.projected) {
            let content = lines
                .iter()
                .enumerate()
                .map(|(index, line)| {
                    if index + 1 < lines.len() {
                        line.raw.clone()
                    } else {
                        line.text.clone()
                    }
                })
                .collect::<String>();
            let content = content.trim_end_matches([' ', '\t']);
            let trimmed = content.trim_start_matches([' ', '\t']);
            let skipped = content.len() - trimmed.len();
            return inline::parse_with_hooks(
                trimmed,
                first.start + utf16_len(&content[..skipped]),
                refs,
                self.options,
                self.hooks,
            );
        }
        // Parse a whole logical paragraph so emphasis, code spans and links may
        // cross container lines. Every projected UTF-16 unit maps back to the
        // original source; container markers never enter the rendered literal.
        let mut content = String::new();
        let mut positions = Vec::<(u32, u32)>::new();
        for (position, line) in lines.iter().enumerate() {
            let leading = line.text.bytes().take_while(|c| horizontal(*c)).count();
            let body = &line.text[leading..];
            let body = if position + 1 == lines.len() || setext {
                body.trim_end_matches([' ', '\t'])
            } else {
                body
            };
            let start = (line.start + leading as u32).saturating_sub(line.virtual_indent);
            content.push_str(body);
            for unit in 0..utf16_len(body) {
                positions.push((start + unit, start + unit + 1));
            }
            if position + 1 < lines.len() {
                content.push('\n');
                let ending = if line.end >= 2 && self.utf16.get(line.end as usize - 2) == Some(&13)
                {
                    2
                } else {
                    1
                };
                positions.push((line.end.saturating_sub(ending), line.end));
            }
        }
        let mapped = self.hooks.map(|hooks| crate::hooks::Mapped { hooks, positions: &positions, fallback: first.start });
        let hooks = mapped.as_ref().map(|h| h as &dyn crate::hooks::Hooks);
        let mut children = inline::parse_with_hooks(&content, 0, refs, self.options, hooks);
        for child in &mut children {
            self.remap_inline(child, &positions, first.start);
        }
        children
    }
    fn remap_inline(&self, node: &mut Node, positions: &[(u32, u32)], fallback: u32) {
        let first = node.span.start as usize;
        let end = node.span.end() as usize;
        let start = positions
            .get(first)
            .map(|p| p.0)
            .unwrap_or_else(|| positions.last().map(|p| p.1).unwrap_or(fallback));
        let end = if end > first {
            positions.get(end - 1).map(|p| p.1).unwrap_or(start)
        } else {
            start
        };
        if matches!(node.kind, Kind::InlineHtml | Kind::InlineMath | Kind::Raw)
            && node.literal.is_none()
        {
            node.literal = Some(node.source.clone());
        }
        node.span.start = start;
        node.span.len = end.saturating_sub(start);
        node.source = self.spelling(start, end);
        for child in &mut node.children {
            self.remap_inline(child, positions, fallback);
        }
    }

    fn list(
        &self,
        lines: &[Line],
        first_index: usize,
        references: &References,
        depth: usize,
    ) -> (Node, usize) {
        let first = list_marker(&lines[first_index].text, 3).unwrap();
        let mut sibling_limit = display_column(&lines[first_index].text[..first.prefix]);
        let mut index = first_index;
        let mut loose = false;
        let mut items = Vec::new();
        while index < lines.len() {
            let Some(marker) = list_marker(&lines[index].text, 3) else {
                break;
            };
            if thematic(&lines[index].text)
                || marker.indentation >= sibling_limit
                || marker.ordered != first.ordered
                || marker.style != first.style
            {
                break;
            }
            let item_start = index;
            let item_line = &lines[index];
            index += 1;
            let mut body = item_line.text[marker.prefix..].to_owned();
            if marker.overflow > 0 {
                body = format!(
                    "{}{}",
                    " ".repeat(marker.overflow),
                    body.trim_start_matches([' ', '\t'])
                );
            }
            let mut checked = None;
            let mut task_length = 0;
            if self.options.gfm
                && body.as_bytes().get(0) == Some(&b'[')
                && matches!(body.as_bytes().get(1), Some(b' ' | b'x' | b'X'))
                && body.as_bytes().get(2) == Some(&b']')
                && body.as_bytes().get(3).is_some_and(|c| horizontal(*c))
            {
                checked = Some(body.as_bytes()[1] != b' ');
                task_length = 3 + body[3..].bytes().take_while(|c| horizontal(*c)).count();
                body = body[task_length..].to_owned();
            }
            let prefix_width = marker.prefix + task_length;
            let content_indent = display_column(&item_line.text[..marker.prefix]).max(
                marker.indentation
                    + if marker.ordered {
                        marker.number.to_string().len() + 2
                    } else {
                        2
                    },
            );
            sibling_limit = content_indent;
            let mut contents = vec![Line {
                raw: format!(
                    "{}{}",
                    body,
                    if item_line.raw.ends_with(['\r', '\n']) {
                        "\n"
                    } else {
                        ""
                    }
                ),
                text: body.clone(),
                start: (item_line.start + prefix_width as u32)
                    .saturating_sub(item_line.virtual_indent),
                end: item_line.end,
                projected: true,
                lazy: false,
                virtual_indent: 0,
            }];
            let mut last_content = item_start;
            let mut active_fence = fence_open(&body);
            while index < lines.len() {
                let current = &lines[index];
                if list_marker(&current.text, 3).is_some_and(|m| m.indentation < content_indent) {
                    break;
                }
                if current.blank() {
                    let mut following = index + 1;
                    while following < lines.len() && lines[following].blank() {
                        following += 1
                    }
                    if following < lines.len()
                        && list_marker(&lines[following].text, 3)
                            .is_some_and(|m| m.indentation < content_indent)
                    {
                        loose = true;
                        index = following;
                        break;
                    }
                    if body.trim().is_empty() && last_content == item_start {
                        break;
                    }
                    if following >= lines.len() || indent(&lines[following].text) < content_indent {
                        break;
                    }
                    let previous_nested = list_marker(&lines[last_content].text, usize::MAX)
                        .is_some_and(|m| {
                            m.indentation >= content_indent
                                && indent(&lines[following].text) > m.indentation
                        });
                    if active_fence.is_none() && !previous_nested {
                        loose = true
                    }
                    while index < following {
                        contents.push(project(&lines[index], 0));
                        index += 1
                    }
                    continue;
                }
                let indentation = indent(&current.text);
                if indentation >= content_indent {
                    let projected = project(current, content_indent.min(indentation));
                    if active_fence
                        .as_ref()
                        .is_some_and(|f| fence_close(&projected.text, f))
                    {
                        active_fence = None
                    } else if active_fence.is_none() {
                        active_fence = fence_open(&projected.text)
                    }
                    contents.push(projected);
                    last_content = index;
                    index += 1;
                    continue;
                }
                if !self.interrupt(lines, index) && !body.is_empty() {
                    let mut continuation = project(current, indentation.min(content_indent));
                    continuation.lazy = true;
                    contents.push(continuation);
                    last_content = index;
                    index += 1;
                    continue;
                }
                break;
            }
            let mut item = self.node(Kind::ListItem, lines, item_start, last_content + 1);
            if checked.is_some() { item.checked = checked; }
            item.children = self.scan(&contents, references, depth + 1);
            items.push(item);
            if index >= lines.len()
                || thematic(&lines[index].text)
                || list_marker(&lines[index].text, 3)
                    .is_none_or(|m| m.indentation >= sibling_limit || m.style != first.style)
            {
                break;
            }
        }
        let end = items
            .last()
            .map(|n| n.span.end())
            .unwrap_or(lines[first_index].end);
        let start = lines[first_index].start;
        let mut node = Node::new(Kind::List, self.spelling(start, end), start, end - start);
        node.ordered = first.ordered;
        node.list_start = first.ordered.then_some(first.number);
        node.tight = Some(!loose);
        node.children = items;
        (node, index.max(first_index + 1))
    }
}
fn remove_code_indent(s: &str, width: usize) -> String {
    let mut column = 0;
    let mut consumed = 0;
    for c in s.bytes() {
        if column >= width || !horizontal(c) {
            break;
        }
        column += if c == b'\t' { 4 - column % 4 } else { 1 };
        consumed += 1
    }
    format!(
        "{}{}",
        " ".repeat(column.saturating_sub(width)),
        &s[consumed..]
    )
}
fn normalize_table_code(node: &mut Node) {
    if node.kind == Kind::InlineCode {
        if let Some(literal) = &mut node.literal {
            *literal = literal.replace("\\|", "|");
        }
    }
    for child in &mut node.children {
        normalize_table_code(child);
    }
}
#[derive(Debug)]
struct Definition {
    label: String,
    destination: String,
    title: Option<String>,
    lines: usize,
}
fn reference_definition(lines: &[Line]) -> Option<Definition> {
    let first = lines.first()?.text.as_str();
    let leading = first.bytes().take_while(|c| *c == b' ').count();
    if leading > 3 || first.as_bytes().get(leading) != Some(&b'[') {
        return None;
    }
    let source = lines
        .iter()
        .take(64)
        .map(|l| l.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");
    let chars: Vec<char> = source.chars().collect();
    let mut i = 0;
    while chars.get(i) == Some(&' ') {
        i += 1
    }
    if i > 3 || chars.get(i) != Some(&'[') {
        return None;
    }
    i += 1;
    let label_start = i;
    while i < chars.len() && chars[i] != ']' {
        if chars[i] == '\\' && i + 1 < chars.len() {
            i += 2;
            continue;
        }
        if chars[i] == '['
            || (chars[i] == '\n'
                && chars[i + 1..]
                    .iter()
                    .skip_while(|c| **c == ' ' || **c == '\t')
                    .next()
                    == Some(&'\n'))
        {
            return None;
        }
        i += 1;
    }
    if i == chars.len() || i == label_start || i - label_start > 999 {
        return None;
    }
    let label: String = chars[label_start..i].iter().collect();
    if label.trim().is_empty() {
        return None;
    }
    i += 1;
    if chars.get(i) != Some(&':') {
        return None;
    }
    i += 1;
    let mut newlines = 0;
    while chars
        .get(i)
        .is_some_and(|c| matches!(*c, ' ' | '\t' | '\n'))
    {
        if chars[i] == '\n' {
            newlines += 1
        }
        if newlines > 1 {
            return None;
        }
        i += 1
    }
    let mut destination_start = i;
    let destination_end;
    if chars.get(i) == Some(&'<') {
        i += 1;
        destination_start = i;
        while i < chars.len() && chars[i] != '>' {
            if matches!(chars[i], '<' | '\n') {
                return None;
            }
            i += if chars[i] == '\\' && i + 1 < chars.len() && chars[i + 1] != '\n' {
                2
            } else {
                1
            };
        }
        if i == chars.len() {
            return None;
        }
        destination_end = i;
        i += 1;
    } else {
        let mut nesting = 0;
        while i < chars.len() && !matches!(chars[i], ' ' | '\t' | '\n') {
            if matches!(chars[i], '<' | '>') || chars[i].is_control() {
                return None;
            }
            if chars[i] == '\\' && i + 1 < chars.len() && chars[i + 1] != '\n' {
                i += 2;
                continue;
            }
            if chars[i] == '(' {
                nesting += 1
            }
            if chars[i] == ')' {
                nesting -= 1
            }
            if !(0..=32).contains(&nesting) {
                return None;
            }
            i += 1;
        }
        if i == destination_start || nesting != 0 {
            return None;
        }
        destination_end = i;
    }
    let destination = inline::decode_text(
        &chars[destination_start..destination_end]
            .iter()
            .collect::<String>(),
    );
    let separator = i;
    while chars.get(i).is_some_and(|c| matches!(*c, ' ' | '\t')) {
        i += 1
    }
    let destination_line_end = i;
    let title_next = chars.get(i) == Some(&'\n');
    if title_next {
        i += 1;
        while chars.get(i).is_some_and(|c| matches!(*c, ' ' | '\t')) {
            i += 1
        }
    }
    let without_title = || {
        if destination_line_end == chars.len() || chars.get(destination_line_end) == Some(&'\n') {
            Some(Definition {
                label: label.clone(),
                destination: destination.clone(),
                title: None,
                lines: chars[..destination_line_end]
                    .iter()
                    .filter(|c| **c == '\n')
                    .count()
                    + 1,
            })
        } else {
            None
        }
    };
    if i >= chars.len() || i == separator || !matches!(chars[i], '\'' | '"' | '(') {
        return without_title();
    }
    let opening = chars[i];
    let closing = if opening == '(' { ')' } else { opening };
    i += 1;
    let title_start = i;
    let mut newline = false;
    while i < chars.len() && chars[i] != closing {
        if chars[i] == '\\' && i + 1 < chars.len() {
            i += 2;
            newline = false;
            continue;
        }
        if opening == '(' && chars[i] == '(' {
            return if title_next { without_title() } else { None };
        }
        if chars[i] == '\n' {
            if newline {
                return if title_next { without_title() } else { None };
            }
            newline = true
        } else if !matches!(chars[i], ' ' | '\t') {
            newline = false
        }
        i += 1;
    }
    if i >= chars.len() {
        return if title_next { without_title() } else { None };
    }
    let title = inline::decode_text(&chars[title_start..i].iter().collect::<String>());
    i += 1;
    while chars.get(i).is_some_and(|c| matches!(*c, ' ' | '\t')) {
        i += 1
    }
    if i < chars.len() && chars[i] != '\n' {
        return if title_next { without_title() } else { None };
    }
    Some(Definition {
        label,
        destination,
        title: Some(title),
        lines: chars[..i].iter().filter(|c| **c == '\n').count() + 1,
    })
}
fn collect_references(nodes: &[Node], references: &mut References) {
    for node in nodes {
        if node.kind == Kind::ReferenceDefinition {
            references
                .entry(inline::normalize_reference(&node.label))
                .or_insert_with(|| Reference {
                    destination: node.destination.clone(),
                    title: node.title.clone(),
                });
        }
        collect_references(&node.children, references);
    }
}
pub fn parse(source: &str, options: Options) -> Node { parse_with_hooks(source,options,None) }
pub fn parse_with_hooks(source: &str, options: Options, hooks: Option<&dyn crate::hooks::Hooks>) -> Node { parse_with_hook_policy(source,options,hooks,false) }
pub fn parse_with_hook_policy(source: &str, options: Options, hooks: Option<&dyn crate::hooks::Hooks>, hooks_before_fences: bool) -> Node {
    let scanner = Scanner {
        utf16: source.encode_utf16().collect(),
        options,
        hooks,
        hooks_before_fences,
        block_contexts: std::cell::RefCell::new(Vec::new()),
    };
    let lines = lines(source);
    let first = scanner.scan(&lines, &References::new(), 0);
    let mut references = References::new();
    collect_references(&first, &mut references);
    let mut node = Node::new(Kind::Document, source, 0, utf16_len(source));
    node.children = if references.is_empty() {
        first
    } else {
        drop(first);
        scanner.scan(&lines, &references, 0)
    };
    node
}

/// FFI sink: never hold the entire top-level forest alongside its wire buffer.
/// None rewinds the first pass when reference definitions require resolution.
pub(crate) fn visit_blocks(source: &str, options: Options,
    hooks: Option<&dyn crate::hooks::Hooks>, hooks_before_fences: bool,
    mut emit: impl FnMut(Option<&Node>)) {
    let scanner = Scanner { utf16: source.encode_utf16().collect(), options, hooks,
        hooks_before_fences, block_contexts: std::cell::RefCell::new(Vec::new()) };
    let lines = lines(source);
    let mut references = References::new();
    scanner.scan_into(&lines, &References::new(), 0, |node| {
        collect_references(std::slice::from_ref(&node), &mut references);
        emit(Some(&node));
    });
    if !references.is_empty() {
        emit(None);
        scanner.scan_into(&lines, &references, 0, |node| emit(Some(&node)));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn nested_blocks_keep_original_utf16_ranges() {
        let source = "> 😀 first\r\n>\r\n> - item\r\n>   continuation\r\n";
        let tree = parse(source, Options::default());
        assert_eq!(tree.children[0].kind, Kind::BlockQuote);
        fn visit(node: &Node, source: &[u16]) {
            assert!(node.span.end() as usize <= source.len());
            if matches!(
                node.kind,
                Kind::Document | Kind::BlockQuote | Kind::List | Kind::ListItem | Kind::Paragraph
            ) {
                assert_eq!(
                    node.source,
                    String::from_utf16_lossy(
                        &source[node.span.start as usize..node.span.end() as usize]
                    )
                );
            }
            for child in &node.children {
                visit(child, source)
            }
        }
        visit(&tree, &source.encode_utf16().collect::<Vec<_>>());
    }
    #[test]
    fn ordered_lists_keep_start_and_tightness() {
        let tree = parse("3. first\n4. second\n", Options::default());
        let list = &tree.children[0];
        assert_eq!(list.list_start, Some(3));
        assert_eq!(list.tight, Some(true));
        assert_eq!(list.children.len(), 2);
        assert_eq!(list.children[0].children[0].kind, Kind::Paragraph);
        assert_eq!(
            parse("- one\n\n- two\n", Options::default()).children[0].tight,
            Some(false)
        );
    }
    #[test]
    fn gfm_table_cells_and_task_markers() {
        let tree = parse(
            "| A | B |\n| :- | -: |\n| 😀 | `a\\|b` |\n\n- [x] done\n",
            Options::default(),
        );
        assert_eq!(
            tree.children[0].alignments,
            vec![Some("left".into()), Some("right".into())]
        );
        assert_eq!(tree.children[0].children.len(), 2);
        assert_eq!(tree.children[1].children[0].checked, Some(true));
    }
    #[test]
    fn forward_references_are_resolved() {
        let tree = parse("[hello][id]\n\n[id]: /url \"title\"\n", Options::default());
        let link = &tree.children[0].children[0];
        assert_eq!(link.kind, Kind::Link);
        assert_eq!(link.destination, "/url");
        assert_eq!(link.title.as_deref(), Some("title"));
    }
    #[test]
    fn code_literals_strip_container_markers_and_preserve_terminal_newline() {
        let tree = parse("> ```rust\n> let x = 1;\n> ```\n", Options::default());
        assert_eq!(
            tree.children[0].children[0].literal.as_deref(),
            Some("let x = 1;\n")
        );
        assert_eq!(
            parse("    first\n    second\n", Options::default()).children[0]
                .literal
                .as_deref(),
            Some("first\nsecond\n")
        );
    }
    #[test]
    fn excessive_recursion_retains_raw_source() {
        let source = format!("{}body\n", "> ".repeat(200));
        let tree = parse(&source, Options::default());
        let mut node = &tree.children[0];
        let mut depth = 0;
        while !node.children.is_empty() {
            node = &node.children[0];
            depth += 1;
        }
        assert!(depth <= 128);
        assert_eq!(node.kind, Kind::Raw);
        assert!(node.source.contains("body"));
    }
}

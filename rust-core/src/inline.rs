//! Source-preserving inline grammar. Byte positions are internal only; every AST span is UTF-16.
use crate::ast::{utf16_len, Kind, Node, Options, References};
#[path = "entities.rs"]
mod entities;

pub fn normalize_reference(label: &str) -> String {
    label
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .replace('ẞ', "ß")
        .chars()
        .flat_map(char::to_uppercase)
        .flat_map(char::to_lowercase)
        .collect()
}
pub fn decode_text(source: &str) -> String {
    if !source.contains(['\\', '&']) { return source.to_owned(); }
    let mut out = String::new();
    let mut i = 0;
    while i < source.len() {
        let c = source[i..].chars().next().unwrap();
        if c == '\\' {
            if let Some(next) = source[i + 1..].chars().next() {
                if next.is_ascii_punctuation() {
                    out.push(next);
                    i += 1 + next.len_utf8();
                    continue;
                }
            }
        }
        if c == '&' {
            if let Some(end) = source[i + 1..].find(';').map(|j| i + 1 + j) {
                if end - i <= 33 {
                    if let Some(value) = decode_entity(&source[i + 1..end]) {
                        out.push_str(&value);
                        i = end + 1;
                        continue;
                    }
                }
            }
        }
        out.push(c);
        i += c.len_utf8();
    }
    out
}
fn decode_entity(token: &str) -> Option<String> {
    if !token.starts_with('#') {
        return entities::named(token).map(str::to_owned);
    }
    let (digits, radix, limit) = if token.starts_with("#x") || token.starts_with("#X") {
        (&token[2..], 16, 6)
    } else {
        (&token[1..], 10, 7)
    };
    if digits.is_empty()
        || digits.len() > limit
        || !digits.chars().all(|c| c.is_ascii() && c.is_digit(radix))
    {
        return None;
    }
    let value = u32::from_str_radix(digits, radix).ok()?;
    Some(
        char::from_u32(value)
            .filter(|c| *c != '\0')
            .unwrap_or('\u{fffd}')
            .to_string(),
    )
}
fn code_span(raw: &str) -> String {
    let count = raw.bytes().take_while(|b| *b == b'`').count();
    let value = raw[count..raw.len() - count]
        .replace("\r\n", " ")
        .replace(['\r', '\n'], " ");
    if value.len() >= 2
        && value.starts_with(' ')
        && value.ends_with(' ')
        && value.chars().any(|c| c != ' ')
    {
        value[1..value.len() - 1].to_owned()
    } else {
        value
    }
}
struct Parser<'a> {
    s: &'a str,
    offset: u32,
    refs: &'a References,
    options: Options,
    positions: Vec<u32>,
    depth: usize,
    hooks: Option<&'a dyn crate::hooks::Hooks>,
    hook_units: Vec<u16>,
}
impl<'a> Parser<'a> {
    fn new(s: &'a str, offset: u32, refs: &'a References, options: Options, depth: usize, hooks: Option<&'a dyn crate::hooks::Hooks>) -> Self {
        let mut positions = vec![0; s.len() + 1];
        let mut at = 0;
        for (i, c) in s.char_indices() {
            positions[i] = at;
            at += c.len_utf16() as u32;
            positions[i + c.len_utf8()] = at;
        }
        Self {
            s,
            offset,
            refs,
            options,
            positions,
            depth,
            hooks,
            hook_units: if hooks.is_some() { s.encode_utf16().collect() } else { Vec::new() },
        }
    }
    fn node(&self, kind: Kind, start: usize, end: usize) -> Node {
        Node::new(
            kind,
            &self.s[start..end],
            self.offset + self.positions[start],
            self.positions[end] - self.positions[start],
        )
    }
    fn text(&self, start: usize, end: usize) -> Node {
        let mut n = self.node(Kind::Text, start, end);
        n.literal = Some(decode_text(&n.source));
        n
    }
    fn children(&self, start: usize, end: usize) -> Vec<Node> {
        parse_depth(
            &self.s[start..end],
            self.offset + self.positions[start],
            self.refs,
            self.options,
            self.depth + 1,
            self.hooks,
        )
    }
    fn eol(&self, at: usize) -> usize {
        if self.s[at..].starts_with("\r\n") {
            at + 2
        } else {
            at + 1
        }
    }
    fn run(&self, at: usize, marker: u8) -> usize {
        let mut end = at;
        while self.s.as_bytes().get(end) == Some(&marker) {
            end += 1;
        }
        end
    }
    fn ticks(&self, count: usize, from: usize) -> Option<usize> {
        let mut at = from;
        while at < self.s.len() {
            if self.s.as_bytes()[at] == b'`' {
                let end = self.run(at, b'`');
                if end - at == count {
                    return Some(at);
                }
                at = end;
            } else {
                at += self.s[at..].chars().next()?.len_utf8();
            }
        }
        None
    }
    fn closing(&self, marker: &str, from: usize) -> Option<usize> {
        let mut at = from;
        while at < self.s.len() {
            let c = self.s[at..].chars().next()?;
            if c == '\\' {
                at += 1;
                if let Some(c) = self.s[at..].chars().next() {
                    at += c.len_utf8();
                }
                continue;
            }
            if self.s[at..].starts_with(marker) {
                return Some(at);
            }
            at += c.len_utf8();
        }
        None
    }
    fn bracket(&self, from: usize) -> Option<usize> {
        let mut at = from;
        let mut depth = 0;
        while at < self.s.len() {
            let c = self.s[at..].chars().next()?;
            if c == '\\' {
                at += 1;
                if let Some(c) = self.s[at..].chars().next() {
                    at += c.len_utf8();
                }
                continue;
            }
            if c == '`' {
                let end = self.run(at, b'`');
                if let Some(close) = self.ticks(end - at, end) {
                    at = close + end - at;
                    continue;
                }
            }
            if c == '<' {
                if let Some(len) = html_length(&self.s[at..]) {
                    at += len;
                    continue;
                }
                if let Some(end) = self.s[at + 1..].find('>') {
                    let end = at + 1 + end;
                    if autolink(&self.s[at + 1..end]).is_some() {
                        at = end + 1;
                        continue;
                    }
                }
            }
            if c == '[' {
                depth += 1;
            }
            if c == ']' {
                if depth == 0 {
                    return Some(at);
                }
                depth -= 1;
            }
            at += c.len_utf8();
        }
        None
    }
    fn tail(&self, opening: usize) -> Option<(String, Option<String>, usize)> {
        let b = self.s.as_bytes();
        let mut at = opening + 1;
        skip_space(self.s, &mut at)?;
        if at >= b.len() {
            return None;
        }
        let start;
        let end;
        if b[at] == b'<' {
            at += 1;
            start = at;
            loop {
                let c = *b.get(at)?;
                if c == b'\\' && at + 1 < b.len() {
                    at += 1 + self.s[at + 1..].chars().next()?.len_utf8();
                    continue;
                }
                if matches!(c, b'\r' | b'\n' | b'<') {
                    return None;
                }
                if c == b'>' {
                    break;
                }
                at += self.s[at..].chars().next()?.len_utf8();
            }
            end = at;
            at += 1;
        } else {
            start = at;
            let mut depth = 0;
            while at < b.len() {
                let c = b[at];
                if c == b'\\' && at + 1 < b.len() {
                    at += 1 + self.s[at + 1..].chars().next()?.len_utf8();
                    continue;
                }
                if c.is_ascii_whitespace() || c == b'<' || c == b'>' || c < 32 || c == 127 {
                    break;
                }
                if c == b'(' {
                    depth += 1;
                    if depth > 32 {
                        return None;
                    }
                } else if c == b')' {
                    if depth == 0 {
                        break;
                    }
                    depth -= 1;
                }
                at += self.s[at..].chars().next()?.len_utf8();
            }
            if depth != 0 {
                return None;
            }
            end = at;
        }
        let destination = decode_text(&self.s[start..end]);
        let separator = at;
        skip_space(self.s, &mut at)?;
        let mut title = None;
        if at > separator && matches!(b.get(at), Some(b'\"' | b'\'' | b'(')) {
            let delimiter = if b[at] == b'(' { b')' } else { b[at] };
            at += 1;
            let start = at;
            let mut newline = false;
            while at < b.len() {
                let c = b[at];
                if c == b'\\' && at + 1 < b.len() {
                    at += 1 + self.s[at + 1..].chars().next()?.len_utf8();
                    newline = false;
                    continue;
                }
                if c == delimiter {
                    break;
                }
                if matches!(c, b'\r' | b'\n') {
                    if newline {
                        return None;
                    }
                    newline = true;
                    at = self.eol(at);
                    continue;
                }
                if !matches!(c, b' ' | b'\t') {
                    newline = false;
                }
                at += self.s[at..].chars().next()?.len_utf8();
            }
            if at >= b.len() {
                return None;
            }
            title = Some(decode_text(&self.s[start..at]));
            at += 1;
            skip_space(self.s, &mut at)?;
        }
        if b.get(at) == Some(&b')') {
            Some((destination, title, at + 1))
        } else {
            None
        }
    }
    fn parse(&self) -> Vec<Node> {
        if let Some(h)=self.hooks {h.begin_inline(&self.hook_units)}
        let _scope=crate::hooks::InlineScope(self.hooks);
        let b = self.s.as_bytes();
        let mut nodes = Vec::new();
        let mut i = 0;
        let mut plain = 0;
        macro_rules! flush {
            ($end:expr) => {
                if plain < $end {
                    nodes.push(self.text(plain, $end));
                }
            };
        }
        while i < b.len() {
            // Recognize math before CommonMark consumes its opening escape.
            if self.options.extensions && self.s[i..].starts_with(r"\(") {
                if let Some(relative) = math_closing(&self.s[i + 2..], r"\)") {
                    let end = i + 2 + relative;
                    if end > i + 2 {
                        flush!(i);
                        let mut n = self.node(Kind::InlineMath, i, end + 2);
                        n.literal = Some(self.s[i + 2..end].to_owned());
                        nodes.push(n);
                        i = end + 2;
                        plain = i;
                        continue;
                    }
                }
            }
            if b[i] == b'\\' && i + 1 < b.len() {
                if matches!(b[i + 1], b'\r' | b'\n') {
                    flush!(i);
                    let mut end = self.eol(i + 1);
                    while matches!(b.get(end), Some(b' ' | b'\t')) {
                        end += 1;
                    }
                    nodes.push(self.node(Kind::HardBreak, i, end));
                    i = end;
                    plain = i;
                    continue;
                }
                let c = self.s[i + 1..].chars().next().unwrap();
                if c.is_ascii_punctuation() {
                    i += 1 + c.len_utf8();
                    continue;
                }
            }
            if matches!(b[i], b'\r' | b'\n') {
                let hard = i >= 2 && b[i - 1] == b' ' && b[i - 2] == b' ';
                let mut start = i;
                while start > plain && matches!(b[start - 1], b' ' | b'\t') {
                    start -= 1;
                }
                let mut end = self.eol(i);
                while matches!(b.get(end), Some(b' ' | b'\t')) {
                    end += 1;
                }
                flush!(start);
                nodes.push(self.node(
                    if hard {
                        Kind::HardBreak
                    } else {
                        Kind::SoftBreak
                    },
                    start,
                    end,
                ));
                i = end;
                plain = i;
                continue;
            }
            if b[i] == b'`' {
                let end = self.run(i, b'`');
                if let Some(close) = self.ticks(end - i, end) {
                    flush!(i);
                    let next = close + end - i;
                    let mut n = self.node(Kind::InlineCode, i, next);
                    n.literal = Some(code_span(&n.source));
                    nodes.push(n);
                    i = next;
                    plain = i;
                    continue;
                }
                i = end;
                continue;
            }
            if let Some(matched) = self.hooks.and_then(|h| h.inline(self.s, &self.hook_units, self.positions[i], self.offset + self.positions[i])) {
                if matched.id > 0 && matched.consumed > 0 {
                    let target = self.positions[i].saturating_add(matched.consumed);
                    if let Some(end) = (i+1..=self.s.len()).find(|&at| self.s.is_char_boundary(at) && self.positions[at] == target) {
                        flush!(i);
                        let mut node = self.node(Kind::Custom,i,end);
                        node.label = matched.id.to_string();
                        nodes.push(node); i=end; plain=i; continue;
                    }
                }
            }
            if b[i] == b'<' {
                if let Some(end) = self.s[i + 1..].find('>').map(|j| i + 1 + j) {
                    if let Some(destination) = autolink(&self.s[i + 1..end]) {
                        flush!(i);
                        let mut n = self.node(Kind::Link, i, end + 1);
                        n.destination = destination;
                        let mut child = self.node(Kind::Text, i + 1, end);
                        child.literal = Some(child.source.clone());
                        n.children.push(child);
                        nodes.push(n);
                        i = end + 1;
                        plain = i;
                        continue;
                    }
                }
                if let Some(length) = html_length(&self.s[i..]) {
                    flush!(i);
                    nodes.push(self.node(Kind::InlineHtml, i, i + length));
                    i += length;
                    plain = i;
                    continue;
                }
            }
            if self.options.gfm
                && (i == 0
                    || self.s[..i]
                        .chars()
                        .next_back()
                        .is_some_and(|c| c.is_whitespace() || "*_~(".contains(c)))
            {
                if let Some((length, destination)) = bare_autolink(&self.s[i..]) {
                    flush!(i);
                    let mut n = self.node(Kind::Link, i, i + length);
                    n.destination = destination;
                    let mut child = self.node(Kind::Text, i, i + length);
                    child.literal = Some(child.source.clone());
                    n.children.push(child);
                    nodes.push(n);
                    i += length;
                    plain = i;
                    continue;
                }
            }
            if self.options.extensions && b[i] == b'$' && b.get(i + 1) != Some(&b'$') {
                if let Some(end) = self.closing("$", i + 1) {
                    if end > i + 1 && b[end - 1] != b' ' {
                        flush!(i);
                        let mut n = self.node(Kind::InlineMath, i, end + 1);
                        n.literal = Some(self.s[i + 1..end].to_owned());
                        nodes.push(n);
                        i = end + 1;
                        plain = i;
                        continue;
                    }
                }
            }
            if self.options.extensions && self.s[i..].starts_with("[^") {
                if let Some(end) = self.closing("]", i + 2) {
                    let label = &self.s[i + 2..end];
                    if !label.is_empty()
                        && !label
                            .chars()
                            .any(|c| c.is_whitespace() || c == '[' || c == '`')
                    {
                        flush!(i);
                        let mut n = self.node(Kind::FootnoteReference, i, end + 1);
                        n.label = label.to_owned();
                        nodes.push(n);
                        i = end + 1;
                        plain = i;
                        continue;
                    }
                }
            }
            if b[i] == b'[' || (b[i] == b'!' && b.get(i + 1) == Some(&b'[')) {
                let image = b[i] == b'!';
                let open = i + usize::from(image);
                if let Some(close) = self.bracket(open + 1) {
                    let label = &self.s[open + 1..close];
                    let mut end = close + 1;
                    let mut target = None;
                    if b.get(end) == Some(&b'(') {
                        target = self.tail(end);
                    }
                    if target.is_none() {
                        if b.get(end) == Some(&b'[') {
                            if let Some(reference_end) = self.closing("]", end + 1) {
                                let reference = &self.s[end + 1..reference_end];
                                let reference = if reference.is_empty() {
                                    label
                                } else {
                                    reference
                                };
                                if let Some(r) = self.refs.get(&normalize_reference(reference)) {
                                    target = Some((
                                        r.destination.clone(),
                                        r.title.clone(),
                                        reference_end + 1,
                                    ));
                                }
                            }
                        } else if let Some(r) = self.refs.get(&normalize_reference(label)) {
                            target = Some((r.destination.clone(), r.title.clone(), end));
                        }
                    }
                    if let Some((destination, title, next)) = target {
                        let children = self.children(open + 1, close);
                        if image || !children.iter().any(contains_link) {
                            end = next;
                            flush!(i);
                            let mut n =
                                self.node(if image { Kind::Image } else { Kind::Link }, i, end);
                            n.destination = destination;
                            n.title = title;
                            n.children = children;
                            nodes.push(n);
                            i = end;
                            plain = i;
                            continue;
                        }
                    }
                }
            }
            if b[i] == b'*' || b[i] == b'_' || (self.options.gfm && b[i] == b'~') {
                let end = self.run(i, b[i]);
                flush!(i);
                nodes.push(self.text(i, end));
                i = end;
                plain = i;
                continue;
            }
            i += self.s[i..].chars().next().unwrap().len_utf8();
        }
        flush!(b.len());
        resolve_emphasis(nodes, self.s, self.offset, self.options.gfm)
    }
}
pub fn parse(source: &str, offset: u32, refs: &References, options: Options) -> Vec<Node> {
    parse_with_hooks(source, offset, refs, options, None)
}
pub fn parse_with_hooks(source: &str, offset: u32, refs: &References, options: Options, hooks: Option<&dyn crate::hooks::Hooks>) -> Vec<Node> {
    parse_depth(source,offset,refs,options,0,hooks)
}
fn parse_depth(
    source: &str,
    offset: u32,
    refs: &References,
    options: Options,
    depth: usize,
    hooks: Option<&dyn crate::hooks::Hooks>,
) -> Vec<Node> {
    // Bound malformed/adversarial nesting without overflowing the native call stack.
    if depth >= 128 {
        let mut n = Node::new(Kind::Text, source, offset, utf16_len(source));
        n.literal = Some(decode_text(source));
        return vec![n];
    }
    Parser::new(source, offset, refs, options, depth, hooks).parse()
}
fn contains_link(n: &Node) -> bool {
    n.kind == Kind::Link || n.children.iter().any(contains_link)
}
fn skip_space(s: &str, at: &mut usize) -> Option<()> {
    let b = s.as_bytes();
    let mut endings = 0;
    while *at < b.len() && b[*at].is_ascii_whitespace() {
        if matches!(b[*at], b'\r' | b'\n') {
            endings += 1;
            if endings > 1 {
                return None;
            }
            if s[*at..].starts_with("\r\n") {
                *at += 2;
            } else {
                *at += 1;
            }
        } else if matches!(b[*at], b' ' | b'\t') {
            *at += 1;
        } else {
            break;
        }
    }
    Some(())
}
fn autolink(s: &str) -> Option<String> {
    if s.is_empty()
        || s.chars()
            .any(|c| c.is_whitespace() || matches!(c, '<' | '>'))
    {
        return None;
    }
    if let Some(colon) = s.find(':') {
        let scheme = &s[..colon];
        if (2..=32).contains(&scheme.len())
            && scheme.as_bytes()[0].is_ascii_alphabetic()
            && scheme
                .bytes()
                .all(|c| c.is_ascii_alphanumeric() || b"+.-".contains(&c))
        {
            return Some(s.to_owned());
        }
    }
    if valid_email(s, false) {
        Some(format!("mailto:{s}"))
    } else {
        None
    }
}
fn valid_email(s: &str, bare: bool) -> bool {
    let Some((local, domain)) = s.split_once('@') else {
        return false;
    };
    let Some((_, last)) = domain.rsplit_once('.') else {
        return false;
    };
    !local.is_empty()
        && local
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || b".!#$%&'*+/=?^_`{|}~-".contains(&c))
        && !domain.is_empty()
        && domain.as_bytes()[0].is_ascii_alphanumeric()
        && domain
            .as_bytes()
            .last()
            .is_some_and(u8::is_ascii_alphanumeric)
        && domain
            .bytes()
            .all(|c| c.is_ascii_alphanumeric() || c == b'.' || c == b'-')
        && (bare || (last.len() >= 2 && last.bytes().all(|c| c.is_ascii_alphabetic())))
}
fn bare_autolink(s: &str) -> Option<(usize, String)> {
    if !s.chars().next()?.is_alphanumeric() {
        return None;
    }
    let url = s.starts_with("http://")
        || s.starts_with("https://")
        || s.starts_with("ftp://")
        || s.starts_with("www.");
    let mut end = s
        .char_indices()
        .find(|(_, c)| c.is_whitespace() || matches!(c, '<' | '>'))
        .map_or(s.len(), |(i, _)| i);
    if !url {
        end = s[..end]
            .char_indices()
            .find(|(_, c)| !c.is_ascii_alphanumeric() && !".!#$%&'*+/=?^_`{|}~-@".contains(*c))
            .map_or(end, |(i, _)| i);
    }
    if s[..end].ends_with(';') {
        if let Some(amp) = s[..end].rfind('&') {
            if !s[amp + 1..end - 1].is_empty()
                && s[amp + 1..end - 1]
                    .bytes()
                    .all(|c| c.is_ascii_alphanumeric())
            {
                end = amp;
            }
        }
    }
    while end > 0 && ".,!?;:".contains(s[..end].chars().next_back()?) {
        end -= 1;
    }
    while s[..end].ends_with(')')
        && s[..end].bytes().filter(|c| *c == b')').count()
            > s[..end].bytes().filter(|c| *c == b'(').count()
    {
        end -= 1;
    }
    let spelling = &s[..end];
    if spelling.is_empty() {
        return None;
    }
    let destination = if spelling.starts_with("www.") {
        let domain = spelling[4..].split(['/', ':', '?', '#']).next()?;
        let labels: Vec<_> = domain.split('.').collect();
        if labels.len() < 2
            || labels.iter().any(|s| s.is_empty())
            || labels.iter().rev().take(2).any(|s| s.contains('_'))
        {
            return None;
        }
        format!("http://{spelling}")
    } else if url {
        let authority = spelling
            .split_once("://")?
            .1
            .split(['/', '?', '#'])
            .next()?;
        if authority.is_empty() {
            return None;
        }
        spelling.to_owned()
    } else if valid_email(spelling, true) {
        format!("mailto:{spelling}")
    } else {
        return None;
    };
    Some((end, destination))
}
fn html_length(s: &str) -> Option<usize> {
    if s.starts_with("<!--") {
        if s.starts_with("<!-->") {
            return Some(5);
        }
        if s.starts_with("<!--->") {
            return Some(6);
        }
        return s[4..].find("-->").map(|i| i + 7);
    }
    if s.starts_with("<?") {
        return s[2..].find("?>").map(|i| i + 4);
    }
    if s.starts_with("<![CDATA[") {
        return s[9..].find("]]>").map(|i| i + 12);
    }
    let b = s.as_bytes();
    let mut i = 1;
    if s.starts_with("<!") {
        i = 2;
        let start = i;
        while b.get(i).is_some_and(u8::is_ascii_uppercase) {
            i += 1;
        }
        if i == start || !b.get(i).is_some_and(u8::is_ascii_whitespace) {
            return None;
        }
        return s[i..].find('>').map(|j| i + j + 1);
    }
    let closing = b.get(i) == Some(&b'/');
    if closing {
        i += 1;
    }
    if !b.get(i).is_some_and(u8::is_ascii_alphabetic) {
        return None;
    }
    i += 1;
    while b
        .get(i)
        .is_some_and(|c| c.is_ascii_alphanumeric() || *c == b'-')
    {
        i += 1;
    }
    loop {
        let start = i;
        while b
            .get(i)
            .is_some_and(|c| matches!(c, b' ' | b'\t' | b'\n' | b'\r'))
        {
            i += 1;
        }
        if b.get(i) == Some(&b'>') {
            return Some(i + 1);
        }
        if !closing && b.get(i) == Some(&b'/') && b.get(i + 1) == Some(&b'>') {
            return Some(i + 2);
        }
        if closing || i == start {
            return None;
        }
        if !b
            .get(i)
            .is_some_and(|c| c.is_ascii_alphabetic() || matches!(c, b'_' | b':'))
        {
            return None;
        }
        i += 1;
        while b
            .get(i)
            .is_some_and(|c| c.is_ascii_alphanumeric() || b"_.:-".contains(c))
        {
            i += 1;
        }
        let before_space = i;
        while b
            .get(i)
            .is_some_and(|c| matches!(c, b' ' | b'\t' | b'\n' | b'\r'))
        {
            i += 1;
        }
        if b.get(i) != Some(&b'=') {
            i = before_space;
            continue;
        }
        i += 1;
        while b
            .get(i)
            .is_some_and(|c| matches!(c, b' ' | b'\t' | b'\n' | b'\r'))
        {
            i += 1;
        }
        if matches!(b.get(i), Some(b'\"' | b'\'')) {
            let q = b[i];
            i += 1;
            while b.get(i) != Some(&q) {
                b.get(i)?;
                i += 1;
            }
            i += 1;
        } else {
            let start = i;
            while b.get(i).is_some_and(|c| !b" \t\r\n\"'=<>`".contains(c)) {
                i += 1;
            }
            if i == start {
                return None;
            }
        }
    }
}
#[derive(Clone)]
struct Token {
    node: Option<Node>,
    prev: Option<usize>,
    next: Option<usize>,
}
struct Delimiter {
    token: usize,
    marker: char,
    count: u32,
    original: u32,
    opens: bool,
    closes: bool,
    active: bool,
}
fn resolve_emphasis(nodes: Vec<Node>, source: &str, offset: u32, gfm: bool) -> Vec<Node> {
    // A single token cannot contain an emphasis pair or adjacent text to merge.
    if nodes.len() < 2 { return nodes; }
    let mut map = vec![0; utf16_len(source) as usize + 1];
    let mut utf = 0;
    for (byte, c) in source.char_indices() {
        map[utf] = byte;
        utf += c.len_utf16();
        map[utf] = byte + c.len_utf8();
    }
    let mut tokens = vec![Token {
        node: None,
        prev: None,
        next: None,
    }];
    let mut tail = 0;
    let mut delimiters = Vec::new();
    for node in nodes {
        let index = tokens.len();
        let marker = node.source.chars().next();
        if node.kind == Kind::Text
            && (matches!(marker, Some('*' | '_'))
                || (gfm && marker == Some('~') && node.span.len <= 2))
            && node.source.chars().all(|c| Some(c) == marker)
        {
            let marker = marker.unwrap();
            let start = map[(node.span.start - offset) as usize];
            let end = map[(node.span.end() - offset) as usize];
            let before = source[..start].chars().next_back();
            let after = source[end..].chars().next();
            let space = |c: Option<char>| c.is_none_or(char::is_whitespace);
            let punct = |c: Option<char>| c.is_some_and(entities::punctuation);
            let left = !space(after) && (!punct(after) || space(before) || punct(before));
            let right = !space(before) && (!punct(before) || space(after) || punct(after));
            let opens = if marker == '_' {
                left && (!right || punct(before))
            } else {
                left
            };
            let closes = if marker == '_' {
                right && (!left || punct(after))
            } else {
                right
            };
            delimiters.push(Delimiter {
                token: index,
                marker,
                count: node.span.len,
                original: node.span.len,
                opens,
                closes,
                active: true,
            });
        }
        tokens.push(Token {
            node: Some(node),
            prev: Some(tail),
            next: None,
        });
        tokens[tail].next = Some(index);
        tail = index;
    }
    fn remove(tokens: &mut [Token], index: usize) {
        let (prev, next) = (tokens[index].prev, tokens[index].next);
        if let Some(p) = prev {
            tokens[p].next = next;
        }
        if let Some(n) = next {
            tokens[n].prev = prev;
        }
        tokens[index].prev = None;
        tokens[index].next = None;
    }
    for ci in 0..delimiters.len() {
        if !delimiters[ci].active || !delimiters[ci].closes {
            continue;
        }
        while delimiters[ci].count > 0 {
            let closer = &delimiters[ci];
            let Some(oi) = (0..ci).rev().find(|i| {
                let o = &delimiters[*i];
                o.active
                    && o.opens
                    && o.count > 0
                    && o.marker == closer.marker
                    && (o.marker != '~' || o.count == closer.count)
                    && !(o.marker != '~'
                        && (o.closes || closer.opens)
                        && (o.original + closer.original) % 3 == 0
                        && (o.original % 3 != 0 || closer.original % 3 != 0))
            }) else {
                break;
            };
            let ot = delimiters[oi].token;
            let ct = delimiters[ci].token;
            let open = tokens[ot].node.as_ref().unwrap().span;
            let close = tokens[ct].node.as_ref().unwrap().span;
            let used = if delimiters[oi].count >= 2 && delimiters[ci].count >= 2 {
                2
            } else {
                1
            };
            let lower = open.end() - used;
            let upper = close.start + used;
            let spelling = |start: u32, end: u32| {
                source[map[(start - offset) as usize]..map[(end - offset) as usize]].to_owned()
            };
            let mut wrapper = Node::new(
                if delimiters[oi].marker == '~' {
                    Kind::Strikethrough
                } else if used == 2 {
                    Kind::Strong
                } else {
                    Kind::Emphasis
                },
                spelling(lower, upper),
                lower,
                upper - lower,
            );
            let mut cursor = tokens[ot].next;
            while let Some(index) = cursor {
                if index == ct {
                    break;
                }
                if let Some(node) = tokens[index].node.take() {
                    wrapper.children.push(node);
                }
                cursor = tokens[index].next;
            }
            let wi = tokens.len();
            tokens.push(Token {
                node: Some(wrapper),
                prev: Some(ot),
                next: Some(ct),
            });
            tokens[ot].next = Some(wi);
            tokens[ct].prev = Some(wi);
            for d in delimiters.iter_mut().take(ci).skip(oi + 1) {
                d.active = false;
            }
            delimiters[oi].count -= used;
            delimiters[ci].count -= used;
            if delimiters[oi].count == 0 {
                delimiters[oi].active = false;
                remove(&mut tokens, ot);
            } else {
                let mut n = Node::new(
                    Kind::Text,
                    spelling(open.start, open.start + delimiters[oi].count),
                    open.start,
                    delimiters[oi].count,
                );
                n.literal = Some(n.source.clone());
                tokens[ot].node = Some(n);
            }
            if delimiters[ci].count == 0 {
                delimiters[ci].active = false;
                remove(&mut tokens, ct);
            } else {
                let mut n = Node::new(
                    Kind::Text,
                    spelling(upper, upper + delimiters[ci].count),
                    upper,
                    delimiters[ci].count,
                );
                n.literal = Some(n.source.clone());
                tokens[ct].node = Some(n);
            }
        }
    }
    let mut result: Vec<Node> = Vec::new();
    let mut cursor = tokens[0].next;
    while let Some(index) = cursor {
        if let Some(n) = tokens[index].node.take() {
            if let Some(last) = result.last_mut() {
                if last.kind == Kind::Text
                    && n.kind == Kind::Text
                    && last.span.end() == n.span.start
                {
                    last.source.push_str(&n.source);
                    last.span.len += n.span.len;
                    last.literal = Some(decode_text(&last.source));
                    cursor = tokens[index].next;
                    continue;
                }
            }
            result.push(n);
        }
        cursor = tokens[index].next;
    }
    result
}

// An odd number of preceding backslashes escapes a delimiter.
pub(crate) fn math_closing(source: &str, delimiter: &str) -> Option<usize> {
    // Preserve the established dollar block closing behavior.
    if delimiter == "$$" { return source.find(delimiter); }
    source.match_indices(delimiter).find_map(|(at, _)| {
        let escapes = source.as_bytes()[..at].iter().rev().take_while(|&&c| c == b'\\').count();
        (escapes % 2 == 0).then_some(at)
    })
}

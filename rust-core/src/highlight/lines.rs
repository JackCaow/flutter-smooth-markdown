//! Line-oriented views for source and diff viewers: whole-input highlighting
//! split into display lines, and unified diffs with per-side highlighting and
//! word-level changes.

use super::{highlight, Token};

/// One display line: text with tabs expanded, and its tokens (offsets into `text`).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Line {
    pub text: Vec<u16>,
    pub tokens: Vec<Token>,
}

#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RowKind { Hunk = 0, Context = 1, Added = 2, Removed = 3, Note = 4 }

/// One unified-diff row. Code rows carry the new-file line number (removed rows the old one),
/// display text without the `+`/`-`/space prefix, highlight tokens and the word-level change.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DiffRow {
    pub kind: RowKind,
    pub number: Option<u32>,
    pub line: Line,
    pub changed: Option<(u32, u32)>,
}

/// Highlights `source` as one text (so multi-line constructs keep their state) and splits it
/// into lines. A trailing newline does not produce an empty last line.
pub fn highlight_lines(source: &[u16], language: &str, tab_width: usize) -> Vec<Line> {
    let mut end = source.len();
    if end > 0 && source[end - 1] == '\n' as u16 { end -= 1 }
    let source = &source[..end];
    split(source, &highlight(source, language), tab_width)
}

fn split(source: &[u16], tokens: &[Token], tab_width: usize) -> Vec<Line> {
    let mut lines = Vec::new();
    let mut start = 0usize;
    let mut next = 0usize;
    loop {
        let stop = source[start..].iter().position(|&u| u == '\n' as u16).map(|p| start + p).unwrap_or(source.len());
        let content_end = if stop > start && source[stop - 1] == '\r' as u16 { stop - 1 } else { stop };
        let mut line_tokens = Vec::new();
        while next < tokens.len() && (tokens[next].start as usize) < content_end {
            let t = tokens[next];
            let s = (t.start as usize).max(start);
            let e = ((t.start + t.len) as usize).min(content_end);
            if e > s { line_tokens.push(Token { start: (s - start) as u32, len: (e - s) as u32, kind: t.kind }) }
            if (t.start + t.len) as usize <= content_end { next += 1 } else { break }
        }
        lines.push(expand_tabs(&source[start..content_end], line_tokens, tab_width));
        if stop >= source.len() { break }
        start = stop + 1;
        // Tokens spanning the newline continue on the next line.
        while next < tokens.len() && ((tokens[next].start + tokens[next].len) as usize) <= start { next += 1 }
    }
    lines
}

/// Expands tabs to `tab_width` spaces (0 keeps them) and remaps token offsets.
fn expand_tabs(text: &[u16], tokens: Vec<Token>, tab_width: usize) -> Line {
    if tab_width == 0 || !text.contains(&('\t' as u16)) { return Line { text: text.to_vec(), tokens } }
    let mut map = Vec::with_capacity(text.len() + 1);
    let mut out = Vec::with_capacity(text.len() + 8);
    for &u in text {
        map.push(out.len() as u32);
        if u == '\t' as u16 { out.extend(std::iter::repeat(' ' as u16).take(tab_width)) } else { out.push(u) }
    }
    map.push(out.len() as u32);
    let tokens = tokens.into_iter().map(|t| {
        let s = map[t.start as usize];
        Token { start: s, len: map[(t.start + t.len) as usize] - s, kind: t.kind }
    }).collect();
    Line { text: out, tokens }
}

fn parse_hunk_header(line: &[u16]) -> Option<(u32, u32, usize)> {
    // `@@ -a[,b] +c[,d] @@[ context]`
    let text: String = String::from_utf16_lossy(line);
    let rest = text.strip_prefix("@@ -")?;
    let (old, rest) = rest.split_once(' ')?;
    let rest = rest.strip_prefix('+')?;
    let (new, rest) = rest.split_once(" @@")?;
    let old_start = old.split(',').next()?.parse().ok()?;
    let new_start = new.split(',').next()?.parse().ok()?;
    let header_len = text.len() - rest.len();
    Some((old_start, new_start, text[..header_len].encode_utf16().count()))
}

/// Parses a unified diff for display. Git metadata (`diff --git`, `index`, `---`, `+++`) is
/// dropped; binary, symlink and missing-newline facts become notes.
pub fn diff(patch: &[u16], language: &str, tab_width: usize) -> Vec<DiffRow> {
    let mut rows: Vec<DiffRow> = Vec::new();
    let mut in_hunk = false;
    let (mut old_line, mut new_line) = (0u32, 0u32);
    let mut code: Vec<(usize, Vec<u16>)> = Vec::new(); // (row index, raw text) of code rows
    let patch = if patch.last() == Some(&('\n' as u16)) { &patch[..patch.len() - 1] } else { patch };
    for raw in patch.split(|&u| u == '\n' as u16) {
        let raw = if raw.last() == Some(&('\r' as u16)) { &raw[..raw.len() - 1] } else { raw };
        let starts = |s: &str| s.encode_utf16().enumerate().all(|(k, u)| raw.get(k) == Some(&u));
        if let Some((old, new, header)) = parse_hunk_header(raw) {
            old_line = old;
            new_line = new;
            in_hunk = true;
            let context: Vec<u16> = raw[header..].iter().copied().skip_while(|&u| u == ' ' as u16).collect();
            let mut text: Vec<u16> = raw[..header].to_vec();
            if !context.is_empty() { text.push(' ' as u16); text.extend(context) }
            rows.push(DiffRow { kind: RowKind::Hunk, number: None, line: Line { text, tokens: Vec::new() }, changed: None });
        } else if starts("diff --git ") {
            in_hunk = false;
        } else if in_hunk && (starts("+") || starts("-") || starts(" ") || raw.is_empty()) {
            let (kind, number) = match raw.first().copied() {
                Some(u) if u == '+' as u16 => { new_line += 1; (RowKind::Added, new_line - 1) }
                Some(u) if u == '-' as u16 => { old_line += 1; (RowKind::Removed, old_line - 1) }
                _ => { new_line += 1; old_line += 1; (RowKind::Context, new_line - 1) }
            };
            let body = if raw.is_empty() { &raw[..] } else { &raw[1..] };
            code.push((rows.len(), body.to_vec()));
            rows.push(DiffRow { kind, number: Some(number), line: Line { text: Vec::new(), tokens: Vec::new() }, changed: None });
        } else if starts("\\ ") {
            rows.push(note(&raw[2..]));
        } else if starts("Binary files ") || starts("new file mode 120000") || starts("deleted file mode 120000") {
            rows.push(note(raw));
        }
    }
    highlight_sides(&mut rows, &code, language, tab_width);
    mark_word_changes(&mut rows, &code, tab_width);
    rows
}

fn note(text: &[u16]) -> DiffRow {
    DiffRow { kind: RowKind::Note, number: None, line: Line { text: text.to_vec(), tokens: Vec::new() }, changed: None }
}

/// Highlights each hunk's new side (context + added) and old side (context + removed)
/// as continuous text; context rows take the new side's tokens.
fn highlight_sides(rows: &mut [DiffRow], code: &[(usize, Vec<u16>)], language: &str, tab_width: usize) {
    let mut k = 0;
    while k < code.len() {
        // A hunk is a run of consecutive code rows.
        let start = k;
        while k + 1 < code.len() && code[k + 1].0 == code[k].0 + 1 { k += 1 }
        let hunk = &code[start..=k];
        k += 1;
        for (keep_added, keep) in [(true, [RowKind::Context, RowKind::Added]), (false, [RowKind::Removed, RowKind::Removed])] {
            let side: Vec<&(usize, Vec<u16>)> = hunk.iter().filter(|(row, _)| {
                let kind = rows[*row].kind;
                if keep_added { kind != RowKind::Removed } else { kind != RowKind::Added }
            }).collect();
            if !keep_added && !side.iter().any(|(row, _)| rows[*row].kind == RowKind::Removed) { continue }
            let mut joined: Vec<u16> = Vec::new();
            for (n, (_, text)) in side.iter().enumerate() {
                if n > 0 { joined.push('\n' as u16) }
                joined.extend_from_slice(text);
            }
            let lines = split(&joined, &highlight(&joined, language), tab_width);
            for ((row, _), line) in side.iter().zip(lines) {
                if keep.contains(&rows[*row].kind) { rows[*row].line = line }
            }
        }
    }
    // Rows that never received a line (empty hunks) still need their text.
    for (row, text) in code {
        if rows[*row].line.text.is_empty() && !text.is_empty() { rows[*row].line = expand_tabs(text, Vec::new(), tab_width) }
    }
}

/// Pairs each removed run with the added run after it and marks the differing middle of each pair.
fn mark_word_changes(rows: &mut [DiffRow], code: &[(usize, Vec<u16>)], tab_width: usize) {
    let raw: std::collections::HashMap<usize, &Vec<u16>> = code.iter().map(|(row, text)| (*row, text)).collect();
    let mut i = 0;
    while i < rows.len() {
        let removed_start = i;
        while i < rows.len() && rows[i].kind == RowKind::Removed { i += 1 }
        let added_start = i;
        while i < rows.len() && rows[i].kind == RowKind::Added { i += 1 }
        let pairs = (added_start - removed_start).min(i - added_start);
        for offset in 0..pairs {
            let (r, a) = (removed_start + offset, added_start + offset);
            let (old, new) = (raw[&r], raw[&a]);
            let prefix = old.iter().zip(new.iter()).take_while(|(x, y)| x == y).count();
            let suffix = old[prefix..].iter().rev().zip(new[prefix..].iter().rev()).take_while(|(x, y)| x == y).count();
            // Lines that share nothing are rewrites; highlighting the whole line adds nothing.
            if prefix + suffix == 0 { continue }
            for (row, text) in [(r, old), (a, new)] {
                let end = text.len() - suffix;
                if end > prefix {
                    let s = display_offset(text, prefix, tab_width);
                    let e = display_offset(text, end, tab_width);
                    rows[row].changed = Some((s, e - s));
                }
            }
        }
        if i == removed_start { i += 1 }
    }
}

fn display_offset(text: &[u16], offset: usize, tab_width: usize) -> u32 {
    if tab_width == 0 { return offset as u32 }
    let tabs = text[..offset].iter().filter(|&&u| u == '\t' as u16).count();
    (offset + tabs * (tab_width.saturating_sub(1))) as u32
}

impl DiffRow {
    pub fn is_code(&self) -> bool { matches!(self.kind, RowKind::Context | RowKind::Added | RowKind::Removed) }
}

//! Lexer and structural classifier for C-family and scripting languages.

use super::{is_digit, is_ident_part, is_ident_start, is_space, is_upper, Kind, Out, Src};

#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum Interp {
    None,
    /// `${expr}` (JS templates, Kotlin, Dart, Groovy, Scala, shell-like).
    DollarBrace,
    /// `${expr}` and `$name`.
    DollarIdent,
    /// Swift `\(expr)`.
    BackslashParen,
    /// Python f-strings and C# `$"…{expr}…"`; `{{` escapes a brace.
    Brace,
    /// Ruby `#{expr}`.
    HashBrace,
}

pub(crate) struct Str {
    pub open: &'static str,
    pub close: &'static str,
    pub escapes: bool,
    pub multiline: bool,
    pub interp: Interp,
    pub kind: Kind,
}

impl Str {
    pub(crate) const fn new(open: &'static str, close: &'static str) -> Str {
        Str { open, close, escapes: true, multiline: false, interp: Interp::None, kind: Kind::String }
    }
    pub(crate) const fn raw(self) -> Str { Str { escapes: false, ..self } }
    pub(crate) const fn multi(self) -> Str { Str { multiline: true, ..self } }
    pub(crate) const fn interp(self, interp: Interp) -> Str { Str { interp, ..self } }
    pub(crate) const fn special(self) -> Str { Str { kind: Kind::StringSpecial, ..self } }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum Annot { None, At, RustAttr }

#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum Params {
    /// `name: Type` (Kotlin, Swift, TS, Rust, Python, Scala, Dart named).
    NameColonType,
    /// `Type name` (C, C++, Java, C#, Dart, Groovy).
    TypeName,
    /// `name Type` (Go).
    NameType,
    /// Bare names (JavaScript, Ruby, Lua, PHP, R).
    Names,
}

pub(crate) struct Spec {
    pub name: &'static str,
    pub line_comments: &'static [&'static str],
    pub block_comment: Option<(&'static str, &'static str)>,
    pub nested_comments: bool,
    pub doc_comments: &'static [&'static str],
    pub strings: &'static [Str],
    pub keywords: &'static [&'static str],
    pub control: &'static [&'static str],
    pub declaration: &'static [&'static str],
    pub import: &'static [&'static str],
    pub operator_words: &'static [&'static str],
    pub booleans: &'static [&'static str],
    pub constants: &'static [&'static str],
    pub special_vars: &'static [&'static str],
    pub builtin_types: &'static [&'static str],
    /// Keywords whose next identifier is a function definition.
    pub fn_decl: &'static [&'static str],
    /// Keywords whose next identifier is a declared type.
    pub type_decl: &'static [&'static str],
    /// Keywords whose next identifier is a declared variable (`let`, `val`).
    pub var_decl: &'static [&'static str],
    /// Keywords after which the next identifier is in a type position.
    pub type_after: &'static [&'static str],
    pub params: Params,
    pub annotation: Annot,
    pub arrow_return: bool,
    pub capitalized_types: bool,
    pub jsx: bool,
    pub regex: bool,
    pub rust: bool,
    pub swift_raw: bool,
    pub cpp_raw: bool,
    pub preproc: bool,
    pub dollar_idents: bool,
    pub case_insensitive: bool,
}

pub(crate) const BASE: Spec = Spec {
    name: "",
    line_comments: &["//"],
    block_comment: Some(("/*", "*/")),
    nested_comments: false,
    doc_comments: &["/**", "///"],
    strings: &[],
    keywords: &[],
    control: &[],
    declaration: &[],
    import: &[],
    operator_words: &[],
    booleans: &["true", "false"],
    constants: &[],
    special_vars: &[],
    builtin_types: &[],
    fn_decl: &[],
    type_decl: &[],
    var_decl: &[],
    type_after: &[],
    params: Params::Names,
    annotation: Annot::None,
    arrow_return: false,
    capitalized_types: true,
    jsx: false,
    regex: false,
    rust: false,
    swift_raw: false,
    cpp_raw: false,
    preproc: false,
    dollar_idents: false,
    case_insensitive: false,
};

#[derive(Clone, Copy)]
struct Lx {
    s: usize,
    e: usize,
    k: Kind,
    /// Identifier still to be classified by the structural pass.
    word: bool,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Stop { End, Brace, Paren }

const MAX_NESTING: usize = 48;

pub(crate) fn highlight(src: &Src, out: &mut Out, spec: &'static Spec, start: usize, end: usize, _depth: usize) {
    let mut lexer = Lexer { src, spec, toks: Vec::new(), nesting: 0, start };
    lexer.lex(start, end, Stop::End);
    classify(src, spec, &mut lexer.toks);
    for t in lexer.toks { out.push(t.s, t.e, t.k) }
}

struct Lexer<'a, 'b> {
    src: &'a Src<'b>,
    spec: &'static Spec,
    toks: Vec<Lx>,
    nesting: usize,
    start: usize,
}

impl Lexer<'_, '_> {
    fn emit(&mut self, s: usize, e: usize, k: Kind) {
        if e > s { self.toks.push(Lx { s, e, k, word: false }) }
    }

    fn last_sig(&self) -> Option<Lx> {
        self.toks.iter().rev().find(|t| !matches!(t.k, Kind::Comment | Kind::CommentDoc)).copied()
    }

    fn last_text(&self) -> String {
        self.last_sig().map(|t| self.src.ascii(t.s, t.e)).unwrap_or_default()
    }

    /// Lexes code until `end` or, inside an interpolation, its closing delimiter.
    fn lex(&mut self, mut i: usize, end: usize, stop: Stop) -> usize {
        let src = self.src;
        let spec = self.spec;
        let mut depth = 0usize;
        while i < end {
            let c = src.at(i);
            if is_space(c) { i += 1; continue }
            if stop == Stop::Brace && c == '}' as u16 && depth == 0 { return i }
            if stop == Stop::Paren && c == ')' as u16 && depth == 0 { return i }
            if let Some(j) = self.comment(i, end) { i = j; continue }
            if spec.preproc && c == '#' as u16 && src.at_line_start(i, self.start) { i = self.preproc(i, end); continue }
            if let Some(j) = self.special_string(i, end) { i = j; continue }
            if let Some(j) = self.string(i, end) { i = j; continue }
            if spec.annotation == Annot::RustAttr && c == '#' as u16 && (src.is(i + 1, '[') || (src.is(i + 1, '!') && src.is(i + 2, '['))) {
                i = self.rust_attribute(i, end); continue
            }
            if spec.annotation == Annot::At && c == '@' as u16 && is_ident_start(src.at(i + 1)) {
                let mut j = src.ident_end(i + 1, end, &[]);
                // Qualified annotations such as `@java.lang.Deprecated`.
                while src.is(j, '.') && is_ident_start(src.at(j + 1)) { j = src.ident_end(j + 1, end, &[]) }
                let label = i > 0 && is_ident_part(src.at(i - 1));
                self.emit(i, j, if label { Kind::Label } else { Kind::Attribute });
                i = j;
                continue;
            }
            if spec.regex && c == '/' as u16 && self.regex_allowed() {
                if let Some(j) = self.regex(i, end) { i = j; continue }
            }
            if spec.jsx && c == '<' as u16 && (is_ident_start(src.at(i + 1)) || src.is(i + 1, '>')) && self.jsx_allowed() && self.nesting < MAX_NESTING {
                self.nesting += 1;
                i = self.jsx_element(i, end);
                self.nesting -= 1;
                continue;
            }
            if is_digit(c) || (c == '.' as u16 && is_digit(src.at(i + 1)) && !src.is(i.wrapping_sub(1), '.')) {
                let j = src.number_end(i, end);
                self.emit(i, j, Kind::Number);
                i = j;
                continue;
            }
            if is_ident_start(c) || (c == '$' as u16 && (spec.dollar_idents || spec.name == "javascript" || spec.name == "typescript" || spec.name == "tsx")) {
                let j = src.ident_end(i + 1, end, if spec.dollar_idents || spec.jsx || spec.regex { b"$" } else { b"" });
                // Rust macros (`println!`), Ruby predicates (`empty?`) and bang methods.
                let j = if (spec.rust || spec.name == "ruby") && (src.is(j, '!') || (spec.name == "ruby" && src.is(j, '?'))) && !src.is(j + 1, '=') { j + 1 } else { j };
                let kind = self.word_kind(i, j);
                if kind == Kind::Variable {
                    self.toks.push(Lx { s: i, e: j, k: Kind::Variable, word: true });
                } else {
                    self.emit(i, j, kind);
                }
                i = j;
                continue;
            }
            // Punctuation and operators.
            let (len, kind) = self.symbol(i);
            match c {
                0x7B => depth += usize::from(stop == Stop::Brace),
                0x7D => depth = depth.saturating_sub(usize::from(stop == Stop::Brace)),
                0x28 => depth += usize::from(stop == Stop::Paren),
                0x29 => depth = depth.saturating_sub(usize::from(stop == Stop::Paren)),
                _ => {}
            }
            self.emit(i, i + len, kind);
            i += len;
        }
        end
    }

    fn word_kind(&self, i: usize, j: usize) -> Kind {
        let spec = self.spec;
        let mut text = self.src.ascii(i, j);
        if text.is_empty() { return Kind::Variable }
        if spec.case_insensitive { text.make_ascii_lowercase() }
        let t = text.as_str();
        // Member names may reuse keywords (`obj.type`, `x.class`).
        if self.last_text() == "." && !spec.case_insensitive && !spec.special_vars.contains(&t) { return Kind::Variable }
        if spec.booleans.contains(&t) { Kind::Boolean }
        else if spec.constants.contains(&t) { Kind::ConstantBuiltin }
        else if spec.special_vars.contains(&t) { Kind::VariableSpecial }
        else if spec.control.contains(&t) { Kind::KeywordControl }
        else if spec.import.contains(&t) { Kind::KeywordImport }
        else if spec.declaration.contains(&t) || spec.fn_decl.contains(&t) || spec.type_decl.contains(&t) || spec.var_decl.contains(&t) { Kind::KeywordDeclaration }
        else if spec.operator_words.contains(&t) { Kind::KeywordOperator }
        else if spec.keywords.contains(&t) { Kind::Keyword }
        else if spec.builtin_types.contains(&t) { Kind::TypeBuiltin }
        else { Kind::Variable }
    }

    fn symbol(&self, i: usize) -> (usize, Kind) {
        const OPS: [&str; 33] = ["===", "!==", "...", "..<", "**=", "<<=", ">>=", "?.", "?:", "??", "=>", "->", "<-", "::", "==", "!=",
            "<=", ">=", "&&", "||", "++", "--", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "..", "<<", "|>"];
        for op in OPS {
            if self.src.starts(i, op) {
                let kind = if op == "::" || op == "?." { Kind::PunctuationDelimiter } else { Kind::Operator };
                return (op.len(), kind);
            }
        }
        match self.src.at(i) as u8 {
            b'(' | b')' | b'[' | b']' | b'{' | b'}' => (1, Kind::PunctuationBracket),
            b',' | b';' | b'.' | b':' => (1, Kind::PunctuationDelimiter),
            b'+' | b'-' | b'*' | b'/' | b'%' | b'=' | b'<' | b'>' | b'!' | b'&' | b'|' | b'^' | b'~' | b'?' => (1, Kind::Operator),
            _ if self.src.at(i) >= 0xD800 && self.src.at(i) < 0xDC00 => (2, Kind::None),
            _ => (1, Kind::Punctuation),
        }
    }

    fn comment(&mut self, i: usize, end: usize) -> Option<usize> {
        let src = self.src;
        let spec = self.spec;
        if let Some((open, close)) = spec.block_comment {
            if src.starts(i, open) {
                let doc = spec.doc_comments.iter().any(|d| d.len() > 2 && d.starts_with(open) && src.starts(i, d) && !src.starts(i, &format!("{open}{}", &close[close.len() - 1..])) && !src.starts(i + d.len(), close));
                let mut depth = 1usize;
                let mut j = i + open.len();
                while j < end && depth > 0 {
                    if src.starts(j, close) { depth -= 1; j += close.len() }
                    else if spec.nested_comments && src.starts(j, open) { depth += 1; j += open.len() }
                    else { j += 1 }
                }
                let j = j.min(end);
                self.emit(i, j, if doc { Kind::CommentDoc } else { Kind::Comment });
                return Some(j);
            }
        }
        for lc in spec.line_comments {
            if src.starts(i, lc) {
                // `#` comments must not swallow `#!`-less hashes in Rust attributes, etc.
                let j = src.line_end(i, end);
                let doc = spec.doc_comments.iter().any(|d| d.starts_with(lc) && d.len() > lc.len() && src.starts(i, d) && !src.starts(i, &format!("{d}{}", &d[d.len() - 1..])));
                self.emit(i, j, if doc { Kind::CommentDoc } else { Kind::Comment });
                return Some(j);
            }
        }
        None
    }

    fn preproc(&mut self, i: usize, end: usize) -> usize {
        let src = self.src;
        let k = src.skip_blank(i + 1, end);
        let j = src.ident_end(k, end, &[]);
        self.emit(i, j, Kind::Preproc);
        let word = src.ascii(k, j);
        let mut m = src.skip_blank(j, end);
        if (word == "include" || word == "import") && src.is(m, '<') {
            let close = src.find(m, src.line_end(m, end), ">").map(|p| p + 1).unwrap_or(m + 1);
            self.emit(m, close, Kind::String);
            m = close;
        } else if word == "define" {
            let n = src.ident_end(m, end, &[]);
            self.emit(m, n, Kind::Constant);
            m = n;
        }
        m
    }

    /// Rust raw strings, Swift raw strings and C++ raw strings.
    fn special_string(&mut self, i: usize, end: usize) -> Option<usize> {
        let src = self.src;
        if self.spec.rust {
            let mut k = i;
            if src.is(k, 'b') || src.is(k, 'c') { k += 1 }
            if src.is(k, 'r') && (src.is(k + 1, '"') || src.is(k + 1, '#')) && (i == 0 || !is_ident_part(src.at(i - 1))) {
                let mut h = k + 1;
                while src.is(h, '#') { h += 1 }
                if src.is(h, '"') {
                    let hashes = h - k - 1;
                    let mut j = h + 1;
                    while j < end {
                        if src.is(j, '"') && (1..=hashes).all(|n| src.is(j + n, '#')) { j += 1 + hashes; break }
                        j += 1;
                    }
                    self.emit(i, j.min(end), Kind::String);
                    return Some(j.min(end));
                }
            }
            // Character literals versus lifetimes / labels.
            if src.is(i, '\'') {
                if src.is(i + 1, '\\') {
                    let close = src.find(i + 2, src.line_end(i, end), "'").map(|p| p + 1).unwrap_or(i + 2);
                    self.emit(i, i + 1, Kind::String);
                    self.emit(i + 1, close - 1, Kind::StringEscape);
                    self.emit(close - 1, close, Kind::String);
                    return Some(close);
                }
                let width = if src.at(i + 1) >= 0xD800 && src.at(i + 1) < 0xDC00 { 2 } else { 1 };
                if src.is(i + 1 + width, '\'') {
                    self.emit(i, i + 2 + width, Kind::String);
                    return Some(i + 2 + width);
                }
                if is_ident_start(src.at(i + 1)) {
                    let j = src.ident_end(i + 1, end, &[]);
                    self.emit(i, j, Kind::Label);
                    return Some(j);
                }
            }
        }
        if self.spec.swift_raw && src.is(i, '#') && (src.is(i + 1, '"') || src.is(i + 1, '#')) {
            let mut h = i;
            while src.is(h, '#') { h += 1 }
            if !src.is(h, '"') { return None }
            let hashes = h - i;
            let triple = src.starts(h, "\"\"\"");
            let mut j = h + if triple { 3 } else { 1 };
            loop {
                if j >= end { break }
                let close_quote = if triple { src.starts(j, "\"\"\"") } else { src.is(j, '"') };
                let q = if triple { 3 } else { 1 };
                if close_quote && (0..hashes).all(|n| src.is(j + q + n, '#')) { j += q + hashes; break }
                j += 1;
            }
            self.emit(i, j.min(end), Kind::String);
            return Some(j.min(end));
        }
        if self.spec.cpp_raw && (src.starts(i, "R\"") || src.starts(i, "u8R\"") || src.starts(i, "LR\"")) {
            let q = src.find(i, i + 4, "\"")?;
            let paren = src.find(q, end.min(q + 18), "(")?;
            let delim: String = src.ascii(q + 1, paren);
            let close = format!("){delim}\"");
            let j = src.find(paren, end, &close).map(|p| p + close.len()).unwrap_or(end);
            self.emit(i, j, Kind::String);
            return Some(j);
        }
        None
    }

    fn string(&mut self, i: usize, end: usize) -> Option<usize> {
        let src = self.src;
        for rule in self.spec.strings {
            if !src.starts_ci(i, rule.open) { continue }
            let first = rule.open.as_bytes()[0];
            // Prefixed openers (`f"`, `@"`, `r'`) must start a token.
            if first.is_ascii_alphabetic() && i > 0 && is_ident_part(src.at(i - 1)) { continue }
            return Some(self.string_body(rule, i, i + rule.open.len(), end));
        }
        None
    }

    fn string_body(&mut self, rule: &Str, start: usize, mut j: usize, end: usize) -> usize {
        let src = self.src;
        let mut seg = start;
        while j < end {
            if src.starts(j, rule.close) {
                j += rule.close.len();
                self.emit(seg, j, rule.kind);
                return j;
            }
            let c = src.at(j);
            if !rule.multiline && c == '\n' as u16 { break }
            if rule.interp == Interp::BackslashParen && src.starts(j, "\\(") && self.nesting < MAX_NESTING {
                self.emit(seg, j, rule.kind);
                j = self.interpolation(j, 2, end, Stop::Paren, ')');
                seg = j;
                continue;
            }
            if rule.escapes && c == '\\' as u16 {
                self.emit(seg, j, rule.kind);
                let n = self.escape_end(j, end);
                self.emit(j, n, Kind::StringEscape);
                j = n;
                seg = j;
                continue;
            }
            match rule.interp {
                Interp::DollarBrace | Interp::DollarIdent if c == '$' as u16 && src.is(j + 1, '{') && self.nesting < MAX_NESTING => {
                    self.emit(seg, j, rule.kind);
                    j = self.interpolation(j, 2, end, Stop::Brace, '}');
                    seg = j;
                    continue;
                }
                Interp::DollarIdent if c == '$' as u16 && is_ident_start(src.at(j + 1)) => {
                    self.emit(seg, j, rule.kind);
                    let n = src.ident_end(j + 1, end, &[]);
                    self.emit(j, j + 1, Kind::PunctuationSpecial);
                    self.emit(j + 1, n, Kind::Variable);
                    j = n;
                    seg = j;
                    continue;
                }
                Interp::Brace if c == '{' as u16 => {
                    if src.is(j + 1, '{') {
                        self.emit(seg, j, rule.kind);
                        self.emit(j, j + 2, Kind::StringEscape);
                        j += 2;
                        seg = j;
                        continue;
                    }
                    if self.nesting < MAX_NESTING {
                        self.emit(seg, j, rule.kind);
                        j = self.interpolation(j, 1, end, Stop::Brace, '}');
                        seg = j;
                        continue;
                    }
                }
                Interp::Brace if c == '}' as u16 && src.is(j + 1, '}') => {
                    self.emit(seg, j, rule.kind);
                    self.emit(j, j + 2, Kind::StringEscape);
                    j += 2;
                    seg = j;
                    continue;
                }
                Interp::HashBrace if src.starts(j, "#{") && self.nesting < MAX_NESTING => {
                    self.emit(seg, j, rule.kind);
                    j = self.interpolation(j, 2, end, Stop::Brace, '}');
                    seg = j;
                    continue;
                }
                _ => {}
            }
            j += if c >= 0xD800 && c < 0xDC00 { 2 } else { 1 };
        }
        let j = j.min(end);
        self.emit(seg, j, rule.kind);
        j
    }

    /// Emits an interpolation's delimiters and lexes the embedded expression.
    fn interpolation(&mut self, at: usize, open_len: usize, end: usize, stop: Stop, close: char) -> usize {
        self.emit(at, at + open_len, Kind::PunctuationSpecial);
        self.nesting += 1;
        let k = self.lex(at + open_len, end, stop);
        self.nesting -= 1;
        if self.src.is(k, close) {
            self.emit(k, k + 1, Kind::PunctuationSpecial);
            k + 1
        } else {
            k
        }
    }

    fn escape_end(&self, j: usize, end: usize) -> usize {
        let src = self.src;
        let next = src.at(j + 1);
        let hex = |from: usize, max: usize| {
            let mut k = from;
            while k < end && k < from + max && (src.at(k) as u8).is_ascii_hexdigit() && src.at(k) < 128 { k += 1 }
            k
        };
        match next as u8 {
            b'u' if src.is(j + 2, '{') => src.find(j + 3, end.min(j + 14), "}").map(|p| p + 1).unwrap_or(j + 2),
            b'u' if next < 128 => hex(j + 2, 4),
            b'U' if next < 128 => hex(j + 2, 8),
            b'x' if next < 128 => hex(j + 2, 2),
            b'0'..=b'7' if next < 128 && self.spec.name != "javascript" => {
                let mut k = j + 1;
                while k < j + 4 && (b'0' as u16..=b'7' as u16).contains(&src.at(k)) { k += 1 }
                k
            }
            _ => (j + 2).min(end),
        }
    }

    fn rust_attribute(&mut self, i: usize, end: usize) -> usize {
        let src = self.src;
        let mut j = src.find(i, end, "[").unwrap_or(i) + 1;
        let mut depth = 1;
        while j < end && depth > 0 {
            match src.at(j) as u8 {
                b'[' => depth += 1,
                b']' => depth -= 1,
                b'"' => { j = src.find(j + 1, end, "\"").unwrap_or(end) }
                _ => {}
            }
            j += 1;
        }
        self.emit(i, j.min(end), Kind::Attribute);
        j.min(end)
    }

    fn regex_allowed(&self) -> bool {
        match self.last_sig() {
            None => true,
            Some(t) => match t.k {
                Kind::Number | Kind::String | Kind::StringSpecial | Kind::StringRegex | Kind::Variable | Kind::VariableSpecial
                | Kind::Boolean | Kind::ConstantBuiltin | Kind::TypeBuiltin => false,
                Kind::PunctuationBracket => matches!(self.src.at(t.s) as u8, b'(' | b'[' | b'{'),
                Kind::Keyword | Kind::KeywordControl | Kind::KeywordOperator | Kind::KeywordDeclaration => true,
                _ => !matches!(self.src.ascii(t.s, t.e).as_str(), "++" | "--"),
            },
        }
    }

    fn regex(&mut self, i: usize, end: usize) -> Option<usize> {
        let src = self.src;
        if src.is(i + 1, '/') || src.is(i + 1, '*') { return None }
        let mut j = i + 1;
        let mut class = false;
        while j < end {
            match src.at(j) as u8 {
                b'\n' => return None,
                b'\\' => { j += 2; continue }
                b'[' => class = true,
                b']' => class = false,
                b'/' if !class => break,
                _ => {}
            }
            j += 1;
        }
        if j >= end { return None }
        j += 1;
        while j < end && (src.at(j) as u8).is_ascii_alphabetic() && src.at(j) < 128 { j += 1 }
        self.emit(i, j, Kind::StringRegex);
        Some(j)
    }

    fn jsx_allowed(&self) -> bool {
        match self.last_sig() {
            None => true,
            Some(t) => matches!(self.src.ascii(t.s, t.e).as_str(),
                "(" | "," | "=" | ":" | "?" | "[" | "{" | "}" | "=>" | "return" | "&&" | "||" | "??" | ";" | "!" | "yield" | "default" | "else" | "case"),
        }
    }

    /// Parses one JSX element starting at `<`; returns the offset after it.
    fn jsx_element(&mut self, i: usize, end: usize) -> usize {
        let src = self.src;
        self.emit(i, i + 1, Kind::PunctuationBracket);
        let mut j = i + 1;
        if !src.is(j, '>') {
            let name_end = src.ident_end(j, end, b".-:");
            let name = src.ascii(j, name_end);
            let component = is_upper(src.at(j)) || name.contains('.');
            self.emit(j, name_end, if component { Kind::TagComponent } else { Kind::Tag });
            j = name_end;
            // Attributes.
            loop {
                j = src.skip_space(j, end);
                if j >= end { return end }
                if src.starts(j, "/>") { self.emit(j, j + 2, Kind::PunctuationBracket); return j + 2 }
                if src.is(j, '>') { self.emit(j, j + 1, Kind::PunctuationBracket); j += 1; break }
                if src.is(j, '{') {
                    j = self.jsx_expression(j, end);
                    continue;
                }
                if is_ident_start(src.at(j)) {
                    let a = src.ident_end(j, end, b"-:");
                    self.emit(j, a, Kind::Attribute);
                    j = src.skip_space(a, end);
                    if src.is(j, '=') {
                        self.emit(j, j + 1, Kind::Operator);
                        j = src.skip_space(j + 1, end);
                        let q = src.at(j);
                        if q == '"' as u16 || q == '\'' as u16 {
                            let close = (j + 1..end).find(|&k| src.at(k) == q).map(|k| k + 1).unwrap_or(end);
                            self.emit(j, close, Kind::String);
                            j = close;
                        } else if q == '{' as u16 {
                            j = self.jsx_expression(j, end);
                        }
                    }
                    continue;
                }
                // Not JSX after all (e.g. a comparison); stop treating it as markup.
                return j;
            }
        } else {
            self.emit(j, j + 1, Kind::PunctuationBracket);
            j += 1;
        }
        // Children.
        while j < end {
            if src.starts(j, "</") {
                self.emit(j, j + 2, Kind::PunctuationBracket);
                let n = src.ident_end(j + 2, end, b".-:");
                let component = is_upper(src.at(j + 2)) || src.ascii(j + 2, n).contains('.');
                self.emit(j + 2, n, if component { Kind::TagComponent } else { Kind::Tag });
                let gt = src.find(n, end, ">").map(|p| p + 1).unwrap_or(end);
                self.emit(gt - 1, gt, Kind::PunctuationBracket);
                return gt;
            }
            if src.is(j, '<') && (is_ident_start(src.at(j + 1)) || src.is(j + 1, '>')) && self.nesting < MAX_NESTING {
                self.nesting += 1;
                j = self.jsx_element(j, end);
                self.nesting -= 1;
                continue;
            }
            if src.is(j, '{') { j = self.jsx_expression(j, end); continue }
            j += 1;
        }
        end
    }

    fn jsx_expression(&mut self, j: usize, end: usize) -> usize {
        self.emit(j, j + 1, Kind::PunctuationBracket);
        self.nesting += 1;
        let k = self.lex(j + 1, end, Stop::Brace);
        self.nesting -= 1;
        if self.src.is(k, '}') { self.emit(k, k + 1, Kind::PunctuationBracket); k + 1 } else { k }
    }
}

// ---------------------------------------------------------------------------
// Structural pass: classify identifiers by syntactic position.
// ---------------------------------------------------------------------------

fn is_constant_name(text: &str) -> bool {
    text.len() > 1 && text.bytes().any(|b| b.is_ascii_uppercase())
        && text.bytes().all(|b| b.is_ascii_uppercase() || b.is_ascii_digit() || b == b'_')
}

fn classify(src: &Src, spec: &Spec, toks: &mut [Lx]) {
    let sig: Vec<usize> = (0..toks.len()).filter(|&i| !matches!(toks[i].k, Kind::Comment | Kind::CommentDoc)).collect();
    let texts: Vec<String> = sig.iter().map(|&i| src.ascii(toks[i].s, toks[i].e)).collect();
    let spans: Vec<(usize, usize)> = sig.iter().map(|&i| (toks[i].s, toks[i].e)).collect();
    let text = |n: usize| -> String { texts.get(n).cloned().unwrap_or_default() };
    let newline_between = |a: usize, b: usize| -> bool {
        match (spans.get(a), spans.get(b)) {
            (Some(x), Some(y)) => src.0[x.1..y.0].contains(&('\n' as u16)),
            _ => true,
        }
    };

    let mut paren: i32 = 0;
    let mut expect_fn = false;
    let mut expect_type = false;
    let mut expect_var = false;
    // Paren depth whose contents are a parameter list.
    let mut param_depth: Option<i32> = None;
    let mut fn_signature = false;
    // Type position: active until a terminator; angle bracket nesting inside it.
    let mut type_ctx = false;
    let mut type_paren = 0i32;
    let mut angle = 0i32;
    // Type header (`class A : B, C<D> {`), active until `{` or `=`.
    let mut header = false;
    let mut import_line = false;
    let mut last_var = false;
    let mut last_param = false;
    // Paren depth at which a type header is active.
    let mut header_paren = 0i32;
    // Brace stack: true for type bodies (interface/class/struct members).
    let mut braces: Vec<bool> = Vec::new();
    let mut last_member = false;

    let n_total = sig.len();
    let mut n = 0;
    while n < n_total {
        let i = sig[n];
        let t = text(n);
        let tok = toks[i];
        // Line-bound contexts.
        if n > 0 && newline_between(n - 1, n) {
            let prev = text(n - 1);
            let continued = matches!(prev.as_str(), "," | "." | "|" | "&" | "<" | ":" | "->" | "=" | "(" | "?") || t.starts_with('.');
            if !continued {
                import_line = false;
                if angle == 0 { type_ctx = false }
            }
        }
        if !tok.word {
            match t.as_str() {
                "(" => {
                    paren += 1;
                    if fn_signature && param_depth.is_none() { param_depth = Some(paren) }
                }
                ")" => {
                    if param_depth == Some(paren) && expect_fn {
                        // Go receiver `func (r *T) Name(`: the name and parameters follow.
                        param_depth = None;
                        paren -= 1;
                        type_ctx = false;
                        n += 1;
                        continue;
                    }
                    if param_depth == Some(paren) {
                        param_depth = None;
                        // Return type after `)` (`): Int`, `) -> T`).
                        if matches!(text(n + 1).as_str(), ":" | "->") && spec.params != Params::TypeName {
                            type_ctx = true;
                            type_paren = paren - 1;
                            n += 2;
                            paren -= 1;
                            fn_signature = false;
                            continue;
                        }
                        fn_signature = false;
                        if spec.params == Params::NameType && !matches!(text(n + 1).as_str(), "{" | "") { type_ctx = true; type_paren = paren - 1 }
                    }
                    paren -= 1;
                    if type_ctx && paren < type_paren { type_ctx = false }
                }
                "<" if type_ctx || (n > 0 && toks[sig[n - 1]].k == Kind::Type || toks.get(sig.get(n.wrapping_sub(1)).copied().unwrap_or(usize::MAX)).map(|p| matches!(p.k, Kind::TypeBuiltin | Kind::Constructor)).unwrap_or(false)) && angle_closes(&sig, toks, src, n) => {
                    angle += 1;
                    type_ctx = true;
                }
                ">" if angle > 0 => {
                    angle -= 1;
                    if angle == 0 && !header { type_ctx = matches!(text(n + 1).as_str(), "." | "?" | "[" | "|" | "&") }
                }
                ">>" if angle > 0 => { angle = (angle - 2).max(0) }
                ":" => {
                    if (last_param || last_var || last_member) && spec.params == Params::NameColonType {
                        type_ctx = true;
                        type_paren = paren;
                    } else if header && spec.params == Params::NameColonType {
                        type_ctx = true;
                    }
                }
                "->" if spec.arrow_return => { type_ctx = true; type_paren = paren }
                "{" | ";" | "=" | "=>" => {
                    if t == "{" { braces.push(header && paren == header_paren) }
                    if angle == 0 { type_ctx = false }
                    if (t != "=" || angle == 0) && paren == header_paren { header = false }
                    if t == "{" || t == ";" { fn_signature = false }
                }
                "}" => { braces.pop(); type_ctx = false }
                "," if angle == 0 && type_ctx && paren <= type_paren + i32::from(param_depth.is_some()) => type_ctx = param_depth.is_none() && header,
                _ => {}
            }
            last_var = false;
            last_param = false;
            last_member = false;
            let kind_text = t.as_str();
            if matches!(toks[i].k, Kind::KeywordDeclaration | Kind::Keyword | Kind::KeywordImport | Kind::KeywordOperator | Kind::KeywordControl) {
                let key = if spec.case_insensitive { kind_text.to_ascii_lowercase() } else { kind_text.to_string() };
                if spec.fn_decl.contains(&key.as_str()) { expect_fn = true; fn_signature = true }
                if spec.type_decl.contains(&key.as_str()) { expect_type = true }
                if spec.var_decl.contains(&key.as_str()) { expect_var = true }
                if spec.import.contains(&key.as_str()) && key != "as" { import_line = true }
                if spec.type_after.contains(&key.as_str()) { type_ctx = true; type_paren = paren }
            }
            n += 1;
            continue;
        }

        // An identifier.
        let prev = if n > 0 { text(n - 1) } else { String::new() };
        let next = text(n + 1);
        let in_params = param_depth == Some(paren);
        let builtin = spec.builtin_types.contains(&t.as_str());
        let capital = is_upper(src.at(tok.s));
        let kind = if import_line {
            if matches!(next.as_str(), "." | "::" | "/" | ".*") || prev == "from" || (!capital && prev != "import") { Kind::Namespace }
            else if capital { Kind::Type } else { Kind::Namespace }
        } else if expect_fn && !in_params {
            expect_fn = false;
            // Go methods: `func (r *T) Name(`; C/Java: handled by `TypeName` below.
            Kind::FunctionDefinition
        } else if expect_type {
            expect_type = false;
            header = true;
            header_paren = paren;
            // Primary constructors / record parameters: `class A(val x: Int)`.
            if next == "(" { fn_signature = true }
            Kind::Type
        } else if type_ctx && prev == "." {
            Kind::Type
        } else if matches!(prev.as_str(), "." | "?." | "::" | "!." | "->") && !(spec.rust && prev == "::" && capital) {
            if next == "(" || (spec.rust && t.ends_with('!')) { Kind::FunctionMethod }
            else if prev == "->" && spec.params != Params::TypeName { Kind::Type }
            else if is_constant_name(&t) { Kind::Constant }
            else if capital && (spec.name == "swift" || spec.name == "kotlin") && next != "=" { Kind::Type }
            else { Kind::Property }
        } else if type_ctx {
            if builtin { Kind::TypeBuiltin } else if next == "." && !capital { Kind::Namespace } else { Kind::Type }
        } else if in_params && is_parameter(spec, &prev, &next, n, &sig, toks) {
            last_param = true;
            expect_var = false;
            Kind::VariableParameter
        } else if in_params && spec.params == Params::NameType && matches!(prev.as_str(), "*" | "]" | "&") {
            Kind::Type
        } else if expect_var {
            expect_var = false;
            last_var = true;
            if is_constant_name(&t) { Kind::Constant } else { Kind::Variable }
        } else if header && paren == header_paren {
            if builtin { Kind::TypeBuiltin } else { Kind::Type }
        } else if matches!(next.as_str(), ":" | "?") && matches!(prev.as_str(), "{" | "," | ";" | "") && !in_params
            && (braces.last().copied().unwrap_or(false) || (next == ":" && spec.params != Params::NameColonType) || (next == ":" && braces.last().is_some() && prev != ";")) {
            // Members of type bodies and object literal keys.
            last_member = braces.last().copied().unwrap_or(false);
            Kind::Property
        } else if spec.rust && t.ends_with('!') {
            Kind::Function
        } else if next == "(" || (next == "<" && generic_call(&sig, toks, src, n)) {
            if spec.params == Params::TypeName && is_definition_after_type(&prev, n, &sig, toks) {
                fn_signature = true;
                param_depth = None;
                Kind::FunctionDefinition
            } else if capital && spec.capitalized_types { Kind::Constructor }
            else { Kind::Function }
        } else if spec.params == Params::TypeName && next_is_word(n + 1, &sig, toks) && !matches!(prev.as_str(), "." | "->") {
            // `Type name` declarations: the first word is the type.
            if builtin { Kind::TypeBuiltin } else { Kind::Type }
        } else if spec.params == Params::TypeName && next == "<" && angle_closes(&sig, toks, src, n + 1) && type_then_word(&sig, toks, src, n + 1) {
            Kind::Type
        } else if builtin {
            Kind::TypeBuiltin
        } else if is_constant_name(&t) {
            Kind::Constant
        } else if capital && spec.capitalized_types {
            Kind::Type
        } else if next == ":" && matches!(prev.as_str(), "{" | ",") && spec.params != Params::NameColonType {
            Kind::Property
        } else if spec.rust && next == "!" {
            Kind::Function
        } else {
            Kind::Variable
        };
        toks[i].k = kind;
        // A definition's parameter list follows it.
        if kind == Kind::FunctionDefinition { fn_signature = true }
        if kind == Kind::VariableParameter && spec.params == Params::NameType && next_is_word(n + 1, &sig, toks) { type_ctx = true; type_paren = paren }
        if kind != Kind::VariableParameter { last_param = false }
        if kind != Kind::Variable && kind != Kind::Constant { last_var = false }
        n += 1;
    }
}

fn next_is_word(n: usize, sig: &[usize], toks: &[Lx]) -> bool {
    sig.get(n).map(|&i| toks[i].word || toks[i].k == Kind::TypeBuiltin).unwrap_or(false)
}

fn is_parameter(spec: &Spec, prev: &str, next: &str, n: usize, sig: &[usize], toks: &[Lx]) -> bool {
    match spec.params {
        Params::NameColonType => matches!(next, ":" | "," | ")" | "=" | "?" | "...") && !matches!(prev, "." | ":"),
        Params::TypeName => matches!(next, "," | ")" | "=" | "[" | ":") && n > 0 && {
            let p = toks[sig[n - 1]];
            p.word || matches!(p.k, Kind::TypeBuiltin | Kind::Type) || matches!(prev, ">" | "]" | "*" | "&" | "?" | "...")
        },
        Params::NameType => matches!(prev, "(" | ",") && (next_is_word(n + 1, sig, toks) || matches!(next, "," | "*" | "[" | "...")),
        Params::Names => matches!(prev, "(" | "," | "*" | "**" | "...") && matches!(next, "," | ")" | "=" | ":" | "?"),
    }
}

/// `Type name(` at statement level is a definition in type-first languages.
fn is_definition_after_type(prev: &str, n: usize, sig: &[usize], toks: &[Lx]) -> bool {
    n > 0 && {
        let p = toks[sig[n - 1]];
        (p.word || matches!(p.k, Kind::TypeBuiltin | Kind::Type)) && !matches!(prev, "return" | "new" | "else" | "throw" | "await" | "yield")
            || matches!(prev, ">" | "]" | "*" | "&") && n > 1
    }
}

/// True when the `<` at `n` closes on the same line with only type-like tokens inside.
fn angle_closes(sig: &[usize], toks: &[Lx], src: &Src, n: usize) -> bool {
    let mut depth = 0;
    for &i in sig.iter().skip(n).take(24) {
        let t = src.ascii(toks[i].s, toks[i].e);
        match t.as_str() {
            "<" => depth += 1,
            ">" => { depth -= 1; if depth == 0 { return true } }
            ">>" => { depth -= 2; if depth <= 0 { return true } }
            "," | "." | "?" | "[" | "]" | "&" | "|" | "*" | "::" | ":" | "extends" | "super" | "in" | "out" | "keyof" | "dyn" | "impl" | "'" | "'static" => {}
            _ if toks[i].word || matches!(toks[i].k, Kind::TypeBuiltin | Kind::Type | Kind::Label | Kind::Keyword | Kind::KeywordDeclaration | Kind::Number) => {}
            _ => return false,
        }
    }
    false
}

fn generic_call(sig: &[usize], toks: &[Lx], src: &Src, n: usize) -> bool {
    if !angle_closes(sig, toks, src, n + 1) { return false }
    let mut depth = 0;
    for (k, &i) in sig.iter().enumerate().skip(n + 1) {
        match src.ascii(toks[i].s, toks[i].e).as_str() {
            "<" => depth += 1,
            ">" => { depth -= 1; if depth == 0 { return sig.get(k + 1).map(|&j| src.is(toks[j].s, '(')).unwrap_or(false) } }
            _ => {}
        }
    }
    false
}

fn type_then_word(sig: &[usize], toks: &[Lx], src: &Src, n: usize) -> bool {
    let mut depth = 0;
    for (k, &i) in sig.iter().enumerate().skip(n) {
        match src.ascii(toks[i].s, toks[i].e).as_str() {
            "<" => depth += 1,
            ">" => { depth -= 1; if depth == 0 { return next_is_word(k + 1, sig, toks) } }
            ">>" => { depth -= 2; if depth <= 0 { return next_is_word(k + 1, sig, toks) } }
            _ => {}
        }
    }
    false
}

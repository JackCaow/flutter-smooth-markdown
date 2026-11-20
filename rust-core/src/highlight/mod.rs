//! Syntax highlighting for source and diff viewers.
//!
//! Two layers, both stateful over the whole input:
//! 1. a lexer with a mode stack (string interpolation, nested comments, JSX,
//!    embedded languages) that never resets at line boundaries;
//! 2. a structural pass over the token stream that classifies identifiers by
//!    position (declarations, parameters, type positions, calls, members,
//!    import paths) instead of guessing from spelling alone.
//!
//! Offsets are UTF-16 code units so both bindings can apply them directly.

mod clike;
mod data;
mod lines;
mod markdown;
mod markup;
mod shell;
mod specs;

pub use lines::{diff as parse_diff, highlight_lines, DiffRow, Line, RowKind};

/// Token classes. Values are part of the C ABI (`smr_highlight_utf16`).
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Kind {
    None = 0,
    Attribute = 1,
    Boolean = 2,
    Comment = 3,
    CommentDoc = 4,
    Constant = 5,
    ConstantBuiltin = 6,
    Constructor = 7,
    DiffMinus = 8,
    DiffPlus = 9,
    Embedded = 10,
    Emphasis = 11,
    EmphasisStrong = 12,
    Function = 13,
    FunctionDefinition = 14,
    FunctionMethod = 15,
    Keyword = 16,
    KeywordControl = 17,
    KeywordDeclaration = 18,
    KeywordImport = 19,
    KeywordOperator = 20,
    Label = 21,
    Namespace = 22,
    Number = 23,
    Operator = 24,
    Preproc = 25,
    Property = 26,
    PropertyKey = 27,
    Punctuation = 28,
    PunctuationBracket = 29,
    PunctuationDelimiter = 30,
    PunctuationListMarker = 31,
    PunctuationSpecial = 32,
    Selector = 33,
    SelectorClass = 34,
    SelectorId = 35,
    SelectorPseudo = 36,
    String = 37,
    StringEscape = 38,
    StringRegex = 39,
    StringSpecial = 40,
    Tag = 41,
    TagDoctype = 42,
    TagComponent = 43,
    TextLiteral = 44,
    Title = 45,
    Type = 46,
    TypeBuiltin = 47,
    Variable = 48,
    VariableParameter = 49,
    VariableSpecial = 50,
    LinkText = 51,
    LinkUri = 52,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Token {
    pub start: u32,
    pub len: u32,
    pub kind: Kind,
}

/// Highlights `source` written in `language` (a fence tag, file extension or
/// file name). Unknown languages produce no tokens. Tokens are sorted,
/// non-overlapping and never `Kind::None`; uncovered ranges are plain text.
pub fn highlight(source: &[u16], language: &str) -> Vec<Token> {
    let Some(lang) = Lang::resolve(language) else { return Vec::new() };
    let src = Src(source);
    let mut out = Out::default();
    highlight_range(&src, &mut out, lang, 0, source.len(), 0);
    out.finish()
}

/// The canonical language name for a fence tag, extension or file name, or
/// `None` when the highlighter does not support it.
pub fn normalize_language(language: &str) -> Option<&'static str> {
    Lang::resolve(language).map(Lang::name)
}

const MAX_EMBED_DEPTH: usize = 8;

pub(crate) fn highlight_range(src: &Src, out: &mut Out, lang: Lang, start: usize, end: usize, depth: usize) {
    if depth > MAX_EMBED_DEPTH || start >= end { return }
    match lang {
        Lang::Code(spec) => clike::highlight(src, out, spec, start, end, depth),
        Lang::Json => data::json(src, out, start, end),
        Lang::Yaml => data::yaml(src, out, start, end),
        Lang::Toml => data::toml(src, out, start, end),
        Lang::Ini => data::ini(src, out, start, end),
        Lang::Markdown => markdown::highlight(src, out, start, end, depth),
        Lang::Html(flavor) => markup::html(src, out, flavor, start, end, depth),
        Lang::Css(flavor) => markup::css(src, out, flavor, start, end),
        Lang::Shell(flavor) => shell::highlight(src, out, flavor, start, end, depth),
        Lang::Diff => diff(src, out, start, end),
    }
}

fn diff(src: &Src, out: &mut Out, start: usize, end: usize) {
    let mut line = start;
    while line < end {
        let stop = src.line_end(line, end);
        let kind = match src.at(line) {
            b if b == '+' as u16 && !src.starts(line, "+++ ") => Kind::DiffPlus,
            b if b == '-' as u16 && !src.starts(line, "--- ") => Kind::DiffMinus,
            b if b == '@' as u16 && src.starts(line, "@@") => Kind::Keyword,
            _ if src.starts(line, "diff ") || src.starts(line, "index ") || src.starts(line, "+++ ") || src.starts(line, "--- ") => Kind::Comment,
            _ => Kind::None,
        };
        out.push(line, stop, kind);
        line = stop + 1;
    }
}

// ---------------------------------------------------------------------------
// Languages
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum HtmlFlavor { Html, Xml, Vue, Svelte }
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum CssFlavor { Css, Scss, Less }
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum ShellFlavor { Sh, Dockerfile, Makefile }

#[derive(Clone, Copy)]
pub(crate) enum Lang {
    Code(&'static clike::Spec),
    Json,
    Yaml,
    Toml,
    Ini,
    Markdown,
    Html(HtmlFlavor),
    Css(CssFlavor),
    Shell(ShellFlavor),
    Diff,
}

impl Lang {
    pub(crate) fn resolve(language: &str) -> Option<Lang> {
        let raw = language.trim();
        let file = raw.rsplit('/').next().unwrap_or(raw);
        let lower = file.to_ascii_lowercase();
        // File names without a meaningful extension.
        match lower.as_str() {
            "dockerfile" | "containerfile" => return Some(Lang::Shell(ShellFlavor::Dockerfile)),
            "makefile" | "gnumakefile" => return Some(Lang::Shell(ShellFlavor::Makefile)),
            ".env" | ".envrc" => return Some(Lang::Shell(ShellFlavor::Sh)),
            ".bashrc" | ".zshrc" | ".profile" | ".bash_profile" => return Some(Lang::Shell(ShellFlavor::Sh)),
            ".gitignore" | ".dockerignore" | ".gitattributes" | ".editorconfig" => return Some(Lang::Ini),
            "cargo.lock" | "pipfile" | "poetry.lock" => return Some(Lang::Toml),
            "gemfile" | "rakefile" | "podfile" => return Some(Lang::Code(&specs::RUBY)),
            _ => {}
        }
        if lower.starts_with("dockerfile.") || lower.ends_with(".dockerfile") { return Some(Lang::Shell(ShellFlavor::Dockerfile)) }
        if lower.starts_with(".env.") { return Some(Lang::Shell(ShellFlavor::Sh)) }
        let tag = lower.split(|c: char| c.is_whitespace() || c == ',' || c == '{').next().unwrap_or("");
        let key = match tag.rsplit_once('.') {
            Some((_, ext)) if !ext.is_empty() => ext,
            _ => tag,
        };
        // `build.gradle.kts` resolves through `kts`; `build.gradle` through `gradle`.
        Some(match key {
            "js" | "mjs" | "cjs" | "javascript" | "node" | "jsx" => Lang::Code(&specs::JAVASCRIPT),
            "ts" | "mts" | "cts" | "typescript" => Lang::Code(&specs::TYPESCRIPT),
            "tsx" => Lang::Code(&specs::TSX),
            "kt" | "kts" | "kotlin" => Lang::Code(&specs::KOTLIN),
            "swift" => Lang::Code(&specs::SWIFT),
            "java" => Lang::Code(&specs::JAVA),
            "groovy" | "gradle" | "gvy" => Lang::Code(&specs::GROOVY),
            "scala" | "sc" | "sbt" => Lang::Code(&specs::SCALA),
            "c" | "h" => Lang::Code(&specs::C),
            "cc" | "cpp" | "c++" | "cxx" | "hpp" | "hh" | "hxx" | "ino" => Lang::Code(&specs::CPP),
            "m" | "mm" | "objc" | "objective-c" | "objectivec" => Lang::Code(&specs::OBJC),
            "cs" | "c#" | "csharp" => Lang::Code(&specs::CSHARP),
            "go" | "golang" => Lang::Code(&specs::GO),
            "rs" | "rust" => Lang::Code(&specs::RUST),
            "py" | "pyi" | "python" | "python3" | "py3" => Lang::Code(&specs::PYTHON),
            "rb" | "ruby" | "rake" | "gemspec" => Lang::Code(&specs::RUBY),
            "php" | "phtml" => Lang::Code(&specs::PHP),
            "dart" => Lang::Code(&specs::DART),
            "lua" => Lang::Code(&specs::LUA),
            "r" => Lang::Code(&specs::R),
            "sql" | "mysql" | "pgsql" | "postgres" | "postgresql" | "sqlite" | "plsql" => Lang::Code(&specs::SQL),
            "graphql" | "gql" => Lang::Code(&specs::GRAPHQL),
            "proto" | "protobuf" => Lang::Code(&specs::PROTO),
            "zig" => Lang::Code(&specs::ZIG),
            "json" | "jsonc" | "json5" | "webmanifest" | "babelrc" | "eslintrc" => Lang::Json,
            "yaml" | "yml" => Lang::Yaml,
            "toml" => Lang::Toml,
            "ini" | "cfg" | "conf" | "properties" | "env" | "dotenv" | "editorconfig" | "gitconfig" => Lang::Ini,
            "md" | "markdown" | "mdx" | "mkd" => Lang::Markdown,
            "html" | "htm" | "xhtml" => Lang::Html(HtmlFlavor::Html),
            "xml" | "svg" | "plist" | "xsd" | "xsl" | "storyboard" | "xib" | "csproj" | "pom" => Lang::Html(HtmlFlavor::Xml),
            "vue" => Lang::Html(HtmlFlavor::Vue),
            "svelte" => Lang::Html(HtmlFlavor::Svelte),
            "css" => Lang::Css(CssFlavor::Css),
            "scss" | "sass" => Lang::Css(CssFlavor::Scss),
            "less" => Lang::Css(CssFlavor::Less),
            "sh" | "bash" | "zsh" | "fish" | "ksh" | "shell" | "shellscript" | "console" | "shellsession" | "command" => Lang::Shell(ShellFlavor::Sh),
            "dockerfile" | "docker" | "containerfile" => Lang::Shell(ShellFlavor::Dockerfile),
            "makefile" | "make" | "mk" | "mak" => Lang::Shell(ShellFlavor::Makefile),
            "diff" | "patch" => Lang::Diff,
            _ => return None,
        })
    }

    pub(crate) fn name(self) -> &'static str {
        match self {
            Lang::Code(spec) => spec.name,
            Lang::Json => "json",
            Lang::Yaml => "yaml",
            Lang::Toml => "toml",
            Lang::Ini => "ini",
            Lang::Markdown => "markdown",
            Lang::Html(HtmlFlavor::Html) => "html",
            Lang::Html(HtmlFlavor::Xml) => "xml",
            Lang::Html(HtmlFlavor::Vue) => "vue",
            Lang::Html(HtmlFlavor::Svelte) => "svelte",
            Lang::Css(CssFlavor::Css) => "css",
            Lang::Css(CssFlavor::Scss) => "scss",
            Lang::Css(CssFlavor::Less) => "less",
            Lang::Shell(ShellFlavor::Sh) => "shell",
            Lang::Shell(ShellFlavor::Dockerfile) => "dockerfile",
            Lang::Shell(ShellFlavor::Makefile) => "makefile",
            Lang::Diff => "diff",
        }
    }
}

// ---------------------------------------------------------------------------
// Source access and token output
// ---------------------------------------------------------------------------

pub(crate) struct Src<'a>(pub &'a [u16]);

impl Src<'_> {
    #[inline]
    pub(crate) fn at(&self, i: usize) -> u16 { self.0.get(i).copied().unwrap_or(0) }
    #[inline]
    pub(crate) fn is(&self, i: usize, c: char) -> bool { self.at(i) == c as u16 }
    pub(crate) fn starts(&self, i: usize, needle: &str) -> bool {
        needle.bytes().enumerate().all(|(k, b)| self.at(i + k) == b as u16)
    }
    pub(crate) fn starts_ci(&self, i: usize, needle: &str) -> bool {
        needle.bytes().enumerate().all(|(k, b)| {
            let u = self.at(i + k);
            u < 128 && (u as u8).eq_ignore_ascii_case(&b)
        })
    }
    pub(crate) fn line_end(&self, i: usize, end: usize) -> usize {
        let mut j = i;
        while j < end && self.at(j) != b'\n' as u16 { j += 1 }
        j
    }
    pub(crate) fn line_start(&self, i: usize, start: usize) -> usize {
        let mut j = i;
        while j > start && self.at(j - 1) != b'\n' as u16 { j -= 1 }
        j
    }
    /// True when only spaces or tabs precede `i` on its line.
    pub(crate) fn at_line_start(&self, i: usize, start: usize) -> bool {
        let mut j = i;
        while j > start {
            match self.at(j - 1) {
                0x20 | 0x09 => j -= 1,
                0x0A => return true,
                _ => return false,
            }
        }
        true
    }
    pub(crate) fn skip_blank(&self, mut i: usize, end: usize) -> usize {
        while i < end && matches!(self.at(i), 0x20 | 0x09) { i += 1 }
        i
    }
    pub(crate) fn skip_space(&self, mut i: usize, end: usize) -> usize {
        while i < end && is_space(self.at(i)) { i += 1 }
        i
    }
    pub(crate) fn ident_end(&self, mut i: usize, end: usize, extra: &[u8]) -> usize {
        while i < end && (is_ident_part(self.at(i)) || extra.iter().any(|&b| self.at(i) == b as u16)) { i += 1 }
        i
    }
    /// ASCII text of `[i, j)`, or empty when it contains non-ASCII units.
    pub(crate) fn ascii(&self, i: usize, j: usize) -> String {
        let slice = &self.0[i.min(self.0.len())..j.min(self.0.len())];
        if slice.iter().any(|&u| u >= 128) { return String::new() }
        slice.iter().map(|&u| u as u8 as char).collect()
    }
    pub(crate) fn find(&self, mut i: usize, end: usize, needle: &str) -> Option<usize> {
        while i < end {
            if self.starts(i, needle) { return Some(i) }
            i += 1;
        }
        None
    }
    pub(crate) fn number_end(&self, i: usize, end: usize) -> usize {
        let mut j = i;
        if self.is(j, '0') && matches!(self.at(j + 1) as u8 | 0x20, b'x' | b'b' | b'o') && self.at(j + 1) < 128 {
            j += 2;
            while j < end && (is_ident_part(self.at(j))) { j += 1 }
            return j;
        }
        while j < end {
            let c = self.at(j);
            if is_digit(c) || c == '_' as u16 { j += 1 }
            else if c == '.' as u16 && is_digit(self.at(j + 1)) { j += 1 }
            else if (c == 'e' as u16 || c == 'E' as u16) && (is_digit(self.at(j + 1)) || ((self.is(j + 1, '+') || self.is(j + 1, '-')) && is_digit(self.at(j + 2)))) { j += 2 }
            else { break }
        }
        // Type suffixes such as 10L, 1.5f, 3u32, 2n.
        while j < end && is_ident_part(self.at(j)) && self.at(j) < 128 { j += 1 }
        j
    }
}

#[inline] pub(crate) fn is_space(u: u16) -> bool { matches!(u, 0x20 | 0x09 | 0x0A | 0x0D | 0x0C | 0xA0 | 0x3000 | 0xFEFF) }
#[inline] pub(crate) fn is_digit(u: u16) -> bool { (b'0' as u16..=b'9' as u16).contains(&u) }
#[inline] pub(crate) fn is_ident_start(u: u16) -> bool {
    (u >= 'a' as u16 && u <= 'z' as u16) || (u >= 'A' as u16 && u <= 'Z' as u16) || u == '_' as u16 || (u >= 0x80 && !is_space(u))
}
#[inline] pub(crate) fn is_ident_part(u: u16) -> bool { is_ident_start(u) || is_digit(u) }
#[inline] pub(crate) fn is_upper(u: u16) -> bool { u >= 'A' as u16 && u <= 'Z' as u16 }

/// Collects tokens in source order, dropping overlaps and merging neighbours.
#[derive(Default)]
pub(crate) struct Out {
    tokens: Vec<Token>,
    cursor: usize,
}

impl Out {
    pub(crate) fn push(&mut self, start: usize, end: usize, kind: Kind) {
        let start = start.max(self.cursor);
        if end <= start { return }
        self.cursor = end;
        if kind == Kind::None { return }
        if let Some(last) = self.tokens.last_mut() {
            if last.kind == kind && (last.start + last.len) as usize == start {
                last.len += (end - start) as u32;
                return;
            }
        }
        self.tokens.push(Token { start: start as u32, len: (end - start) as u32, kind });
    }
    pub(crate) fn finish(self) -> Vec<Token> { self.tokens }
}

#[cfg(test)]
mod tests;

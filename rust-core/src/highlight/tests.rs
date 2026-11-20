use super::{highlight, normalize_language, Kind};

fn utf16(s: &str) -> Vec<u16> { s.encode_utf16().collect() }

/// (text, kind) pairs for every token.
fn tokens(code: &str, lang: &str) -> Vec<(String, Kind)> {
    let units = utf16(code);
    highlight(&units, lang).iter().map(|t| {
        (String::from_utf16_lossy(&units[t.start as usize..(t.start + t.len) as usize]), t.kind)
    }).collect()
}

/// Kind of the `nth` (0-based) token whose text equals `text`, ignoring neighbours merged into it.
fn kind_of(code: &str, lang: &str, text: &str, nth: usize) -> Option<Kind> {
    let units = utf16(code);
    let toks = highlight(&units, lang);
    let needle = utf16(text);
    let mut seen = 0;
    let mut from = 0;
    while let Some(pos) = units[from..].windows(needle.len()).position(|w| w == needle.as_slice()) {
        let at = from + pos;
        let boundary_before = at == 0 || !super::is_ident_part(units[at - 1]) || !super::is_ident_part(needle[0]);
        let boundary_after = at + needle.len() >= units.len() || !super::is_ident_part(units[at + needle.len()]) || !super::is_ident_part(*needle.last().unwrap());
        if boundary_before && boundary_after {
            if seen == nth {
                return Some(toks.iter().find(|t| (t.start as usize) <= at && at < (t.start + t.len) as usize).map(|t| t.kind).unwrap_or(Kind::None));
            }
            seen += 1;
        }
        from = at + 1;
    }
    None
}

#[track_caller]
fn expect(code: &str, lang: &str, cases: &[(&str, usize, Kind)]) {
    for &(text, nth, kind) in cases {
        let got = kind_of(code, lang, text, nth);
        assert_eq!(got, Some(kind), "{lang}: `{text}` #{nth} in:\n{code}\ntokens: {:?}", tokens(code, lang));
    }
}

#[test]
fn tokens_are_sorted_and_disjoint() {
    for (code, lang) in [
        ("const a = `x ${b + `y ${c}`}` // done", "ts"),
        ("fun f() = \"$a ${b.c()}\"", "kt"),
        ("<div className={a ? <b/> : null}>{list.map(x => <Item key={x}/>)}</div>", "tsx"),
        ("# T\n```rust\nfn main() {}\n```\n", "md"),
        ("<template><a :href=\"url\">{{ name }}</a></template><script lang=\"ts\">let x: number = 1</script>", "vue"),
    ] {
        let units = utf16(code);
        let toks = highlight(&units, lang);
        let mut cursor = 0;
        for t in &toks {
            assert!(t.start >= cursor, "{lang}: overlap at {}", t.start);
            assert_ne!(t.kind, Kind::None);
            cursor = t.start + t.len;
        }
        assert!(cursor as usize <= units.len());
    }
}

#[test]
fn language_names() {
    assert_eq!(normalize_language("kt"), Some("kotlin"));
    assert_eq!(normalize_language("src/App.tsx"), Some("tsx"));
    assert_eq!(normalize_language("build.gradle.kts"), Some("kotlin"));
    assert_eq!(normalize_language("build.gradle"), Some("groovy"));
    assert_eq!(normalize_language("Dockerfile"), Some("dockerfile"));
    assert_eq!(normalize_language("Makefile"), Some("makefile"));
    assert_eq!(normalize_language(".env"), Some("shell"));
    assert_eq!(normalize_language("Cargo.toml"), Some("toml"));
    assert_eq!(normalize_language("README"), None);
}

#[test]
fn kotlin_declarations_and_interpolation() {
    let code = "package demo.app\n\nimport kotlinx.coroutines.flow.Flow\n\n/** Greets. */\n@Composable\ndata class Greeting(val name: String, val count: Int = 1) : Base() {\n    fun render(prefix: String?): String = \"Hello, $name! ${count + 1}\"\n}\n";
    expect(code, "kt", &[
        ("package", 0, Kind::KeywordImport),
        ("demo", 0, Kind::Namespace),
        ("Flow", 0, Kind::Type),
        ("/** Greets. */", 0, Kind::CommentDoc),
        ("@Composable", 0, Kind::Attribute),
        ("data", 0, Kind::KeywordDeclaration),
        ("Greeting", 0, Kind::Type),
        ("name", 0, Kind::VariableParameter),
        ("String", 0, Kind::TypeBuiltin),
        ("Base", 0, Kind::Type),
        ("render", 0, Kind::FunctionDefinition),
        ("prefix", 0, Kind::VariableParameter),
        ("$", 0, Kind::PunctuationSpecial),
        ("${", 0, Kind::PunctuationSpecial),
        ("count", 1, Kind::Variable),
        ("1", 1, Kind::Number),
    ]);
}

#[test]
fn multiline_constructs_keep_state() {
    let code = "val a = 1 /* start\n  still comment fun x()\n end */ val b = \"\"\"\nraw ${a}\n\"\"\"";
    expect(code, "kt", &[("still", 0, Kind::Comment), ("fun", 0, Kind::Comment), ("raw", 0, Kind::String), ("a", 1, Kind::Variable)]);
    let py = "def f(x: int) -> str:\n    \"\"\"Doc\n    def not_code\n    \"\"\"\n    return f\"{x!r}\"\n";
    expect(py, "py", &[("f", 0, Kind::FunctionDefinition), ("x", 0, Kind::VariableParameter), ("int", 0, Kind::TypeBuiltin), ("str", 0, Kind::TypeBuiltin), ("not_code", 0, Kind::String), ("x", 1, Kind::Variable)]);
}

#[test]
fn typescript_types_and_calls() {
    let code = "import { useState } from 'react'\nexport interface Props extends Base<T> { title: string }\nexport function App({ title }: Props): JSX.Element {\n  const [n, setN] = useState<number>(0)\n  return n > 1 ? title.toUpperCase() : null\n}\n";
    expect(code, "ts", &[
        ("import", 0, Kind::KeywordImport),
        ("useState", 0, Kind::Namespace),
        ("'react'", 0, Kind::String),
        ("Props", 0, Kind::Type),
        ("Base", 0, Kind::Type),
        ("App", 0, Kind::FunctionDefinition),
        ("Props", 1, Kind::Type),
        ("useState", 1, Kind::Function),
        ("number", 0, Kind::TypeBuiltin),
        ("toUpperCase", 0, Kind::FunctionMethod),
        ("null", 0, Kind::ConstantBuiltin),
    ]);
}

#[test]
fn tsx_elements() {
    let code = "const view = <Card title=\"x\" onClick={() => go(1)}>\n  <span className=\"a\">{label}</span>\n</Card>\n";
    expect(code, "tsx", &[
        ("Card", 0, Kind::TagComponent),
        ("title", 0, Kind::Attribute),
        ("\"x\"", 0, Kind::String),
        ("go", 0, Kind::Function),
        ("span", 0, Kind::Tag),
        ("className", 0, Kind::Attribute),
        ("Card", 1, Kind::TagComponent),
    ]);
    // A comparison is not markup.
    expect("if (a < b && c > d) {}", "tsx", &[("b", 0, Kind::Variable)]);
}

#[test]
fn javascript_regex_and_templates() {
    let code = "const re = /a[/]b\\//g; const s = `n=${a / 2}`; x = y / z";
    expect(code, "js", &[("/a[/]b\\//g", 0, Kind::StringRegex), ("2", 0, Kind::Number), ("z", 0, Kind::Variable)]);
}

#[test]
fn swift_signatures() {
    let code = "import SwiftUI\n\nstruct Card: View {\n    @State private var count = 0\n    func render(_ name: String, times: Int) -> some View { Text(\"Hi \\(name)\") }\n}\n";
    expect(code, "swift", &[
        ("SwiftUI", 0, Kind::Type),
        ("Card", 0, Kind::Type),
        ("View", 0, Kind::Type),
        ("@State", 0, Kind::Attribute),
        ("render", 0, Kind::FunctionDefinition),
        ("times", 0, Kind::VariableParameter),
        ("Int", 0, Kind::TypeBuiltin),
        ("Text", 0, Kind::Constructor),
        ("\\(", 0, Kind::PunctuationSpecial),
    ]);
}

#[test]
fn rust_items() {
    let code = "#[derive(Debug)]\npub struct Point<'a> { name: &'a str }\nimpl<'a> Point<'a> {\n    /// Doc\n    pub fn new(name: &'a str) -> Self { println!(\"{}\", r#\"raw\"#); Self { name } }\n}\n";
    expect(code, "rs", &[
        ("#[derive(Debug)]", 0, Kind::Attribute),
        ("Point", 0, Kind::Type),
        ("'a", 0, Kind::Label),
        ("str", 0, Kind::TypeBuiltin),
        ("/// Doc", 0, Kind::CommentDoc),
        ("new", 0, Kind::FunctionDefinition),
        ("name", 1, Kind::VariableParameter),
        ("Self", 0, Kind::VariableSpecial),
        ("println!", 0, Kind::Function),
        ("r#\"raw\"#", 0, Kind::String),
    ]);
}

#[test]
fn go_and_java_parameter_styles() {
    let go = "package main\n\nfunc (s *Server) Handle(w http.ResponseWriter, n int) error {\n\treturn nil\n}\n";
    expect(go, "go", &[("Handle", 0, Kind::FunctionDefinition), ("w", 0, Kind::VariableParameter), ("n", 0, Kind::VariableParameter), ("int", 0, Kind::TypeBuiltin), ("error", 0, Kind::TypeBuiltin)]);
    let java = "public class Main {\n  @Override\n  public List<String> names(int count, String prefix) { return new ArrayList<>(); }\n}\n";
    expect(java, "java", &[("Main", 0, Kind::Type), ("@Override", 0, Kind::Attribute), ("List", 0, Kind::TypeBuiltin), ("names", 0, Kind::FunctionDefinition), ("count", 0, Kind::VariableParameter), ("prefix", 0, Kind::VariableParameter), ("ArrayList", 0, Kind::Type)]);
}

#[test]
fn data_formats() {
    expect("{\"name\": \"x\", \"n\": 1, \"ok\": true, \"v\": null}", "json", &[("\"name\"", 0, Kind::PropertyKey), ("\"x\"", 0, Kind::String), ("1", 0, Kind::Number), ("true", 0, Kind::Boolean), ("null", 0, Kind::ConstantBuiltin)]);
    expect("name: demo # c\nlist:\n  - &a 1\n  - text here\nblock: |\n  line one\n  key: inside\nnext: true\n", "yaml", &[
        ("name", 0, Kind::PropertyKey), ("demo", 0, Kind::String), ("# c", 0, Kind::Comment), ("-", 0, Kind::PunctuationListMarker),
        ("&a", 0, Kind::Label), ("text here", 0, Kind::String), ("key: inside", 0, Kind::String), ("next", 0, Kind::PropertyKey), ("true", 0, Kind::Boolean),
    ]);
    expect("[package]\nname = \"demo\"\nversion = 2\n[dependencies.serde]\nfeatures = [\"derive\"]\n", "toml", &[("package", 0, Kind::Namespace), ("name", 0, Kind::PropertyKey), ("2", 0, Kind::Number), ("dependencies.serde", 0, Kind::Namespace)]);
    expect("export API_URL=https://x # note\n", ".env", &[("export", 0, Kind::KeywordDeclaration), ("API_URL", 0, Kind::Variable)]);
}

#[test]
fn markdown_embeds_fenced_code() {
    let code = "# Title\n\nSome **bold** and `code` with [link](https://a.b).\n\n```kotlin\nfun main() = println(\"hi\")\n```\n- item\n";
    expect(code, "md", &[
        ("Title", 0, Kind::Title),
        ("**bold**", 0, Kind::EmphasisStrong),
        ("`code`", 0, Kind::TextLiteral),
        ("link", 0, Kind::LinkText),
        ("https://a.b", 0, Kind::LinkUri),
        ("kotlin", 0, Kind::Label),
        ("main", 0, Kind::FunctionDefinition),
        ("\"hi\"", 0, Kind::String),
        ("-", 0, Kind::PunctuationListMarker),
    ]);
}

#[test]
fn markup_and_styles() {
    let html = "<!DOCTYPE html>\n<div class=\"a\" id=x>&amp;<script>const n = 1</script><style>.a { color: #fff; margin: 4px }</style></div>";
    expect(html, "html", &[("div", 0, Kind::Tag), ("class", 0, Kind::Attribute), ("\"a\"", 0, Kind::String), ("&amp;", 0, Kind::ConstantBuiltin), ("const", 0, Kind::KeywordDeclaration), (".a", 0, Kind::SelectorClass), ("color", 0, Kind::Property), ("#fff", 0, Kind::Constant), ("margin", 0, Kind::Property)]);
    let scss = "$gap: 4px;\n.card:hover > .title { padding: $gap; &.active { color: red !important; } }\n";
    expect(scss, "scss", &[("$gap", 0, Kind::VariableSpecial), (".card", 0, Kind::SelectorClass), (":hover", 0, Kind::SelectorPseudo), ("padding", 0, Kind::Property), ("!important", 0, Kind::Keyword)]);
    let vue = "<template><a :href=\"base + path\" @click=\"go()\">{{ name }}</a></template>";
    expect(vue, "vue", &[(":href", 0, Kind::Attribute), ("go", 0, Kind::Function), ("name", 0, Kind::Variable), ("{{", 0, Kind::PunctuationSpecial)]);
}

#[test]
fn shell_and_build_files() {
    let sh = "#!/bin/bash\nexport NAME=\"world\"\nif [ -n \"$NAME\" ]; then\n  echo \"Hello ${NAME}\" | grep -q x\nfi\ncat <<EOF\nbody $x\nEOF\n";
    expect(sh, "sh", &[("#!/bin/bash", 0, Kind::Comment), ("export", 0, Kind::KeywordDeclaration), ("NAME", 0, Kind::Variable), ("if", 0, Kind::KeywordControl), ("-n", 0, Kind::Attribute), ("$NAME", 0, Kind::VariableSpecial), ("echo", 0, Kind::Function), ("grep", 0, Kind::Function), ("-q", 0, Kind::Attribute), ("body", 0, Kind::String), ("EOF", 1, Kind::Label)]);
    let docker = "FROM node:20 AS build\nENV PORT=8080\nRUN npm ci && npm run build\n";
    expect(docker, "Dockerfile", &[("FROM", 0, Kind::Keyword), ("node:20", 0, Kind::String), ("build", 0, Kind::Label), ("PORT", 0, Kind::Variable), ("npm", 0, Kind::Function)]);
    let make = "CC := gcc\n\nbuild: main.o\n\t$(CC) -o app main.o\n";
    expect(make, "Makefile", &[("CC", 0, Kind::Variable), ("build", 0, Kind::FunctionDefinition)]);
}

#[test]
fn sql_is_case_insensitive() {
    expect("SELECT id, COUNT(*) FROM users WHERE name LIKE 'a%' -- note", "sql", &[("SELECT", 0, Kind::Keyword), ("COUNT", 0, Kind::Function), ("LIKE", 0, Kind::KeywordOperator), ("'a%'", 0, Kind::String), ("-- note", 0, Kind::Comment)]);
}

#[test]
fn hostile_input_is_bounded() {
    let deep = "${".repeat(5000) + &"}".repeat(5000);
    let units = utf16(&format!("`{deep}`"));
    let _ = highlight(&units, "js");
    let lone = [0xD800u16, 'a' as u16, 0xDC00, '"' as u16];
    let _ = highlight(&lone, "kt");
    let tags = "<a>".repeat(2000);
    let _ = highlight(&utf16(&tags), "tsx");
}

#[test]
fn c_abi_round_trip() {
    use crate::ffi::{smr_buffer_free, smr_highlight_language, smr_highlight_utf16, SmrBuffer};
    let code = utf16("val x = 1");
    let mut buffer = SmrBuffer::default();
    let status = unsafe { smr_highlight_utf16(code.as_ptr(), code.len(), b"kt".as_ptr(), 2, &mut buffer) };
    assert_eq!(status, 0);
    let bytes = unsafe { std::slice::from_raw_parts(buffer.data, buffer.len) }.to_vec();
    assert_eq!(&bytes[..4], b"SMH1");
    let count = u32::from_le_bytes(bytes[4..8].try_into().unwrap());
    assert_eq!(count as usize, highlight(&code, "kt").len());
    assert_eq!(u32::from_le_bytes(bytes[16..20].try_into().unwrap()), Kind::KeywordDeclaration as u32);
    unsafe { smr_buffer_free(&mut buffer) };
    let mut name = SmrBuffer::default();
    assert_eq!(unsafe { smr_highlight_language(b"App.tsx".as_ptr(), 7, &mut name) }, 0);
    assert_eq!(unsafe { std::slice::from_raw_parts(name.data, name.len) }, b"tsx");
    unsafe { smr_buffer_free(&mut name) };
}

#[test]
fn large_input_is_fast() {
    let unit = "fun greet(name: String): String {\n    val x = \"Hello, ${name}!\" // c\n    return x.uppercase()\n}\n";
    let code = utf16(&unit.repeat(4000));
    let started = std::time::Instant::now();
    let tokens = highlight(&code, "kt");
    let elapsed = started.elapsed();
    assert!(tokens.len() > 50_000);
    assert!(elapsed.as_millis() < 2_000, "{} units took {elapsed:?}", code.len());
}

fn line_text(line: &super::Line) -> String { String::from_utf16_lossy(&line.text) }
fn line_kind(line: &super::Line, text: &str) -> Option<Kind> {
    let units = &line.text;
    let needle = utf16(text);
    let at = units.windows(needle.len()).position(|w| w == needle.as_slice())? as u32;
    Some(line.tokens.iter().find(|t| t.start <= at && at < t.start + t.len).map(|t| t.kind).unwrap_or(Kind::None))
}

#[test]
fn lines_keep_multiline_state_and_expand_tabs() {
    let code = utf16("val a = 1 /* open\n\tstill */ val b\n\"\"\"x\nmore\"\"\"\n");
    let lines = super::highlight_lines(&code, "kt", 4);
    assert_eq!(lines.len(), 4);
    assert_eq!(line_text(&lines[1]), "    still */ val b");
    assert_eq!(line_kind(&lines[1], "still"), Some(Kind::Comment));
    assert_eq!(line_kind(&lines[1], "val"), Some(Kind::KeywordDeclaration));
    assert_eq!(line_kind(&lines[3], "more"), Some(Kind::String));
}

#[test]
fn diff_rows_numbers_sides_and_word_changes() {
    let patch = "diff --git a/A.kt b/A.kt\nindex 1..2 100644\n--- a/A.kt\n+++ b/A.kt\n@@ -10,4 +10,4 @@ class A {\n /* start\n-   old */ val x = 1\n+   new */ val x = 2\n \tfun f() = x\n\\ No newline at end of file\n";
    let rows = super::parse_diff(&utf16(patch), "kt", 4);
    use super::RowKind::*;
    assert_eq!(rows.iter().map(|r| r.kind).collect::<Vec<_>>(), vec![Hunk, Context, Removed, Added, Context, Note]);
    assert_eq!(line_text(&rows[0].line), "@@ -10,4 +10,4 @@ class A {");
    assert_eq!(rows.iter().map(|r| r.number).collect::<Vec<_>>(), vec![None, Some(10), Some(11), Some(11), Some(12), None]);
    // The comment opened on a context line continues on both sides.
    assert_eq!(line_kind(&rows[2].line, "old"), Some(Kind::Comment));
    assert_eq!(line_kind(&rows[3].line, "new"), Some(Kind::Comment));
    assert_eq!(line_kind(&rows[3].line, "val"), Some(Kind::KeywordDeclaration));
    assert_eq!(line_text(&rows[4].line), "    fun f() = x");
    assert_eq!(line_kind(&rows[4].line, "f("), Some(Kind::FunctionDefinition));
    // Word-level change covers the differing middle only.
    let (s, l) = rows[3].changed.unwrap();
    assert_eq!(String::from_utf16_lossy(&rows[3].line.text[s as usize..(s + l) as usize]), "new */ val x = 2");
    let (s, l) = rows[2].changed.unwrap();
    assert_eq!(String::from_utf16_lossy(&rows[2].line.text[s as usize..(s + l) as usize]), "old */ val x = 1");
}

#[test]
fn diff_word_change_is_minimal_for_small_edits() {
    let rows = super::parse_diff(&utf16("@@ -1 +1 @@\n-let total = price * 2\n+let total = price * 3\n"), "js", 0);
    let (s, l) = rows[2].changed.unwrap();
    assert_eq!(String::from_utf16_lossy(&rows[2].line.text[s as usize..(s + l) as usize]), "3");
}

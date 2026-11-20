use smooth_markdown_rust::ast::{utf16_len, Kind, Node, Options, Reference, References};
use smooth_markdown_rust::html;
use smooth_markdown_rust::inline::{decode_text, normalize_reference, parse};
fn render(source: &str, gfm: bool) -> String {
    let mut n = Node::new(Kind::Paragraph, source, 0, utf16_len(source));
    n.children = parse(
        source,
        0,
        &References::new(),
        Options {
            gfm,
            extensions: false,
        },
    );
    html::render(&n)
}
#[test]
fn nested_emphasis_and_utf16_ranges() {
    let nodes = parse("😀 ***hello***", 17, &References::new(), Options::default());
    assert_eq!(nodes[0].span.start, 17);
    assert_eq!(nodes[0].span.len, 3);
    assert_eq!(nodes[1].kind, Kind::Emphasis);
    assert_eq!(nodes[1].span.start, 20);
    assert_eq!(nodes[1].span.len, 11);
    assert_eq!(nodes[1].children[0].kind, Kind::Strong);
    assert_eq!(nodes[1].children[0].children[0].span.start, 23);
}
#[test]
fn entities_escapes_and_invalid_scalar_values() {
    assert_eq!(
        decode_text(r"\* &NotEqualTilde; &#x1F600; &#0; &#xD800; &#1114112; &unknown;"),
        "* ≂̸ 😀 � � � &unknown;"
    );
    assert_eq!(decode_text(r"\&amp; &amp;lt;"), "&amp; &lt;");
    assert_eq!(decode_text("&NewLine;&Tab;&fjlig;"), "\n\tfj");
}
#[test]
fn code_span_preserves_literals_and_normalizes_newlines() {
    assert_eq!(
        render("`` ` hi &amp;\r\n ``", false),
        "<p><code>` hi &amp;amp; </code></p>\n"
    );
    assert_eq!(
        render("`  ` and ` a `", false),
        "<p><code>  </code> and <code>a</code></p>\n"
    );
}
#[test]
fn rule_of_three_intraword_and_unicode_flanking() {
    assert_eq!(render("foo_bar_baz", false), "<p>foo_bar_baz</p>\n");
    assert_eq!(
        render("***foo** bar*", false),
        "<p><em><strong>foo</strong> bar</em></p>\n"
    );
    assert_eq!(render("a*😀*b", false), "<p>a*😀*b</p>\n");
    assert_eq!(render("*😀*", false), "<p><em>😀</em></p>\n");
}
#[test]
fn balanced_destination_title_and_nested_image() {
    assert_eq!(
        render("[x](a(b)c \"ti&amp;tle\")", false),
        "<p><a href=\"a(b)c\" title=\"ti&amp;tle\">x</a></p>\n"
    );
    assert_eq!(
        render("[![a *b*](img)](url)", false),
        "<p><a href=\"url\"><img src=\"img\" alt=\"a b\" /></a></p>\n"
    );
    assert_eq!(
        render("[a [b](u)](v)", false),
        "<p>[a <a href=\"u\">b</a>](v)</p>\n"
    );
}
#[test]
fn full_collapsed_and_shortcut_references() {
    let mut refs = References::new();
    refs.insert(
        normalize_reference("Straße  TEST"),
        Reference {
            destination: "url".into(),
            title: Some("Title".into()),
        },
    );
    for source in ["[x][STRASSE test]", "[Straße test][]", "[Straße test]"] {
        let nodes = parse(source, 6, &refs, Options::default());
        assert_eq!(nodes.len(), 1);
        assert_eq!(nodes[0].kind, Kind::Link);
        assert_eq!(nodes[0].destination, "url");
        assert_eq!(nodes[0].span.start, 6);
    }
}
#[test]
fn angle_autolinks_use_literal_text_without_entity_decoding() {
    assert_eq!(render("<https://x.test/?a&copy;> <a@b.test>",false),"<p><a href=\"https://x.test/?a&amp;copy;\">https://x.test/?a&amp;copy;</a> <a href=\"mailto:a@b.test\">a@b.test</a></p>\n");
}
#[test]
fn gfm_autolink_trims_entity_suffix_and_unbalanced_parentheses() {
    assert_eq!(
        render("www.google.com/q=x&hl;", true),
        "<p><a href=\"http://www.google.com/q=x\">www.google.com/q=x</a>&amp;hl;</p>\n"
    );
    assert_eq!(
        render("(www.test.com/a(b)))", true),
        "<p>(<a href=\"http://www.test.com/a(b)\">www.test.com/a(b)</a>))</p>\n"
    );
    assert_eq!(
        render("a.b-c_d@a.b- a.b-c_d@a.b", true),
        "<p>a.b-c_d@a.b- <a href=\"mailto:a.b-c_d@a.b\">a.b-c_d@a.b</a></p>\n"
    );
}
#[test]
fn html_scanner_accepts_attributes_and_retains_invalid_tags_as_text() {
    assert_eq!(
        render("a <x a='😀' b=foo> c", false),
        "<p>a <x a='😀' b=foo> c</p>\n"
    );
    assert_eq!(render("a <x a=> c", false), "<p>a &lt;x a=&gt; c</p>\n");
    assert_eq!(
        render("a <!-- hi --> b <![CDATA[😀]]> c", false),
        "<p>a <!-- hi --> b <![CDATA[😀]]> c</p>\n"
    );
}
#[test]
fn hard_soft_crlf_and_backslash_break_spans() {
    let nodes = parse(
        "😀  \r\n  x\\\n\ty",
        3,
        &References::new(),
        Options::default(),
    );
    assert_eq!(nodes[1].kind, Kind::HardBreak);
    assert_eq!(nodes[1].span.start, 5);
    assert_eq!(nodes[1].span.len, 6);
    assert_eq!(nodes[3].kind, Kind::HardBreak);
    assert_eq!(nodes[3].span.start, 12);
    assert_eq!(nodes[3].span.len, 3);
}
#[test]
fn extension_options_gate_math_and_footnotes() {
    let s = "$x$ [^note] ~~gone~~";
    let ext = parse(s, 0, &References::new(), Options::default());
    assert!(ext.iter().any(|n| n.kind == Kind::InlineMath));
    assert!(ext.iter().any(|n| n.kind == Kind::FootnoteReference));
    assert!(ext.iter().any(|n| n.kind == Kind::Strikethrough));
    let core = parse(
        s,
        0,
        &References::new(),
        Options {
            gfm: false,
            extensions: false,
        },
    );
    assert!(core.iter().all(|n| n.kind == Kind::Text));
}
#[test]
fn adversarial_nested_images_have_bounded_recursion() {
    let s = format!("{}x{}", "![".repeat(300), "](url)".repeat(300));
    let nodes = parse(&s, 0, &References::new(), Options::default());
    assert!(!nodes.is_empty());
    assert_eq!(nodes[0].span.start, 0);
    assert_eq!(nodes[0].span.len, utf16_len(&s));
    fn depth(n: &Node) -> usize {
        1 + n.children.iter().map(depth).max().unwrap_or(0)
    }
    assert!(depth(&nodes[0]) <= 130);
}
#[test]
fn strikethrough_delimiters_respect_code_and_whitespace() {
    assert_eq!(
        render("~~a `~~` b~~", true),
        "<p><del>a <code>~~</code> b</del></p>\n"
    );
    assert_eq!(
        render("~~ a~~ ~~a ~~ ~~~a~~~", true),
        "<p>~~ a~~ ~~a ~~ ~~~a~~~</p>\n"
    );
    assert_eq!(
        render("~~**a**~~", true),
        "<p><del><strong>a</strong></del></p>\n"
    );
}

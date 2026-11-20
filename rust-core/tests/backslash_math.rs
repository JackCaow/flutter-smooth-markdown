use smooth_markdown_rust::{ast::{Kind, Node, Options}, parse, stream::Session};
fn math<'a>(node: &'a Node, kind: Kind) -> Vec<&'a Node> {
    let mut found = if node.kind == kind { vec![node] } else { vec![] };
    for child in &node.children { found.extend(math(child, kind)); }
    found
}
#[test]
fn delimiters_preserve_literals_and_utf16_ranges() {
    let source = "😀 Math \\(x_1\\) and $y_2$\n\n\\[\n\\frac{x}{y}\n\\]\n";
    let root = parse(source, Options::default());
    let inline = math(&root, Kind::InlineMath);
    assert_eq!(inline.len(), 2);
    assert_eq!(inline[0].source, r"\(x_1\)");
    assert_eq!(inline[0].span.start, 8);
    assert_eq!(inline[0].span.len, 7);
    assert_eq!(inline[0].literal.as_deref(), Some("x_1"));
    assert_eq!(math(&root, Kind::BlockMath)[0].literal.as_deref(), Some(r"\frac{x}{y}"));
}
#[test]
fn escapes_code_links_and_disabled_extensions() {
    let source = r"`\(code\)` \\(escaped\) \(open [ref][id]";
    let root = parse(source, Options::default());
    assert!(math(&root, Kind::InlineMath).is_empty());
    assert!(math(&parse("```\n\\[x\\]\n```", Options::default()), Kind::BlockMath).is_empty());
    let disabled = parse(r"\(x\) $y$", Options { gfm: true, extensions: false });
    assert!(math(&disabled, Kind::InlineMath).is_empty());
    let linked = parse("[\\(x\\)][id]\n\n[id]: /path", Options::default());
    assert_eq!(math(&linked, Kind::Link)[0].destination, "/path");
    assert_eq!(math(&linked, Kind::InlineMath)[0].literal.as_deref(), Some("x"));
    let escaped_close = parse(r"\(a\\)b\)", Options::default());
    assert_eq!(math(&escaped_close, Kind::InlineMath)[0].literal.as_deref(), Some(r"a\\)b"));
}
#[test]
fn every_stream_prefix_matches_batch_including_unclosed_blocks_and_references() {
    let source = "a\n\nb\n\nc\n\nMath \\(x\\) [link][ref]\n\n\\[\nx\n\ny\n\\]\n\n[ref]: /ok\n\nend";
    let mut session = Session::new(Options::default());
    let mut current = Node::new(Kind::Document, "", 0, 0);
    for end in source.char_indices().map(|(i,_)| i).chain(std::iter::once(source.len())) {
        let prefix = &source[..end];
        let delta = session.update(&prefix.encode_utf16().collect::<Vec<_>>());
        current.children.truncate(delta.retained_blocks);
        current.children.extend(delta.children);
        current.source = prefix.to_owned(); current.span.len = prefix.encode_utf16().count() as u32;
        assert_eq!(current, parse(prefix, Options::default()), "prefix {prefix:?}");
    }
}

#[test]
fn escaped_bracket_prose_and_closed_math_trailers_keep_their_source() {
    for source in [r"\[^escaped] and [^real]", r"\[ordinary] prose"] {
        let root = parse(source, Options::default());
        assert_eq!(root.children[0].kind, Kind::Paragraph);
        assert!(math(&root, Kind::BlockMath).is_empty());
    }
    for source in [r"\[x\] trailing", "\\[\nx\n\\] trailing"] {
        let root = parse(source, Options::default());
        assert_eq!(root.children.len(), 2);
        assert_eq!(root.children[0].kind, Kind::BlockMath);
        assert_eq!(root.children[0].literal.as_deref(), Some("x"));
        assert!(root.children[0].source.ends_with(r"\]"));
        assert_eq!(root.children[1].kind, Kind::Paragraph);
        assert_eq!(root.children[1].source, " trailing");
        assert_eq!(root.children[0].span.start + root.children[0].span.len, root.children[1].span.start);
    }
}

#[test]
fn every_prefix_keeps_bracket_prose_and_math_trailers_equivalent() {
    for source in [
        "a\n\nb\n\nc\n\n\\[^escaped] and [^real]\n\nend",
        "a\n\nb\n\nc\n\n\\[ordinary] prose\n\nend",
        "a\n\nb\n\nc\n\n\\[x\\] trailing\n\nend",
        "a\n\nb\n\nc\n\n\\[\nx[0]\n\n\\] trailing\n\nend",
        "a\n\nb\n\nc\n\n\\[x[0]\\] trailing\n\nend",
        "a\n\nb\n\nc\n\n\\[x[0]\n+1\n\\]",
        "a\n\nb\n\nc\n\n\\[x[0]",
    ] {
        let mut session = Session::new(Options::default());
        let mut current = Node::new(Kind::Document, "", 0, 0);
        for end in source.char_indices().map(|(i,_)| i).chain(std::iter::once(source.len())) {
            let prefix = &source[..end];
            let delta = session.update(&prefix.encode_utf16().collect::<Vec<_>>());
            current.children.truncate(delta.retained_blocks);
            current.children.extend(delta.children);
            current.source = prefix.to_owned(); current.span.len = prefix.encode_utf16().count() as u32;
            assert_eq!(current, parse(prefix, Options::default()), "prefix {prefix:?}");
        }
    }
}

#[test]
fn nested_array_on_opening_line_remains_math_closed_or_streaming() {
    for (source, literal) in [("\\[x[0]\n+1\n\\]", "x[0]\n+1"), (r"\[x[0]", "x[0]")] {
        let root = parse(source, Options::default());
        assert_eq!(root.children[0].kind, Kind::BlockMath);
        assert_eq!(root.children[0].literal.as_deref(), Some(literal));
    }
}

#[test]
fn indented_math_delimiters_remain_code() {
    let continued = parse("prose\n    \\[x\\]", Options::default());
    assert_eq!(continued.children.len(), 1);
    assert_eq!(continued.children[0].kind, Kind::Paragraph);
    for source in ["    \\[\\]\n", "\t\\[x\\]", "    $$x$$"] {
        let root = parse(source, Options::default());
        assert_eq!(root.children[0].kind, Kind::IndentedCode);
    }
}

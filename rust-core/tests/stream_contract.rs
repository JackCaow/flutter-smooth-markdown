use smooth_markdown_rust::{ast::{Kind, Node, Options}, parse, stream::Session};

fn apply(session: &mut Session, current: &mut Node, source: &str) -> usize {
    let delta = session.update(&source.encode_utf16().collect::<Vec<_>>());
    let retained = delta.retained_blocks;
    assert!(retained <= current.children.len());
    current.children.truncate(retained);
    current.children.extend(delta.children);
    current.source = source.to_owned();
    current.span.len = source.encode_utf16().count() as u32;
    retained
}

fn base64(value: &str) -> String {
    let mut bytes = Vec::new(); let mut pending = 0u32; let mut bits = 0;
    for ch in value.bytes() {
        let n = match ch { b'A'..=b'Z' => ch-b'A', b'a'..=b'z' => ch-b'a'+26,
            b'0'..=b'9' => ch-b'0'+52, b'+' => 62, b'/' => 63, b'=' => break, _ => continue };
        pending = (pending << 6) | u32::from(n); bits += 6;
        if bits >= 8 { bits -= 8; bytes.push((pending >> bits) as u8); }
    }
    String::from_utf8(bytes).unwrap()
}

#[test]
fn all_conformance_examples_match_batch_at_every_character_prefix() {
    for (fixture, gfm) in [(include_str!("fixtures/commonmark-0.31.2.tsv"), false),
                           (include_str!("fixtures/gfm-extensions.tsv"), true)] {
        for line in fixture.lines() {
            let fields: Vec<_> = line.split('\t').collect();
            let source = base64(fields[1]);
            let options = Options { gfm, extensions: false };
            let mut session = Session::new(options);
            let mut root = Node::new(Kind::Document, "", 0, 0);
            for end in source.char_indices().map(|(i,_)|i).chain(std::iter::once(source.len())) {
                let prefix = &source[..end];
                apply(&mut session, &mut root, prefix);
                assert_eq!(root, parse(prefix, options), "fixture {} prefix {:?}", fields[0], prefix);
            }
        }
    }
}

#[test]
fn extended_nested_tail_and_global_definition_changes_match_batch() {
    let sources = [
        "# 中文🙂\r\n\r\nOne **bold**.\r\n\r\n> quote\r\n> - [x] task\r\n\r\n$$\r\nx^2\r\n$$\r\n\r\nEnd[^a]\r\n\r\n[^a]: 中文\r\n    second line\r\n",
        "start\n\nfirst\n\nprior\n#plain\n\n```x`\n\n[link][a]\n\n> [a]: /url\n",
        "a\n\nb\n\nc\n\n- item\n\n  continued\n\n- next\n\n    code\n\n    more\n",
        "a\n\nb\n\nc\n\n<div>\ntext\n\nend\n",
        "a\n\nb\n\nc\n\n[inline](https://example.test)\n\n![image](image.png)\n",
    ];
    for source in sources {
        let options = Options::default(); let mut session = Session::new(options);
        let mut root = Node::new(Kind::Document, "", 0, 0);
        for end in source.char_indices().map(|(i,_)|i).chain(std::iter::once(source.len())) {
            let prefix = &source[..end]; apply(&mut session, &mut root, prefix);
            assert_eq!(root, parse(prefix, options), "prefix {prefix:?}");
        }
    }
}

#[test]
fn stable_prefix_is_retained_and_non_append_edits_reset() {
    let mut session = Session::new(Options::default());
    let mut root = Node::new(Kind::Document, "", 0, 0);
    apply(&mut session, &mut root, "one\n\ntwo\n\nthree\n\nfour\n");
    assert_eq!(apply(&mut session, &mut root, "one\n\ntwo\n\nthree\n\nfour\n\nfive"), 2);
    assert_eq!(root, parse(&root.source, Options::default()));
    assert_eq!(apply(&mut session, &mut root, "é\n\nx"), 0);
    assert_eq!(apply(&mut session, &mut root, "e\u{301}\n\nx"), 0);
    assert_eq!(root, parse(&root.source, Options::default()));
    assert_eq!(apply(&mut session, &mut root, ""), 0);
    assert!(root.children.is_empty());
}

#[test]
fn malformed_final_interrupt_rolls_back_the_preceding_block() {
    for (before, after) in [("a\n\nb\n\nprior\n#", "a\n\nb\n\nprior\n#plain"),
                            ("a\n\nb\n\nprior\n```", "a\n\nb\n\nprior\n```bad`info")] {
        let mut session = Session::new(Options::default());
        let mut root = Node::new(Kind::Document, "", 0, 0);
        apply(&mut session, &mut root, before); apply(&mut session, &mut root, after);
        assert_eq!(root, parse(after, Options::default()));
    }
}

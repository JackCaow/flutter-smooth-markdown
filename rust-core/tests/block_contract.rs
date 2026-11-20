use smooth_markdown_rust::{
    ast::{Kind, Node, Options},
    ffi, html, parse,
};

fn validate(node: &Node, units: &[u16]) {
    let a = node.span.start as usize;
    let b = node.span.end() as usize;
    assert!(
        a <= b && b <= units.len(),
        "invalid {:?} range {:?} in {:?}",
        node.kind,
        node.span,
        String::from_utf16_lossy(units)
    );
    assert_eq!(
        node.source,
        String::from_utf16(&units[a..b]).expect("surrogate boundary"),
        "{:?} at {:?}",
        node.kind,
        node.span
    );
    for child in &node.children {
        validate(child, units);
    }
}

#[test]
fn projected_multiline_inline_grammar_keeps_original_ranges() {
    let cases = [
        (
            "> *😀 first\r\n> second*\r\n",
            "<blockquote>\n<p><em>😀 first\nsecond</em></p>\n</blockquote>\n",
        ),
        (
            "- **first\n  second**\n",
            "<ul>\n<li><strong>first\nsecond</strong></li>\n</ul>\n",
        ),
        (
            "> `first\n> second`\n",
            "<blockquote>\n<p><code>first second</code></p>\n</blockquote>\n",
        ),
        (
            "> [first\n> second](/target)\n",
            "<blockquote>\n<p><a href=\"/target\">first\nsecond</a></p>\n</blockquote>\n",
        ),
        (
            "> \t# 😀 heading\n",
            "<blockquote>\n<h1>😀 heading</h1>\n</blockquote>\n",
        ),
        (
            ">\t- 😀 text\n",
            "<blockquote>\n<ul>\n<li>😀 text</li>\n</ul>\n</blockquote>\n",
        ),
        (
            "> *first\r> second*\r",
            "<blockquote>\n<p><em>first\nsecond</em></p>\n</blockquote>\n",
        ),
        (
            "# heading\r\r```\rcode\r```\r",
            "<h1>heading</h1>\n<pre><code>code\n</code></pre>\n",
        ),
    ];
    for (source, expected) in cases {
        let tree = parse(source, Options::default());
        assert_eq!(html::render(&tree), expected, "{source:?}");
        validate(&tree, &source.encode_utf16().collect::<Vec<_>>());
    }
}

#[test]
fn every_unfinished_container_and_reference_prefix_is_source_preserving() {
    let source = ">\t- **中🙂文\r\n>\t  continuation** [label][ref]\r\n>\r\n> [ref]: <https://example.com> \"标题\"\r\n\r\n| A | B |\r\n| :- | -: |\r\n| e\u{301} | `x\\|y` |\r\n\r\n- [x] finished\r\n\r\n[^note]: note\r\n    nested\r\n";
    for end in source
        .char_indices()
        .map(|(i, _)| i)
        .chain(std::iter::once(source.len()))
    {
        let prefix = &source[..end];
        let tree = parse(prefix, Options::default());
        validate(&tree, &prefix.encode_utf16().collect::<Vec<_>>());
    }
}

#[test]
fn deeply_nested_container_inputs_remain_bounded_through_c_abi() {
    for source in [
        format!("{}body\n", "> ".repeat(4096)),
        format!("{}body\n", "- ".repeat(4096)),
    ] {
        let tree = parse(&source, Options::default());
        validate(&tree, &source.encode_utf16().collect::<Vec<_>>());
        fn depth(node: &Node) -> usize {
            1 + node.children.iter().map(depth).max().unwrap_or(0)
        }
        assert!(depth(&tree) <= 260);
        fn raw(node: &Node) -> bool {
            node.kind == Kind::Raw || node.children.iter().any(raw)
        }
        assert!(raw(&tree));
        let units: Vec<u16> = source.encode_utf16().collect();
        let mut buffer = ffi::SmrBuffer::default();
        let status = unsafe { ffi::smr_parse_utf16(units.as_ptr(), units.len(), 3, &mut buffer) };
        // The C ABI may reject trees at its own stricter transport-depth limit.
        assert!(status == 0 || status == 2, "C ABI status {status}");
        unsafe {
            ffi::smr_buffer_free(&mut buffer);
        }
    }
}

/// Run `cargo test --release --test block_contract parser_and_c_abi_baseline -- --ignored --nocapture`.
/// Measures Rust parse and the full C ABI parse/copy/AST serialization/free path.
/// Swift/Kotlin AST decoding, JNI transitions and UI work are deliberately excluded.
#[test]
#[ignore = "local performance baseline; no machine-dependent pass threshold"]
fn parser_and_c_abi_baseline() {
    use std::{hint::black_box, time::Instant};
    let sample = "# Heading 中文🙂\n\nA **bold** paragraph with [link](https://example.com) and `code`.\n\n> Nested quote\n> - one\n> - two\n\n| A | B |\n| :- | -: |\n| x | y |\n\n```rust\nlet answer = 42;\n```\n\n";
    for target in [1024usize, 10 * 1024, 100 * 1024] {
        let source = sample.repeat(target.div_ceil(sample.len()));
        let units: Vec<u16> = source.encode_utf16().collect();
        let iterations = if target < 100 * 1024 { 100 } else { 20 };
        for _ in 0..3 {
            black_box(parse(&source, Options::default()));
        }
        let start = Instant::now();
        for _ in 0..iterations {
            black_box(parse(black_box(&source), Options::default()));
        }
        let parse_us = start.elapsed().as_secs_f64() * 1e6 / iterations as f64;
        let start = Instant::now();
        let mut output_bytes = 0;
        for _ in 0..iterations {
            let mut buffer = ffi::SmrBuffer::default();
            assert_eq!(
                unsafe { ffi::smr_parse_utf16(units.as_ptr(), units.len(), 3, &mut buffer) },
                0
            );
            output_bytes = black_box(buffer.len);
            unsafe {
                ffi::smr_buffer_free(&mut buffer);
            }
        }
        let ffi_us = start.elapsed().as_secs_f64() * 1e6 / iterations as f64;
        eprintln!("input_bytes={} utf16_units={} ast_wire_bytes={} parse_us={parse_us:.1} full_c_abi_us={ffi_us:.1} iterations={iterations}", source.len(), units.len(), output_bytes);
    }
}

#[test]
fn native_extensions_interrupt_paragraphs_and_keep_footnote_continuations() {
    let source = "Before\n$$E=mc^2$$\nAfter\n$$\n\\frac{a}{b}\n$$\n$$unclosed";
    let tree = parse(source, Options::default());
    assert_eq!(tree.children.iter().map(|n| n.kind).collect::<Vec<_>>(),
        [Kind::Paragraph, Kind::BlockMath, Kind::Paragraph, Kind::BlockMath, Kind::BlockMath]);
    assert_eq!(parse("[^a]: ", Options::default()).children[0].kind, Kind::Paragraph);
    let source = "Intro\n[^note]: First **bold** line\n    Second line\n\n    Third line\nAfter";
    let tree = parse(source, Options::default());
    assert_eq!(tree.children.iter().map(|n| n.kind).collect::<Vec<_>>(),
        [Kind::Paragraph, Kind::FootnoteDefinition, Kind::Paragraph]);
    assert!(tree.children[1].source.contains("Third line"));
    assert!(!parse("Before\n$$x$$", Options { gfm: false, extensions: false }).children.iter().any(|n| n.kind == Kind::BlockMath));
}

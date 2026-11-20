use smooth_markdown_rust::{ast::{Node, Options}, html, parse};

fn base64(value: &str) -> String {
    let mut bytes = Vec::new(); let mut pending = 0u32; let mut bits = 0;
    for ch in value.bytes() {
        let n = match ch { b'A'..=b'Z' => ch-b'A', b'a'..=b'z' => ch-b'a'+26,
            b'0'..=b'9' => ch-b'0'+52, b'+' => 62, b'/' => 63, b'=' => break, _ => continue };
        pending = (pending << 6) | u32::from(n); bits += 6;
        if bits >= 8 { bits -= 8; bytes.push((pending >> bits) as u8); }
    }
    String::from_utf8(bytes).expect("Fixture is UTF-8")
}
fn ranges(node: &Node, source: &[u16], errors: &mut Vec<String>, number: &str) {
    let start = node.span.start as usize; let end = node.span.end() as usize;
    if start > end || end > source.len() { errors.push(format!("{number}: {:?} invalid span {:?}", node.kind,node.span)); return; }
    let original = String::from_utf16(&source[start..end]).expect("Range must not split a surrogate pair");
    if original != node.source { errors.push(format!("{number}: {:?} source mismatch {:?}: original={original:?}, node={:?}", node.kind,node.span,node.source)); }
    for child in &node.children { ranges(child,source,errors,number); }
}
fn verify(fixtures: &str, expected_count: usize, gfm: bool) {
    let mut errors = Vec::new(); let mut count = 0;
    for line in fixtures.lines() {
        let fields: Vec<_> = line.split('\t').collect(); assert_eq!(fields.len(),3);
        count += 1;
        let source = base64(fields[1]); let expected = base64(fields[2]);
        let tree = parse(&source, Options { gfm, extensions: false });
        let actual = if gfm { html::render_gfm(&tree) } else { html::render(&tree) };
        if actual != expected { errors.push(format!("{}: source={source:?}\nexpected={expected:?}\nactual={actual:?}",fields[0])); }
        ranges(&tree,&source.encode_utf16().collect::<Vec<_>>(),&mut errors,fields[0]);
    }
    assert_eq!(count,expected_count);
    assert!(errors.is_empty(), "{} failures:\n{}", errors.len(),errors.iter().take(30).cloned().collect::<Vec<_>>().join("\n\n"));
}
#[test] fn commonmark_0312_all_652_examples() { verify(include_str!("fixtures/commonmark-0.31.2.tsv"),652,false); }
#[test] fn gfm_extension_examples() { verify(include_str!("fixtures/gfm-extensions.tsv"),24,true); }

#[test] fn unicode_and_unfinished_stream_prefixes_preserve_ranges() {
    let input = "# 中文 👨‍👩‍👧‍👦 e\u{301}\r\n\r\n> **加粗🙂** [链接](https://example.com)\r\n\r\n```rust\r\nlet a = 1;\r\n```\r\n";
    for end in input.char_indices().map(|(i,_)|i).chain(std::iter::once(input.len())) {
        let prefix = &input[..end]; let tree = parse(prefix, Options::default()); let mut errors = Vec::new();
        ranges(&tree,&prefix.encode_utf16().collect::<Vec<_>>(),&mut errors,"prefix");
        assert!(errors.is_empty(),"{errors:?}");
    }
}

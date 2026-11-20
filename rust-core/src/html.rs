use crate::ast::{Kind, Node};

pub fn escape(value: &str) -> String {
    let mut out = String::new();
    for c in value.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\0' => out.push('\u{fffd}'),
            _ => out.push(c),
        }
    }
    out
}
fn destination(value: &str) -> String {
    let mut out = String::new();
    for byte in value.as_bytes() {
        if byte.is_ascii_alphanumeric() || b"-._~:/?#@!$&'()*+,;=%".contains(byte) {
            out.push(*byte as char);
        } else {
            out.push_str(&format!("%{byte:02X}"));
        }
    }
    escape(&out)
}
pub fn plain_text(node: &Node) -> String {
    if let Some(literal) = &node.literal {
        return literal.clone();
    }
    match node.kind {
        Kind::Text | Kind::InlineCode => crate::inline::decode_text(&node.source),
        Kind::SoftBreak | Kind::HardBreak => "\n".into(),
        _ => node.children.iter().map(plain_text).collect(),
    }
}
pub fn render(node: &Node) -> String {
    render_with_options(node, 0)
}
pub fn render_with_options(node: &Node, options: u32) -> String {
    render_inner(node, node.tight.unwrap_or(false), options)
}
fn children(node: &Node, options: u32) -> String {
    node.children
        .iter()
        .map(|n| render_inner(n, n.tight.unwrap_or(false), options))
        .collect()
}
fn render_inner(node: &Node, tight: bool, options: u32) -> String {
    let title = node
        .title
        .as_ref()
        .map(|title| format!(" title=\"{}\"", escape(title)))
        .unwrap_or_default();
    match node.kind {
        Kind::Document | Kind::Custom => children(node, options),
        Kind::TableHead => format!("<thead>\n{}</thead>\n", children(node, options)),
        Kind::TableBody => {
            if node.children.is_empty() {
                String::new()
            } else {
                format!("<tbody>\n{}</tbody>\n", children(node, options))
            }
        }
        Kind::TableRow => {
            if options & 8 != 0 {
                children(node, options)
            } else {
                format!("<tr>\n{}</tr>\n", children(node, options))
            }
        }
        Kind::TableCell => {
            if options & 8 != 0 {
                return children(node, options);
            }
            let tag = if node.html_header { "th" } else { "td" };
            let alignment = node
                .alignments
                .first()
                .and_then(|v| v.as_ref())
                .map(|v| format!(" align=\"{}\"", escape(v)))
                .unwrap_or_default();
            format!("<{tag}{alignment}>{}</{tag}>\n", children(node, options))
        }
        Kind::TaskMarker => format!(
            "<input {}disabled=\"\" type=\"checkbox\"> ",
            if node.checked == Some(true) {
                "checked=\"\" "
            } else {
                ""
            }
        ),
        Kind::Text => escape(
            &node
                .literal
                .clone()
                .unwrap_or_else(|| crate::inline::decode_text(&node.source)),
        ),
        Kind::Paragraph => {
            let text = children(node, options);
            if tight {
                text
            } else {
                format!("<p>{text}</p>\n")
            }
        }
        Kind::Heading => {
            let level = node.html_number.unwrap_or(node.level as i64);
            format!("<h{level}>{}</h{level}>\n", children(node, options))
        }
        Kind::FencedCode | Kind::IndentedCode => {
            let language = node.info.split_whitespace().next().unwrap_or("");
            let attr = if node.kind == Kind::FencedCode && !language.is_empty() {
                format!(" class=\"language-{}\"", escape(language))
            } else {
                String::new()
            };
            format!(
                "<pre><code{attr}>{}</code></pre>\n",
                escape(node.literal.as_deref().unwrap_or(""))
            )
        }
        Kind::ThematicBreak => "<hr />\n".into(),
        Kind::Strong => format!("<strong>{}</strong>", children(node, options)),
        Kind::Emphasis => format!("<em>{}</em>", children(node, options)),
        Kind::Strikethrough => format!("<del>{}</del>", children(node, options)),
        Kind::InlineCode => format!(
            "<code>{}</code>",
            escape(node.literal.as_deref().unwrap_or(&node.source))
        ),
        Kind::SoftBreak => "\n".into(),
        Kind::HardBreak => "<br />\n".into(),
        Kind::InlineHtml => {
            let text = node.literal.as_deref().unwrap_or(&node.source);
            if options & 4 != 0 {
                escape(text)
            } else {
                text.to_owned()
            }
        }
        Kind::HtmlBlock => {
            let raw = node.literal.as_deref().unwrap_or(&node.source);
            let text = if options & 4 != 0 {
                escape(raw)
            } else {
                raw.to_owned()
            };
            format!("{text}{}", if text.ends_with('\n') { "" } else { "\n" })
        }
        Kind::Link => format!(
            "<a href=\"{}\"{title}>{}</a>",
            destination(&node.destination),
            children(node, options)
        ),
        Kind::Image => format!(
            "<img src=\"{}\" alt=\"{}\"{title} />",
            destination(&node.destination),
            escape(&plain_text(node))
        ),
        Kind::ReferenceDefinition => String::new(),
        Kind::BlockQuote => format!("<blockquote>\n{}</blockquote>\n", children(node, options)),
        Kind::List => {
            let tag = if node.ordered { "ol" } else { "ul" };
            let start = match node.html_number.or(node.list_start.map(i64::from)) {
                Some(start) if node.ordered && start != 1 => format!(" start=\"{start}\""),
                _ => String::new(),
            };
            let body: String = node
                .children
                .iter()
                .map(|n| render_inner(n, node.tight.unwrap_or(true), options))
                .collect();
            format!("<{tag}{start}>\n{body}</{tag}>\n")
        }
        Kind::ListItem => {
            let checkbox = node
                .checked
                .map(|checked| {
                    format!(
                        "<input {}disabled=\"\" type=\"checkbox\"> ",
                        if checked { "checked=\"\" " } else { "" }
                    )
                })
                .unwrap_or_default();
            if node.children.is_empty() {
                return format!("<li>{checkbox}</li>\n");
            }
            if !tight {
                let text = children(node, options);
                let body = if !checkbox.is_empty() && text.starts_with("<p>") {
                    format!("<p>{checkbox}{}", &text[3..])
                } else {
                    format!("{checkbox}{text}")
                };
                return format!("<li>\n{body}</li>\n");
            }
            // Both public host AST facades are supported: Kotlin keeps paragraph
            // nodes in tight items; Swift's legacy AST can store inline children.
            let mut body = String::new();
            if node
                .children
                .first()
                .is_some_and(|n| is_block(n) && n.kind != Kind::Paragraph)
            {
                body.push('\n');
            }
            for (index, child) in node.children.iter().enumerate() {
                if index > 0 && is_block(child) && !body.ends_with('\n') {
                    body.push('\n');
                }
                body.push_str(&render_inner(child, child.kind == Kind::Paragraph, options));
            }
            if node
                .children
                .last()
                .is_some_and(|n| is_block(n) && n.kind != Kind::Paragraph)
                && !body.ends_with('\n')
            {
                body.push('\n');
            }
            format!("<li>{checkbox}{body}</li>\n")
        }
        Kind::Table => {
            if node
                .children
                .iter()
                .any(|n| matches!(n.kind, Kind::TableHead | Kind::TableBody))
            {
                return format!("<table>\n{}</table>\n", children(node, options & !8));
            }
            let Some(header) = node.children.first() else {
                return if options & 8 != 0 {
                    String::new()
                } else {
                    "<table>\n</table>\n".into()
                };
            };
            let row = |row: &Node, header: bool| {
                let tag = if header { "th" } else { "td" };
                let cells: String = row
                    .children
                    .iter()
                    .enumerate()
                    .map(|(index, cell)| {
                        let alignment = node
                            .alignments
                            .get(index)
                            .and_then(|a| a.as_ref())
                            .map(|a| format!(" align=\"{}\"", escape(a)))
                            .unwrap_or_default();
                        format!("<{tag}{alignment}>{}</{tag}>\n", children(cell, options))
                    })
                    .collect();
                format!("<tr>\n{cells}</tr>\n")
            };
            let body: String = node
                .children
                .iter()
                .skip(1)
                .map(|n| row(n, false))
                .collect();
            format!(
                "<table>\n<thead>\n{}</thead>\n{}</table>\n",
                row(header, true),
                if body.is_empty() {
                    body
                } else {
                    format!("<tbody>\n{body}</tbody>\n")
                }
            )
        }
        Kind::InlineMath | Kind::FootnoteReference | Kind::Raw => escape(&node.source),
        Kind::BlockMath | Kind::FootnoteDefinition => format!(
            "<p>{}</p>\n",
            escape(node.source.trim_matches(['\r', '\n']))
        ),
    }
}
fn is_block(node: &Node) -> bool {
    matches!(
        node.kind,
        Kind::Paragraph
            | Kind::Heading
            | Kind::FencedCode
            | Kind::IndentedCode
            | Kind::ThematicBreak
            | Kind::BlockQuote
            | Kind::List
            | Kind::HtmlBlock
            | Kind::Table
            | Kind::Raw
    )
}

/// GFM tagfilter applies to raw HTML; generated tags never use these names.
pub fn render_gfm(node: &Node) -> String {
    filter_gfm(&render(node))
}
pub fn filter_gfm(html: &str) -> String {
    let blocked = [
        "title",
        "textarea",
        "style",
        "xmp",
        "iframe",
        "noembed",
        "noframes",
        "script",
        "plaintext",
    ];
    let mut result = String::new();
    let mut cursor = 0;
    while let Some(relative) = html[cursor..].find('<') {
        let position = cursor + relative;
        result.push_str(&html[cursor..position]);
        let rest = html[position + 1..]
            .strip_prefix('/')
            .unwrap_or(&html[position + 1..]);
        let length = rest.bytes().take_while(u8::is_ascii_alphabetic).count();
        let forbidden = blocked
            .iter()
            .any(|tag| rest[..length].eq_ignore_ascii_case(tag))
            && rest
                .as_bytes()
                .get(length)
                .is_some_and(|c| c.is_ascii_whitespace() || *c == b'>' || *c == b'/');
        result.push_str(if forbidden { "&lt;" } else { "<" });
        cursor = position + 1;
    }
    result.push_str(&html[cursor..]);
    result
}

/// Reject excessive output before constructing escaped HTML or its UTF16 transport.
/// The preflight is conservative for tight lists and transparent table facades.
pub fn render_bounded(root: &Node, options: u32, limit: usize) -> Result<String, i32> {
    fn escaped(s: &str) -> usize {
        s.chars()
            .map(|c| match c {
                '&' => 5,
                '<' | '>' => 4,
                '"' => 6,
                _ => c.len_utf16(),
            })
            .sum()
    }
    fn url(s: &str) -> usize {
        s.bytes()
            .map(|b| {
                if b.is_ascii_alphanumeric() || b"-._~:/?#@!$&'()*+,;=%".contains(&b) {
                    if b == b'&' {
                        5
                    } else {
                        1
                    }
                } else {
                    3
                }
            })
            .sum()
    }
    fn plain(n: &Node) -> usize {
        if let Some(s) = &n.literal {
            return escaped(s);
        }
        match n.kind {
            Kind::Text | Kind::InlineCode => escaped(&n.source),
            Kind::SoftBreak | Kind::HardBreak => 1,
            _ => n.children.iter().map(plain).sum(),
        }
    }
    let mut total = 0usize;
    let mut stack = vec![root];
    while let Some(n) = stack.pop() {
        let title = n.title.as_ref().map_or(0, |s| 9 + escaped(s));
        let alignment = n
            .alignments
            .iter()
            .flatten()
            .map(|s| 9 + escaped(s))
            .sum::<usize>();
        let size = match n.kind {
            Kind::Document | Kind::Custom | Kind::ReferenceDefinition => 0,
            Kind::Text => escaped(n.literal.as_deref().unwrap_or(&n.source)),
            Kind::Paragraph => 7,
            Kind::Heading => 48,
            Kind::FencedCode | Kind::IndentedCode => {
                25 + escaped(n.literal.as_deref().unwrap_or(""))
                    + 18
                    + escaped(n.info.split_whitespace().next().unwrap_or(""))
            }
            Kind::ThematicBreak => 7,
            Kind::Strong => 17,
            Kind::Emphasis => 9,
            Kind::Strikethrough => 11,
            Kind::InlineCode => 13 + escaped(n.literal.as_deref().unwrap_or(&n.source)),
            Kind::SoftBreak => 1,
            Kind::HardBreak => 7,
            Kind::InlineHtml | Kind::HtmlBlock => {
                1 + escaped(n.literal.as_deref().unwrap_or(&n.source))
            }
            Kind::Link => 15 + url(&n.destination) + title,
            Kind::Image => 24 + url(&n.destination) + title + plain(n),
            Kind::BlockQuote => 28,
            Kind::List => 50,
            Kind::ListItem => 12 + if n.checked.is_some() { 48 } else { 0 },
            Kind::TaskMarker => 48,
            Kind::Table => 52 + alignment.checked_mul(n.children.len()).ok_or(2)?,
            Kind::TableHead | Kind::TableBody => 18,
            Kind::TableRow => 12,
            Kind::TableCell => 14 + alignment,
            Kind::InlineMath | Kind::FootnoteReference | Kind::Raw => escaped(&n.source),
            Kind::BlockMath | Kind::FootnoteDefinition => 7 + escaped(&n.source),
        };
        total = total.checked_add(size).ok_or(2)?;
        if total > limit {
            return Err(2);
        }
        if n.kind != Kind::Image {
            stack.extend(n.children.iter().rev());
        }
    }
    let html = render_with_options(root, options);
    if html.encode_utf16().count() > limit {
        return Err(2);
    }
    Ok(html)
}

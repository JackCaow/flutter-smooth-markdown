use std::collections::HashMap;

/// Stable wire IDs; append values rather than reordering them.
#[repr(u16)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Document = 0,
    Paragraph = 1,
    Heading = 2,
    FencedCode = 3,
    IndentedCode = 4,
    Table = 5,
    TableRow = 6,
    TableCell = 7,
    List = 8,
    ListItem = 9,
    BlockQuote = 10,
    ThematicBreak = 11,
    Text = 12,
    Strong = 13,
    Emphasis = 14,
    Strikethrough = 15,
    InlineCode = 16,
    InlineMath = 17,
    SoftBreak = 18,
    HardBreak = 19,
    InlineHtml = 20,
    BlockMath = 21,
    FootnoteReference = 22,
    FootnoteDefinition = 23,
    ReferenceDefinition = 24,
    Link = 25,
    Image = 26,
    HtmlBlock = 27,
    Raw = 28,
    Custom = 29,
    TableHead = 30,
    TableBody = 31,
    TaskMarker = 32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct Span {
    pub start: u32,
    pub len: u32,
}
impl Span {
    pub fn end(self) -> u32 {
        self.start + self.len
    }
}

#[derive(Clone)]
#[cfg_attr(not(feature = "flutter-compact-ast"), derive(Debug, PartialEq, Eq))]
pub struct Node {
    #[cfg(feature = "flutter-compact-ast")]
    attributes: Option<Box<NodeAttributes>>,
    pub kind: Kind,
    pub span: Span,
    pub source: String,
    pub children: Vec<Node>,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub level: u32,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub info: String,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub destination: String,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub title: Option<String>,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub ordered: bool,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub checked: Option<bool>,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub tight: Option<bool>,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub list_start: Option<u32>,
    pub literal: Option<String>,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub alignments: Vec<Option<String>>,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub label: String,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub html_header: bool,
    #[cfg(not(feature = "flutter-compact-ast"))]
    pub html_number: Option<i64>,
}
impl Node {
    pub fn new(kind: Kind, source: impl Into<String>, start: u32, len: u32) -> Self {
        Self {
            #[cfg(feature = "flutter-compact-ast")]
            attributes: None,
            kind,
            span: Span { start, len },
            source: source.into(),
            children: Vec::new(),
            #[cfg(not(feature = "flutter-compact-ast"))]
            level: 0,
            #[cfg(not(feature = "flutter-compact-ast"))]
            info: String::new(),
            #[cfg(not(feature = "flutter-compact-ast"))]
            destination: String::new(),
            #[cfg(not(feature = "flutter-compact-ast"))]
            title: None,
            #[cfg(not(feature = "flutter-compact-ast"))]
            ordered: false,
            #[cfg(not(feature = "flutter-compact-ast"))]
            checked: None,
            #[cfg(not(feature = "flutter-compact-ast"))]
            tight: None,
            #[cfg(not(feature = "flutter-compact-ast"))]
            list_start: None,
            literal: None,
            #[cfg(not(feature = "flutter-compact-ast"))]
            alignments: Vec::new(),
            #[cfg(not(feature = "flutter-compact-ast"))]
            label: String::new(),
            #[cfg(not(feature = "flutter-compact-ast"))]
            html_header: false,
            #[cfg(not(feature = "flutter-compact-ast"))]
            html_number: None,
        }
    }
}
// Private build feature: the default Rust Node API/layout remains unchanged.
#[cfg(feature = "flutter-compact-ast")]
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct NodeAttributes {
    pub level: u32,
    pub info: String,
    pub destination: String,
    pub title: Option<String>,
    pub ordered: bool,
    pub checked: Option<bool>,
    pub tight: Option<bool>,
    pub list_start: Option<u32>,
    pub alignments: Vec<Option<String>>,
    pub label: String,
    pub html_header: bool,
    pub html_number: Option<i64>,
}
#[cfg(feature = "flutter-compact-ast")]
static EMPTY_ATTRIBUTES: NodeAttributes = NodeAttributes {
    level: 0,
    info: String::new(),
    destination: String::new(),
    title: None,
    ordered: false,
    checked: None,
    tight: None,
    list_start: None,
    alignments: Vec::new(),
    label: String::new(),
    html_header: false,
    html_number: None,
};
#[cfg(feature = "flutter-compact-ast")]
impl std::ops::Deref for Node {
    type Target = NodeAttributes;
    fn deref(&self) -> &Self::Target { self.attributes.as_deref().unwrap_or(&EMPTY_ATTRIBUTES) }
}
#[cfg(feature = "flutter-compact-ast")]
impl std::ops::DerefMut for Node {
    fn deref_mut(&mut self) -> &mut Self::Target {
        self.attributes.get_or_insert_with(|| Box::new(NodeAttributes::default()))
    }
}
#[cfg(feature = "flutter-compact-ast")]
impl PartialEq for Node {
    fn eq(&self, other: &Self) -> bool {
        self.kind == other.kind && self.span == other.span && self.source == other.source
            && self.children == other.children && self.literal == other.literal
            && **self == **other
    }
}
#[cfg(feature = "flutter-compact-ast")]
impl Eq for Node {}
#[cfg(feature = "flutter-compact-ast")]
impl std::fmt::Debug for Node {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Node")
            .field("kind", &self.kind)
            .field("span", &self.span)
            .field("source", &self.source)
            .field("children", &self.children)
            .field("level", &self.level)
            .field("info", &self.info)
            .field("destination", &self.destination)
            .field("title", &self.title)
            .field("ordered", &self.ordered)
            .field("checked", &self.checked)
            .field("tight", &self.tight)
            .field("list_start", &self.list_start)
            .field("literal", &self.literal)
            .field("alignments", &self.alignments)
            .field("label", &self.label)
            .field("html_header", &self.html_header)
            .field("html_number", &self.html_number)
            .finish()
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Options {
    pub gfm: bool,
    pub extensions: bool,
}
impl Default for Options {
    fn default() -> Self {
        Self {
            gfm: true,
            extensions: true,
        }
    }
}
#[derive(Debug, Clone)]
pub struct Reference {
    pub destination: String,
    pub title: Option<String>,
}
pub type References = HashMap<String, Reference>;
pub fn utf16_len(s: &str) -> u32 {
    s.encode_utf16().count() as u32
}

#[cfg(all(test, feature = "flutter-compact-ast", target_pointer_width = "64"))]
mod compact_contract {
    use super::*;
    #[test]
    fn compact_leaf_size_and_default_metadata_equality() {
        assert!(std::mem::size_of::<Node>() <= 96);
        let a = Node::new(Kind::Text, "text", 0, 4);
        let mut b = a.clone();
        assert!(a.attributes.is_none());
        b.level = 0;
        assert!(b.attributes.is_some());
        assert_eq!(a, b);
    }
}

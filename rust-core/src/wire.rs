//! Bounds checked decoding of host-created mutable ASTs. No source reparsing.
use crate::ast::{Kind, Node, Reference, References};
pub struct Cursor<'a> {
    bytes: &'a [u8],
    at: usize,
}
impl<'a> Cursor<'a> {
    fn new(bytes: &'a [u8], magic: &[u8]) -> Result<Self, i32> {
        if bytes.len() > 64 * 1024 * 1024 || !bytes.starts_with(magic) {
            return Err(1);
        }
        Ok(Self { bytes, at: 4 })
    }
    fn word(&mut self) -> Result<u32, i32> {
        let end = self.at.checked_add(4).ok_or(1)?;
        let b = self.bytes.get(self.at..end).ok_or(1)?;
        self.at = end;
        Ok(u32::from_le_bytes(b.try_into().unwrap()))
    }
    fn string(&mut self) -> Result<Option<String>, i32> {
        let len = self.word()?;
        if len == u32::MAX {
            return Ok(None);
        }
        if len == 0xfffffffe {
            return Err(1);
        }
        let end = self
            .at
            .checked_add((len as usize).checked_mul(2).ok_or(1)?)
            .ok_or(1)?;
        let b = self.bytes.get(self.at..end).ok_or(1)?;
        self.at = end;
        let units: Vec<u16> = b
            .chunks_exact(2)
            .map(|x| u16::from_le_bytes([x[0], x[1]]))
            .collect();
        Ok(Some(String::from_utf16_lossy(&units)))
    }
    fn required(&mut self) -> Result<String, i32> {
        self.string()?.ok_or(1)
    }
    fn node(&mut self, remaining: &mut u32, depth: u32) -> Result<Node, i32> {
        if *remaining == 0 || depth > 256 {
            return Err(2);
        }
        *remaining -= 1;
        let kind = match self.word()? {
            0 => Kind::Document,
            1 => Kind::Paragraph,
            2 => Kind::Heading,
            3 => Kind::FencedCode,
            4 => Kind::IndentedCode,
            5 => Kind::Table,
            6 => Kind::TableRow,
            7 => Kind::TableCell,
            8 => Kind::List,
            9 => Kind::ListItem,
            10 => Kind::BlockQuote,
            11 => Kind::ThematicBreak,
            12 => Kind::Text,
            13 => Kind::Strong,
            14 => Kind::Emphasis,
            15 => Kind::Strikethrough,
            16 => Kind::InlineCode,
            17 => Kind::InlineMath,
            18 => Kind::SoftBreak,
            19 => Kind::HardBreak,
            20 => Kind::InlineHtml,
            21 => Kind::BlockMath,
            22 => Kind::FootnoteReference,
            23 => Kind::FootnoteDefinition,
            24 => Kind::ReferenceDefinition,
            25 => Kind::Link,
            26 => Kind::Image,
            27 => Kind::HtmlBlock,
            28 => Kind::Raw,
            29 => Kind::Custom,
            30 => Kind::TableHead,
            31 => Kind::TableBody,
            32 => Kind::TaskMarker,
            _ => return Err(1),
        };
        let start = self.word()?;
        let len = self.word()?;
        let level = self.word()?;
        let flags = self.word()?;
        let list_start = self.word()?;
        let children = self.word()?;
        if flags & !255 != 0 || children > *remaining {
            return Err(1);
        }
        let mut n = Node::new(kind, self.required()?, start, len);
        n.level = level;
        n.ordered = flags & 1 != 0;
        n.checked = (flags & 4 != 0).then_some(flags & 2 != 0);
        n.tight = (flags & 16 != 0).then_some(flags & 8 != 0);
        n.list_start = (flags & 32 != 0).then_some(list_start);
        n.html_header = flags & 64 != 0;
        n.info = self.required()?;
        n.destination = self.required()?;
        n.title = self.string()?;
        n.literal = self.string()?;
        n.label = self.required()?;
        if flags & 128 != 0 {
            if !matches!(kind, Kind::Heading | Kind::List) {
                return Err(1);
            }
            n.html_number = Some(n.label.parse::<i64>().map_err(|_| 1)?);
        }
        let align = self.word()?;
        if align > 1_000_000 {
            return Err(2);
        }
        for _ in 0..align {
            n.alignments.push(self.string()?)
        }
        for _ in 0..children {
            n.children.push(self.node(remaining, depth + 1)?)
        }
        Ok(n)
    }
}
pub fn decode(bytes: &[u8]) -> Result<Node, i32> {
    let mut c = Cursor::new(bytes, b"SMR1")?;
    let mut count = c.word()?;
    if count == 0 || count > 1_000_000 {
        return Err(2);
    }
    let n = c.node(&mut count, 0)?;
    if count != 0 || c.at != bytes.len() {
        return Err(1);
    }
    Ok(n)
}
pub fn references(bytes: &[u8]) -> Result<References, i32> {
    if bytes.is_empty() {
        return Ok(References::new());
    }
    let mut c = Cursor::new(bytes, b"SMF1")?;
    let count = c.word()?;
    if count > 1_000_000 {
        return Err(2);
    }
    let mut refs = References::new();
    for _ in 0..count {
        let key = crate::inline::normalize_reference(&c.required()?);
        let destination = c.required()?;
        let title = c.string()?;
        refs.entry(key).or_insert(Reference { destination, title });
    }
    if c.at != bytes.len() {
        return Err(1);
    }
    Ok(refs)
}

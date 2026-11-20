//! Append-only parsing with a conservative mutable tail. Host hooks deliberately
//! use the batch API: arbitrary callbacks may inspect the entire document.
use crate::ast::{Kind, Node, Options};

pub struct Delta {
    pub retained_blocks: usize,
    pub children: Vec<Node>,
    pub source_units: usize,
    pub parsed_units: usize,
    pub total_nodes: usize,
    pub total_wire_bytes: usize,
}

pub struct Session {
    options: Options,
    source: Vec<u16>,
    blocks: Vec<(u32, usize, usize)>,
    global_definitions: bool,
    total_nodes: usize,
    total_wire_bytes: usize,
}

fn node_stats(node: &Node) -> (usize, usize) {
    let mut count = 1;
    let mut bytes = crate::ffi::encoded_node_size(node);
    for child in &node.children {
        let stats = node_stats(child); count += stats.0; bytes += stats.1;
    }
    (count, bytes)
}

fn translate(node: &mut Node, offset: u32) {
    node.span.start += offset;
    for child in &mut node.children {
        translate(child, offset);
    }
}

impl Session {
    pub fn new(options: Options) -> Self {
        Self { options, source: Vec::new(), blocks: Vec::new(), global_definitions: false,
               total_nodes: 1, total_wire_bytes: 64 }
    }

    pub fn reset(&mut self) {
        self.source.clear();
        self.blocks.clear();
        self.global_definitions = false;
        self.total_nodes = 1;
        self.total_wire_bytes = 64;
    }

    pub fn update(&mut self, source: &[u16]) -> Delta {
        let append = source.starts_with(&self.source);
        let previous_len = self.source.len();
        let delta = self.update_tail(source, append, previous_len);
        if append { self.source.extend_from_slice(&source[previous_len..]); }
        else { self.source.clear(); self.source.extend_from_slice(source); }
        delta
    }

    /// Additive transport entry: same parsing policy, only transfer new units.
    pub fn append(&mut self, suffix: &[u16]) -> Delta {
        let mut source = std::mem::take(&mut self.source);
        let previous_len = source.len();
        source.extend_from_slice(suffix);
        let delta = self.update_tail(&source, true, previous_len);
        self.source = source;
        delta
    }

    pub(crate) fn source(&self) -> &[u16] { &self.source }

    fn update_tail(&mut self, source: &[u16], append: bool, previous_len: usize) -> Delta {
        if append && source.len() == previous_len {
            return Delta {
                retained_blocks: self.blocks.len(), children: Vec::new(),
                source_units: source.len(), parsed_units: 0,
                total_nodes: self.total_nodes, total_wire_bytes: self.total_wire_bytes,
            };
        }
        // A definition can resolve links anywhere, including inside quotes and
        // lists. Every recognized reference/footnote definition contains ]:.
        // False positives (e.g. code strings) are intentionally conservative.
        let scan_start = if append { previous_len.saturating_sub(1) } else { 0 };
        let definitions = (append && self.global_definitions)
            || source[scan_start..].windows(2).any(|s| s == [b']' as u16, b':' as u16]);
        let retained = if append && !definitions { self.blocks.len().saturating_sub(2) } else { 0 };
        let start = if retained == 0 { 0 } else { self.blocks[retained].0 as usize };
        let text = String::from_utf16_lossy(&source[start..]);
        let mut root = crate::parse(&text, self.options);
        for node in &mut root.children { translate(node, start as u32); }
        if retained == 0 {
            self.total_nodes = 1; self.total_wire_bytes = 64;
        } else {
            for block in &self.blocks[retained..] {
                self.total_nodes -= block.1; self.total_wire_bytes -= block.2;
            }
        }
        self.blocks.truncate(retained);
        for node in &root.children {
            let stats = node_stats(node);
            self.total_nodes += stats.0; self.total_wire_bytes += stats.1;
            self.blocks.push((node.span.start, stats.0, stats.1));
        }
        self.global_definitions = definitions;
        Delta {
            retained_blocks: retained, children: root.children,
            source_units: source.len(), parsed_units: source.len() - start,
            total_nodes: self.total_nodes,
            total_wire_bytes: self.total_wire_bytes,
        }
    }
}

impl Delta {
    /// The wire source sentinel uses the caller's complete source; only children
    /// are transmitted. No duplicate full document string is needed here.
    pub fn into_wire_root(self) -> Node {
        let mut root = Node::new(Kind::Document, "", 0, self.source_units as u32);
        root.children = self.children;
        root
    }
}

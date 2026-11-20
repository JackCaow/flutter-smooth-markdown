//! Synchronous host extensions; callbacks borrow projected context only for the call.
#[derive(Clone, Copy, Debug)]
pub struct Match {
    pub consumed: u32,
    pub id: u32,
}
pub trait Hooks {
    fn begin_inline(&self, _units: &[u16]) {}
    fn end_inline(&self) {}
    fn begin_block(&self, _units: &[Vec<u16>]) {}
    fn end_block(&self) {}
    fn inline(&self, _source: &str, _units: &[u16], _index: u32, _absolute: u32) -> Option<Match> {
        None
    }
    fn block(&self, _lines: &[Vec<u16>], _index: usize, _absolute: u32) -> Option<Match> {
        None
    }
}
pub struct Mapped<'a> {
    pub hooks: &'a dyn Hooks,
    pub positions: &'a [(u32, u32)],
    pub fallback: u32,
}
impl Hooks for Mapped<'_> {
    fn begin_inline(&self, u: &[u16]) {
        self.hooks.begin_inline(u)
    }
    fn end_inline(&self) {
        self.hooks.end_inline()
    }
    fn inline(&self, source: &str, units: &[u16], index: u32, absolute: u32) -> Option<Match> {
        let at = self
            .positions
            .get(absolute as usize)
            .map(|p| p.0)
            .unwrap_or_else(|| self.positions.last().map(|p| p.1).unwrap_or(self.fallback));
        self.hooks.inline(source, units, index, at)
    }
}

pub struct InlineScope<'a>(pub Option<&'a dyn Hooks>);
impl Drop for InlineScope<'_> {
    fn drop(&mut self) {
        if let Some(h) = self.0 {
            h.end_inline()
        }
    }
}
pub struct BlockScope<'a>(pub Option<&'a dyn Hooks>);
impl Drop for BlockScope<'_> {
    fn drop(&mut self) {
        if let Some(h) = self.0 {
            h.end_block()
        }
    }
}

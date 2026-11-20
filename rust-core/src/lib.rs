pub mod ast;
pub mod block;
pub mod ffi;
pub mod highlight;
pub mod hooks;
pub mod html;
pub mod inline;
pub mod stream;

pub fn parse(source: &str, options: ast::Options) -> ast::Node {
    block::parse(source, options)
}

pub mod wire;

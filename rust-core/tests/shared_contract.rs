use smooth_markdown_rust::{ast::{Kind,Options,References},hooks::{Hooks,Match},ffi::*};
use std::cell::RefCell;
struct Plugins { calls:RefCell<Vec<(String,u32,u32)>> }
impl Hooks for Plugins{
    fn inline(&self,s:&str,_:&[u16],index:u32,absolute:u32)->Option<Match>{let tail=String::from_utf16_lossy(&s.encode_utf16().skip(index as usize).collect::<Vec<_>>());if tail.starts_with("@!"){self.calls.borrow_mut().push((s.into(),index,absolute));Some(Match{consumed:2,id:7})}else{None}}
    fn block(&self,lines:&[Vec<u16>],index:usize,_:u32)->Option<Match>{String::from_utf16_lossy(&lines[index]).starts_with(":::").then_some(Match{consumed:1,id:9})}
}
#[test]fn shared_hooks_respect_code_escape_and_original_projected_offsets(){
    let h=Plugins{calls:RefCell::new(vec![])};
    let source="> 😀 @!\r\n> later @!\r\n\n`@!` \\@!\n\n```\n::: block\n```\n\nparagraph\n::: custom\n";
    let tree=smooth_markdown_rust::block::parse_with_hooks(source,Options::default(),Some(&h));
    let calls=h.calls.borrow();assert_eq!(calls.len(),2);assert_eq!(calls[0].2,5);assert_eq!(calls[1].2,17);assert_eq!(calls[0].0,"😀 @!\nlater @!");
    assert_eq!(tree.children.last().unwrap().kind,Kind::Custom);assert_eq!(tree.children[2].kind,Kind::FencedCode);
}
#[test]fn fragment_parser_does_not_promote_editor_heading_to_block(){let n=smooth_markdown_rust::inline::parse("# **😀**",0,&References::new(),Options::default());assert_eq!(n[0].kind,Kind::Text);assert_eq!(n[1].kind,Kind::Strong);assert_eq!(n[1].span.start,2);}
unsafe extern "C" fn fail(_: *mut std::ffi::c_void,_:*const u16,_:usize,_:u32,_:u32,_:*mut SmrMatch)->i32{-1}
#[test]fn callback_error_aborts_without_allocating_result(){let s:Vec<u16>="plain".encode_utf16().collect();let mut out=SmrBuffer::default();let hooks=SmrHooks{context:std::ptr::null_mut(),inline_callback:Some(fail),block_callback:None,inline_context:None,block_context:None};assert_eq!(unsafe{smr_parse_with_hooks_utf16(s.as_ptr(),s.len(),0,&hooks,&mut out)},4);assert!(out.owner.is_null());}
fn word(b:&mut Vec<u8>,n:u32){b.extend(n.to_le_bytes());}
fn string(b:&mut Vec<u8>,s:Option<&str>){if let Some(s)=s{let u:Vec<u16>=s.encode_utf16().collect();word(b,u.len() as u32);for u in u{b.extend(u.to_le_bytes())}}else{word(b,u32::MAX)}}
fn single(kind:u32,literal:&str,flags:u32)->Vec<u8>{let mut b=b"SMR1".to_vec();for n in [1,kind,987,0,0,flags,0,0]{word(&mut b,n)}for s in [Some("unrelated source"),Some(""),Some(""),None,Some(literal),Some("")]{string(&mut b,s)}word(&mut b,0);b}
#[test]fn mutable_subtree_html_uses_wire_literal_not_reparsed_source(){let b=single(12,"changed <😀>",0);let mut out=SmrBuffer::default();assert_eq!(unsafe{smr_render_ast_utf16(b.as_ptr(),b.len(),0,&mut out)},0);let bytes=unsafe{std::slice::from_raw_parts(out.data,out.len)};let u:Vec<u16>=bytes.chunks_exact(2).map(|b|u16::from_le_bytes([b[0],b[1]])).collect();assert_eq!(String::from_utf16(&u).unwrap(),"changed &lt;😀&gt;");unsafe{smr_buffer_free(&mut out)}}
#[test]fn malformed_host_wire_is_rejected(){let mut b=single(12,"x",0);b.truncate(b.len()-1);let mut out=SmrBuffer::default();assert_ne!(unsafe{smr_render_ast_utf16(b.as_ptr(),b.len(),0,&mut out)},0);assert!(out.owner.is_null());}
struct ScopeCounts { inline:i32,block:i32,peak:i32 }
unsafe extern "C" fn inline_scope(ctx:*mut std::ffi::c_void,_:*const u16,_:usize,begin:i32)->i32{let c=&mut *ctx.cast::<ScopeCounts>();c.inline+=if begin!=0{1}else{-1};c.peak=c.peak.max(c.inline);assert!(c.inline>=0);0}
unsafe extern "C" fn block_scope(ctx:*mut std::ffi::c_void,_:*const *const u16,_:*const usize,_:usize,begin:i32)->i32{let c=&mut *ctx.cast::<ScopeCounts>();c.block+=if begin!=0{1}else{-1};assert!(c.block>=0);0}
#[test]fn ffi_context_scopes_unwind_nested_fragments_and_errors(){
    for failing in [false,true]{
        let mut counts=ScopeCounts{inline:0,block:0,peak:0};let hooks=SmrHooks{context:(&mut counts as *mut ScopeCounts).cast(),inline_callback:if failing{Some(fail)}else{None},block_callback:None,inline_context:Some(inline_scope),block_context:Some(block_scope)};
        let source:Vec<u16>="> - [outer **inner**](url)\n> - end\n\n[ref]: /url\n".encode_utf16().collect();let mut out=SmrBuffer::default();let status=unsafe{smr_parse_with_hooks_utf16(source.as_ptr(),source.len(),0,&hooks,&mut out)};
        assert_eq!(status,if failing{4}else{0});assert_eq!((counts.inline,counts.block),(0,0));if !failing{assert!(counts.peak>=2)}unsafe{smr_buffer_free(&mut out)}
    }
}
struct FencePlugin;
impl Hooks for FencePlugin {fn block(&self,lines:&[Vec<u16>],index:usize,_:u32)->Option<Match>{String::from_utf16_lossy(&lines[index]).starts_with("```mermaid").then_some(Match{consumed:3,id:3})}}
#[test]fn host_can_explicitly_claim_fenced_extension_without_entering_ordinary_code(){let s="```mermaid\ngraph TD; A-->B\n```\n\n```text\n```mermaid\n```";let h=FencePlugin;
    let default=smooth_markdown_rust::block::parse_with_hooks(s,Options::default(),Some(&h));assert_eq!(default.children[0].kind,Kind::FencedCode);
    let host=smooth_markdown_rust::block::parse_with_hook_policy(s,Options::default(),Some(&h),true);assert_eq!(host.children[0].kind,Kind::Custom);assert_eq!(host.children[1].kind,Kind::FencedCode);
}
#[test]fn bounded_html_rejects_escape_expansion_before_transport_allocation(){let mut n=smooth_markdown_rust::ast::Node::new(Kind::Text,"",0,0);n.literal=Some("&".repeat(100));assert_eq!(smooth_markdown_rust::html::render_bounded(&n,0,499),Err(2));assert_eq!(smooth_markdown_rust::html::render_bounded(&n,0,500).unwrap(),"&amp;".repeat(100));}
#[test]fn extended_block_literals_use_projected_body_and_exact_definition_prefix(){
    let source="> $$\n> x +\n> y\n> $$\n>\n> [^a:b]: first\n>     second\n";
    let tree=smooth_markdown_rust::parse(source,Options::default());let nodes=&tree.children[0].children;
    assert_eq!(nodes[0].kind,Kind::BlockMath);assert_eq!(nodes[0].literal.as_deref(),Some("x +\ny"));
    assert_eq!(nodes[1].kind,Kind::FootnoteDefinition);assert_eq!(nodes[1].label,"a:b");assert_eq!(nodes[1].literal.as_deref(),Some("first\nsecond"));
    assert!(nodes[0].source.contains("> x"));assert!(nodes[1].source.contains(">     second"));
    let list=smooth_markdown_rust::parse("- $$\n  x\n  $$",Options::default());assert_eq!(list.children[0].children[0].children[0].literal.as_deref(),Some("x"));
}

#[test]fn footnote_children_share_local_and_outer_references_and_original_ranges(){
    let source="> [^😀:n]: [local]: /local\r\n>     [x][local] [y][outer]\r\n\r\n[outer]: /outer\r\n";
    let tree=smooth_markdown_rust::parse(source,Options::default());
    let footnote=&tree.children[0].children[0];assert_eq!(footnote.children.len(),2);
    let paragraph=&footnote.children[1];assert_eq!(paragraph.kind,Kind::Paragraph);
    let links:Vec<_>=paragraph.children.iter().filter(|n|n.kind==Kind::Link).collect();
    assert_eq!(links.len(),2);assert_eq!(links[0].destination,"/local");assert_eq!(links[1].destination,"/outer");
    assert_eq!(links[0].span.start,source[..source.find("[x]").unwrap()].encode_utf16().count() as u32);
    let definition=&footnote.children[0];assert_eq!(definition.kind,Kind::ReferenceDefinition);assert_eq!(definition.source,"[local]: /local\r\n");
    let plain=smooth_markdown_rust::parse("[x][local]\n[local]: /local",Options::default());
    assert_eq!(plain.children.len(),1);assert!(!plain.children[0].children.iter().any(|n|n.kind==Kind::Link));
    let code=smooth_markdown_rust::parse("[^n]: ```\n    [local]: /code\n    ```\n    [x][local]",Options::default());
    assert_eq!(code.children[0].children[0].kind,Kind::FencedCode);
    assert!(!code.children[0].children[1].children.iter().any(|n|n.kind==Kind::Link));
}

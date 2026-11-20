use smooth_markdown_rust as candidate;
use smooth_markdown_rust_reference as reference;
use std::{hint::black_box, time::Instant};

fn measure(mut operation: impl FnMut()) -> Vec<f64> {
    for _ in 0..5 { operation(); }
    (0..9).map(|_| {
        let start = Instant::now();
        for _ in 0..60 { operation(); }
        start.elapsed().as_secs_f64() * 1e6 / 60.0
    }).collect()
}

struct Hooks;
macro_rules! hooks {
    ($core:ident) => {
        impl $core::hooks::Hooks for Hooks {
            fn inline(&self, _: &str, units: &[u16], index: u32, _: u32) -> Option<$core::hooks::Match> {
                (units.get(index as usize) == Some(&64)).then_some($core::hooks::Match { consumed: 1, id: 1 })
            }
        }
    };
}
hooks!(candidate);
hooks!(reference);

fn wire_candidate(units: &[u16], flags: u32) -> Vec<u8> {
    let mut buffer = candidate::ffi::SmrBuffer::default();
    unsafe {
        assert_eq!(candidate::ffi::smr_parse_utf16(units.as_ptr(), units.len(), flags, &mut buffer), 0);
        let bytes = std::slice::from_raw_parts(buffer.data, buffer.len).to_vec();
        candidate::ffi::smr_buffer_free(&mut buffer); bytes
    }
}
fn wire_reference(units: &[u16], flags: u32) -> Vec<u8> {
    let mut buffer = reference::ffi::SmrBuffer::default();
    unsafe {
        assert_eq!(reference::ffi::reference_smr_parse_utf16(units.as_ptr(), units.len(), flags, &mut buffer), 0);
        let bytes = std::slice::from_raw_parts(buffer.data, buffer.len).to_vec();
        reference::ffi::reference_smr_buffer_free(&mut buffer); bytes
    }
}

fn check(text: &str) {
    for gfm in [false, true] { for extensions in [false, true] {
        let units: Vec<_> = text.encode_utf16().collect();
        let flags = u32::from(gfm) | (u32::from(extensions) << 1);
        assert_eq!(wire_candidate(&units, flags), wire_reference(&units, flags), "wire source={text:?}");
        let a = candidate::parse(text, candidate::ast::Options { gfm, extensions });
        let b = reference::parse(text, reference::ast::Options { gfm, extensions });
        assert_eq!(format!("{a:?}"), format!("{b:?}"), "source={text:?}");
        let a = candidate::inline::parse_with_hooks(text, 17, &Default::default(),
            candidate::ast::Options { gfm, extensions }, Some(&Hooks));
        let b = reference::inline::parse_with_hooks(text, 17, &Default::default(),
            reference::ast::Options { gfm, extensions }, Some(&Hooks));
        assert_eq!(format!("{a:?}"), format!("{b:?}"), "inline hooks: source={text:?}");
    }}
}

fn main() {
    let args: Vec<_> = std::env::args().collect();
    let text = std::fs::read_to_string(&args[1]).unwrap();
    let units: Vec<_> = text.encode_utf16().collect();
    let a = candidate::parse(&text, Default::default());
    let b = reference::parse(&text, Default::default());
    let before_parse = measure(|| { black_box(reference::parse(black_box(&text), black_box(Default::default()))); });
    let after_parse = measure(|| { black_box(candidate::parse(black_box(&text), black_box(Default::default()))); });
    let before_wire = measure(|| { black_box(reference::ffi::encode(black_box(&b), black_box(&units)).unwrap()); });
    let after_wire = measure(|| { black_box(candidate::ffi::encode(black_box(&a), black_box(&units)).unwrap()); });
    let convert = measure(|| { black_box(String::from_utf16_lossy(black_box(&units))); });
    let fixtures = std::fs::read(&args[2]).unwrap();
    let (mut at, mut count) = (0, 0);
    while at < fixtures.len() {
        let size = u32::from_le_bytes(fixtures[at..at+4].try_into().unwrap()) as usize;
        at += 4;
        check(std::str::from_utf8(&fixtures[at..at+size]).unwrap());
        at += size;
        count += 1;
    }
    let mut seed = 487_u64;
    let tokens = ["plain", "*", "**", "_", "___", "~", "~~", "\\", "&amp;", "\n", " ", "中", "🙂", "`", "[", "]", "(", ")", "<", ">", "$", "!", ":", "#", "|", "-", "\t", "@"];
    for _ in 0..10000 {
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
        let mut text = String::new();
        for _ in 0..(seed >> 32) as usize % 40 {
            seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1);
            text.push_str(tokens[(seed >> 32) as usize % tokens.len()]);
        }
        check(&text);
    }
    let before_node_bytes = std::mem::size_of::<reference::ast::Node>();
    let after_node_bytes = std::mem::size_of::<candidate::ast::Node>();
    println!("{{\"before_node_bytes\":{before_node_bytes},\"after_node_bytes\":{after_node_bytes},\"wire_equal\":true,\"utf16_units\":{},\"before_parse_drop_us\":{before_parse:?},\"after_parse_drop_us\":{after_parse:?},\"before_encode_drop_us\":{before_wire:?},\"after_encode_drop_us\":{after_wire:?},\"input_convert_us\":{convert:?},\"fixtures\":{count},\"generated_documents\":10000,\"option_combinations\":4,\"full_and_inline_hook_ast_equal\":true}}", units.len());
}

use smooth_markdown_rust::ffi::*;
use std::time::Instant;

fn sample(source: &[u16], incremental: bool) -> (f64, usize, usize) {
    let session = if incremental { smr_stream_new(3) } else { std::ptr::null_mut() };
    let started = Instant::now(); let mut wire_bytes = 0; let mut publishes = 0;
    for end in (512..source.len()).step_by(512).chain(std::iter::once(source.len())) {
        let mut output = SmrBuffer::default(); let mut retained = 0;
        unsafe {
            let status = if incremental {
                smr_stream_update_utf16(session, source.as_ptr(), end, &mut output, &mut retained)
            } else { smr_parse_utf16(source.as_ptr(), end, 3, &mut output) };
            assert_eq!(status, 0);
            wire_bytes += output.len; publishes += 1;
            smr_buffer_free(&mut output);
        }
    }
    let ms = started.elapsed().as_secs_f64() * 1000.0;
    unsafe { smr_stream_free(session); }
    (ms, wire_bytes, publishes)
}

#[test]
#[ignore = "observational host release benchmark; no machine-dependent threshold"]
fn batch_vs_incremental_ffi_transport() {
    let paragraphs = "# Heading 中文🙂\n\nParagraph with **bold** and [link](https://example.test).\n\n- first\n- second\n\n```rust\nlet n = 1;\n```\n\n".repeat(500);
    for (label, source) in [
        ("multiple-blocks", paragraphs.clone()),
        ("single-container", "a ".repeat(30_000)),
        ("global-definition", format!("[a]: /url\n\n{paragraphs}")),
    ] {
        let units: Vec<_> = source.encode_utf16().collect();
        sample(&units, false); sample(&units, true);
        let mut batch = Vec::new(); let mut stream = Vec::new();
        for _ in 0..3 { batch.push(sample(&units,false)); stream.push(sample(&units,true)); }
        batch.sort_by(|a,b| a.0.total_cmp(&b.0)); stream.sort_by(|a,b| a.0.total_cmp(&b.0));
        println!("STREAM_FFI scenario={label} utf16={} publishes={} batchMedianMs={:.3} incrementalMedianMs={:.3} speedup={:.3} batchWireBytes={} incrementalWireBytes={}",
            units.len(), batch[1].2, batch[1].0, stream[1].0, batch[1].0/stream[1].0, batch[1].1, stream[1].1);
    }
}

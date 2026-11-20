# Shared-core baseline diagnosis — 2026-11-19

This document records the **pre-optimization** state. See
[the incremental compatibility check and 435k rendering results](stream-eligibility-results.md),
[the retained-block/lazy-sliver rendering results](block-layout-results.md),
[the actual streaming render-frame comparison](render-results.md),
[the latest sustained-stream RSS investigation](sustained-rss-results.md),
[the latest bridge CPU/memory results](bridge-optimization-results.md),
[the latest batch optimizations and measurements](batch-round2-results.md)
and [the equivalent Dart/Rust incremental comparison](equal-incremental-results.md)
and [the fresh-process memory comparison](memory-results.md) for current behavior
and results.

Measured on an **Apple M4, macOS 27.2, Flutter 3.41.6 / Dart 3.11.4,
Profile/AOT**. These are host measurements, not Android device results.
The Android phone was disconnected before performance profiling. Earlier
functional installation and source/diff inspection succeeded on the phone.

The current integration does **not** establish an overall rendering speedup.
The ordinary Rust batch path is slower than the established Dart parser in
these same-input cases. Incremental parsing has a substantial win only when
that path is eligible; Flutter UI construction is still a whole-document pass.

## Same-input results

The recovered aggregates of the successful baseline run are stored in
[evidence/macos-profile-2026-11-19-baseline.json](evidence/macos-profile-2026-11-19-baseline.json).
The complete sample file for that successful run was overwritten by the subsequent stage probe; the evidence explicitly records this limitation. A separate complete first-run distribution is retained in `evidence/macos-profile-2026-11-19-first.json`.

Parsing includes input conversion, Rust, binary transport, Dart decoding and AST
adaptation, with widget cache disabled. Each reported parse value is the median
of nine samples (500 iterations for the short message, 12 for documents).

| Input (UTF-16 units) | Original Dart | Rust public parser |
| --- | ---: | ---: |
| Short message, 60 | 3.45 µs | 7.75 µs |
| Mixed Markdown, 10,880 | 0.620 ms | 1.436 ms |
| Mixed Markdown, 43,520 | 2.449 ms | 6.052 ms |
| Single paragraph, 50,400 | 2.110 ms | 4.244 ms |

A 14,800-unit eligible stream with 58 complete-prefix publications took **23.153
ms** in original Dart batch parsing, **46.760 ms** in Rust batch parsing, and
**3.260 ms** in the Rust incremental adapter (whole sequence medians). This is
about **7.1× less parsing time than Dart**, excluding widget work. The first run
measured about 6.6×. It is not an FPS claim.

The frame comparison used a smaller 3,264-unit mixed document, forty changed
publications per backend, both with the same Rust highlighter. The successful
baseline had build median/P95 **3.555/5.535 ms** for Dart and **4.250/9.450 ms**
for Rust. Another run had a lower Rust median but a worse P95. Neither run
showed a stable across-the-board frame improvement. Frame timing covers actual
build/raster work; this is not a scrolling or large-list benchmark.

## Located costs

### 1. Native work plus two Dart object projections

The actual path is:

`Dart source → Rust AST → SMR1 bytes → CoreNode tree → Flutter MarkdownNode tree`

[The stage probe](evidence/macos-profile-2026-11-19-stages.json) measures the
hook-free adapter directly, with 61 observations after warmup. For 43,520 input
UTF-16 units, it produced **467,264 wire bytes and 7,201 wire nodes**:

| Stage | Median |
| --- | ---: |
| Input/buffer preparation | 0.099 ms |
| Native parse and wire serialization | 2.894 ms |
| Copy the result buffer | 0.035 ms |
| Decode the CoreNode tree | 1.228 ms |
| Build the Flutter AST | 0.537 ms |
| Adapter total | 4.973 ms |

Per-stage medians do not sum exactly to the total median. This direct adapter
probe and the public parser baseline use different timing loops; do not assign
the entire difference between 4.973 and 6.052 ms to one unmeasured check.

Confirmed sources of allocation in `lib/src/rust/wire.dart` include eager
`source.substring` for source sentinels and a temporary boxed `List<int>` for
each UTF-16 string before `String.fromCharCodes`. The decoded intermediate tree
is then traversed into another AST in `ast_adapter.dart`. Sampling also shows
allocation, substring, wire/string decoding and adaptation costs. **The raw
buffer copy is small; removing that copy alone will not fix the regression.**

The public parser additionally lowercases the document for disclosure detection
and scans table compatibility before calling Rust. Their isolated cost has not
been measured yet. Rust also performs stricter grammar/source-range work than
the legacy parser, so these are not algorithms doing identical internal work.

Priorities: typed UTF-16 reads, avoid allocating empty/unused source strings,
then decode directly into the supported Flutter AST without changing that API.
Keep bounds, UTF-16/source-range and ownership checks intact.

### 2. Size-oriented Rust compiler configuration

The pinned crate has `opt-level = "s"`, not speed-oriented level 3.
A separate same-input native experiment used an indirect, `black_box` protected
C ABI entry point. Three alternating trials had C ABI medians of approximately
**2.256 ms** for `s` and **2.072 ms** for `3` (about 8% less time). An initial
single trial showed a larger difference, which did not reproduce consistently.
See [raw optimization trials](evidence/macos-native-optimization-2026-11-19.json).
This experiment excludes the Dart bridge and UI; a compiler switch alone will
not eliminate the extra projections. Production compiler settings are unchanged.

### 3. Incremental eligibility excludes real AI example usage

`StreamMarkdown` currently requires no plugin registry, HTML disabled, and no
`<` or `|` in the prefix. `example/lib/ai_chat_demo.dart` passes a plugin registry,
so that example uses batch parsing. A single comparison operator or a pipe in a
code fence also disables incrementality. The core stream ABI itself has no host
hooks, so removing all guards would break plugin/compatibility contracts.

Priorities: accurately identify supported syntax instead of blanket character
exclusions; make any extension capabilities explicit; preserve full-document
fallback for unknown host hooks. Use the real AI-chat fixtures for acceptance.

### 4. Incremental AST does not imply incremental Flutter UI

`StreamMarkdown` passes all retained nodes to `SmoothMarkdown.renderNodes`,
which creates the renderer/builders and rebuilds the document widget tree.
`RepaintBoundary` alone does not skip widget construction or layout.
Committed AST blocks need stable rendering identity and retained widget/layout
work to convert parser savings into consistent end-to-end frame savings.

## Reproduce

The public parser/frame fixture is
`example/integration_test/core_performance_test.dart`; the no-UI stage fixture is
`example/integration_test/core_stages_test.dart`. The latter avoids OS window
scheduling when diagnosing transport costs.

```sh
cd example
flutter drive --profile -d DEVICE_ID \
  --driver test_driver/core_performance_driver.dart \
  --target integration_test/core_performance_test.dart --keep-app-running
flutter drive --profile -d DEVICE_ID \
  --driver test_driver/core_performance_driver.dart \
  --target integration_test/core_stages_test.dart --keep-app-running
```

The driver now writes `build/core-performance/profile-comparison.json` and
`build/core-performance/profile-stages.json` separately to prevent overwriting. On this host, current Xcode's multi-architecture
`lipo -verify_arch` is incompatible with the installed Flutter invocation. The
successful Mac runs used a temporary `XCODE_XCCONFIG_FILE` containing
`ARCHS = arm64` and `ONLY_ACTIVE_ARCH = YES`. No SDK source was modified.

The first evidence file preserves an earlier run whose measurements completed
but whose subsequent menu-navigation cleanup failed. The baseline and stage
reports named above came from successful runs. No transport or rendering
optimizations have been applied as part of this diagnosis.

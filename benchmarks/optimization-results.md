# Compatible shared-core optimizations — 2026-11-19

The following records the first round. See [the second batch investigation and
results](batch-round2-results.md) for the latest implementation and comparison.

Measured on the same **Apple M4 / macOS 27.2 / Flutter 3.41.6 / Dart 3.11.4**,
using Profile/AOT. Public parser inputs, warmup and sample loops are unchanged.
The Android phone is disconnected, so these results are **not Android numbers**.

## Implemented, in order

1. **Decode directly into the supported Flutter AST.** Production batch and
   stream paths no longer allocate a whole `CoreNode` tree and adapt it again.
   UTF-16 uses aligned typed views where possible, including a checked unaligned
   fallback. Empty strings and unused source fields do not allocate per-node
   temporary lists/substrings. Bounds, depth/count, source ranges, custom node
   ownership and explicit/sentinel source forms remain checked. The old decoder
   and adapter remain as a contract-test reference.
2. **Broaden the proven-safe incremental subset.** Valid GFM tables, comparison
   operators and pipes/less-than signs in code no longer disable incremental
   parsing merely because of those characters. Exact built-in plugins whose
   syntax cannot occur in the prefix can use the native stream without hooks.
   Active extensions, unknown/custom plugin subclasses, enabled HTML, disclosures
   and legacy ragged tables retain their batch fallback. In particular, active
   thinking/artifact/tool blocks are still batch; the shared stream ABI has no
   hooks. No parser is silently selected by document length.
3. **Retain completed built-in block widgets.** The stream preserves widget
   identity alongside retained AST identity, allowing unchanged subtrees to skip
   build/layout work. Removed nodes are pruned. Stream changes, host rebuilds,
   styles and inherited dependencies invalidate widgets. Custom code/image/block
   builders retain per-publication evaluation. Selection, callbacks, spacing and
   renderer configuration keep their existing contracts.
4. **Compile native assets for throughput.** The Flutter build hook defaults to
   optimization level 3 instead of the upstream crate's size-oriented level.
   At this first-round checkpoint, vendored Rust sources, ABI, and source hashes
   remained unchanged.

Existing constructors and callbacks remain usable. `renderNodes` and
`MarkdownRenderer.render` only gain an optional block cache; normal callers do
not need to supply it. A cache supplied directly by advanced callers must obey
its documented identity/invalidation rules.

## Same-input batch and incremental results

| Input | Rust before | Rust after | Less time |
| --- | ---: | ---: | ---: |
| 60-unit short message | 7.75 µs | 4.31 µs | 44% |
| 10,880-unit mixed Markdown | 1.436 ms | 0.806 ms | 44% |
| 43,520-unit mixed Markdown | 6.052 ms | 3.452 ms | 43% |
| 50,400-unit single paragraph | 4.244 ms | 2.247 ms | 47% |

The same-input original Dart parser in the optimized run takes approximately
**0.625 / 2.571 / 2.140 ms** for the three documents. Thus the batch Rust path is
still slower than Dart by about **29% / 34% / 5%** on these fixtures. This work
reduces the regression; it does not establish Rust batch superiority.

For 14,800 UTF-16 units across 58 eligible stream publications:

| Whole sequence | Before | After |
| --- | ---: | ---: |
| Rust batch | 46.760 ms | 26.429 ms |
| Rust incremental | 3.260 ms | 2.661 ms |
| Original Dart batch control | 23.153 ms | 22.249 ms |

Incremental parsing is approximately **8.4× faster than the same-run Dart batch
control** here. This excludes widget work and active extension fallback paths.

## Measured bridge stages

For 43,520 units, with the same 467,264-byte / 7,201-node SMR1 buffer:

| Stage | Before | After |
| --- | ---: | ---: |
| Native parse + wire | 2.894 ms | 2.022 ms |
| Decode then adapt / direct decode | 1.228 + 0.537 ms | 0.810 ms |
| Direct adapter total | 4.973 ms | 3.013 ms |

The Dart decoding/adaptation portion uses about **54% less time**. Native and
public-parser measurements have distinct loops; per-stage medians need not add
exactly to the total, and the native difference is not solely attributable to a
single compiler flag. The protocol itself was not changed.

## Actual streaming widget build timings

A new paired test feeds identical complete chunks to real `StreamMarkdown`
widgets: forty publications, a 3,264-unit starting document containing tables,
the example's thinking/artifact/tool-call plugin registry, no active extension
markers, the same highlighter, and publication intervals above the 50ms throttle.
Both backends run in the same window. These are the new run's paired controls,
not historical numbers for an unmeasured older stream-widget fixture.

| Build metric | Original Dart backend | Optimized Rust stream | Less time |
| --- | ---: | ---: | ---: |
| Median | 5.296 ms | 3.252 ms | 39% |
| P95 | 11.468 ms | 5.149 ms | 55% |

**Raster timing did not improve consistently**: median/P95 were 0.988/2.176 ms
for Dart and 1.275/3.709 ms for the Rust stream in this run. The optimization
retains build/layout work; it does not guarantee a GPU/raster win. Both paths
still lay out a whole document container rather than virtualizing offscreen
content. Static whole-document frame measurements also remain variable.

## Compatibility checks

- The direct decoder matches the previous decoder/adapter on all **676**
  CommonMark/GFM fixtures. Further checks cover every UTF-16 prefix of Unicode
  content, unaligned buffers, truncated records, invalid kind/flags and depth.
- Inactive built-in AI registries are compared with batch hooks across eligible
  conformance fixtures; valid table/code/operator prefixes match batch output.
- Widget tests check retained identity, style changes, active-plugin transition,
  custom-builder callbacks, reference invalidation and stream replacement.
- Full Flutter run: **1,148 passed**, with the same three previously observed
  Mermaid golden mismatches. Two further decoder contract tests were added and
  checked separately. No golden baselines were regenerated.
- Speed-oriented Rust conformance/stream tests and the five example tests pass.
  Web preview compilation is checked separately.

## Evidence and reproduction

- [Original successful-run aggregates](evidence/macos-profile-2026-11-19-baseline.json)
- [Original complete first-run samples](evidence/macos-profile-2026-11-19-first.json)
- [Optimized full parser/frame samples](evidence/macos-profile-2026-11-19-optimized.json)
- [Original stage samples](evidence/macos-profile-2026-11-19-stages.json)
- [Optimized stage samples](evidence/macos-profile-2026-11-19-stages-optimized.json)

The original successful run's full sample file was overwritten by the old
shared report filename; only its verified printed aggregates could be recovered.
The separate complete first-run sample distribution shows the same batch
regression (43.5k-unit Rust median 6.218 ms) and records its later UI-cleanup
failure. Against that complete first run, the new batch result is about 45%
faster. No missing raw samples were reconstructed or invented.

The driver now keeps `profile-comparison.json` and `profile-stages.json` separate.
Reproduction commands and the temporary single-architecture Xcode workaround
are in [the baseline methodology](README.md#reproduce). Frame data is one
observational run of forty frames per path; Android, other hardware, long
single containers, active extensions and custom builders need their own
measurements before making broader performance claims.

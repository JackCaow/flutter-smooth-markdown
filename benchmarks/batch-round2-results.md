# Static batch investigation, round 2 — 2026-11-19

For the subsequent comparison with Dart also using incremental parsing, see
[equivalent incremental strategy results](equal-incremental-results.md). The
streaming comparisons below used the older Dart full-parse control.

**43,520-unit mixed Markdown: 3.452 → 2.646 ms, 23% less time than round 1.**
The same final run's Dart control takes 2.561 ms: Rust is still about **3% slower**
on that fixture. This does not establish an across-the-board Rust batch win.

Apple M4, macOS 27.2, Flutter 3.41.6 / Dart 3.11.4, Profile/AOT, Rust optimization
level 3. The input, public parser calls, warmup, nine sample groups and iteration
counts match [round 1](optimization-results.md). Native and Dart work run on the
same isolate. Android is disconnected; these are host measurements.

## What accounted for the remaining regression

The additional stage test interleaves compatibility checks, direct native calls,
public Rust parsing and the Dart control in one process. It measures the guard
instead of attributing the difference between unrelated stage/benchmark runs to
it. For 43,520 units:

| Component | Before this round | After this round |
| --- | ---: | ---: |
| Compatibility guard, isolated | 278 µs | 83 µs |
| Input allocation/copy | 98 µs | 23 µs |
| Native parse + encoding | 2,008 µs | 1,705 µs |
| Result copy into Dart memory | 33 µs | 33 µs |
| Direct Flutter AST decoding | 814 µs | 601 µs |
| Direct stage-probe total | 3,004 µs | 2,398 µs |

Per-stage medians do not sum to the total median. The separate interleaved
public-parser medians are **3,407 → 2,596 µs**, with Dart **2,509 → 2,522 µs**.
These are diagnostic loops, separate from the full end-to-end benchmark below.

A disposable native probe compares patched and unpatched copies at the same
compiler setting. Median parse-and-drop decreases **1,759 → 1,420 µs** (19%).
Encoding an already-built tree stays approximately **147 → 149 µs**; UTF-16
input conversion is approximately **48 µs**. Thus the native cost was primarily
parser allocations, text decoding and emphasis bookkeeping, rather than the
FFI call or serialization alone. The remaining Dart AST construction is still
real work that the original Dart parser does not have to repeat across a wire.
Standalone probe times are diagnostic, not interchangeable with Flutter totals.

## Changes and compatibility

- The legacy table guard scans candidate line ranges rather than splitting the
  document and running a delimiter regular expression repeatedly. The scanner
  preserves the old expression's whitespace and cell-count rules, including
  conservative decisions inside code fences, escaped pipes and ragged rows.
- Native input preparation copies UTF-16 code units directly into the native
  typed buffer, avoiding the generic code-unit iterable copy. Embedded NULs and
  isolated surrogates retain their existing handling.
- The decoder reuses one aligned UTF-16 view with checked range decoding,
  removes per-node capturing helper closures, and recognizes the standard text
  leaf layout. Explicit sources and nonstandard fields use the general decoder.
  Bounds, node counts, depth, required/null fields and ownership checks remain.
- A small Rust patch avoids escape/entity decoding for plain text, skips emphasis
  tables when fewer than two tokens exist, reads delimiter spans directly and
  moves children into emphasis wrappers instead of deep-cloning them.

No supported Dart API, AST shape, callback contract, backend selection, C ABI or
SMR1 format changed in this round. No document-length routing or result cache
was introduced to improve batch numbers. Active plugin/HTML/disclosure and
legacy-table fallbacks keep their existing behavior.

To control upgrade cost, the Rust changes are an explicit
[patch](../tools/rust-core-patches/0001-inline-allocation.patch), recorded in
`rust-core/UPSTREAM`; `SOURCE.sha256` hashes the resulting patched source.
The sync script stages clean upstream source and checks patches before replacing
vendored files. A conflict or an upstream that already contains the patch fails
for review while preserving the current snapshot. The native probe reverses the
patch in a temporary reference crate to check full AST equality independently.

## Full public-parser comparison

All values below are medians. “Before” is the prior completed optimization
round, not the original slower integration.

| Input (UTF-16 units) | Rust before | Rust after | Less time | Same-run Dart |
| --- | ---: | ---: | ---: | ---: |
| Short message (60) | 4.31 µs | 3.82 µs | 12% | 3.49 µs |
| Mixed document (10,880) | 0.806 ms | 0.625 ms | 22% | 0.649 ms |
| Mixed document (43,520) | 3.452 ms | 2.646 ms | 23% | 2.561 ms |
| Single paragraph (50,400) | 2.247 ms | 1.852 ms | 18% | 2.906 ms |

The short message remains slower than Dart by about 9%. The 10.9k document is
about 4% faster in this run, close enough that run-to-run variability matters.
The single-paragraph Dart control varied substantially between runs (2.140 ms
in round 1 versus 2.906 ms here); its 36% same-run advantage must not be treated
as a stable cross-device claim. Raw samples are retained below.

For 14,800 units / 58 publications:

| Whole sequence | Rust before | Rust after | Same-run Dart batch |
| --- | ---: | ---: | ---: |
| Batch | 26.429 ms | 22.313 ms | 22.554 ms |
| Incremental | 2.661 ms | 1.809 ms | 22.554 ms |

The incremental path uses 32% less time than round 1 on this fixture; active
extension fallback is not represented by this hook-free sequence.

## Example and frame checks

The same example integration test successfully exercised both static rendering
and actual `StreamMarkdown` updates, then opened the Code & Diff demo. Forty
frames were recorded for each path, with the same source, highlighter and window.

| Build metric | Dart | Rust |
| --- | ---: | ---: |
| Static median / P95 | 3.116 / 4.465 ms | 2.407 / 3.861 ms |
| Stream median / P95 | 2.946 / 5.646 ms | 2.041 / 3.828 ms |

Stream raster median/P95 was **0.661/1.200 ms for Dart** and **0.995/2.263 ms for
Rust**. As in round 1, build improvements do not imply a consistent raster/GPU
improvement. Frame results are observational runs, not a physical-device claim.

## Verification

- Full Flutter suite: **1,154 passed**, the same **three pre-existing Mermaid
  golden mismatches**; no golden baselines updated.
- Focused Rust/parser/editor/stream/renderer suite: **656 passed** before the
  final input-copy change and added layout test; the final full suite covers both.
- All **73 Rust tests** pass at optimization level 3; two benchmark tests remain
  intentionally ignored. Includes every-character-prefix stream conformance.
- Direct decoder/old adapter equality across **676 CommonMark/GFM fixtures**,
  Unicode prefixes, malformed/truncated buffers, unaligned data and explicit
  source/nonstandard text layouts.
- Guard equivalence across all fixtures, 10,000 generated documents, prefixes,
  and every BMP code unit used as delimiter whitespace.
- Patched/unpatched Rust full AST equality on **676 fixtures + 10,000 generated
  documents × four option combinations**, both full parse and custom-hook inline
  parse. The public C/wire signatures remain unchanged.
- Five example tests pass; static analysis reports zero errors and warnings.
- The Web preview builds successfully, including the Wasm dry run.
- Clean-source sync and conflict-preserves-snapshot checks pass; source hashes
  and `git diff --check` pass.

## Evidence and reproduction

- [Round 1 complete benchmark](evidence/macos-profile-2026-11-19-optimized.json)
- [Before: interleaved diagnostics](evidence/macos-profile-2026-11-19-round2-before-stages.json)
- [After: interleaved diagnostics](evidence/macos-profile-2026-11-19-round2-after-stages.json)
- [Final complete benchmark and frame samples](evidence/macos-profile-2026-11-19-round2-final.json)
- [Native probe samples and AST comparison result](evidence/macos-native-2026-11-19-round2.json)

Use the existing [Profile/AOT reproduction commands](README.md#reproduce).
Run `integration_test/core_stages_test.dart` with the same driver for stages;
the driver saves the stage and full benchmark reports separately. Native probe:

```sh
python3 benchmarks/probes/native_profile.py > native-profile.json
```

The native probe modifies only disposable copies to expose private encoding for
measurement and distinguish duplicate C symbols. Neither modification is part
of the production ABI. Stage aggregates have microsecond timer resolution;
interleaved and full benchmark sample arrays are included in their evidence.

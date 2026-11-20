# Equivalent incremental strategy: Dart versus Rust — 2026-11-19

This records the comparison before the subsequent
[bridge and node-layout optimizations](bridge-optimization-results.md).

For retained heap and process RSS, see the subsequent
[30-process memory comparison](memory-results.md).

**With the same incremental strategy and verified source ranges, Rust is not
faster on the measured ordinary streaming documents.** Dart takes 1.540 ms versus
Rust 1.790 ms for the 14.8k-unit sequence, and 7.154 ms versus 8.103 ms for the
43.5k-unit sequence. Rust uses 16% / 13% more time respectively. Rust retains an
advantage on the long single-paragraph control, where neither engine can retain
a completed prefix. These are full-session times, not time per publication.

## Implemented comparison

The existing Dart grammar now has a package-internal incremental session backed
by the original block and inline parsers. Original source starts are captured
during block parsing; they are not guessed by joining AST text. The policy is
the same as `rust-core/src/stream.rs`:

1. On append, retain all but the last two top-level blocks and parse the tail.
2. On a non-append edit, clear retention and parse the complete replacement.
3. Scan across chunk boundaries for `]:`; definitions conservatively invalidate
   the whole document on subsequent appends, including false positives in code.
4. An unchanged prefix retains every block and parses zero units.
5. Return the complete flattened Flutter AST, retaining committed node identity.

`StreamMarkdown` uses this path for `legacyDart`, and for Web `automatic`. Native
`automatic` / `rust` keep their previous Rust selection. Both use the same widget
identity cache, pruning, style/dependency invalidation and custom-builder rules.
HTML, disclosures, ragged tables, active extensions and unknown plugins keep the
existing full-parser route. Static `MarkdownParser.parse` remains a full parse.
There are no new supported constructors, flags or session types to migrate to.

Each backend preserves its own existing batch semantics. In particular, this
change does not add Rust reference-link behavior to the Dart grammar. The
benchmark compares complete implementations with a controlled incremental
policy, rather than measuring an isolated language/runtime difference.

## Method and exact work equality

Apple M4, macOS 27.2, Flutter 3.41.6 / Dart 3.11.4, Profile/AOT, Rust opt-level 3.
All four paths run in the same process: Dart batch, Rust batch, Dart incremental
and Rust incremental. Each receives five warmup sequences and nine sample groups
of two whole sequences. Measurement order rotates between sample groups. Native
input copies, FFI, wire decoding, Flutter AST adaptation, result flattening and
session construction/disposal are included. AST inspection happens outside the
timed loops. A consumed block count prevents discarding all parse results.

Before timing, the test checks every publication against its backend's batch
AST. Separately, a diagnostic native session reads actual native top-level spans
and returned retention counts. Dart's parsed ranges and retained counts must
match those native arrays **at every publication**, or the benchmark fails.

| Sequence | Publications | Batch units processed | Incremental units, both engines |
| --- | ---: | ---: | ---: |
| Short message, 60 units | 10 | 330 | 330 |
| Original stream, 14,800 units / 256-unit chunks | 58 | 437,968 | 17,893 |
| Mixed Markdown, 43,520 units / complete sections | 160 | 3,503,360 | 61,805 |
| Single paragraph, 50,400 units / 512-unit chunks | 99 | 2,534,112 | 2,534,112 |
| Global definitions, 5,949 units / 256-unit chunks | 24 | 76,605 | 76,605 |

The mixed-document case publishes complete 272-unit sections so table delimiter
prefixes do not introduce different compatibility-route transitions. The original
14.8k stream uses the exact 256-unit publication sequence from the previous
reports. The other cases expose fixed overhead and lack of retention, rather
than assuming every input benefits from incremental parsing.

## CPU results

Medians below cover the **whole publication sequence**:

| Sequence | Dart batch | Dart incremental | Rust batch | Rust incremental | Rust incremental time vs Dart |
| --- | ---: | ---: | ---: | ---: | ---: |
| Short message | 19.5 µs | 21.5 µs | 27.0 µs | 31.0 µs | +44% |
| Original 14.8k stream | 22.423 ms | 1.540 ms | 22.112 ms | 1.790 ms | +16% |
| Mixed 43.5k stream | 199.120 ms | 7.154 ms | 205.098 ms | 8.103 ms | +13% |
| Single paragraph | 106.464 ms | 109.244 ms | 87.527 ms | 85.854 ms | −21% |
| Global definitions | 3.982 ms | 4.190 ms | 6.089 ms | 6.155 ms | +47% |

Dart incremental is **14.6× faster than its batch control** for the original
stream; the strategy reduces parsed units by 95.9%. The earlier roughly 12.5×
Rust-incremental versus Dart-batch comparison primarily demonstrated algorithmic
reuse. It did not isolate a Rust advantage.

The existing example benchmark independently repeats the original 14.8k sequence:
**Dart incremental 1.489 ms, Rust incremental 1.719 ms**, again about 15% more
time for Rust. Its batch controls are 22.443 / 22.100 ms.

The Rust integration still converts/copies the complete UTF-16 prefix for each
call and decodes the returned tail across the FFI boundary. Dart parses its tail
directly into the existing Flutter AST. These are costs in the measured paths;
this experiment does not assign the entire remaining difference to one stage.

## Actual example widget comparison

The example also feeds identical publications to both `StreamMarkdown` backends
with the same inactive AI registry, tables, highlighter, throttling interval and
completed-widget cache. Forty frames are captured per path:

| Stream frame metric | Dart incremental | Rust incremental |
| --- | ---: | ---: |
| Build median / P95 | 2.166 / 3.721 ms | 3.072 / 4.098 ms |
| Build average | 2.352 ms | 2.707 ms |
| Raster median / P95 | 1.299 / 1.917 ms | 1.606 / 2.166 ms |

These are observational host frame samples. Build/layout/raster work and
scheduling contribute to them, so they are not an isolated parser-language
measurement. The previous UI comparison used Dart full parsing; these new
stream-frame controls both use incremental sessions and widget reuse.

## Compatibility and verification

- Dart incremental matches the original Dart batch AST on every UTF-16 prefix
  of all **676 CommonMark/GFM fixtures**, with a committed prefix to exercise
  actual retention. This is equivalence to the legacy grammar, not a new claim
  that it conforms to every CommonMark/GFM rule.
- Tests cover 500 generated append/replacement sequences, nested lists/quotes,
  tables, Unicode/isolated surrogates, CRLF, unchanged input, two-block rollback,
  global-definition invalidation, disposal, error recovery and retained identity.
  The existing legacy CRLF-header parse error remains an error.
- Widget tests cover both backend caches, styles, active-plugin transitions,
  unknown-plugin callbacks, custom builders, backend switching on the same
  buffer, and stream replacement. Backend switching reparses with the selected
  grammar instead of reusing a stale AST from the other backend.
- Full Flutter suite: **1,162 passed**, with the same three pre-existing Mermaid
  golden mismatches. No golden baselines updated.
- Five example tests pass. Static analysis has zero errors and warnings.
- Web preview builds, including the Wasm dry run. No physical-device performance
  claim is made in this round.

## Evidence and reproduction

- [Same-strategy CPU samples and per-publication work counters](evidence/macos-profile-2026-11-19-equal-incremental.json)
- [Independent example CPU repeat and actual widget frame samples](evidence/macos-profile-2026-11-19-both-incremental-example.json)
- [Prior static-batch investigation](batch-round2-results.md)

From `example/`, run:

```sh
flutter drive --profile -d macos \
  --driver test_driver/core_performance_driver.dart \
  --target integration_test/incremental_performance_test.dart

flutter drive --profile -d macos \
  --driver test_driver/core_performance_driver.dart \
  --target integration_test/core_performance_test.dart
```

The first report is written to `build/core-performance/profile-incremental.json`;
the second to `profile-comparison.json`. See [the host build workaround](README.md#reproduce)
for this machine's temporary arm64 Xcode configuration. The work-accounting
probe uses the old tree decoder only outside timed loops and changes no C ABI.

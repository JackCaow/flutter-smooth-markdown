# Sustained-stream RSS investigation — 2026-11-20

Actual Flutter frame work is measured separately in
[the streaming-render comparison](render-results.md); the CPU figures below
cover parsing and result publication.

The 435,200-UTF-16-unit, 1,600-publication stress case now retains **17.08 MiB
RSS above its prepared-input baseline**, down from **25.70 MiB (−33.6%)**.
The unchanged Dart incremental control measures **17.89 MiB**. Their ranges
overlap: this resolves the previous material retained-RSS disadvantage without
establishing a universal Rust memory advantage. Sampled workload peaks remain
higher in Rust.

Apple M4, macOS 27.2, Flutter 3.41.6 / Dart 3.11.4, Profile/AOT, Rust opt-level 3.
These measurements cover parser/AST/session work, not article widgets, images,
scrolling or mobile-device FPS.

## Located cost and change

The large discrepancy was chiefly in the host bridge's allocation pattern.
The Rust session retains source units and block statistics, not a committed
Rust AST. In the diagnostic baseline, whole-process malloc in-use growth is
about **1.55 MiB** for Rust, which cannot account for the roughly 8 MiB retained
RSS difference. `malloc_zone_pressure_relief(NULL, 0)` returns zero. VM region
inspection places most additional residency in **Untagged anonymous mappings**;
VM heap-space counters also show different young/old generation capacities.
These observations do not assign every RSS page to a particular VM allocation.

The adapter previously executed `List.unmodifiable(_nodes)` on every update.
In this fixture, publishing all prior nodes copies **6,404,000 node references**
over one sequence, despite reparsing only two trailing blocks. These temporary
lists affect GC scheduling, heap capacity and resident free pages, so their RSS
effect exceeds the final retained list's size.

`StreamSnapshot` now presents the same immutable `List<MarkdownNode>` interface
using private **128-node pages**. Completed pages are shared. Each publication
copies the page directory, at most 127 retained boundary nodes, and the new tail.
No mutable parser buffer backs an earlier publication. Native block-end offsets
still handle omitted reference groups and list groups that project into several
Flutter nodes. Edits, failures and disposal release the session's current
snapshot without changing results already returned to callers.

Only the Dart native bridge changed in production. The Rust framework's SHA-256
is identical between the before/after memory runs. Supported constructors,
callbacks, AST schemas, C ABI/SMR1, eligibility/fallback decisions, two-block
rollback and global-definition invalidation are unchanged. The existing Dart
incremental parser and its publication implementation remain unchanged.

A prototype also applied paged publication and separate start offsets to Dart.
Its three-process median RSS increased to 23.22 MiB despite lower reported heap
usage. That prototype was discarded; its evidence remains separate. Equivalent
incremental **parsing policy** does not require identical internal collection
representations. The accepted comparisons verify equal parsed ranges and
retained block counts at every publication.

## Memory comparison

Six fresh processes establish this round's 435k before control. Thirty fresh
processes cover five after scenarios, two backends and three trials per cell.
Input is prepared before baseline. Prefixes are generated on demand, without
retaining all intermediate strings. Host-requested GC runs twice at each
baseline, retained and released snapshot. Backend order alternates by trial;
runner, Dart AOT and Rust framework fingerprints are recorded.

435k medians, with min–max in brackets. All RSS values are **increments above
each process's baseline**, not total application memory:

| Metric | Rust before | Rust after | Current Dart |
| --- | ---: | ---: | ---: |
| Retained RSS after requested GC | 25.70 [24.86–26.23] MiB | **17.08 [16.88–17.80] MiB** | 17.89 [17.66–18.56] MiB |
| Max sampled RSS during updates | 33.59 [32.84–34.91] MiB | 31.02 [28.69–32.36] MiB | 26.73 [24.23–28.14] MiB |
| VM-reported Dart heap increment after requested GC | 5,540.95 KiB | 5,479.45 KiB | 5,751.73 KiB |
| VM-reported heap capacity increment | 10.16 MiB | 6.08 MiB | 10.58 MiB |
| Whole-process malloc in-use increment | — | 1.49 MiB | 0.32 MiB |

The unchanged Dart before control measured 18.03 [17.42–18.06] MiB retained RSS,
close to its after control. Rust's improvement is therefore not produced by a
worse accepted Dart implementation. The reduction is primarily resident VM
overhead, rather than an 8 MiB reduction in final AST payload.

The sampled peak is the maximum `ProcessInfo.currentRss` immediately after an
update. It is a lower bound on the actual peak inside calls. OS lifetime
`maxRss` is also recorded; its median growth above baseline high-water is
26.41 MiB for Rust and 22.98 MiB for Dart. Startup can mask workload peaks in
that metric. Neither peak metric establishes a Rust advantage.

All after scenarios, retained RSS increments (medians):

| Scenario | Rust | Dart |
| --- | ---: | ---: |
| Incremental 14,800 units / 58 updates | 1.38 MiB | 2.67 MiB |
| Incremental 43,520 units / 160 updates | 5.42 MiB | 7.48 MiB |
| Incremental 435,200 units / 1,600 updates | 17.08 MiB | 17.89 MiB |
| Static 43,520 units | 2.06 MiB | 3.33 MiB |
| Static 435,200 units | 20.08 MiB | 23.23 MiB |

Releasing the AST/session returns the reported Dart heap exactly to baseline
in all 30 samples. RSS retains resident capacity; this is not a long-duration
native leak test. Tracked Dart external bytes do not include ordinary Rust
allocations. macOS malloc counters aggregate all process zones, not Rust alone.

## CPU comparison and tradeoff

The 435k probe creates the same prefixes lazily in each lane and includes prefix
creation, session creation/disposal, FFI, decoding and result publication. It
verifies all 1,600 parsed ranges and retained-block counts, plus own-backend
batch AST equality at publications 1, 2, 320 and 1,600. Both parsers process
**619,085 UTF-16 units**; Rust transfers 435,200 input units.

Cross-process before/after CPU runs showed substantial host variation, including
their unchanged Dart controls. A frozen copy of the previous native adapter in
`integration_test/support/flat_native_stream.dart` provides the old full-list
publication path in the **same AOT process**, with the same ABI checks,
finalizer, source transfer, buffer lifetime and decoder. All three lanes rotate
order over nine groups, two full sequences per group, after five warmups.
Published lengths are consumed and the final checksum is verified as positive.

Whole-sequence CPU medians:

| 435k / 1,600 updates | Time |
| --- | ---: |
| Old Rust bridge, frozen same-process control | 429.33 ms |
| Current Rust bridge | **453.93 ms** |
| Unchanged Dart incremental | 500.33 ms |

This is a **5.7% CPU cost versus the old Rust bridge**, about 24.6 ms over 1,600
updates, alongside the 33.6% retained-RSS reduction. Current Rust takes about
**9.3% less time than same-strategy Dart**. An earlier same-process run measured
439.18 / 455.30 / 505.31 ms for old Rust / current Rust / Dart, a 3.7% cost;
it preceded adding the old adapter's ABI-version check to its probe constructor.
Both runs show a small CPU tradeoff. This round is a memory optimization, not
an across-the-board CPU improvement.

The original five-case benchmark also completed. It preallocates prefixes and
therefore has different timing scope from the new 435k probe:

| Sequence | Rust incremental | Same-run Dart incremental |
| --- | ---: | ---: |
| Short message / 10 updates | 28.0 µs | 21.5 µs |
| 14,800 units / 58 updates | 1.369 ms | 1.564 ms |
| Mixed 43,520 units / 160 updates | 6.222 ms | 7.185 ms |
| Single paragraph 50,400 units / 99 updates | 78.805 ms | 110.718 ms |
| Global definitions / 24 updates | 5.959 ms | 4.161 ms |

The ordinary 14k/43k Rust timings remain close to the preceding bridge round.
Definitions retain full invalidation and each backend's existing grammar;
short-message and definition-heavy cases still favor Dart.

## Verification and evidence

- New snapshot tests retain hundreds of old publications, vary rollback/edits
  across page boundaries, mutate caller-owned tail arrays, and exercise List
  mutation APIs including empty/no-op writes. Native AST snapshots remain
  stable after later updates, replacements and disposal, with retained node
  identities preserved.
- Rust/stream regression group: **55 passed**. Full Flutter suite: **1,167
  passed**, with the same three pre-existing Mermaid golden mismatches. No
  golden baseline was changed. Rust source and ABI are unchanged in this round.
- Example tests: **5 passed**. Web preview build succeeded, including the default
  Wasm dry run (existing compatibility/font notices remain). Static analysis:
  **zero errors/warnings**, 296 style/info diagnostics. Example dev dependencies
  explicitly declare the frozen probe's FFI dependency; its SDK constraint now
  matches the package's existing Dart 3.10 minimum.

Primary evidence:

- [Six-process before memory control](evidence/macos-memory-2026-11-20-rss-before/summary.json)
- [Thirty-process final memory summary](evidence/macos-memory-2026-11-20-rss-final/summary.json)
- [Same-process 435k CPU samples](evidence/macos-profile-2026-11-20-sustained-final.json)
- [Original five-case CPU samples](evidence/macos-profile-2026-11-20-incremental-final.json)
- [Allocator/region diagnostics and intervention notes](evidence/macos-rss-diagnostics-2026-11-20/README.md)
- [Discarded shared-publication prototype](evidence/macos-memory-2026-11-20-snapshot-pilot/summary.json)

The `*-pilot.json` files,
[separate baseline CPU run](evidence/macos-profile-2026-11-20-sustained-before.json)
and [cross-run after sample](evidence/macos-profile-2026-11-20-sustained-cross-run-final.json)
preserve exploratory measurements. The paired same-process result above is the
accepted CPU comparison; [the earlier paired run](evidence/macos-profile-2026-11-20-sustained-paired-first.json)
is also retained. Diagnostic region
walks and allocator interventions are excluded from primary acceptance samples.

Reproduce from the repository root:

```sh
python3 benchmarks/probes/memory_profile.py --output /tmp/smooth-memory
# Focused before/after control, using the appropriate checkout:
python3 benchmarks/probes/memory_profile.py --cases stream_435k --output /tmp/smooth-435k
cd example
flutter drive --profile --no-pub -d macos \
  --driver test_driver/core_performance_driver.dart \
  --target integration_test/sustained_performance_test.dart
```

This host uses the existing temporary `XCODE_XCCONFIG_FILE` with `ARCHS = arm64`
and `ONLY_ACTIVE_ARCH = YES`; the Flutter SDK is unmodified. For diagnostic-only
runs, the memory driver recognizes `SMOOTH_MEMORY_DIAGNOSE=1` for heap-space
counters plus a post-measurement allocator-relief intervention, and
`SMOOTH_MEMORY_VMMAP=1` for baseline/retained region summaries. These alter the
observed process and must remain outside acceptance runs.

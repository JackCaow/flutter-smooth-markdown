# Bridge and node-layout optimizations — 2026-11-19

The retained 435k RSS disadvantage recorded here is addressed by the
[2026-11-20 sustained-stream follow-up](sustained-rss-results.md). This report
preserves the earlier measurements.

**Ordinary incremental Rust paths now take 10–12% less time than same-strategy
Dart controls on this host.** Large static-parse RSS peak growth drops from
66.42 to 19.23 MiB. There is still a material limitation: the 435k incremental
stress case retains **25.42 MiB RSS above baseline versus Dart's 17.25 MiB**,
despite a smaller live Dart heap. These changes do not establish an all-workload
memory advantage.

Apple M4, macOS 27.2, Flutter 3.41.6 / Dart 3.11.4, Profile/AOT, Rust opt-level 3.
The [previous equal-strategy CPU results](equal-incremental-results.md) and
[previous memory results](memory-results.md) are retained as before evidence.

## Implementation

1. **Transfer only the appended UTF-16 suffix.** An optional ABI-1 extension,
   `smr_stream_append_utf16`, extends the native session's owned source. Existing
   full-prefix update still handles replacements and remains compatible with
   sessions that used append. The Dart adapter compares the previous complete
   string to detect replacements exactly; no hash-only edit detection is used.
   Rollback, definitions, limits and error invalidation keep their old policy.
2. **Decode inside the native buffer's lifetime.** Batch/inline and stream AST
   readers consume a checked native typed-data view synchronously, then free the
   Rust owner in `finally`. Published strings and AST objects own their data.
   This removes a full result-buffer copy; it does not expose native pointers
   or borrowed views through the supported API.
3. **Encode completed top-level blocks and release them.** The C batch parser
   no longer retains the entire Rust forest alongside the accumulating SMR1
   buffer. Nested parsing and inline delimiter resolution still build the
   subtree currently needed. Reference definitions rewind the sink and perform
   the established resolution pass, preserving final bytes and callback order.
   The ordinary Rust AST API also drops its first-pass tree before constructing
   its reference-resolved tree. A full Flutter AST is still required at the end.
4. **Make cold node metadata lazy.** Flutter's private `flutter-compact-ast`
   feature reduces the 64-bit hot node struct from **240 to 96 bytes**. String
   contents, child buffers and optional boxed attributes are additional memory;
   this is not a claim of 60% less total AST memory. The default Rust build keeps
   its original public struct API; only the internal Flutter build opts in.
   Semantic equality and Debug output preserve the original representation.
5. **Retain flat Flutter nodes with native-block end indices.** This removes
   one adapted list per native block and repeated nested-iterator flattening.
   Empty reference blocks and lists that adapt into multiple Flutter lists
   retain the exact native block indexing and node identity.

No supported Flutter constructor, callback, AST schema, backend-selection or
compatibility-route contract changed. SMR1 bytes and all existing C signatures
remain compatible. Native automatic selection stays Rust; Dart incremental uses
the existing `legacyDart` policy. The added append entry is bundled with the
pinned source; old C consumers may continue using complete-prefix update.

Both shared-core changes are tracked in `tools/rust-core-patches/`, recorded in
`UPSTREAM`, and included in the resulting source hash manifest. The sync script
checks patches in staging before replacing the vendor tree. Default and compact
builds are tested separately to protect the ordinary Rust source API.

## Equal-strategy CPU comparison

The original paired benchmark is unchanged apart from transport metadata and
input-transfer counters: same inputs, publications, two-block rollback policy,
five warmup sequences, nine rotating sample groups, two sequences per group.
Every publication matches its backend's batch AST. Actual native and Dart
retention counts and parsed source ranges must agree before timing starts.
Native creation/disposal, FFI, decoding and output flattening are included.

These are **whole-sequence medians**, not single-publication times:

| Sequence | Rust before | Rust after | Same-run Dart incremental | Rust time vs Dart |
| --- | ---: | ---: | ---: | ---: |
| 60-unit message, 10 updates | 31.0 µs | 27.5 µs | 21.5 µs | +28% |
| 14,800 units, 58 updates | 1.790 ms | 1.387 ms | 1.549 ms | −10% |
| Mixed 43,520 units, 160 updates | 8.103 ms | 6.194 ms | 7.024 ms | −12% |
| Single paragraph 50,400 units, 99 updates | 85.854 ms | 87.872 ms | 128.439 ms | −32% |
| Global definitions, 24 updates | 6.155 ms | 7.047 ms | 5.232 ms | +35% |

The two ordinary streaming cases use approximately **22% / 24% less time than
the previous Rust implementation**. An earlier optimized run independently
measured 1.353/1.511 ms and 6.268/7.011 ms for Rust/Dart on those same cases.
Long-paragraph and full-reparse controls vary more between runs: the final
Rust paragraph result is about 2% slower than its historical Rust median,
although faster than its same-run Dart control. No universal gain is claimed.
Definitions remain a full-reparse path, and the two existing grammars differ in
reference-link functionality; that case is not a pure language comparison.

Transferred input shrinks from **437,968 → 14,800 UTF-16 units** for the original
stream and **3,503,360 → 43,520 units** for the mixed sequence. The amount of text
actually parsed is unchanged: **17,893 / 61,805 units** for both engines.

## Memory: same fresh-process methodology

Thirty fresh processes cover five scenarios, both backends and three trials.
Prepared input is excluded from the incremental baseline; intermediate prefixes
are created as updates occur. The host forces GC twice at each retained/released
snapshot. Results cover parsing/AST/session retention, not complete article
widgets, images or scrolling caches. Measurements are not mobile-device claims.

GC-surviving Dart heap above baseline, medians:

| Scenario | Previous Rust | Current Rust | Current Dart |
| --- | ---: | ---: | ---: |
| Incremental 14.8k | 176.9 KiB | 147.5 KiB | 155.8 KiB |
| Incremental 43.5k | 616.5 KiB | 557.7 KiB | 577.0 KiB |
| Incremental 435k | 6.02 MiB | 5.41 MiB | 5.62 MiB |
| Static 435k | 5.29 MiB | 5.29 MiB | 5.31 MiB |

Ordinary native allocations are not fully tracked as Dart external usage, so
this table does not measure the entire Rust working set.

Post-GC process RSS increments, medians [min–max]:

| Scenario | Current Dart | Current Rust |
| --- | ---: | ---: |
| Incremental 14.8k | 2.64 [2.44–2.66] MiB | 1.44 [1.42–1.45] MiB |
| Incremental 43.5k | 7.45 [3.72–7.50] MiB | 5.36 [5.19–5.66] MiB |
| Incremental 435k | 17.25 [12.66–18.11] MiB | 25.42 [25.27–26.22] MiB |
| Static 43.5k | 3.28 [3.27–3.36] MiB | 1.86 [−14.30–1.92] MiB |
| Static 435k | 23.19 [21.62–23.23] MiB | 19.81 [19.77–20.48] MiB |

The negative small-static RSS sample reflects resident-page reclamation after
the baseline, not negative parser allocation. RSS includes heap capacity, native
allocators, engine activity and retained free pages; small differences and
overlapping ranges should not be generalized. The incremental stress RSS
regression is real in these samples and remains unresolved. It prevents claiming
a consistent whole-process memory reduction even though live Dart objects shrink.

For the **435k static parse**, workload RSS high-water growth changes:

| Metric | Previous Rust | Current Rust | Same-run Dart |
| --- | ---: | ---: | ---: |
| Median above baseline high-water | 66.42 MiB | 19.23 MiB | 19.36 MiB |
| Current min–max | — | 15.25–19.38 MiB | 17.62–21.39 MiB |

This is approximately **71% less peak growth than previous Rust** and close to
the current Dart control. It is a high-water **increment**, not total process RSS.
The unchanged Dart control previously measured 23.17 MiB, illustrating why
same-run controls and ranges matter. Lifetime high-water values can hide smaller
workload peaks behind startup peaks; zero growth is not zero allocation.

In all thirty samples, releasing the final AST/session and forcing GC returns
the Dart heap exactly to its per-process baseline. RSS may remain elevated; this
is not a long-duration native leak test.

## Compatibility and validation

- Exact AST and C-ABI SMR1 byte equality against the unpatched pinned source:
  **676 fixtures + 10,000 generated documents × four option combinations**.
  Inline custom-hook ASTs also match. Compact node size is measured as 96 bytes.
- New native tests compare block-sink encoding to whole-tree encoding at every
  UTF-16 prefix, all four options; append and full-prefix transports match for
  Unicode/surrogate splits, definitions, edits, unchanged input and failures.
- Default Rust build: **75 passed**. Compact build: **76 passed**. Two benchmark
  tests remain intentionally ignored. Existing conformance/stream-prefix gates pass.
- Flutter full suite: **1,164 passed**, the same three pre-existing Mermaid
  golden mismatches. No goldens updated. New ownership tests reuse native
  allocations after freeing owners and verify saved ASTs survive disposal.
- Five example tests pass. Web preview and Wasm dry run build successfully.
  Static analysis has zero errors/warnings; source hashes and diff checks pass.
- One memory launch failed before VM-service connection and produced no sample.
  Saved samples were retained, missing samples completed, and app payload
  timestamps/hashes checked while resuming. Failed attempts are excluded.
- An additional UI frame run stalled at macOS window scheduling and was stopped;
  its data is excluded. The completed CPU comparison and memory probes provide
  the measurements above; no new rendering/FPS improvement is claimed.

## Evidence

- [Final same-strategy CPU samples and work counters](evidence/macos-profile-2026-11-19-bridge-final.json)
- [Earlier optimized CPU repeat](evidence/macos-profile-2026-11-19-bridge-pilot.json)
- [Native layout, AST and exact wire comparison](evidence/macos-native-2026-11-19-bridge.json)
- [Thirty-process memory summary and payload fingerprints](evidence/macos-memory-2026-11-19-bridge/summary.json)

Use the existing CPU and memory reproduction commands in the linked prior
reports. `memory_profile.py --resume` can complete missing samples only if the
app payload has not changed. The summary now fingerprints the runner, Dart AOT
framework and Rust framework; the previous memory report fingerprinted only the
runner. This round keeps its before/after raw evidence in separate files.

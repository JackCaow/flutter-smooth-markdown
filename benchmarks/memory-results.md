# Dart/Rust memory comparison — 2026-11-19

This records the comparison before the subsequent
[bridge and node-layout optimizations](bridge-optimization-results.md).

**The current Rust integration is not a consistent memory reduction.** In these
Mac host samples, ordinary incremental workloads are broadly close in process
RSS, with a modest Rust RSS reduction on the 43.5k stream. The larger 435k static
parse has a substantially higher Rust RSS peak. Final batch AST live Dart heaps
are almost identical; Rust incremental sessions retain a little more Dart heap.

## Method and scope

Apple M4, macOS 27.2, Flutter 3.41.6 / Dart 3.11.4, Profile/AOT, Rust opt-level 3.
There are **30 fresh app processes**: five scenarios, two backends, three trials.
All PIDs are unique. The same prebuilt application binary is used, and backend
order alternates by trial. Both paths get the same small Dart-and-Rust warmup,
including loading the native library. No production parser/ABI behavior changed.

The 14.8k and 43.5k incremental inputs and publication schedules are the same as
the [equal-strategy CPU comparison](equal-incremental-results.md); 435k repeats the
mixed corpus ten times further. Static cases parse the complete source once.
The full input is prepared before the baseline, but all intermediate prefixes
are **not** preallocated/retained. Prefixes are created as updates occur.

The host driver requests VM-service `_collectAllGarbage` twice before the
baseline, while holding the final AST/session, and after releasing them. It
records `getMemoryUsage` and in-app `ProcessInfo.currentRss` / `maxRss`.
No self-WebSocket connection is made from the sandboxed app.

These measurements cover **parsing, AST/session retention and their transient
allocations in a Flutter host**. They do not render a complete article or
include article widget trees, images or scrolling caches. They are not Android
or iPhone memory measurements.

## GC-surviving Dart heap

Increment over the prepared-input baseline, median of three fresh processes:

| Scenario | Dart backend | Rust backend |
| --- | ---: | ---: |
| Incremental 14,800 units / 58 updates | 155.8 KiB | 176.9 KiB |
| Incremental 43,520 units / 160 updates | 577.0 KiB | 616.5 KiB |
| Incremental 435,200 units / 1,600 updates | 5.62 MiB | 6.02 MiB |
| Static 43,520 units / one parse | 543.9 KiB | 543.2 KiB |
| Static 435,200 units / one parse | 5.31 MiB | 5.29 MiB |

The live-heap increments are identical across all three trials of each cell.
Rust incremental retains about 7% more Dart heap on the mixed corpus in this
implementation. Its adapter retains native-block groups alongside Flutter AST
objects; the Dart session retains block-start/node records. This compares their
existing representations rather than a theoretical language minimum.

**Rust's ordinary native allocations are not fully included in Dart heap or
tracked external usage.** Tracked external usage is zero here, even though the
native session owns UTF-16 source and block metadata. Therefore this table alone
cannot rank total memory usage. Process RSS below includes resident native pages.

## Process RSS while retaining the result, after GC

RSS increment over each process's own baseline, median [minimum–maximum]:

| Scenario | Dart backend | Rust backend |
| --- | ---: | ---: |
| Incremental 14.8k | 2.64 [2.62–2.66] MiB | 3.09 [2.97–3.19] MiB |
| Incremental 43.5k | 7.48 [7.47–7.48] MiB | 6.05 [3.61–6.59] MiB |
| Incremental 435k | 18.05 [17.86–18.53] MiB | 18.17 [17.53–19.30] MiB |
| Static 43.5k | 3.31 [3.30–3.31] MiB | 6.31 [2.89–6.48] MiB |
| Static 435k | 23.25 [23.12–23.27] MiB | 66.45 [62.36–66.75] MiB |

RSS includes the VM/engine, unused heap capacity and allocator caches. Forced GC
can itself touch/grow resident pages. Post-GC RSS is consequently much larger
than the live AST, and is not a byte count of live parser objects. Baseline
normalization and fresh processes help, but do not remove all OS/allocator noise.
The small RSS differences should not be generalized across devices or allocators.

## Workload RSS high-water growth

This is `maxRss` immediately after parsing minus `maxRss` at the baseline,
**before the post-workload forced GCs**. It captures native transient peaks too.

| Scenario | Dart, median [range] | Rust, median [range] |
| --- | ---: | ---: |
| Incremental 14.8k | 0.00 [0.00–2.09] MiB | 0.00 [0.00–2.55] MiB |
| Incremental 43.5k | 6.77 [0.00–6.81] MiB | 0.00 [0.00–5.55] MiB |
| Incremental 435k | 26.05 [15.03–26.30] MiB | 17.59 [15.28–24.09] MiB |
| Static 43.5k | 2.73 [2.73–2.81] MiB | 3.31 [2.62–6.41] MiB |
| Static 435k | 23.17 [23.03–23.17] MiB | 66.42 [65.34–70.47] MiB |

`maxRss` is a lifetime OS high-water mark. Zero growth means the workload did
not exceed the earlier startup/baseline peak; it does **not** mean zero allocation
or zero working memory. It is not appropriate to derive a speedup or memory ratio
from the zero-valued incremental cells. Incremental stress ranges also overlap.

The static 435k result is much clearer: approximately **2.9× the RSS peak growth**
for Rust. The full Rust AST, UTF-16 input, encoded wire data and subsequent Dart
AST decoding introduce intermediate memory representations. The experiment
measures their combined path, not an exact allocation attribution to each stage.

## Release checks and interpretation

After dropping the AST and disposing the session/parser, GC-surviving Dart heap
returns **exactly to its per-process baseline in all 30 samples**. RSS mostly
stays elevated because object liveness, heap capacity and resident allocator
pages are different quantities. This is a release check for these workloads,
not a long-running native leak test.

For this implementation, memory provides no broad additional reason to prefer
Rust: normal stream differences are small, and large full parses have higher
transient/resident cost. Its cross-platform shared implementation remains a
separate benefit. API and backend-selection policy are unchanged in this round.

## Evidence and reproduction

- [Summary with medians, ranges, all samples and 30 unique PIDs](evidence/macos-memory-2026-11-19/summary.json)
- Per-process raw JSON files are alongside the summary, including baseline,
  before-GC, retained, released, OS high-water and per-publication RSS data.
- The summary records the application executable's SHA-256; all trials use that
  prebuilt executable. Driver logs stay under `example/build/core-performance/memory/logs/`.

```sh
python3 benchmarks/probes/memory_profile.py --trials 3 \
  --output benchmarks/evidence/macos-memory-YYYY-MM-DD
```

This host uses the temporary arm64-only Xcode workaround documented in
[the build instructions](README.md#reproduce), supplied through
`XCODE_XCCONFIG_FILE`. The first run builds the memory target; subsequent samples
relaunch the same binary. Every app-side test and host driver completed
successfully. The harness and `flutter_driver` dependency are development-only.

# Diagnostic-only RSS probes

These are separate from the acceptance memory samples. `vmmap` can perturb
target residency. Allocator pressure relief is an intervention after the
primary retained snapshot, not a production parser behavior.

- Trials **101**: previous flat-publication bridge; whole-process malloc
  statistics and `malloc_zone_pressure_relief(NULL, 0)`. Dart also has a retained
  region summary. Relief returns zero for both engines.
- Trials **102**: previous bridge, with baseline/retained `vmmap -summary` and
  VM-service `_heaps` counters. Rust's retained Untagged resident mappings total
  30.3 MiB; all-zone malloc in-use is about 10.5 MiB (about 1.55 MiB above its
  baseline). Dart has smaller anonymous residency and different VM capacities.
- Trials **103**: exploratory paged publications in both backends, before
  selecting fixed-length native pages and restoring the original Dart path.
  These are not the final accepted implementation. They illustrate that VM
  capacity/RSS need not decrease just because reported retained objects shrink.
- Trials **104**: final native paged publication, original Dart incremental
  implementation. Rust's retained Untagged resident mappings total 21.6 MiB,
  versus 30.3 MiB in trial 102, while all-zone malloc in-use remains about
  10.5 MiB. Allocator relief still returns zero.

The accepted, repeated before/after RSS and CPU comparisons are linked from
[the investigation report](../../sustained-rss-results.md). Region totals above
are diagnostic observations; differences do not precisely identify every VM
page's owner or substitute for the three-trial RSS distributions.

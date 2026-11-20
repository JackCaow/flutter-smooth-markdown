# Local shared-core patches

`rust-core/UPSTREAM` records the base revision and patches. `SOURCE.sha256` hashes
the resulting vendored sources, rather than claiming they are unmodified upstream.
The sync script reapplies patches with a checked context. Remove a patch once the
pinned upstream incorporates it; a conflict requires an explicit upgrade review.

`0001-inline-allocation.patch` preserves the existing grammar, AST and SMR1/C ABI:

- Copy plain text directly when it contains neither an entity nor an escape.
- Skip emphasis work tables for fewer than two tokens: no delimiter pair or
  adjacent-text merge can exist.
- Read delimiter spans instead of cloning full nodes, and move children into the
  resulting emphasis wrapper instead of deep-cloning discarded subtrees.

`0002-bridge-memory.patch` adds the optional ABI-1 suffix update while preserving
all existing entry points. Batch encoding releases completed top-level subtrees;
reference passes keep the same final wire and callback order. The ordinary Rust
AST API drops the first reference-pass tree before building the second.

Flutter opts into the private `flutter-compact-ast` feature: cold attributes are
lazy, and the 64-bit hot node is 96 bytes instead of 240, excluding payloads and
optional metadata. The default Rust build keeps its original public struct API.
Both builds preserve semantic equality, Debug output, SMR1 and the C ABI.

The offline native probe compares full ASTs and exact wire bytes with the unpatched source on all
676 fixtures and 10,000 generated documents, four option combinations, both full
parsing and inline parsing with custom hooks. Run it after editing or rebasing:

```sh
python3 benchmarks/probes/native_profile.py
```

Run Rust conformance/stream tests and Flutter compatibility tests as documented
in `docs/rust-core.md` as well. Probe timing is diagnostic; Flutter Profile/AOT
public-parser measurements remain the end-to-end performance acceptance.

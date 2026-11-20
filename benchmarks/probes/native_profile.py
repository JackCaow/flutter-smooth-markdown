#!/usr/bin/env python3
"""Compare patched/unpatched core in disposable crates; never change the ABI.

Run from any directory: python3 benchmarks/probes/native_profile.py > result.json
Requires the same offline Rust toolchain as the Flutter native-asset build.
"""
import base64
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='smooth-native-profile-') as tmp:
    root = Path(tmp)
    for name in ('candidate', 'reference'):
        target = root / name
        shutil.copytree(repo / 'rust-core', target,
                        ignore=shutil.ignore_patterns('target'))
    reference = root / 'reference'
    for patch in reversed(sorted((repo / 'tools/rust-core-patches').glob('*.patch'))):
        subprocess.run(['git', 'apply', '--reverse', str(patch)], cwd=reference, check=True)
    # The two crates must have distinct Rust names and C symbols in one binary.
    manifest = reference / 'Cargo.toml'
    manifest.write_text(manifest.read_text()
                        .replace('"smooth-markdown-rust"', '"smooth-markdown-rust-reference"')
                        .replace('"smooth_markdown_rust"', '"smooth_markdown_rust_reference"'))
    for path in (reference / 'src').rglob('*.rs'):
        path.write_text(path.read_text().replace('smr_', 'reference_smr_'))
    for name in ('candidate', 'reference'):
        # Probe-only visibility: time encoding an existing AST separately.
        path = root / name / 'src/ffi.rs'
        path.write_text(path.read_text().replace('fn encode(root:', 'pub fn encode(root:'))
    (root / 'src').mkdir()
    shutil.copyfile(Path(__file__).with_suffix('.rs'), root / 'src/main.rs')
    (root / 'Cargo.toml').write_text('''[package]
name = "smooth-native-profile"
version = "0.0.0"
edition = "2021"
[dependencies]
smooth-markdown-rust = {path="candidate", features=["flutter-compact-ast"]}
smooth-markdown-rust-reference = {path="reference"}
[profile.release]
opt-level=3
lto=true
codegen-units=1
''')
    fixtures = []
    for name in ('commonmark-0.31.2.tsv', 'gfm-extensions.tsv'):
        for line in (repo / 'rust-core/tests/fixtures' / name).read_text().splitlines():
            fixtures.append(base64.b64decode(line.split('\t')[1]))
    (root / 'fixtures.bin').write_bytes(b''.join(len(s).to_bytes(4, 'little') + s for s in fixtures))
    test = (repo / 'example/integration_test/core_stages_test.dart').read_text()
    section = test.split("const section = '''", 1)[1].split("''';", 1)[0]
    (root / 'input.md').write_text(section * 160)
    result = subprocess.run(['cargo', 'run', '--offline', '--release', '--manifest-path',
                             str(root / 'Cargo.toml'), '--', str(root / 'input.md'),
                             str(root / 'fixtures.bin')], check=True, text=True, capture_output=True)
    print(json.dumps(json.loads(result.stdout), indent=2))

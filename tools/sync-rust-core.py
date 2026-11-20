#!/usr/bin/env python3
"""Vendor a clean, pinned checkout of the shared owned core; never copy builds."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root.parent / 'smooth-rust-core'
revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
if subprocess.check_output(['git', '-C', str(source), 'status', '--porcelain'], text=True).strip():
    raise SystemExit('Refusing to vendor a dirty Rust checkout')
target = root / 'rust-core'
patches = sorted((root / 'tools' / 'rust-core-patches').glob('*.patch'))
with tempfile.TemporaryDirectory(prefix='smooth-core-sync-') as tmp:
    staged = Path(tmp)
    for name in ('src', 'include', 'tests'):
        shutil.copytree(source / name, staged / name)
    for name in ('Cargo.toml', 'Cargo.lock', 'LICENSE'):
        shutil.copyfile(source / name, staged / name)
    # Check upgrades before replacing any vendored file. Remove a local patch
    # once upstream contains it; conflicts must not silently discard the fix.
    for patch in patches:
        subprocess.run(['git', 'apply', '--check', str(patch)], cwd=staged, check=True)
        subprocess.run(['git', 'apply', str(patch)], cwd=staged, check=True)
    (staged / 'UPSTREAM').write_text(
        f'https://github.com/JackCaow/smooth-rust-core\n{revision}\n' +
        ''.join(f'patch: tools/rust-core-patches/{p.name}\n' for p in patches))
    files = sorted(p for p in staged.rglob('*') if p.is_file())
    (staged / 'SOURCE.sha256').write_text(''.join(
        f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(staged).as_posix()}\n'
        for p in files))
    target.mkdir(exist_ok=True)
    for name in ('src', 'include', 'tests'):
        if (target / name).exists():
            shutil.rmtree(target / name)
        shutil.copytree(staged / name, target / name)
    for name in ('Cargo.toml', 'Cargo.lock', 'LICENSE', 'UPSTREAM', 'SOURCE.sha256'):
        shutil.copyfile(staged / name, target / name)
print(f'Vendored {revision}: {len(files)} files')

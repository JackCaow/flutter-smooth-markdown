#!/usr/bin/env python3
"""Profile retained Dart heap and whole-process RSS in fresh macOS app processes.

Run with the normal Flutter/Xcode environment; the first drive builds the target,
then the same prebuilt app is relaunched for every sample. No production edits.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import statistics
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--trials', type=int, default=3)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--resume', action='store_true')
parser.add_argument('--cases', nargs='+', choices=['stream_14k', 'stream_43k', 'stream_435k', 'static_43k', 'static_435k'])
args = parser.parse_args()
if args.trials < 1:
    parser.error('--trials must be positive')
repo = Path(__file__).resolve().parents[2]
example = repo / 'example'
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
logs = example / 'build/core-performance/memory/logs'
logs.mkdir(parents=True, exist_ok=True)
bundle = example / 'build/macos/Build/Products/Profile/flutter_smooth_markdown_example.app'
cases = ['stream_14k', 'stream_43k', 'stream_435k', 'static_43k', 'static_435k']
if args.cases:
    cases = args.cases
records = []
payloads = [bundle / 'Contents/MacOS/flutter_smooth_markdown_example',
            bundle / 'Contents/Frameworks/App.framework/Versions/A/App',
            bundle / 'Contents/Frameworks/smooth_markdown_rust.framework/smooth_markdown_rust']
fingerprint = None
def payload_hashes():
    return {p.relative_to(bundle).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in payloads}

existing = list(output.glob('*-*.json')) if args.resume else []
if existing:
    oldest = min(p.stat().st_mtime_ns for p in existing)
    assert all(p.stat().st_mtime_ns <= oldest for p in payloads), 'App payload changed since saved samples'
    fingerprint = payload_hashes()

for trial in range(1, args.trials + 1):
    for case in cases:
        # Balance engine order across trials; never reuse an app process.
        for backend in (['dart', 'rust'] if trial % 2 else ['rust', 'dart']):
            label = f'{case}-{backend}-{trial}'
            saved = output / f'{label}.json'
            if args.resume and saved.exists():
                records.append(json.loads(saved.read_text()))
                print(f'Reusing completed {label}', flush=True)
                continue
            print(f'Measuring {label}', flush=True)
            command = ['flutter', 'drive', '--profile', '--no-pub', '-d', 'macos',
                       '--driver', 'test_driver/memory_performance_driver.dart',
                       '--target', 'integration_test/memory_performance_test.dart']
            if records:
                command += ['--use-application-binary', str(bundle)]
            env = dict(os.environ, SMOOTH_MEMORY_BACKEND=backend,
                       SMOOTH_MEMORY_CASE=case, SMOOTH_MEMORY_TRIAL=str(trial))
            if fingerprint is not None:
                assert payload_hashes() == fingerprint, 'App payload changed between trials'
            for attempt in range(2):
                try:
                    with (logs / f'{label}-attempt-{attempt+1}.log').open('w') as log:
                        process = subprocess.Popen(command, cwd=example, env=env,
                            stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                        try:
                            status = process.wait(timeout=55)
                        except subprocess.TimeoutExpired:
                            os.killpg(process.pid, signal.SIGTERM)
                            try:
                                process.wait(timeout=3)
                            except subprocess.TimeoutExpired:
                                os.killpg(process.pid, signal.SIGKILL)
                                process.wait()
                            raise
                        if status:
                            raise subprocess.CalledProcessError(status, command)
                    break
                except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
                    if attempt == 1:
                        raise
                    print(f'Retrying failed launch {label}; failed attempt excluded', flush=True)
                    time.sleep(1)
            if fingerprint is None:
                fingerprint = payload_hashes()
            source = example / 'build/core-performance/memory' / f'{label}.json'
            record = json.loads(source.read_text())
            shutil.copyfile(source, output / source.name)
            records.append(record)

pids = [r['baseline']['pid'] for r in records]
assert len(set(pids)) == len(pids), 'A process was reused across samples'
def stats(values):
    return {'median': statistics.median(values), 'min': min(values), 'max': max(values), 'samples': values}

summary = {}
for case in cases:
    summary[case] = {}
    for backend in ['dart', 'rust']:
        group = [r for r in records if r['preparation']['case'] == case and r['preparation']['backend'] == backend]
        metrics = {
            'baseline_rss_bytes': lambda r: r['baseline']['rss_bytes'],
            'retained_dart_heap_delta_bytes': lambda r: r['retained_after_gc']['dart_heap_used_bytes'] - r['baseline']['dart_heap_used_bytes'],
            'retained_dart_heap_capacity_delta_bytes': lambda r: r['retained_after_gc']['dart_heap_capacity_bytes'] - r['baseline']['dart_heap_capacity_bytes'],
            'retained_rss_delta_bytes': lambda r: r['retained_after_gc']['rss_bytes'] - r['baseline']['rss_bytes'],
            'sampled_workload_peak_rss_growth_bytes': lambda r: max(r['workload']['rss_after_each_update_bytes']) - r['baseline']['rss_bytes'],
            'retained_malloc_in_use_delta_bytes': lambda r: r['retained_after_gc'].get('malloc_in_use_bytes', 0) - r['baseline'].get('malloc_in_use_bytes', 0),
            'workload_max_rss_bytes': lambda r: r['workload']['max_rss_bytes'],
            'workload_max_rss_growth_bytes': lambda r: r['workload']['max_rss_bytes'] - r['baseline']['max_rss_bytes'],
            'released_heap_delta_bytes': lambda r: r['released_after_gc']['dart_heap_used_bytes'] - r['baseline']['dart_heap_used_bytes'],
            'released_rss_delta_bytes': lambda r: r['released_after_gc']['rss_bytes'] - r['baseline']['rss_bytes'],
            'dart_external_tracked_bytes': lambda r: r['retained_after_gc']['dart_external_tracked_bytes'],
        }
        summary[case][backend] = {key: stats([get(r) for r in group]) for key, get in metrics.items()}
summary['metadata'] = {
    'created_utc': datetime.now(timezone.utc).isoformat(),
    'trials_per_engine_per_case': args.trials,
    'fresh_pids': pids,
    'binary_sha256': hashlib.sha256((bundle / 'Contents/MacOS/flutter_smooth_markdown_example').read_bytes()).hexdigest(),
    'payload_sha256': fingerprint,
    'resumed_saved_samples': len(existing),
    'profile_mode': True,
    'sample_count': len(records),
}
(output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(f'Completed {len(records)} fresh-process samples: {output / "summary.json"}', flush=True)

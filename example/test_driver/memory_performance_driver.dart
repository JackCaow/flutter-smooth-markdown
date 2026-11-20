import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

Future<void> main() async {
  final backend = Platform.environment['SMOOTH_MEMORY_BACKEND'] ?? 'dart';
  final scenario = Platform.environment['SMOOTH_MEMORY_CASE'] ?? 'stream_43k';
  final trial = Platform.environment['SMOOTH_MEMORY_TRIAL'] ?? '1';
  final driver = await FlutterDriver.connect();
  final service = driver.serviceClient;
  final isolate = driver.appIsolate.id!;
  Future<Map<String, dynamic>> command(String action,
      [Map<String, String> args = const {}]) async {
    final response = await service.callServiceExtension('ext.smooth.memory',
        isolateId: isolate, args: {'action': action, ...args});
    return response.json!;
  }

  Future<Map<String, dynamic>> snapshot({required bool collect}) async {
    if (collect) {
      // The host connection avoids the sandboxed app's self-WebSocket problem.
      await driver.forceGC();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await driver.forceGC();
    }
    final heap = await service.getMemoryUsage(isolate);
    final heaps = Platform.environment['SMOOTH_MEMORY_DIAGNOSE'] == '1'
        ? (await service.getIsolate(isolate)).json!['_heaps']
        : null;
    return {
      'forced_gc': collect,
      'dart_heap_used_bytes': heap.heapUsage,
      'dart_heap_capacity_bytes': heap.heapCapacity,
      'dart_external_tracked_bytes': heap.externalUsage,
      if (heaps != null) 'diagnostic_heap_spaces': heaps,
      ...await command('stats'),
    };
  }

  try {
    final preparation =
        await command('prepare', {'backend': backend, 'case': scenario});
    await Future<void>.delayed(const Duration(milliseconds: 500));
    String? baselineVmmap;
    if (Platform.environment['SMOOTH_MEMORY_VMMAP'] == '1') {
      final mapping = await Process.run(
          '/usr/bin/vmmap', ['-summary', '${preparation['pid']}']);
      baselineVmmap = '${mapping.stdout}\n${mapping.stderr}';
    }
    final baseline = await snapshot(collect: true);
    final workload = await command('run');
    final beforeGc = await snapshot(collect: false);
    final retained = await snapshot(collect: true);
    String? vmmap;
    if (Platform.environment['SMOOTH_MEMORY_VMMAP'] == '1') {
      final mapping = await Process.run(
          '/usr/bin/vmmap', ['-summary', '${retained['pid']}']);
      vmmap = '${mapping.stdout}\n${mapping.stderr}';
    }
    Map<String, dynamic>? relief;
    if (Platform.environment['SMOOTH_MEMORY_DIAGNOSE'] == '1') {
      relief = {
        'allocator_relief': await command('relief'),
        'retained_after_relief': await snapshot(collect: true)
      };
    }
    await command('release');
    final released = await snapshot(collect: true);
    final result = {
      'metadata': {
        'trial': int.parse(trial),
        'fresh_process': true,
        'same_small_warmup_for_both_backends': true,
        'gc_method':
            'VM-service _collectAllGarbage twice at each retained snapshot',
        'rss_high_watermark':
            'ProcessInfo.maxRss, includes pre-workload startup',
        'dart_external_excludes_unregistered_rust_allocations': true,
      },
      'preparation': preparation,
      'baseline': baseline,
      'workload': workload,
      'before_gc': beforeGc,
      'retained_after_gc': retained,
      'released_after_gc': released,
      if (relief != null) 'diagnostic_intervention': relief,
      if (vmmap != null) 'diagnostic_vmmap': vmmap,
      if (baselineVmmap != null) 'diagnostic_baseline_vmmap': baselineVmmap,
    };
    await command('finish');
    final response = Response.fromJson(
        await driver.requestData(null, timeout: const Duration(minutes: 2)));
    if (!response.allTestsPassed) {
      throw StateError(response.formattedFailureDetails);
    }
    final directory = Directory('build/core-performance/memory')
      ..createSync(recursive: true);
    final file = File('${directory.path}/$scenario-$backend-$trial.json');
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
    print('MEMORY_RESULT=${file.path}');
  } finally {
    await driver.close();
  }
}

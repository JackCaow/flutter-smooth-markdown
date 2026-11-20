import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/parser/markdown_parser.dart'
    show DartStreamParser;
import 'package:flutter_smooth_markdown/src/rust/core_types.dart'
    show CoreStream;
import 'package:flutter_smooth_markdown/src/rust/platform.dart' as native;
import 'package:flutter_smooth_markdown/src/rust/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'core_stages_test.dart' show section;

// All phases are controlled from the host VM-service connection. No in-app
// network client, heap snapshot, or retained list of all source prefixes.
String _source = '', _backend = '', _mode = '';
int _stride = 1;
CoreStream? _session;
MarkdownParser? _batch;
List<MarkdownNode> _nodes = [];

Map<String, int> resident() => {
      'pid': pid,
      'rss_bytes': ProcessInfo.currentRss,
      'max_rss_bytes': ProcessInfo.maxRss,
      'retained_flutter_blocks': _nodes.length,
      ...profileAllocator(),
    };

void release() {
  _session?.dispose();
  _session = null;
  _batch = null;
  _nodes = [];
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test('fresh-process memory probe with host-controlled GC', () async {
    expect(kProfileMode, isTrue);
    expect(MarkdownCore.isNative, isTrue);
    final done = Completer<void>();
    registerExtension('ext.smooth.memory', (method, params) async {
      final action = params['action'];
      Object result;
      switch (action) {
        case 'prepare':
          release();
          _backend = params['backend']!;
          final name = params['case']!;
          if (_backend != 'dart' && _backend != 'rust') {
            throw ArgumentError.value(_backend);
          }
          const streamSection = '## Stream reply\n\n'
              'A paragraph with **marks**, [link](/guide), 中文🙂.\n\n'
              '- First item\n- Second item\n\n'
              '```dart\nint count(String name) => name.length;\n```\n\n';
          switch (name) {
            case 'stream_14k':
              _source = streamSection * 100;
              _stride = 256;
              _mode = 'incremental';
            case 'stream_43k':
              _source = section * 160;
              _stride = section.length;
              _mode = 'incremental';
            case 'stream_435k':
              _source = section * 1600;
              _stride = section.length;
              _mode = 'incremental';
            case 'static_43k':
              _source = section * 160;
              _stride = _source.length;
              _mode = 'batch';
            case 'static_435k':
              _source = section * 1600;
              _stride = _source.length;
              _mode = 'batch';
            default:
              throw ArgumentError.value(name);
          }
          // Identical small warmup in both processes, including loading the
          // native library, so first-load code pages don't count as one lane's AST.
          final d = DartStreamParser(), r = native.createNativeStream()!;
          d.update(section);
          r.update(section);
          d.dispose();
          r.dispose();
          result = {
            'backend': _backend,
            'case': name,
            'mode': _mode,
            'source_utf16_units': _source.length,
            'stride_utf16_units': _stride,
            'publications': (_source.length / _stride).ceil(),
            'source_prepared_before_baseline': true,
            'all_prefixes_preallocated': false,
            'platform': Platform.operatingSystem,
            'os': Platform.operatingSystemVersion,
            ...resident(),
          };
        case 'run':
          if (_mode == 'incremental') {
            _session = _backend == 'dart'
                ? DartStreamParser()
                : native.createNativeStream()!;
          } else {
            _batch = MarkdownParser(
                backend: _backend == 'dart'
                    ? MarkdownParserBackend.legacyDart
                    : MarkdownParserBackend.rust);
          }
          final rss = <int>[];
          for (var end = _stride;; end += _stride) {
            final last = end >= _source.length;
            final prefix = last ? _source : _source.substring(0, end);
            _nodes = _session?.update(prefix) ?? _batch!.parse(prefix);
            rss.add(ProcessInfo.currentRss);
            if (last) break;
          }
          result = {'rss_after_each_update_bytes': rss, ...resident()};
        case 'stats':
          result = resident();
        case 'release':
          release();
          result = resident();
        case 'relief':
          result = {
            'released_by_malloc_bytes': profileAllocatorRelief(),
            ...resident()
          };
        case 'finish':
          release();
          result = {'finished': true};
          scheduleMicrotask(done.complete);
        default:
          throw ArgumentError.value(action);
      }
      return ServiceExtensionResponse.result(jsonEncode(result));
    });
    await done.future.timeout(const Duration(minutes: 10));
    expect(_session, isNull);
    expect(_nodes, isEmpty);
    binding.reportData = {
      'memory_probe': 'completed',
      'profile_mode': kProfileMode
    };
  });
}

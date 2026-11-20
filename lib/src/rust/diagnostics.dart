/// Development-only probe, deliberately absent from supported library exports.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart' as ffi;
import 'core_types.dart';
import 'wire.dart';

final class _MallocStatistics extends Struct {
  @Uint32()
  external int blocks;
  @Size()
  external int inUse;
  @Size()
  external int highWater;
  @Size()
  external int allocated;
}

/// Development-only macOS allocator counters, not a Rust-only allocation count.
Map<String, int> profileAllocator() {
  if (!Platform.isMacOS) return {};
  final statistics = DynamicLibrary.process()
      .lookupFunction<
        Void Function(Pointer<Void>, Pointer<_MallocStatistics>),
        void Function(Pointer<Void>, Pointer<_MallocStatistics>)
      >('malloc_zone_statistics');
  final output = calloc<_MallocStatistics>();
  try {
    statistics(nullptr, output);
    return {
      'malloc_blocks_in_use': output.ref.blocks,
      'malloc_in_use_bytes': output.ref.inUse,
      'malloc_high_water_bytes': output.ref.highWater,
      'malloc_allocated_bytes': output.ref.allocated,
    };
  } finally {
    calloc.free(output);
  }
}

/// Diagnostic intervention only; never used by the parser or acceptance runs.
int profileAllocatorRelief() {
  if (!Platform.isMacOS) return 0;
  return DynamicLibrary.process().lookupFunction<
    Size Function(Pointer<Void>, Size),
    int Function(Pointer<Void>, int)
  >('malloc_zone_pressure_relief')(nullptr, 0);
}

/// Measures the same hook-free parse pipeline without exposing native memory.
Map<String, int> profileNativeParse(String source) {
  if (source.length > 8 * 1024 * 1024)
    throw const MarkdownCoreException('input', 2);
  final watch = Stopwatch()..start();
  final input = calloc<Uint16>(source.isEmpty ? 1 : source.length);
  final buffer = calloc<ffi.SmrBuffer>();
  final units = input.asTypedList(source.length);
  for (var i = 0; i < source.length; i++) {
    units[i] = source.codeUnitAt(i);
  }
  final prepared = watch.elapsedMicroseconds;
  late int parsed,
      copied,
      decoded,
      adapted,
      wireBytes,
      wireNodes,
      flutterBlocks;
  try {
    final status = ffi.parse(input, source.length, 3, buffer);
    parsed = watch.elapsedMicroseconds;
    if (status != 0) throw MarkdownCoreException('profileParse', status);
    wireBytes = buffer.ref.length;
    if (wireBytes > 64 * 1024 * 1024 ||
        (wireBytes != 0 && buffer.ref.data == nullptr)) {
      throw const FormatException('Invalid native result buffer');
    }
    final bytes = buffer.ref.data.asTypedList(wireBytes);
    copied = watch.elapsedMicroseconds;
    final nodes = CoreWireReader(bytes, 'SMR1').markdown(source, const {});
    decoded = watch.elapsedMicroseconds;
    adapted = decoded;
    flutterBlocks = nodes.length;
    wireNodes = ByteData.sublistView(bytes).getUint32(4, Endian.little);
  } finally {
    ffi.bufferFree(buffer);
    calloc.free(buffer);
    calloc.free(input);
  }
  final freed = watch.elapsedMicroseconds;
  return {
    'prepare_us': prepared,
    'native_parse_and_wire_us': parsed - prepared,
    'copy_us': copied - parsed,
    'decode_and_adapt_us': decoded - copied,
    'adapt_us': adapted - decoded,
    'free_us': freed - adapted,
    'total_us': freed,
    'wire_bytes': wireBytes,
    'wire_nodes': wireNodes,
    'flutter_blocks': flutterBlocks,
    'source_utf16_units': source.length,
  };
}

/// Out-of-band work accounting: use actual native block starts/retention, never
/// infer work from the Flutter projection (which can split or omit blocks).
/// This reference tree decoder is deliberately outside timed benchmark loops.
Map<String, List<int>> profileNativeStreamWork(Iterable<String> sources) {
  final handle = ffi.streamNew(3);
  if (handle == nullptr) {
    throw const MarkdownCoreException('profileStreamNew', 3);
  }
  final buffer = calloc<ffi.SmrBuffer>();
  final retained = calloc<Uint32>();
  final parsedUnits = <int>[], retainedBlocks = <int>[], inputUnits = <int>[];
  var starts = <int>[];
  var previous = '';
  var globalDefinitions = false;
  try {
    for (final source in sources) {
      if (source.length > 8 * 1024 * 1024) {
        throw const MarkdownCoreException('input', 2);
      }
      final append = source.startsWith(previous);
      final inputStart = append ? previous.length : 0;
      final inputLength = source.length - inputStart;
      final input = calloc<Uint16>(inputLength == 0 ? 1 : inputLength);
      try {
        final units = input.asTypedList(inputLength);
        for (var i = 0; i < inputLength; i++) {
          units[i] = source.codeUnitAt(inputStart + i);
        }
        final unchanged = append && source.length == previous.length;
        final scanStart = append && previous.isNotEmpty
            ? previous.length - 1
            : 0;
        final definitions =
            (append && globalDefinitions) ||
            source.indexOf(']:', scanStart) >= 0;
        final expected = unchanged
            ? starts.length
            : append && !definitions && starts.length > 2
            ? starts.length - 2
            : 0;
        final start = unchanged
            ? source.length
            : expected == 0
            ? 0
            : starts[expected];
        final status = append
            ? ffi.streamAppend(handle, input, inputLength, buffer, retained)
            : ffi.streamUpdate(handle, input, inputLength, buffer, retained);
        if (status != 0) {
          throw MarkdownCoreException('profileStreamUpdate', status);
        }
        if (retained.value != expected) {
          throw StateError('Native retention policy changed');
        }
        if (buffer.ref.length > 64 * 1024 * 1024 ||
            buffer.ref.data == nullptr) {
          throw const FormatException('Invalid native result buffer');
        }
        final bytes = Uint8List.fromList(
          buffer.ref.data.asTypedList(buffer.ref.length),
        );
        final root = CoreWireReader(bytes, 'SMR1').tree(source);
        starts = [
          ...starts.take(retained.value),
          ...root.children.map((n) => n.start),
        ];
        retainedBlocks.add(retained.value);
        parsedUnits.add(source.length - start);
        inputUnits.add(inputLength);
        previous = source;
        globalDefinitions = definitions;
      } finally {
        ffi.bufferFree(buffer);
        calloc.free(input);
      }
    }
  } finally {
    ffi.streamFree(handle);
    calloc
      ..free(buffer)
      ..free(retained);
  }
  return {
    'parsed_utf16_units': parsedUnits,
    'retained_blocks': retainedBlocks,
    'input_utf16_units': inputUnits,
  };
}

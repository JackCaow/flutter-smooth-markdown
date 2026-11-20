// Frozen pre-page-publication adapter for paired benchmarks only. This keeps
// the old full-list copy in the same AOT process as the production adapter.
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_smooth_markdown/src/rust/bindings.dart' as native;
import 'package:flutter_smooth_markdown/src/rust/core_types.dart';
import 'package:flutter_smooth_markdown/src/rust/wire.dart';

Pointer<Void> _checkedHandle() {
  if (native.abiVersion() != 1) {
    throw StateError('Incompatible Smooth Markdown Rust ABI');
  }
  return native.streamNew(3);
}

T _readResult<T>(
  String operation,
  int Function(Pointer<native.SmrBuffer>) call,
  T Function(Uint8List) read,
) {
  final buffer = calloc<native.SmrBuffer>();
  try {
    final status = call(buffer);
    if (status != 0) throw MarkdownCoreException(operation, status);
    if (buffer.ref.length > 64 * 1024 * 1024 ||
        (buffer.ref.length != 0 && buffer.ref.data == nullptr)) {
      throw const FormatException('Invalid native result buffer');
    }
    return read(buffer.ref.data.asTypedList(buffer.ref.length));
  } finally {
    native.bufferFree(buffer);
    calloc.free(buffer);
  }
}

class FlatNativeStream implements CoreStream, Finalizable {
  FlatNativeStream() : _handle = _checkedHandle() {
    if (_handle == nullptr) throw const MarkdownCoreException('streamNew', 3);
    _finalizer.attach(this, _handle, detach: this);
  }
  static final _finalizer = NativeFinalizer(
    Native.addressOf(native.streamFree),
  );
  Pointer<Void> _handle;
  final _nodes = <MarkdownNode>[];
  final _blockEnds = <int>[];
  String _previous = '';

  @override
  List<MarkdownNode> update(String source) {
    if (_handle == nullptr) throw StateError('Stream session is disposed');
    if (source.length > 8 * 1024 * 1024) {
      throw const MarkdownCoreException('input', 2);
    }
    final append = source.startsWith(_previous);
    final start = append ? _previous.length : 0;
    final length = source.length - start;
    final input = calloc<Uint16>(length == 0 ? 1 : length);
    final retained = calloc<Uint32>();
    try {
      final units = input.asTypedList(length);
      for (var i = 0; i < length; i++) {
        units[i] = source.codeUnitAt(start + i);
      }
      _readResult(
        'streamUpdate',
        (buffer) => append
            ? native.streamAppend(_handle, input, length, buffer, retained)
            : native.streamUpdate(_handle, input, length, buffer, retained),
        (bytes) {
          final count = retained.value;
          if (count > _blockEnds.length) {
            throw const FormatException('Invalid retained block count');
          }
          _nodes.length = count == 0 ? 0 : _blockEnds[count - 1];
          _blockEnds.length = count;
          CoreWireReader(
            bytes,
            'SMR1',
          ).markdownAppend(source, _nodes, _blockEnds);
        },
      );
      _previous = source;
      return List.unmodifiable(_nodes);
    } catch (_) {
      _nodes.clear();
      _blockEnds.clear();
      _previous = '';
      _finalizer.detach(this);
      native.streamFree(_handle);
      _handle = native.streamNew(3);
      if (_handle != nullptr) _finalizer.attach(this, _handle, detach: this);
      rethrow;
    } finally {
      calloc.free(input);
      calloc.free(retained);
    }
  }

  @override
  void dispose() {
    if (_handle == nullptr) return;
    _finalizer.detach(this);
    native.streamFree(_handle);
    _handle = nullptr;
    _nodes.clear();
    _blockEnds.clear();
    _previous = '';
  }
}

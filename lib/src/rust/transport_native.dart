import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../parser/ast/markdown_node.dart';
import '../parser/parser_plugin.dart';
import '../parser/plugins/citation_plugin.dart';
import '../parser/stream_snapshot.dart';
import 'bindings.dart' as ffi;
import 'core_types.dart';
import 'wire.dart';

bool get nativeAvailable {
  if (ffi.abiVersion() != 1) {
    throw StateError('Incompatible Smooth Markdown Rust ABI');
  }
  return true;
}

Pointer<Uint16> _source(String source) {
  if (source.length > maxNativeSourceUnits) {
    throw const MarkdownCoreException('input', 2);
  }
  final pointer = calloc<Uint16>(source.isEmpty ? 1 : source.length);
  final units = pointer.asTypedList(source.length);
  for (var i = 0; i < source.length; i++) {
    units[i] = source.codeUnitAt(i);
  }
  return pointer;
}

Uint8List _result(String operation, int Function(Pointer<ffi.SmrBuffer>) call) {
  return _readResult(operation, call, Uint8List.fromList);
}

// Decode synchronously while the Rust owner is alive. Returned ASTs/strings
// own their data; a native typed-data view must never escape this callback.
T _readResult<T>(
  String operation,
  int Function(Pointer<ffi.SmrBuffer>) call,
  T Function(Uint8List) read,
) {
  final buffer = calloc<ffi.SmrBuffer>();
  try {
    final status = call(buffer);
    if (status != 0) throw MarkdownCoreException(operation, status);
    if (buffer.ref.length > 64 * 1024 * 1024 ||
        (buffer.ref.length != 0 && buffer.ref.data == nullptr)) {
      throw const FormatException('Invalid native result buffer');
    }
    return read(buffer.ref.data.asTypedList(buffer.ref.length));
  } finally {
    ffi.bufferFree(buffer);
    calloc.free(buffer);
  }
}

List<MarkdownNode>? parseNative(
  String source, {
  ParserPluginRegistry? plugins,
  bool inline = false,
}) {
  nativeAvailable;
  final input = _source(source);
  final hooks = plugins == null ? null : _HostHooks(plugins);
  // Only the native block parser knows which definitions are real, including
  // inside lists/quotes and outside code fences. Its wire includes those labels.
  final collectDefinitions =
      !inline && isCitationStreamRegistry(plugins) && source.contains(']:');
  final definitions = collectDefinitions ? <String>{} : null;

  List<MarkdownNode> parse(Set<String>? labels) {
    return _readResult(
      inline ? 'parseInline' : 'parse',
      (buffer) {
        final status = inline
            ? ffi.parseInline(
                input,
                source.length,
                3,
                nullptr,
                0,
                hooks?.pointer ?? nullptr,
                buffer,
              )
            : hooks == null
            ? ffi.parse(input, source.length, 3, buffer)
            : ffi.parseWithHooks(
                input,
                source.length,
                3 | 16,
                hooks.pointer,
                buffer,
              );
        hooks?.throwFailure();
        return status;
      },
      (bytes) => CoreWireReader(
        bytes,
        'SMR1',
        referenceLabels: labels,
      ).markdown(source, hooks?.nodes ?? const {}),
    );
  }

  try {
    final result = parse(definitions);
    if (definitions != null &&
        definitions.isNotEmpty &&
        hooks!.nodes.values.whereType<MarkdownCitationNode>().any(
          (node) => definitions.contains(node.number.toString()),
        )) {
      // A numeric shortcut resolves like any other Markdown link. Only rerun
      // for an actual collision; every other source uses the first result.
      hooks.nodes.clear();
      hooks.referenceLabels = definitions;
      return parse(null);
    }
    return result;
  } finally {
    hooks?.dispose();
    calloc.free(input);
  }
}

class _HostHooks {
  _HostHooks(this.plugins) {
    inline = NativeCallable<ffi.InlineCallback>.isolateLocal(
      _inline,
      exceptionalReturn: -1,
    );
    block = NativeCallable<ffi.BlockCallback>.isolateLocal(
      _block,
      exceptionalReturn: -1,
    );
    inlineContext = NativeCallable<ffi.InlineContext>.isolateLocal(
      _inlineContext,
      exceptionalReturn: -1,
    );
    blockContext = NativeCallable<ffi.BlockContext>.isolateLocal(
      _blockContext,
      exceptionalReturn: -1,
    );
    pointer.ref.inlineContext = inlineContext.nativeFunction;
    pointer.ref.blockContext = blockContext.nativeFunction;
    pointer.ref.inlineCallback = inline.nativeFunction;
    pointer.ref.blockCallback = block.nativeFunction;
  }
  final ParserPluginRegistry plugins;
  final pointer = calloc<ffi.SmrHooks>();
  final nodes = <int, MarkdownNode>{};
  Set<String> referenceLabels = const {};
  late final NativeCallable<ffi.InlineCallback> inline;
  late final NativeCallable<ffi.BlockCallback> block;
  late final NativeCallable<ffi.InlineContext> inlineContext;
  late final NativeCallable<ffi.BlockContext> blockContext;
  final _inlineSources = <String>[];
  final _blockSources = <List<String>>[];
  Object? failure;
  StackTrace? stack;
  int _remember(MarkdownNode node, int consumed, Pointer<ffi.SmrMatch> result) {
    final id = nodes.length + 1;
    nodes[id] = node;
    result.ref
      ..consumed = consumed
      ..id = id;
    return 1;
  }

  int _inline(
    Pointer<Void> context,
    Pointer<Uint16> text,
    int length,
    int index,
    int offset,
    Pointer<ffi.SmrMatch> result,
  ) {
    try {
      if (index >= length) return 0;
      final source = _inlineSources.last;
      for (final plugin in plugins.inlinePlugins) {
        if (!plugin.triggerCharacter.contains(source[index]) ||
            !plugin.canParse(source, index)) {
          continue;
        }
        final match = plugin.parse(source, index);
        if (match != null &&
            match.consumed > 0 &&
            match.consumed <= length - index) {
          final node = match.node;
          if (node is MarkdownCitationNode &&
              referenceLabels.isNotEmpty &&
              referenceLabels.contains(node.number.toString())) {
            continue;
          }
          return _remember(node, match.consumed, result);
        }
      }
      return 0;
    } catch (error, trace) {
      failure = error;
      stack = trace;
      return -1;
    }
  }

  int _block(
    Pointer<Void> context,
    Pointer<Pointer<Uint16>> lines,
    Pointer<Size> lengths,
    int count,
    int index,
    int offset,
    Pointer<ffi.SmrMatch> result,
  ) {
    try {
      if (index >= count) return 0;
      final source = _blockSources.last;
      for (final plugin in plugins.blockPlugins) {
        if (!plugin.canParse(source[index], source, index)) continue;
        final match = plugin.parse(source, index);
        if (match != null &&
            match.linesConsumed > 0 &&
            match.linesConsumed <= count - index) {
          return _remember(match.node, match.linesConsumed, result);
        }
      }
      return 0;
    } catch (error, trace) {
      failure = error;
      stack = trace;
      return -1;
    }
  }

  int _inlineContext(
    Pointer<Void> context,
    Pointer<Uint16> text,
    int length,
    int begin,
  ) {
    try {
      if (begin != 0) {
        _inlineSources.add(String.fromCharCodes(text.asTypedList(length)));
      } else {
        _inlineSources.removeLast();
      }
      return 0;
    } catch (error, trace) {
      failure = error;
      stack = trace;
      return -1;
    }
  }

  int _blockContext(
    Pointer<Void> context,
    Pointer<Pointer<Uint16>> lines,
    Pointer<Size> lengths,
    int count,
    int begin,
  ) {
    try {
      if (begin != 0) {
        _blockSources.add(
          List<String>.unmodifiable(
            List.generate(
              count,
              (i) => String.fromCharCodes(lines[i].asTypedList(lengths[i])),
            ),
          ),
        );
      } else {
        _blockSources.removeLast();
      }
      return 0;
    } catch (error, trace) {
      failure = error;
      stack = trace;
      return -1;
    }
  }

  void throwFailure() {
    if (failure != null) Error.throwWithStackTrace(failure!, stack!);
  }

  void dispose() {
    inline.close();
    block.close();
    inlineContext.close();
    blockContext.close();
    calloc.free(pointer);
  }
}

String? exportNativeHtml(String source, {bool escapeHtml = true}) {
  nativeAvailable;
  final input = _source(source);
  try {
    final bytes = _result(
      'exportHtml',
      (buffer) => ffi.exportHtml(
        input,
        source.length,
        1 | (escapeHtml ? 4 : 0),
        buffer,
      ),
    );
    if (bytes.length.isOdd) throw const FormatException('Invalid HTML UTF16');
    final data = ByteData.sublistView(bytes);
    return String.fromCharCodes(
      List.generate(
        bytes.length ~/ 2,
        (i) => data.getUint16(i * 2, Endian.little),
      ),
    );
  } finally {
    calloc.free(input);
  }
}

T _language<T>(String language, T Function(Pointer<Uint8>, int) call) {
  final bytes = utf8.encode(language);
  final pointer = calloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
  pointer.asTypedList(bytes.length).setAll(0, bytes);
  try {
    return call(pointer, bytes.length);
  } finally {
    calloc.free(pointer);
  }
}

String? normalizedNativeLanguage(String language) {
  nativeAvailable;
  return _language(
    language,
    (pointer, length) => utf8.decode(
      _result(
        'highlightLanguage',
        (buffer) => ffi.highlightLanguage(pointer, length, buffer),
      ),
    ),
  );
}

Uint8List _highlight(String source, String language, int mode, int tabWidth) {
  nativeAvailable;
  if (tabWidth < 0 || tabWidth > 16) {
    throw RangeError.range(tabWidth, 0, 16, 'tabWidth');
  }
  final input = _source(source);
  try {
    return _language(
      language,
      (pointer, length) => _result(
        'highlight',
        (buffer) => switch (mode) {
          0 => ffi.highlight(input, source.length, pointer, length, buffer),
          1 => ffi.highlightLines(
            input,
            source.length,
            pointer,
            length,
            tabWidth,
            buffer,
          ),
          _ => ffi.diff(
            input,
            source.length,
            pointer,
            length,
            tabWidth,
            buffer,
          ),
        },
      ),
    );
  } finally {
    calloc.free(input);
  }
}

List<MarkdownHighlightToken>? nativeHighlightedCode(
  String source,
  String language,
) {
  final reader = CoreWireReader(_highlight(source, language, 0, 0), 'SMH1');
  final result = reader.tokens(source.length);
  reader.finish();
  return result;
}

List<MarkdownHighlightedLine>? nativeHighlightedLines(
  String source,
  String language,
  int tabWidth,
) {
  final reader = CoreWireReader(
    _highlight(source, language, 1, tabWidth),
    'SML1',
  );
  final result = List<MarkdownHighlightedLine>.unmodifiable(
    List.generate(reader.count(), (_) => reader.line()),
  );
  reader.finish();
  return result;
}

List<MarkdownDiffRow>? nativeHighlightedDiff(
  String source,
  String language,
  int tabWidth,
) {
  final reader = CoreWireReader(
    _highlight(source, language, 2, tabWidth),
    'SMD1',
  );
  var oldLine = 0;
  final result = List<MarkdownDiffRow>.unmodifiable(
    List.generate(reader.count(), (_) {
      final kindId = reader.word(),
          number = reader.word(),
          start = reader.word(),
          length = reader.word();
      if (kindId >= MarkdownDiffKind.values.length) {
        throw const FormatException('Invalid diff row');
      }
      final line = reader.line();
      final kind = MarkdownDiffKind.values[kindId];
      if ((start == 0xffffffff) != (length == 0xffffffff) ||
          (start != 0xffffffff &&
              (start > line.text.length ||
                  length > line.text.length - start))) {
        throw const FormatException('Invalid diff change range');
      }
      if (kind == MarkdownDiffKind.hunk) {
        oldLine =
            int.tryParse(
              RegExp(r'^@@ -(\d+)').firstMatch(line.text)?.group(1) ?? '',
            ) ??
            0;
      }
      return MarkdownDiffRow(
        kind: kind,
        line: line,
        oldLineNumber: kind == MarkdownDiffKind.removed
            ? (oldLine = number + 1) - 1
            : kind == MarkdownDiffKind.context
            ? oldLine++
            : null,
        newLineNumber:
            kind == MarkdownDiffKind.added || kind == MarkdownDiffKind.context
            ? number
            : null,
        changedStart: start == 0xffffffff ? null : start,
        changedLength: length == 0xffffffff ? null : length,
      );
    }),
  );
  reader.finish();
  return result;
}

CoreStream? createNativeStream() {
  nativeAvailable;
  return _NativeStream();
}

class _NativeStream implements RetainedCoreStream, Finalizable {
  _NativeStream() : _handle = ffi.streamNew(3) {
    if (_handle == nullptr) throw const MarkdownCoreException('streamNew', 3);
    _finalizer.attach(this, _handle, detach: this);
  }
  static final _finalizer = NativeFinalizer(Native.addressOf(ffi.streamFree));
  Pointer<Void> _handle;
  var _nodes = StreamSnapshot<MarkdownNode>.empty();
  final _blockEnds = <int>[];
  String _previous = '';
  @override
  int retainedNodeCount = 0;
  @override
  List<MarkdownNode> update(String source) {
    if (_handle == nullptr) throw StateError('Stream session is disposed');
    if (source.length > maxNativeSourceUnits) {
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
            ? ffi.streamAppend(_handle, input, length, buffer, retained)
            : ffi.streamUpdate(_handle, input, length, buffer, retained),
        (bytes) {
          final count = retained.value;
          if (count > _blockEnds.length) {
            throw const FormatException('Invalid retained block count');
          }
          final retainedNodes = count == 0 ? 0 : _blockEnds[count - 1];
          retainedNodeCount = retainedNodes;
          final tail = <MarkdownNode>[], tailEnds = <int>[];
          _blockEnds.length = count;
          CoreWireReader(bytes, 'SMR1').markdownAppend(source, tail, tailEnds);
          _nodes = _nodes.replaceTail(retainedNodes, tail);
          for (final end in tailEnds) {
            _blockEnds.add(retainedNodes + end);
          }
        },
      );
      _previous = source;
      return _nodes;
    } catch (_) {
      retainedNodeCount = 0;
      _nodes = StreamSnapshot<MarkdownNode>.empty();
      _blockEnds.clear();
      _previous = '';
      // Decoding failures also invalidate the opaque native session.
      _finalizer.detach(this);
      ffi.streamFree(_handle);
      _handle = ffi.streamNew(3);
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
    ffi.streamFree(_handle);
    _handle = nullptr;
    retainedNodeCount = 0;
    _nodes = StreamSnapshot<MarkdownNode>.empty();
    _blockEnds.clear();
    _previous = '';
  }
}

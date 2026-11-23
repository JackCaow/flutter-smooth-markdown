import 'dart:typed_data';

import '../parser/ast/markdown_node.dart';
import 'core_types.dart';

part 'ast_decoder.dart';

/// Private transport model; never exposed by the supported Dart API.
class CoreNode {
  CoreNode(
    this.kind,
    this.start,
    this.length,
    this.level,
    this.flags,
    this.listStart,
    this.source,
    this.info,
    this.destination,
    this.title,
    this.literal,
    this.label,
    this.alignments,
    this.children,
  );
  final int kind, start, length, level, flags, listStart;
  final String source, info, destination, label;
  final String? title, literal;
  final List<String?> alignments;
  final List<CoreNode> children;
}

/// Bounds-checked decoder. Nothing here retains a pointer into native memory.
class CoreWireReader {
  CoreWireReader(Uint8List bytes, String magic, {this.referenceLabels})
    : _data = ByteData.sublistView(bytes) {
    if (bytes.length > 64 * 1024 * 1024 ||
        bytes.length < 8 ||
        String.fromCharCodes(bytes.take(4)) != magic) {
      throw const FormatException('Invalid core wire header');
    }
  }
  final ByteData _data;
  final Set<String>? referenceLabels;
  // A single checked view for every string; range decoding avoids allocating a
  // new typed-data view for each nonempty field in a large tree.
  late final Uint16List? _units =
      Endian.host == Endian.little && _data.offsetInBytes.isEven
      ? Uint16List.view(
          _data.buffer,
          _data.offsetInBytes,
          _data.lengthInBytes ~/ 2,
        )
      : null;
  int _offset = 4;
  int _remaining = 0;
  int word() {
    if (_offset + 4 > _data.lengthInBytes) {
      throw const FormatException('Truncated core wire');
    }
    final result = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return result;
  }

  String? string({String? source, int start = 0, int length = 0}) {
    final count = word();
    if (count == 0xffffffff) return null;
    if (count == 0xfffffffe) {
      if (source == null ||
          start > source.length ||
          length > source.length - start) {
        throw const FormatException('Invalid source reference');
      }
      return source.substring(start, start + length);
    }
    return _stringBody(count);
  }

  String _stringBody(int count) {
    if (count > (_data.lengthInBytes - _offset) ~/ 2) {
      throw const FormatException('Truncated UTF16 string');
    }
    if (count == 0) return '';
    final units = _units;
    final start = _offset ~/ 2;
    if (units != null && _offset.isEven) {
      _offset += count * 2;
      return String.fromCharCodes(units, start, start + count);
    }
    final fallback = Uint16List(count);
    for (var i = 0; i < count; i++) {
      fallback[i] = _data.getUint16(_offset + i * 2, Endian.little);
    }
    _offset += count * 2;
    return String.fromCharCodes(fallback);
  }

  String requiredString({String? source, int start = 0, int length = 0}) =>
      string(source: source, start: start, length: length) ??
      (throw const FormatException('Unexpected null string'));
  int count() {
    final result = word();
    if (result > 1000000 || result > (_data.lengthInBytes - _offset) ~/ 4) {
      throw const FormatException('Invalid core item count');
    }
    return result;
  }

  void finish() {
    if (_offset != _data.lengthInBytes) {
      throw const FormatException('Trailing core wire bytes');
    }
  }

  CoreNode tree(String source) {
    _remaining = count();
    final result = _node(source, 0);
    if (_remaining != 0 || result.kind != 0) {
      throw const FormatException('Invalid core tree');
    }
    finish();
    return result;
  }

  CoreNode _node(String source, int depth) {
    if (_remaining-- <= 0 || depth > 256) {
      throw const FormatException('Invalid core tree depth/count');
    }
    final kind = word(),
        start = word(),
        length = word(),
        level = word(),
        flags = word(),
        listStart = word(),
        childrenCount = word();
    if (kind > 32 ||
        flags & ~255 != 0 ||
        start > source.length ||
        length > source.length - start ||
        childrenCount > _remaining) {
      throw const FormatException('Invalid core node');
    }
    final nodeSource = requiredString(
      source: source,
      start: start,
      length: length,
    );
    final info = requiredString(),
        destination = requiredString(),
        title = string(),
        literal = string(),
        label = requiredString();
    final alignments = List<String?>.generate(count(), (_) => string());
    final children = List<CoreNode>.generate(
      childrenCount,
      (_) => _node(source, depth + 1),
    );
    return CoreNode(
      kind,
      start,
      length,
      level,
      flags,
      listStart,
      nodeSource,
      info,
      destination,
      title,
      literal,
      label,
      alignments,
      children,
    );
  }

  List<MarkdownHighlightToken> tokens(int sourceLength) {
    var previousEnd = 0;
    return List<MarkdownHighlightToken>.unmodifiable(
      List.generate(count(), (_) {
        final start = word(), length = word(), kind = word();
        if (start < previousEnd ||
            start > sourceLength ||
            length > sourceLength - start ||
            kind == 0 ||
            kind >= MarkdownHighlightKind.values.length) {
          throw const FormatException('Invalid highlight token');
        }
        previousEnd = start + length;
        return MarkdownHighlightToken(
          start: start,
          length: length,
          kind: MarkdownHighlightKind.values[kind],
        );
      }),
    );
  }

  MarkdownHighlightedLine line() {
    final text = requiredString();
    return MarkdownHighlightedLine(text: text, tokens: tokens(text.length));
  }
}

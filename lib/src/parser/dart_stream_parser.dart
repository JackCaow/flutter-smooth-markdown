part of 'markdown_parser.dart';

/// Package-internal Dart counterpart of the native append-only session.
/// Callers use the shared eligibility gate before bypassing host plugins/HTML.
/// Keeps the existing Dart grammar; it does not emulate Rust's AST semantics.
class DartStreamParser implements RetainedCoreStream {
  DartStreamParser({ParserPluginRegistry? plugins})
    : _parser = MarkdownParser(
        backend: MarkdownParserBackend.legacyDart,
        plugins: plugins,
      );

  final MarkdownParser _parser;
  final _blocks = <({int start, MarkdownNode node})>[];
  String _source = '';
  bool _definitions = false;
  bool _disposed = false;

  // Diagnostics used to verify that paired benchmarks parse the same tail.
  int lastParsedUnits = 0;
  int lastRetainedBlocks = 0;
  @override
  int get retainedNodeCount => lastRetainedBlocks;

  @override
  List<MarkdownNode> update(String source) {
    if (_disposed) throw StateError('Stream session is disposed');
    final append = source.startsWith(_source);
    if (append && source.length == _source.length) {
      lastParsedUnits = 0;
      lastRetainedBlocks = _blocks.length;
      return List.unmodifiable(_blocks.map((block) => block.node));
    }
    // Match Rust's conservative invalidation, including ]|: split across chunks
    // and false positives in code. Definitions can change earlier link targets.
    final scanStart = append && _source.isNotEmpty ? _source.length - 1 : 0;
    final definitions =
        (append && _definitions) || source.indexOf(']:', scanStart) >= 0;
    final retained = append && !definitions && _blocks.length > 2
        ? _blocks.length - 2
        : 0;
    final start = retained == 0 ? 0 : _blocks[retained].start;
    try {
      final starts = <int>[];
      final tail = _parser._blockParser.parseWithBlockStarts(
        source.substring(start),
        starts,
      );
      final nodes = tail.map(_parser._processInlineElements).toList();
      _blocks.removeRange(retained, _blocks.length);
      for (var i = 0; i < nodes.length; i++) {
        _blocks.add((start: start + starts[i], node: nodes[i]));
      }
      _source = source;
      _definitions = definitions;
      lastParsedUnits = source.length - start;
      lastRetainedBlocks = retained;
      return List.unmodifiable(_blocks.map((block) => block.node));
    } catch (_) {
      _source = '';
      _blocks.clear();
      _definitions = false;
      lastParsedUnits = 0;
      lastRetainedBlocks = 0;
      rethrow;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _source = '';
    _blocks.clear();
  }
}

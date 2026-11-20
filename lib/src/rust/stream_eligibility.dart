import '../parser/parser_compatibility.dart';
import '../parser/parser_plugin.dart';
import '../parser/plugins/admonition_plugin.dart';
import '../parser/plugins/artifact_plugin.dart';
import '../parser/plugins/emoji_plugin.dart';
import '../parser/plugins/hashtag_plugin.dart';
import '../parser/plugins/mention_plugin.dart';
import '../parser/plugins/mermaid_plugin.dart';
import '../parser/plugins/thinking_plugin.dart';
import '../parser/plugins/tool_call_plugin.dart';

// User extensions can override built-in syntax (including code spans). Only
// the exact built-in plugins below have the native scanner's precedence.
bool usesCompatiblePluginOrder(ParserPluginRegistry? plugins) {
  if (plugins == null) return true;
  if (plugins.runtimeType != ParserPluginRegistry) return false;
  return plugins.blockPlugins.every(
        (p) => const {
          ThinkingPlugin,
          ArtifactPlugin,
          ToolCallPlugin,
          MermaidPlugin,
          AdmonitionPlugin,
        }.contains(p.runtimeType),
      ) &&
      plugins.inlinePlugins.every(
        (p) => const {
          MentionPlugin,
          HashtagPlugin,
          EmojiPlugin,
        }.contains(p.runtimeType),
      );
}

/// Only skip hooks when exact built-in implementations provably cannot match.
/// Unknown plugins/subclasses retain their original full-document callbacks.
/// A completed extension marker can retroactively change a prefix: the widget
/// discards its incremental session before switching to that batch path.
bool canParseIncrementally(String source, ParserPluginRegistry? plugins) {
  if (requiresLegacyMarkdown(source)) return false;
  return _allowsPluginMarkers(source, plugins);
}

bool _allowsPluginMarkers(String source, ParserPluginRegistry? plugins) {
  if (plugins == null) return true;
  String? lower;
  for (final plugin in plugins.blockPlugins) {
    final type = plugin.runtimeType;
    if (type == ThinkingPlugin ||
        type == ArtifactPlugin ||
        type == ToolCallPlugin) {
      if (!source.contains('<')) continue;
      final text = lower ??= source.toLowerCase();
      if (type == ThinkingPlugin &&
          (text.contains('<think') || text.contains('<|think')))
        return false;
      if (type == ArtifactPlugin && text.contains('<artifact')) return false;
      if (type == ToolCallPlugin && text.contains('<tool_use')) return false;
    } else if (type == MermaidPlugin) {
      if (source.contains('```mermaid') || source.contains('~~~mermaid'))
        return false;
    } else if (type == AdmonitionPlugin) {
      if (source.contains(':::')) return false;
    } else {
      return false;
    }
  }
  for (final plugin in plugins.inlinePlugins) {
    final type = plugin.runtimeType;
    if (type != MentionPlugin && type != HashtagPlugin && type != EmojiPlugin)
      return false;
    if (source.contains(plugin.triggerCharacter)) return false;
  }
  return true;
}

/// Package-internal eligibility state owned by one append-only stream.
/// [checkAppend] takes full snapshots from the same buffer. Call [reset]
/// before replacement; verifying the prefix on every append would rescan it.
class StreamEligibility {
  int _length = 0;
  int _markerLength = 0;
  var _tables = StreamTableCheck();
  List<BlockParserPlugin> _blocks = const [];
  List<InlineParserPlugin> _inlines = const [];
  bool _markersAllow = true;

  void reset() {
    _length = 0;
    _markerLength = 0;
    _tables = StreamTableCheck();
    _blocks = const [];
    _inlines = const [];
    _markersAllow = true;
  }

  bool checkAppend(String source, ParserPluginRegistry? plugins) {
    // A subclass can override either getter with arbitrary, stateful behavior.
    // Preserve the full gate's access order and short-circuiting for it.
    if (plugins != null && plugins.runtimeType != ParserPluginRegistry) {
      reset();
      return canParseIncrementally(source, plugins);
    }
    assert(source.length >= _length, 'reset before replacing the stream');
    final ragged = _tables.checkAppend(source, _length);
    _length = source.length;
    if (ragged) return false;
    final start = _markerLength;
    final blocks = plugins?.blockPlugins ?? const <BlockParserPlugin>[];
    final inlines = plugins?.inlinePlugins ?? const <InlineParserPlugin>[];
    // A registry can be edited in place between publications or host builds.
    // Recheck past text when newly registered hooks could match it.
    final sameRules =
        _identicalPlugins(_blocks, blocks) &&
        _identicalPlugins(_inlines, inlines);
    _blocks = blocks;
    _inlines = inlines;
    _markerLength = source.length;
    if (!sameRules || (_markersAllow && start < source.length)) {
      // The longest literal is a ten-character Mermaid fence marker. A folded
      // tag character can originate from a two-unit Unicode scalar. Keep
      // enough original UTF-16 units and let Dart perform its own case folding.
      const overlap = 2 * 10;
      final window = sameRules && start > overlap
          ? source.substring(start - overlap)
          : source;
      _markersAllow =
          !hasLegacyDetails(window) && _allowsPluginMarkers(window, plugins);
    }
    return _markersAllow;
  }

  bool _identicalPlugins(List<ParserPlugin> old, List<ParserPlugin> current) {
    if (old.length != current.length) return false;
    for (var i = 0; i < old.length; i++) {
      if (!identical(old[i], current[i])) return false;
    }
    return true;
  }
}

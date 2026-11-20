import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

// The production guard rechecks custom registries in full because their
// getters can be dynamic. Inherit every getter, so only the check mode
// differs between the two frame controls.
class _FullCheckRegistry extends ParserPluginRegistry {}

ParserPluginRegistry benchmarkPlugins({bool fullCheck = false}) =>
    (fullCheck ? _FullCheckRegistry() : ParserPluginRegistry())
      ..register(const ThinkingPlugin())
      ..register(const ArtifactPlugin())
      ..register(const ToolCallPlugin());

/// A high-performance Flutter package for smooth markdown rendering with streaming support
library;

// Export configuration
export 'src/config/markdown_config.dart';
export 'src/config/style_sheet.dart';

// Export editor
export 'src/editor/document/markdown_document.dart';
export 'src/editor/document/markdown_document_editor.dart';
export 'src/editor/markdown_editor_command.dart';
export 'src/editor/markdown_editor_controller.dart';
export 'src/editor/markdown_editor_export.dart';
export 'src/editor/wikilink.dart';

// Export Mermaid renderer
export 'src/mermaid/mermaid.dart';

// Export AST nodes
export 'src/parser/ast/html_nodes.dart';
export 'src/parser/ast/markdown_node.dart';

// Export parser
export 'src/parser/markdown_parser.dart';
export 'src/parser/parse_cache.dart';

// Export plugin system
export 'src/parser/parser_plugin.dart';

// Export built-in plugins
export 'src/parser/plugins/admonition_plugin.dart';
export 'src/parser/plugins/artifact_plugin.dart';
export 'src/parser/plugins/emoji_plugin.dart';
export 'src/parser/plugins/hashtag_plugin.dart';
export 'src/parser/plugins/mention_plugin.dart';
export 'src/parser/plugins/mermaid_plugin.dart';
export 'src/parser/plugins/thinking_plugin.dart';
export 'src/parser/plugins/tool_call_plugin.dart';

// Export renderer
export 'src/renderer/builders/artifact_builder.dart';
export 'src/renderer/builders/block_math_builder.dart';
export 'src/renderer/builders/details_builder.dart';
export 'src/renderer/builders/enhanced_blockquote_builder.dart';
export 'src/renderer/builders/enhanced_code_block_builder.dart';
export 'src/renderer/builders/enhanced_header_builder.dart';
export 'src/renderer/builders/enhanced_link_builder.dart';
export 'src/renderer/builders/inline_math_builder.dart';
export 'src/renderer/builders/mermaid_builder.dart';
export 'src/renderer/builders/thinking_builder.dart';
export 'src/renderer/builders/tool_call_builder.dart';
export 'src/renderer/markdown_renderer.dart';
export 'src/renderer/widget_builder.dart';

// Export widgets
export 'widgets/smooth_markdown.dart';
export 'widgets/smooth_markdown_editor.dart';
export 'widgets/smooth_selection_region.dart';
export 'widgets/stream_markdown.dart';

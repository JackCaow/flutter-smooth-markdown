import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParserPluginRegistry', () {
    late ParserPluginRegistry registry;

    setUp(() {
      registry = ParserPluginRegistry();
    });

    test('should register block plugins', () {
      registry.registerBlock(const AdmonitionPlugin());
      expect(registry.blockPlugins.length, 1);
      expect(registry.blockPlugins.first.id, 'admonition');
    });

    test('should register inline plugins', () {
      registry.registerInline(const MentionPlugin());
      expect(registry.inlinePlugins.length, 1);
      expect(registry.inlinePlugins.first.id, 'mention');
    });

    test('should auto-detect plugin type on register', () {
      registry.register(const AdmonitionPlugin());
      registry.register(const MentionPlugin());

      expect(registry.blockPlugins.length, 1);
      expect(registry.inlinePlugins.length, 1);
    });

    test('should prevent duplicate plugin IDs', () {
      registry.registerInline(const MentionPlugin());
      expect(
        () => registry.registerInline(const MentionPlugin()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should unregister plugins', () {
      registry.registerInline(const MentionPlugin());
      expect(registry.unregisterInline('mention'), true);
      expect(registry.inlinePlugins, isEmpty);
    });

    test('should return false when unregistering non-existent plugin', () {
      expect(registry.unregisterInline('nonexistent'), false);
    });

    test('should sort plugins by priority', () {
      registry.register(const EmojiPlugin()); // priority 5
      registry.register(const MentionPlugin()); // priority 10
      registry.register(const HashtagPlugin()); // priority 10

      // Higher priority should come first
      expect(registry.inlinePlugins[0].id, anyOf('mention', 'hashtag'));
      expect(registry.inlinePlugins.last.id, 'emoji');
    });

    test('should track inline trigger characters', () {
      registry.register(const MentionPlugin());
      registry.register(const HashtagPlugin());
      registry.register(const EmojiPlugin());

      expect(registry.isInlineTrigger('@'), true);
      expect(registry.isInlineTrigger('#'), true);
      expect(registry.isInlineTrigger(':'), true);
      expect(registry.isInlineTrigger('x'), false);
    });

    test('should get plugin by trigger character', () {
      registry.register(const MentionPlugin());
      final plugin = registry.getInlinePluginByTrigger('@');
      expect(plugin?.id, 'mention');
    });

    test('should find plugins that can parse', () {
      registry.register(const MentionPlugin());
      registry.register(const HashtagPlugin());

      final found = registry.findInlinePlugins('@john', 0).toList();
      expect(found.length, 1);
      expect(found.first.id, 'mention');
    });

    test('should copy registry', () {
      registry.register(const MentionPlugin());
      registry.register(const AdmonitionPlugin());

      final copy = registry.copy();
      expect(copy.inlinePlugins.length, 1);
      expect(copy.blockPlugins.length, 1);
    });

    test('should clear all plugins', () {
      registry.register(const MentionPlugin());
      registry.register(const AdmonitionPlugin());
      registry.clear();

      expect(registry.inlinePlugins, isEmpty);
      expect(registry.blockPlugins, isEmpty);
    });
  });

  group('MentionPlugin', () {
    late MarkdownParser parser;

    setUp(() {
      final registry = ParserPluginRegistry();
      registry.register(const MentionPlugin());
      parser = MarkdownParser(plugins: registry);
    });

    test('should parse simple mention', () {
      final nodes = parser.parse('@john');
      expect(nodes.length, 1);

      final paragraph = nodes.first as ParagraphNode;
      expect(paragraph.children.length, 1);

      final mention = paragraph.children.first as MentionNode;
      expect(mention.username, 'john');
    });

    test('should parse mention in text', () {
      final nodes = parser.parse('Hello @john!');
      expect(nodes.length, 1);

      final paragraph = nodes.first as ParagraphNode;
      expect(paragraph.children.length, 3);
      expect(paragraph.children[0], isA<TextNode>());
      expect(paragraph.children[1], isA<MentionNode>());
      expect(paragraph.children[2], isA<TextNode>());
    });

    test('should handle usernames with numbers', () {
      final nodes = parser.parse('@user123');
      final paragraph = nodes.first as ParagraphNode;
      final mention = paragraph.children.first as MentionNode;
      expect(mention.username, 'user123');
    });

    test('should handle usernames with underscores and hyphens', () {
      final nodes = parser.parse('@john_doe-test');
      final paragraph = nodes.first as ParagraphNode;
      final mention = paragraph.children.first as MentionNode;
      expect(mention.username, 'john_doe-test');
    });

    test('should not parse @ without valid username', () {
      final nodes = parser.parse('@ not a mention');
      final paragraph = nodes.first as ParagraphNode;
      expect(paragraph.children.first, isA<TextNode>());
    });

    test('should not parse @123 (must start with letter)', () {
      final nodes = parser.parse('@123');
      final paragraph = nodes.first as ParagraphNode;
      expect(paragraph.children.first, isA<TextNode>());
    });
  });

  group('HashtagPlugin', () {
    late MarkdownParser parser;

    setUp(() {
      final registry = ParserPluginRegistry();
      registry.register(const HashtagPlugin());
      parser = MarkdownParser(plugins: registry);
    });

    test('should parse simple hashtag', () {
      final nodes = parser.parse('#flutter');
      final paragraph = nodes.first as ParagraphNode;
      final hashtag = paragraph.children.first as HashtagNode;
      expect(hashtag.tag, 'flutter');
    });

    test('should parse hashtag with underscore', () {
      final nodes = parser.parse('#flutter_dev');
      final paragraph = nodes.first as ParagraphNode;
      final hashtag = paragraph.children.first as HashtagNode;
      expect(hashtag.tag, 'flutter_dev');
    });

    test('should parse hashtag starting with underscore', () {
      final nodes = parser.parse('#_private');
      final paragraph = nodes.first as ParagraphNode;
      final hashtag = paragraph.children.first as HashtagNode;
      expect(hashtag.tag, '_private');
    });

    test('should handle multiple hashtags', () {
      final nodes = parser.parse('#flutter #dart');
      final paragraph = nodes.first as ParagraphNode;

      final hashtags = paragraph.children.whereType<HashtagNode>().toList();
      expect(hashtags.length, 2);
      expect(hashtags[0].tag, 'flutter');
      expect(hashtags[1].tag, 'dart');
    });
  });

  group('EmojiPlugin', () {
    late MarkdownParser parser;

    setUp(() {
      final registry = ParserPluginRegistry();
      registry.register(const EmojiPlugin());
      parser = MarkdownParser(plugins: registry);
    });

    test('should parse known emoji', () {
      final nodes = parser.parse(':smile:');
      final paragraph = nodes.first as ParagraphNode;
      final emoji = paragraph.children.first as EmojiNode;
      expect(emoji.shortcode, 'smile');
      expect(emoji.emoji, '😄');
    });

    test('should parse emoji in text', () {
      final nodes = parser.parse('Hello :wave: world!');
      final paragraph = nodes.first as ParagraphNode;

      expect(paragraph.children.length, 3);
      expect((paragraph.children[1] as EmojiNode).shortcode, 'wave');
    });

    test('should not parse unknown emoji', () {
      final nodes = parser.parse(':unknown_emoji:');
      final paragraph = nodes.first as ParagraphNode;
      // Should be parsed as text since emoji is unknown
      expect(paragraph.children.first, isA<TextNode>());
    });

    test('should handle case insensitivity', () {
      final nodes = parser.parse(':SMILE:');
      final paragraph = nodes.first as ParagraphNode;
      final emoji = paragraph.children.first as EmojiNode;
      expect(emoji.shortcode, 'smile');
    });

    test('should support custom emojis', () {
      final customRegistry = ParserPluginRegistry();
      customRegistry.register(const EmojiPlugin(
        customEmojis: {'custom': '🎉'},
      ));
      final customParser = MarkdownParser(plugins: customRegistry);

      final nodes = customParser.parse(':custom:');
      final paragraph = nodes.first as ParagraphNode;
      final emoji = paragraph.children.first as EmojiNode;
      expect(emoji.emoji, '🎉');
    });
  });

  group('AdmonitionPlugin', () {
    late MarkdownParser parser;

    setUp(() {
      final registry = ParserPluginRegistry();
      registry.register(const AdmonitionPlugin());
      parser = MarkdownParser(plugins: registry);
    });

    test('should parse note admonition', () {
      final nodes = parser.parse('''
::: note
This is a note.
:::
''');
      expect(nodes.length, 1);
      final admonition = nodes.first as AdmonitionNode;
      expect(admonition.admonitionType, AdmonitionType.note);
      expect(admonition.title, '');
    });

    test('should parse admonition with title', () {
      final nodes = parser.parse('''
::: warning Important Notice
Please read carefully.
:::
''');
      final admonition = nodes.first as AdmonitionNode;
      expect(admonition.admonitionType, AdmonitionType.warning);
      expect(admonition.title, 'Important Notice');
    });

    test('should parse different admonition types', () {
      final types = ['note', 'tip', 'warning', 'danger', 'important'];

      for (final type in types) {
        final nodes = parser.parse('''
::: $type
Content
:::
''');
        expect(nodes.first, isA<AdmonitionNode>());
      }
    });

    test('should handle aliases', () {
      final nodes = parser.parse('''
::: info
Info content
:::
''');
      final admonition = nodes.first as AdmonitionNode;
      expect(admonition.admonitionType, AdmonitionType.note);
    });

    test('should handle custom types', () {
      final nodes = parser.parse('''
::: custom_type Custom Title
Custom content
:::
''');
      final admonition = nodes.first as AdmonitionNode;
      expect(admonition.admonitionType, AdmonitionType.custom);
      expect(admonition.customType, 'custom_type');
    });

    test('should handle multiline content', () {
      final nodes = parser.parse('''
::: note
Line 1
Line 2
Line 3
:::
''');
      final admonition = nodes.first as AdmonitionNode;
      expect(admonition.children.length, 1);

      final content = (admonition.children.first as ParagraphNode)
          .children
          .first as TextNode;
      expect(content.content, contains('Line 1'));
      expect(content.content, contains('Line 2'));
      expect(content.content, contains('Line 3'));
    });
  });

  group('Combined plugins', () {
    late MarkdownParser parser;

    setUp(() {
      final registry = ParserPluginRegistry();
      registry.registerAll([
        const MentionPlugin(),
        const HashtagPlugin(),
        const EmojiPlugin(),
        const AdmonitionPlugin(),
      ]);
      parser = MarkdownParser(plugins: registry);
    });

    test('should parse multiple plugin types in same document', () {
      final nodes = parser.parse('''# Hello @john :wave:

Check out #flutter!

::: tip Pro Tip
Use plugins for custom syntax.
:::''');

      expect(nodes.length, 3);
      expect(nodes[0], isA<HeaderNode>());
      expect(nodes[1], isA<ParagraphNode>());
      expect(nodes[2], isA<AdmonitionNode>());
    });

    test('should handle plugins in same line', () {
      final nodes = parser.parse('Hey @john :smile: check #flutter');
      final paragraph = nodes.first as ParagraphNode;

      expect(paragraph.children.whereType<MentionNode>().length, 1);
      expect(paragraph.children.whereType<EmojiNode>().length, 1);
      expect(paragraph.children.whereType<HashtagNode>().length, 1);
    });
  });

  group('MermaidPlugin', () {
    test('should preserve tilde fences on Mermaid diagrams', () {
      final registry = ParserPluginRegistry()..register(const MermaidPlugin());
      final parser = MarkdownParser(plugins: registry);

      final nodes = parser.parse('''
~~~mermaid theme=dark
flowchart TD
  A --> B
~~~
''');

      expect(nodes, hasLength(1));
      expect(nodes.single, isA<MermaidDiagramNode>());
      final mermaid = nodes.single as MermaidDiagramNode;
      expect(mermaid.theme, 'dark');
      expect(mermaid.fence, '~~~');
      expect(mermaid.info, 'mermaid theme=dark');
      expect(mermaid.code, 'flowchart TD\n  A --> B');
      expect(mermaid.toJson()['fence'], '~~~');
      expect(mermaid.toJson()['info'], 'mermaid theme=dark');
    });
  });

  group('MarkdownParser with plugins', () {
    test('should work without plugins', () {
      final parser = MarkdownParser();
      final nodes = parser.parse('# Hello');
      expect(nodes.first, isA<HeaderNode>());
    });

    test('should expose plugins property', () {
      final registry = ParserPluginRegistry();
      registry.register(const MentionPlugin());
      final parser = MarkdownParser(plugins: registry);

      expect(parser.plugins, isNotNull);
      expect(parser.plugins!.inlinePlugins.length, 1);
    });

    test('should return null plugins when none registered', () {
      final parser = MarkdownParser();
      expect(parser.plugins, isNull);
    });

    test('plugins should not interfere with standard syntax', () {
      final registry = ParserPluginRegistry();
      registry.register(const MentionPlugin());
      final parser = MarkdownParser(plugins: registry);

      final nodes = parser.parse('**bold** *italic* `code`');
      final paragraph = nodes.first as ParagraphNode;

      expect(paragraph.children.whereType<BoldNode>().length, 1);
      expect(paragraph.children.whereType<ItalicNode>().length, 1);
      expect(paragraph.children.whereType<InlineCodeNode>().length, 1);
    });
  });
}

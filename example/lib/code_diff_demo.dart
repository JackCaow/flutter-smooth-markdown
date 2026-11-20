import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import 'l10n/app_localizations.dart';

enum _Sample {
  dart(
    'Dart',
    'greeting.dart',
    r'''class Greeting {
  const Greeting(this.name);

  final String name;

  String message() {
    return 'Hello, $name!';
  }
}''',
    r"    return 'Hello, $name!';",
    r"    return 'Welcome, $name! 👋';",
  ),
  typescript(
    'TypeScript',
    'greeting.ts',
    r'''export type Guest = {
  name: string;
};

export function greet(guest: Guest): string {
  return `Hello, ${guest.name}!`;
}''',
    r'  return `Hello, ${guest.name}!`;',
    r'  return `Welcome, ${guest.name}! 👋`;',
  ),
  rust(
    'Rust',
    'greeting.rs',
    '''pub struct Guest {
    pub name: String,
}

impl Guest {
    pub fn greet(&self) -> String {
        format!("Hello, {}!", self.name)
    }
}''',
    '        format!("Hello, {}!", self.name)',
    '        format!("Welcome, {}! 👋", self.name)',
  ),
  plaintext(
    'Plain text',
    'greeting.txt',
    '''Greeting template

Hello, {name}!

The name is supplied by the caller.''',
    'Hello, {name}!',
    'Welcome, {name}! 👋',
  );

  const _Sample(
    this.label,
    this.filename,
    this.source,
    this.original,
    this.replacement,
  );
  final String label;
  final String filename;
  final String source;
  final String original;
  final String replacement;

  String get patch {
    final lines = source.split('\n');
    return [
      '--- a/$filename',
      '+++ b/$filename',
      '@@ -1,${lines.length} +1,${lines.length} @@',
      for (final line in lines)
        if (line == original) ...['-$line', '+$replacement'] else ' $line',
    ].join('\n');
  }

  String get markdown =>
      '## $filename\n\n```$name\n$source\n```\n\n```diff $name\n$patch\n```';
}

/// An interactive source viewer for the public code, diff and Markdown widgets.
class CodeDiffDemo extends StatefulWidget {
  const CodeDiffDemo({super.key});

  @override
  State<CodeDiffDemo> createState() => _CodeDiffDemoState();
}

class _CodeDiffDemoState extends State<CodeDiffDemo> {
  _Sample _sample = _Sample.dart;
  bool _numbers = true;
  bool _rawMarkdown = false;
  bool? _darkOverride;

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final theme = Theme.of(context);
    final dark = _darkOverride ?? (theme.brightness == Brightness.dark);
    final palette =
        ColorScheme.fromSeed(
          seedColor: const Color(0xffb74c30),
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          surface: dark ? const Color(0xff23242b) : const Color(0xfffffdfa),
          onSurface: dark ? const Color(0xfff8f6f2) : const Color(0xff20232b),
          primary: dark ? const Color(0xffffac91) : const Color(0xffb74c30),
        );
    final paper = dark ? const Color(0xff191a1f) : const Color(0xfff8f6f2);
    final lineHint = _numbers
        ? (zh ? '隐藏行号' : 'Hide line numbers')
        : (zh ? '显示行号' : 'Show line numbers');
    final baseTheme = theme.brightness == palette.brightness
        ? theme
        : ThemeData(colorScheme: palette, useMaterial3: true);
    return Theme(
      data: baseTheme.copyWith(colorScheme: palette),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: paper,
          appBar: AppBar(
            backgroundColor: paper,
            foregroundColor: palette.onSurface,
            title: Text(
              l10n?.translate('gallery_diff') ?? (zh ? '代码与差异' : 'Code & Diff'),
            ),
            actions: [
              IconButton(
                tooltip: dark
                    ? (zh ? '浅色模式' : 'Light mode')
                    : (zh ? '深色模式' : 'Dark mode'),
                icon: Icon(
                  dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                onPressed: () => setState(() => _darkOverride = !dark),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    TabBar(
                      labelColor: palette.primary,
                      unselectedLabelColor: palette.onSurfaceVariant,
                      indicatorColor: palette.primary,
                      dividerColor: palette.outlineVariant,
                      tabs: [
                        Tab(
                          text:
                              l10n?.translate('gallery_source') ??
                              (zh ? '源码' : 'Source'),
                        ),
                        Tab(text: zh ? '差异' : 'Diff'),
                        const Tab(text: 'Markdown'),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          PopupMenuButton<_Sample>(
                            tooltip: zh ? '选择代码语言' : 'Choose code language',
                            initialValue: _sample,
                            itemBuilder: (_) => [
                              for (final sample in _Sample.values)
                                CheckedPopupMenuItem(
                                  value: sample,
                                  checked: _sample == sample,
                                  child: Text(sample.label),
                                ),
                            ],
                            onSelected: (value) =>
                                setState(() => _sample = value),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.code_rounded,
                                    color: palette.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_sample.label),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.arrow_drop_down, size: 19),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: lineHint,
                            isSelected: _numbers,
                            color: _numbers
                                ? palette.primary
                                : palette.onSurfaceVariant,
                            icon: const Icon(
                              Icons.format_list_numbered_rounded,
                            ),
                            onPressed: () =>
                                setState(() => _numbers = !_numbers),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _FilePanel(
                            filename: _sample.filename,
                            child: MarkdownCodeView(
                              code: _sample.source,
                              language: _sample.name,
                              showLineNumbers: _numbers,
                            ),
                          ),
                          _FilePanel(
                            filename: '${_sample.filename}.diff',
                            child: MarkdownDiffView(
                              patch: _sample.patch,
                              language: _sample.name,
                              showLineNumbers: _numbers,
                            ),
                          ),
                          _FilePanel(
                            filename: '${_sample.filename}.md',
                            action: TextButton(
                              onPressed: () =>
                                  setState(() => _rawMarkdown = !_rawMarkdown),
                              child: Text(
                                _rawMarkdown
                                    ? (zh ? '预览' : 'Preview')
                                    : (zh ? '查看原文' : 'View source'),
                              ),
                            ),
                            child: _rawMarkdown
                                ? MarkdownCodeView(
                                    code: _sample.markdown,
                                    language: 'markdown',
                                    showLineNumbers: _numbers,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SmoothMarkdown(
                                      data: _sample.markdown,
                                      useEnhancedComponents: true,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilePanel extends StatelessWidget {
  const _FilePanel({required this.filename, required this.child, this.action});
  final String filename;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        filename,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (action != null) action!,
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            child,
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

class GalleryEntry {
  const GalleryEntry(this.title, this.icon, this.open, {this.searchAlias = ''});
  final String title;
  final IconData icon;
  final VoidCallback open;
  final String searchAlias;
}

class GalleryLibrary extends StatefulWidget {
  const GalleryLibrary({super.key, required this.tools, required this.samples});
  final List<GalleryEntry> tools;
  final List<GalleryEntry> samples;

  @override
  State<GalleryLibrary> createState() => _GalleryLibraryState();
}

class _GalleryLibraryState extends State<GalleryLibrary> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final groups =
        {
          l.translate('gallery_tools'): widget.tools,
          l.translate('gallery_basics'): widget.samples,
        }.map(
          (title, entries) => MapEntry(
            title,
            entries
                .where(
                  (e) =>
                      e.title.toLowerCase().contains(_query) ||
                      e.searchAlias.toLowerCase().contains(_query),
                )
                .toList(),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.translate('gallery_library'))),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: l.translate('gallery_search'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).deleteButtonTooltip,
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: .48),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      if (groups.values.every((g) => g.isEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Text(l.translate('gallery_no_results')),
                        ),
                      for (final group in groups.entries)
                        if (group.value.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 6),
                            child: Text(
                              group.key,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          for (final entry in group.value)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              leading: Icon(
                                entry.icon,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              title: Text(entry.title),
                              trailing: const Icon(
                                Icons.chevron_right,
                                size: 20,
                              ),
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                entry.open();
                              },
                            ),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

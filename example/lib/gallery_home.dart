import 'package:flutter/material.dart';

const _paper = Color(0xFFF8F6F2);
const _ink = Color(0xFF20232B);
const _terracotta = Color(0xFFB74C30);

/// Entry point for the example reader, interactive demos and tools.
class GalleryHome extends StatelessWidget {
  const GalleryHome({
    super.key,
    required this.onOpenReader,
    required this.onOpenStream,
    required this.onOpenCode,
    required this.onOpenLibrary,
    required this.onOpenEditor,
    required this.onOpenLargeDocument,
    required this.onSettings,
  });

  final VoidCallback onOpenReader;
  final VoidCallback onOpenStream;
  final VoidCallback onOpenCode;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenEditor;
  final ValueChanged<String> onOpenLargeDocument;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final copy = _texts[language] ?? _texts['en']!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFF6F1E7) : _ink;
    final accent = dark ? const Color(0xFFFFAE91) : _terracotta;
    final border = dark ? const Color(0xFF45443F) : const Color(0xFFDEDAD2);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1D2022) : _paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 14),
                      child: Row(
                        children: [
                          const _BrandMark(),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Smooth Markdown',
                              style: TextStyle(
                                color: foreground,
                                fontSize: 21,
                                height: 1.1,
                                letterSpacing: -0.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          PopupMenuButton<_Destination>(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).showMenuTooltip,
                            icon: Icon(Icons.menu_rounded, color: foreground),
                            position: PopupMenuPosition.under,
                            onSelected: (value) {
                              switch (value) {
                                case _Destination.library:
                                  onOpenLibrary();
                                case _Destination.settings:
                                  onSettings();
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: _Destination.library,
                                child: Text(copy.library),
                              ),
                              PopupMenuItem(
                                value: _Destination.settings,
                                child: Text(copy.settings),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _ArticleCover(copy: copy, onTap: onOpenReader),
                    const SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            copy.explore,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.7,
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: accent),
                          onPressed: onOpenLibrary,
                          child: Text.rich(
                            TextSpan(
                              text: copy.library,
                              children: const [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(Icons.arrow_forward, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    LayoutBuilder(
                      builder: (context, box) {
                        final stream = _PreviewTile(
                          stream: true,
                          title: copy.stream,
                          sample: copy.preview,
                          onTap: onOpenStream,
                        );
                        final code = _PreviewTile(
                          stream: false,
                          title: copy.code,
                          sample: copy.preview,
                          onTap: onOpenCode,
                        );
                        final textSize = MediaQuery.textScalerOf(
                          context,
                        ).scale(16);
                        if (box.maxWidth < 306 ||
                            (textSize > 22 && box.maxWidth < 550)) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              stream,
                              const SizedBox(height: 12),
                              code,
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: stream),
                              const SizedBox(width: 12),
                              Expanded(child: code),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Divider(height: 1, thickness: 1, color: border),
                    _ToolRow(
                      title: copy.largeDocument,
                      icon: Icons.chrome_reader_mode_outlined,
                      color: foreground,
                      onTap: () => onOpenLargeDocument(copy.largeDocument),
                    ),
                    Divider(height: 1, thickness: 1, color: border),
                    _ToolRow(
                      title: copy.editor,
                      icon: Icons.edit_note_rounded,
                      color: foreground,
                      onTap: onOpenEditor,
                    ),
                    Divider(height: 1, thickness: 1, color: border),
                    _ToolRow(
                      title: copy.settings,
                      icon: Icons.translate_rounded,
                      color: foreground,
                      onTap: onSettings,
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

enum _Destination { library, settings }

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/gallery/brand-mark.png',
        width: 32,
        height: 32,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _ArticleCover extends StatelessWidget {
  const _ArticleCover({required this.copy, required this.onTap});

  final _Copy copy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final minHeight = (box.maxWidth * 0.70).clamp(234.0, 354.0).toDouble();
        return Semantics(
          button: true,
          onTap: onTap,
          label: '${copy.title}. ${copy.caption}. ${copy.read}',
          excludeSemantics: true,
          child: Material(
            elevation: 0,
            color: const Color(0xFF36474C),
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Ink(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/gallery/ridgeline.jpg'),
                    fit: BoxFit.cover,
                    alignment: Alignment(0, -0.15),
                  ),
                ),
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x080E1516),
                        Color(0x4A101A1C),
                        Color(0xE5121C1F),
                      ],
                      stops: [0, .30, 1],
                    ),
                  ),
                  child: Container(
                    alignment: Alignment.bottomLeft,
                    constraints: BoxConstraints(minHeight: minHeight),
                    padding: const EdgeInsets.fromLTRB(22, 66, 22, 19),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          copy.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Baskervville',
                            fontFamilyFallback: [
                              'Georgia',
                              'Songti SC',
                              'Noto Serif CJK SC',
                              'serif',
                            ],
                            fontSize: 35,
                            letterSpacing: -0.8,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          copy.caption,
                          style: const TextStyle(
                            color: Color(0xFFFCFAF4),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: _paper,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 6,
                            ),
                            child: Text.rich(
                              TextSpan(
                                text: copy.read,
                                children: const [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 5),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 15,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
      },
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.stream,
    required this.title,
    required this.sample,
    required this.onTap,
  });

  final bool stream;
  final String title;
  final String sample;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? const Color(0xFFFAF1E3) : _ink;
    final tone = dark ? const Color(0xFFFFBC9E) : const Color(0xFF9C452F);
    final surface = stream
        ? (dark ? const Color(0xFF3F302B) : const Color(0xFFF4E6DC))
        : (dark ? const Color(0xFF283C36) : const Color(0xFFE6EEE7));
    final accent = stream
        ? tone
        : (dark ? const Color(0xFFA8D5C2) : const Color(0xFF2F6554));
    return Semantics(
      button: true,
      onTap: onTap,
      label: title,
      excludeSemantics: true,
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 13, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  stream
                      ? Icons.chat_bubble_outline_rounded
                      : Icons.difference_outlined,
                  size: 22,
                  color: accent,
                ),
                const SizedBox(height: 13),
                if (stream)
                  Text.rich(
                    TextSpan(
                      text: sample,
                      children: [
                        TextSpan(
                          text: ' ▍',
                          style: TextStyle(color: tone),
                        ),
                      ],
                    ),
                    style: TextStyle(color: accent, fontSize: 12, height: 1.6),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '− .trim().isEmpty\n',
                          style: TextStyle(color: tone),
                        ),
                        TextSpan(
                          text: '+ .isEmpty',
                          style: TextStyle(color: accent),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: fg,
                          fontSize: 17,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.arrow_outward_rounded, size: 16, color: accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 55),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
            child: Row(
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: color, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

typedef _Copy = ({
  String title,
  String caption,
  String read,
  String explore,
  String library,
  String stream,
  String code,
  String preview,
  String editor,
  String largeDocument,
  String settings,
});

const _texts = <String, _Copy>{
  'zh': (
    largeDocument: '长文档阅读器',
    title: '山脊行程手册',
    caption: '查集合与返程安排，勾好出发清单。',
    read: '打开手册',
    explore: '开发者工作台',
    library: '示例库',
    stream: '问开发助手',
    code: '审阅代码改动',
    preview: '先看 UI 线程。',
    editor: 'Markdown 编辑器',
    settings: '语言与外观',
  ),
  'en': (
    largeDocument: 'Long document reader',
    title: 'Ridgeline field guide',
    caption: 'Find the meeting point and check off your packing list.',
    read: 'Open guide',
    explore: 'Developer desk',
    library: 'Library',
    stream: 'Ask the assistant',
    code: 'Review a patch',
    preview: 'Start with the UI thread.',
    editor: 'Markdown editor',
    settings: 'Language & appearance',
  ),
  'ja': (
    largeDocument: '長文リーダー',
    title: '稜線の旅のしおり',
    caption: '集合と帰りの予定を確認し、持ち物をチェック。',
    read: 'しおりを開く',
    explore: '開発ワークスペース',
    library: 'サンプル集',
    stream: 'AI に質問する',
    code: '変更をレビュー',
    preview: 'まず UI スレッドから。',
    editor: 'Markdown エディタ',
    settings: '言語と外観',
  ),
  'es': (
    largeDocument: 'Lector de documentos largos',
    title: 'Guía de la sierra',
    caption: 'Consulta el punto de encuentro y prepara la mochila.',
    read: 'Abrir la guía',
    explore: 'Mesa de desarrollo',
    library: 'Biblioteca',
    stream: 'Pregunta a la IA',
    code: 'Revisar cambios',
    preview: 'Empieza por el hilo UI.',
    editor: 'Editor de Markdown',
    settings: 'Idioma y apariencia',
  ),
  'fr': (
    largeDocument: 'Lecteur de longs documents',
    title: 'Carnet de randonnée',
    caption: 'Retrouvez le point de rendez-vous et préparez votre sac.',
    read: 'Ouvrir le carnet',
    explore: 'Espace de travail',
    library: 'Bibliothèque',
    stream: 'Interroger l’IA',
    code: 'Relire le code',
    preview: 'Examinez le thread UI.',
    editor: 'Éditeur Markdown',
    settings: 'Langue et apparence',
  ),
  'ko': (
    largeDocument: '긴 문서 리더',
    title: '능선 여행 수첩',
    caption: '집결 장소와 귀가 일정을 확인하고 짐을 챙겨요.',
    read: '수첩 열기',
    explore: '개발 작업대',
    library: '예제 모음',
    stream: 'AI에 질문하기',
    code: '코드 변경 검토',
    preview: 'UI 스레드부터 확인해요.',
    editor: 'Markdown 편집기',
    settings: '언어 및 화면 설정',
  ),
};

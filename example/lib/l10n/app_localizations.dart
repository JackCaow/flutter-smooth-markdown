import 'package:flutter/widgets.dart';

/// Supported languages
enum AppLanguage {
  zh('中文', 'zh'),
  en('English', 'en'),
  ja('日本語', 'ja'),
  es('Español', 'es'),
  fr('Français', 'fr'),
  ko('한국어', 'ko');

  const AppLanguage(this.nativeName, this.code);

  final String nativeName;
  final String code;

  Locale get locale => Locale(code);
}

/// App localizations
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      'gallery_copied': '已复制 Markdown 源码',
      'gallery_disclosure': "折叠内容",
      'gallery_library': "示例目录",
      'gallery_search': "搜索示例",
      'gallery_no_results': "没有找到匹配的示例",
      'gallery_tools': "互动演示",
      'gallery_basics': "Markdown 语法",
      'gallery_preferences': "偏好设置",
      'gallery_editor': "Markdown 编辑器",
      'gallery_diff': "代码与 Diff",
      'gallery_html': "HTML 标签",
      'gallery_chats': "聊天列表",
      'gallery_ai': "AI 对话",
      'gallery_conversations': "会话管理",
      'gallery_plugins': "插件系统",
      'gallery_mermaid': "Mermaid 图表",
      'gallery_read': "正文",
      'gallery_source': "源码",
      // App title
      'app_title': 'Flutter Smooth Markdown',
      'app_subtitle': '高性能 Markdown 渲染引擎',

      // Drawer
      'drawer_theme': '主题',
      'drawer_demos': '演示',
      'drawer_light': '明亮',
      'drawer_dark': '暗黑',
      'drawer_ocean': '海洋',
      'drawer_forest': '森林',
      'drawer_sunset': '日落',
      'drawer_midnight': '午夜',
      'drawer_custom': '自定义',

      // Demo titles
      'demo_math': '数学公式',
      'demo_streaming': '流式渲染',
      'demo_footnote': '脚注',

      // Content sections
      'welcome': '欢迎',
      'features': '核心特性',
      'developing': '开发中',
      'conclusion': '结语',

      // Features
      'feature_headers': '标题',
      'feature_headers_desc': 'H1-H6 层级',
      'feature_emphasis': '强调',
      'feature_emphasis_desc': '粗体、斜体、删除线',
      'feature_code': '代码块',
      'feature_code_desc': '带复制按钮和语言标签',
      'feature_syntax': '语法高亮',
      'feature_syntax_desc': '代码块语法着色',
      'feature_lists': '列表',
      'feature_lists_desc': '无序、有序、任务列表',
      'feature_quotes': '引用',
      'feature_quotes_desc': '单层和嵌套引用',
      'feature_links': '链接',
      'feature_links_desc': '悬停动画和外链图标',
      'feature_images': '图片',
      'feature_images_desc': '网络图片加载，支持 PNG/JPEG/GIF/WebP/SVG',
      'feature_hr': '分隔线',
      'feature_hr_desc': '水平分隔线',
      'feature_tables': '表格',
      'feature_tables_desc': '完整的 GFM 表格支持，带对齐',
      'feature_streaming': '流式渲染',
      'feature_streaming_desc': '实时内容更新（可在示例库中查看）',
      'feature_math': '数学公式',
      'feature_math_desc': 'LaTeX 数学表达式（可在示例库中查看）',
      'feature_footnotes': '脚注',
      'feature_footnotes_desc': '文档脚注支持，支持自定义样式（可在示例库中查看）',
      'feature_themes': '主题',
      'feature_themes_desc': '6 种预设主题',

      // Demo pages
      'math_demo_title': '数学公式演示',
      'streaming_demo_title': '流式渲染演示',
      'footnote_demo_title': '脚注演示',

      // Language
      'language': '语言',
      'language_chinese': '中文',
      'language_english': 'English',
      'language_japanese': '日本語',
      'language_spanish': 'Español',
      'language_french': 'Français',
      'language_korean': '한국어',

      // Themes
      'theme_default_light': '默认亮色',
      'theme_default_dark': '默认暗色',
      'theme_github': 'GitHub',
      'theme_github_dark': 'GitHub Dark',
      'theme_vscode': 'VS Code',
      'theme_vscode_dark': 'VS Code Dark',

      // UI Elements
      'drawer_header_title': 'Markdown 示例',
      'tooltip_theme': '选择主题',

      // Example titles
      'example_basic': '基础格式',
      'example_headers': '标题',
      'example_lists': '列表',
      'example_blockquotes': '引用',
      'example_code': '代码块',
      'example_links': '链接',
      'example_images': '图片',
      'example_tables': '表格',
      'example_enhanced': '增强组件',
      'example_theme': '主题展示',
      'example_complete': '完整示例',
    },
    'en': {
      'gallery_copied': 'Markdown source copied',
      'gallery_disclosure': "Disclosure blocks",
      'gallery_library': "Example library",
      'gallery_search': "Search examples",
      'gallery_no_results': "No matching examples",
      'gallery_tools': "Interactive demos",
      'gallery_basics': "Markdown syntax",
      'gallery_preferences': "Preferences",
      'gallery_editor': "Markdown editor",
      'gallery_diff': "Code & Diff",
      'gallery_html': "HTML tags",
      'gallery_chats': "Chat list",
      'gallery_ai': "AI chat",
      'gallery_conversations': "Conversations",
      'gallery_plugins': "Plugins",
      'gallery_mermaid': "Mermaid diagrams",
      'gallery_read': "Read",
      'gallery_source': "Source",
      // App title
      'app_title': 'Flutter Smooth Markdown',
      'app_subtitle': 'High-Performance Markdown Rendering Engine',

      // Drawer
      'drawer_theme': 'Theme',
      'drawer_demos': 'Demos',
      'drawer_light': 'Light',
      'drawer_dark': 'Dark',
      'drawer_ocean': 'Ocean',
      'drawer_forest': 'Forest',
      'drawer_sunset': 'Sunset',
      'drawer_midnight': 'Midnight',
      'drawer_custom': 'Custom',

      // Demo titles
      'demo_math': 'Math Formulas',
      'demo_streaming': 'Streaming',
      'demo_footnote': 'Footnotes',

      // Content sections
      'welcome': 'Welcome',
      'features': 'Core Features',
      'developing': 'In Development',
      'conclusion': 'Conclusion',

      // Features
      'feature_headers': 'Headers',
      'feature_headers_desc': 'H1-H6 hierarchy',
      'feature_emphasis': 'Emphasis',
      'feature_emphasis_desc': 'Bold, italic, strikethrough',
      'feature_code': 'Code Blocks',
      'feature_code_desc': 'With copy button and language tags',
      'feature_syntax': 'Syntax Highlighting',
      'feature_syntax_desc': 'Code block syntax coloring',
      'feature_lists': 'Lists',
      'feature_lists_desc': 'Unordered, ordered, task lists',
      'feature_quotes': 'Quotes',
      'feature_quotes_desc': 'Single and nested blockquotes',
      'feature_links': 'Links',
      'feature_links_desc': 'Hover animation and external icons',
      'feature_images': 'Images',
      'feature_images_desc':
          'Network image loading, supports PNG/JPEG/GIF/WebP/SVG',
      'feature_hr': 'Horizontal Rules',
      'feature_hr_desc': 'Horizontal dividers',
      'feature_tables': 'Tables',
      'feature_tables_desc': 'Full GFM table support with alignment',
      'feature_streaming': 'Streaming',
      'feature_streaming_desc':
          'Real-time content updates (see the Library)',
      'feature_math': 'Math Formulas',
      'feature_math_desc':
          'LaTeX math expressions (see the Library)',
      'feature_footnotes': 'Footnotes',
      'feature_footnotes_desc':
          'Document footnote support with custom styles (see the Library)',
      'feature_themes': 'Themes',
      'feature_themes_desc': '6 preset themes',

      // Demo pages
      'math_demo_title': 'Math Formulas Demo',
      'streaming_demo_title': 'Streaming Demo',
      'footnote_demo_title': 'Footnotes Demo',

      // Language
      'language': 'Language',
      'language_chinese': '中文',
      'language_english': 'English',
      'language_japanese': '日本語',
      'language_spanish': 'Español',
      'language_french': 'Français',
      'language_korean': '한국어',

      // Themes
      'theme_default_light': 'Default Light',
      'theme_default_dark': 'Default Dark',
      'theme_github': 'GitHub',
      'theme_github_dark': 'GitHub Dark',
      'theme_vscode': 'VS Code',
      'theme_vscode_dark': 'VS Code Dark',

      // UI Elements
      'drawer_header_title': 'Markdown Examples',
      'tooltip_theme': 'Select Theme',

      // Example titles
      'example_basic': 'Basic Formatting',
      'example_headers': 'Headers',
      'example_lists': 'Lists',
      'example_blockquotes': 'Blockquotes',
      'example_code': 'Code Blocks',
      'example_links': 'Links',
      'example_images': 'Images',
      'example_tables': 'Tables',
      'example_enhanced': 'Enhanced UI',
      'example_theme': 'Theme Showcase',
      'example_complete': 'Complete Demo',
    },
    'ja': {
      'gallery_copied': 'Markdown ソースをコピーしました',
      'gallery_disclosure': "折りたたみ",
      'gallery_library': "サンプル一覧",
      'gallery_search': "サンプルを検索",
      'gallery_no_results': "該当するサンプルはありません",
      'gallery_tools': "体験する",
      'gallery_basics': "Markdown 記法",
      'gallery_preferences': "設定",
      'gallery_editor': "Markdown エディタ",
      'gallery_diff': "コードと差分",
      'gallery_html': "HTML タグ",
      'gallery_chats': "チャット一覧",
      'gallery_ai': "AI チャット",
      'gallery_conversations': "会話管理",
      'gallery_plugins': "プラグイン",
      'gallery_mermaid': "Mermaid 図",
      'gallery_read': "本文",
      'gallery_source': "ソース",
      // App title
      'app_title': 'Flutter Smooth Markdown',
      'app_subtitle': '高性能Markdownレンダリングエンジン',

      // Drawer
      'drawer_theme': 'テーマ',
      'drawer_demos': 'デモ',
      'drawer_light': 'ライト',
      'drawer_dark': 'ダーク',
      'drawer_ocean': 'オーシャン',
      'drawer_forest': 'フォレスト',
      'drawer_sunset': 'サンセット',
      'drawer_midnight': 'ミッドナイト',
      'drawer_custom': 'カスタム',

      // Demo titles
      'demo_math': '数式',
      'demo_streaming': 'ストリーミング',
      'demo_footnote': '脚注',

      // Content sections
      'welcome': 'ようこそ',
      'features': 'コア機能',
      'developing': '開発中',
      'conclusion': '結論',

      // Features
      'feature_headers': '見出し',
      'feature_headers_desc': 'H1-H6階層',
      'feature_emphasis': '強調',
      'feature_emphasis_desc': '太字、斜体、取り消し線',
      'feature_code': 'コードブロック',
      'feature_code_desc': 'コピーボタンと言語タグ付き',
      'feature_syntax': 'シンタックスハイライト',
      'feature_syntax_desc': 'コードブロックの構文色付け',
      'feature_lists': 'リスト',
      'feature_lists_desc': '箇条書き、番号付き、タスクリスト',
      'feature_quotes': '引用',
      'feature_quotes_desc': '単一およびネストされた引用',
      'feature_links': 'リンク',
      'feature_links_desc': 'ホバーアニメーションと外部アイコン',
      'feature_images': '画像',
      'feature_images_desc': 'ネットワーク画像読み込み、PNG/JPEG/GIF/WebP/SVG対応',
      'feature_hr': '水平線',
      'feature_hr_desc': '水平区切り線',
      'feature_tables': 'テーブル',
      'feature_tables_desc': '完全なGFMテーブルサポート（配置機能付き）',
      'feature_streaming': 'ストリーミング',
      'feature_streaming_desc': 'リアルタイムコンテンツ更新（サンプル集を参照）',
      'feature_math': '数式',
      'feature_math_desc': 'LaTeX数式（サンプル集を参照）',
      'feature_footnotes': '脚注',
      'feature_footnotes_desc': '文書脚注サポート、カスタムスタイル対応（サンプル集を参照）',
      'feature_themes': 'テーマ',
      'feature_themes_desc': '6つのプリセットテーマ',

      // Demo pages
      'math_demo_title': '数式デモ',
      'streaming_demo_title': 'ストリーミングデモ',
      'footnote_demo_title': '脚注デモ',

      // Language
      'language': '言語',
      'language_chinese': '中文',
      'language_english': 'English',
      'language_japanese': '日本語',
      'language_spanish': 'Español',
      'language_french': 'Français',
      'language_korean': '한국어',

      // Themes
      'theme_default_light': 'デフォルトライト',
      'theme_default_dark': 'デフォルトダーク',
      'theme_github': 'GitHub',
      'theme_github_dark': 'GitHub Dark',
      'theme_vscode': 'VS Code',
      'theme_vscode_dark': 'VS Code Dark',

      // UI Elements
      'drawer_header_title': 'Markdownサンプル',
      'tooltip_theme': 'テーマを選択',

      // Example titles
      'example_basic': '基本書式',
      'example_headers': '見出し',
      'example_lists': 'リスト',
      'example_blockquotes': '引用',
      'example_code': 'コードブロック',
      'example_links': 'リンク',
      'example_images': '画像',
      'example_tables': 'テーブル',
      'example_enhanced': '拡張UI',
      'example_theme': 'テーマ',
      'example_complete': '完全なデモ',
    },
    'es': {
      'gallery_copied': 'Código Markdown copiado',
      'gallery_disclosure': "Bloques plegables",
      'gallery_library': "Biblioteca de ejemplos",
      'gallery_search': "Buscar ejemplos",
      'gallery_no_results': "No hay ejemplos coincidentes",
      'gallery_tools': "Demos interactivas",
      'gallery_basics': "Sintaxis Markdown",
      'gallery_preferences': "Preferencias",
      'gallery_editor': "Editor Markdown",
      'gallery_diff': "Código y diferencias",
      'gallery_html': "Etiquetas HTML",
      'gallery_chats': "Lista de chats",
      'gallery_ai': "Chat con IA",
      'gallery_conversations': "Conversaciones",
      'gallery_plugins': "Complementos",
      'gallery_mermaid': "Diagramas Mermaid",
      'gallery_read': "Lectura",
      'gallery_source': "Fuente",
      // App title
      'app_title': 'Flutter Smooth Markdown',
      'app_subtitle': 'Motor de Renderizado Markdown de Alto Rendimiento',

      // Drawer
      'drawer_theme': 'Tema',
      'drawer_demos': 'Demos',
      'drawer_light': 'Claro',
      'drawer_dark': 'Oscuro',
      'drawer_ocean': 'Océano',
      'drawer_forest': 'Bosque',
      'drawer_sunset': 'Atardecer',
      'drawer_midnight': 'Medianoche',
      'drawer_custom': 'Personalizado',

      // Demo titles
      'demo_math': 'Fórmulas Matemáticas',
      'demo_streaming': 'Transmisión',
      'demo_footnote': 'Notas al Pie',

      // Content sections
      'welcome': 'Bienvenido',
      'features': 'Características Principales',
      'developing': 'En Desarrollo',
      'conclusion': 'Conclusión',

      // Features
      'feature_headers': 'Encabezados',
      'feature_headers_desc': 'Jerarquía H1-H6',
      'feature_emphasis': 'Énfasis',
      'feature_emphasis_desc': 'Negrita, cursiva, tachado',
      'feature_code': 'Bloques de Código',
      'feature_code_desc': 'Con botón de copia y etiquetas de idioma',
      'feature_syntax': 'Resaltado de Sintaxis',
      'feature_syntax_desc': 'Coloración de sintaxis de bloques de código',
      'feature_lists': 'Listas',
      'feature_lists_desc': 'Sin ordenar, ordenadas, listas de tareas',
      'feature_quotes': 'Citas',
      'feature_quotes_desc': 'Citas simples y anidadas',
      'feature_links': 'Enlaces',
      'feature_links_desc': 'Animación al pasar el mouse e iconos externos',
      'feature_images': 'Imágenes',
      'feature_images_desc':
          'Carga de imágenes de red, soporta PNG/JPEG/GIF/WebP/SVG',
      'feature_hr': 'Líneas Horizontales',
      'feature_hr_desc': 'Divisores horizontales',
      'feature_tables': 'Tablas',
      'feature_tables_desc': 'Soporte completo de tablas GFM con alineación',
      'feature_streaming': 'Transmisión',
      'feature_streaming_desc':
          'Actualizaciones de contenido en tiempo real (ver la biblioteca)',
      'feature_math': 'Fórmulas Matemáticas',
      'feature_math_desc':
          'Expresiones matemáticas LaTeX (ver la biblioteca)',
      'feature_footnotes': 'Notas al Pie',
      'feature_footnotes_desc':
          'Soporte de notas al pie con estilos personalizados (ver la biblioteca)',
      'feature_themes': 'Temas',
      'feature_themes_desc': '6 temas preestablecidos',

      // Demo pages
      'math_demo_title': 'Demo de Fórmulas Matemáticas',
      'streaming_demo_title': 'Demo de Transmisión',
      'footnote_demo_title': 'Demo de Notas al Pie',

      // Language
      'language': 'Idioma',
      'language_chinese': '中文',
      'language_english': 'English',
      'language_japanese': '日本語',
      'language_spanish': 'Español',
      'language_french': 'Français',
      'language_korean': '한국어',

      // Themes
      'theme_default_light': 'Claro Predeterminado',
      'theme_default_dark': 'Oscuro Predeterminado',
      'theme_github': 'GitHub',
      'theme_github_dark': 'GitHub Oscuro',
      'theme_vscode': 'VS Code',
      'theme_vscode_dark': 'VS Code Oscuro',

      // UI Elements
      'drawer_header_title': 'Ejemplos de Markdown',
      'tooltip_theme': 'Seleccionar Tema',

      // Example titles
      'example_basic': 'Formato Básico',
      'example_headers': 'Encabezados',
      'example_lists': 'Listas',
      'example_blockquotes': 'Citas',
      'example_code': 'Bloques de Código',
      'example_links': 'Enlaces',
      'example_images': 'Imágenes',
      'example_tables': 'Tablas',
      'example_enhanced': 'UI Mejorada',
      'example_theme': 'Demostración de Temas',
      'example_complete': 'Demo Completa',
    },
    'fr': {
      'gallery_copied': 'Source Markdown copiée',
      'gallery_disclosure': "Blocs repliables",
      'gallery_library': "Bibliothèque d’exemples",
      'gallery_search': "Rechercher un exemple",
      'gallery_no_results': "Aucun exemple correspondant",
      'gallery_tools': "Démos interactives",
      'gallery_basics': "Syntaxe Markdown",
      'gallery_preferences': "Préférences",
      'gallery_editor': "Éditeur Markdown",
      'gallery_diff': "Code et différences",
      'gallery_html': "Balises HTML",
      'gallery_chats': "Liste de discussions",
      'gallery_ai': "Discussion IA",
      'gallery_conversations': "Conversations",
      'gallery_plugins': "Extensions",
      'gallery_mermaid': "Diagrammes Mermaid",
      'gallery_read': "Lecture",
      'gallery_source': "Source",
      // App title
      'app_title': 'Flutter Smooth Markdown',
      'app_subtitle': 'Moteur de Rendu Markdown Haute Performance',

      // Drawer
      'drawer_theme': 'Thème',
      'drawer_demos': 'Démos',
      'drawer_light': 'Clair',
      'drawer_dark': 'Sombre',
      'drawer_ocean': 'Océan',
      'drawer_forest': 'Forêt',
      'drawer_sunset': 'Coucher de Soleil',
      'drawer_midnight': 'Minuit',
      'drawer_custom': 'Personnalisé',

      // Demo titles
      'demo_math': 'Formules Mathématiques',
      'demo_streaming': 'Streaming',
      'demo_footnote': 'Notes de Bas de Page',

      // Content sections
      'welcome': 'Bienvenue',
      'features': 'Fonctionnalités Principales',
      'developing': 'En Développement',
      'conclusion': 'Conclusion',

      // Features
      'feature_headers': 'En-têtes',
      'feature_headers_desc': 'Hiérarchie H1-H6',
      'feature_emphasis': 'Emphase',
      'feature_emphasis_desc': 'Gras, italique, barré',
      'feature_code': 'Blocs de Code',
      'feature_code_desc': 'Avec bouton de copie et balises de langue',
      'feature_syntax': 'Coloration Syntaxique',
      'feature_syntax_desc': 'Coloration de la syntaxe des blocs de code',
      'feature_lists': 'Listes',
      'feature_lists_desc': 'Non ordonnées, ordonnées, listes de tâches',
      'feature_quotes': 'Citations',
      'feature_quotes_desc': 'Citations simples et imbriquées',
      'feature_links': 'Liens',
      'feature_links_desc': 'Animation au survol et icônes externes',
      'feature_images': 'Images',
      'feature_images_desc':
          'Chargement d\'images réseau, supporte PNG/JPEG/GIF/WebP/SVG',
      'feature_hr': 'Lignes Horizontales',
      'feature_hr_desc': 'Séparateurs horizontaux',
      'feature_tables': 'Tableaux',
      'feature_tables_desc': 'Support complet des tableaux GFM avec alignement',
      'feature_streaming': 'Streaming',
      'feature_streaming_desc':
          'Mises à jour de contenu en temps réel (voir la bibliothèque)',
      'feature_math': 'Formules Mathématiques',
      'feature_math_desc':
          'Expressions mathématiques LaTeX (voir la bibliothèque)',
      'feature_footnotes': 'Notes de Bas de Page',
      'feature_footnotes_desc':
          'Support des notes de bas de page avec styles personnalisés (voir la bibliothèque)',
      'feature_themes': 'Thèmes',
      'feature_themes_desc': '6 thèmes prédéfinis',

      // Demo pages
      'math_demo_title': 'Démo Formules Mathématiques',
      'streaming_demo_title': 'Démo Streaming',
      'footnote_demo_title': 'Démo Notes de Bas de Page',

      // Language
      'language': 'Langue',
      'language_chinese': '中文',
      'language_english': 'English',
      'language_japanese': '日本語',
      'language_spanish': 'Español',
      'language_french': 'Français',
      'language_korean': '한국어',

      // Themes
      'theme_default_light': 'Clair Par Défaut',
      'theme_default_dark': 'Sombre Par Défaut',
      'theme_github': 'GitHub',
      'theme_github_dark': 'GitHub Sombre',
      'theme_vscode': 'VS Code',
      'theme_vscode_dark': 'VS Code Sombre',

      // UI Elements
      'drawer_header_title': 'Exemples Markdown',
      'tooltip_theme': 'Sélectionner le Thème',

      // Example titles
      'example_basic': 'Formatage de Base',
      'example_headers': 'En-têtes',
      'example_lists': 'Listes',
      'example_blockquotes': 'Citations',
      'example_code': 'Blocs de Code',
      'example_links': 'Liens',
      'example_images': 'Images',
      'example_tables': 'Tableaux',
      'example_enhanced': 'UI Améliorée',
      'example_theme': 'Démonstration de Thèmes',
      'example_complete': 'Démo Complète',
    },
    'ko': {
      'gallery_copied': 'Markdown 소스를 복사했습니다',
      'gallery_disclosure': "접이식 블록",
      'gallery_library': "예제 모음",
      'gallery_search': "예제 검색",
      'gallery_no_results': "일치하는 예제가 없습니다",
      'gallery_tools': "인터랙티브 데모",
      'gallery_basics': "Markdown 문법",
      'gallery_preferences': "환경설정",
      'gallery_editor': "Markdown 편집기",
      'gallery_diff': "코드 및 Diff",
      'gallery_html': "HTML 태그",
      'gallery_chats': "채팅 목록",
      'gallery_ai': "AI 채팅",
      'gallery_conversations': "대화 관리",
      'gallery_plugins': "플러그인",
      'gallery_mermaid': "Mermaid 다이어그램",
      'gallery_read': "본문",
      'gallery_source': "소스",
      // App title
      'app_title': 'Flutter Smooth Markdown',
      'app_subtitle': '고성능 Markdown 렌더링 엔진',

      // Drawer
      'drawer_theme': '테마',
      'drawer_demos': '데모',
      'drawer_light': '라이트',
      'drawer_dark': '다크',
      'drawer_ocean': '오션',
      'drawer_forest': '포레스트',
      'drawer_sunset': '선셋',
      'drawer_midnight': '미드나잇',
      'drawer_custom': '커스텀',

      // Demo titles
      'demo_math': '수학 공식',
      'demo_streaming': '스트리밍',
      'demo_footnote': '각주',

      // Content sections
      'welcome': '환영합니다',
      'features': '핵심 기능',
      'developing': '개발 중',
      'conclusion': '결론',

      // Features
      'feature_headers': '헤더',
      'feature_headers_desc': 'H1-H6 계층',
      'feature_emphasis': '강조',
      'feature_emphasis_desc': '굵게, 기울임, 취소선',
      'feature_code': '코드 블록',
      'feature_code_desc': '복사 버튼 및 언어 태그 포함',
      'feature_syntax': '구문 강조',
      'feature_syntax_desc': '코드 블록 구문 색상',
      'feature_lists': '목록',
      'feature_lists_desc': '순서 없는, 순서 있는, 작업 목록',
      'feature_quotes': '인용',
      'feature_quotes_desc': '단일 및 중첩 인용',
      'feature_links': '링크',
      'feature_links_desc': '호버 애니메이션 및 외부 아이콘',
      'feature_images': '이미지',
      'feature_images_desc': '네트워크 이미지 로드, PNG/JPEG/GIF/WebP/SVG 지원',
      'feature_hr': '수평선',
      'feature_hr_desc': '수평 구분선',
      'feature_tables': '테이블',
      'feature_tables_desc': '정렬 기능이 있는 완전한 GFM 테이블 지원',
      'feature_streaming': '스트리밍',
      'feature_streaming_desc': '실시간 콘텐츠 업데이트 (예제 모음 참조)',
      'feature_math': '수학 공식',
      'feature_math_desc': 'LaTeX 수학 표현식 (예제 모음 참조)',
      'feature_footnotes': '각주',
      'feature_footnotes_desc': '사용자 정의 스타일이 있는 문서 각주 지원 (예제 모음 참조)',
      'feature_themes': '테마',
      'feature_themes_desc': '6가지 사전 설정 테마',

      // Demo pages
      'math_demo_title': '수학 공식 데모',
      'streaming_demo_title': '스트리밍 데모',
      'footnote_demo_title': '각주 데모',

      // Language
      'language': '언어',
      'language_chinese': '中文',
      'language_english': 'English',
      'language_japanese': '日本語',
      'language_spanish': 'Español',
      'language_french': 'Français',
      'language_korean': '한국어',

      // Themes
      'theme_default_light': '기본 라이트',
      'theme_default_dark': '기본 다크',
      'theme_github': 'GitHub',
      'theme_github_dark': 'GitHub 다크',
      'theme_vscode': 'VS Code',
      'theme_vscode_dark': 'VS Code 다크',

      // UI Elements
      'drawer_header_title': 'Markdown 예제',
      'tooltip_theme': '테마 선택',

      // Example titles
      'example_basic': '기본 서식',
      'example_headers': '헤더',
      'example_lists': '목록',
      'example_blockquotes': '인용',
      'example_code': '코드 블록',
      'example_links': '링크',
      'example_images': '이미지',
      'example_tables': '테이블',
      'example_enhanced': '향상된 UI',
      'example_theme': '테마 쇼케이스',
      'example_complete': '완전한 데모',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Theme helpers
  String translateTheme(String themeKey) {
    final key = 'theme_$themeKey';
    return translate(key);
  }

  // Example helpers
  String translateExample(String exampleKey) {
    final key = 'example_$exampleKey';
    return translate(key);
  }

  // Convenience getters
  String get appTitle => translate('app_title');
  String get appSubtitle => translate('app_subtitle');

  // Drawer
  String get drawerTheme => translate('drawer_theme');
  String get drawerDemos => translate('drawer_demos');
  String get drawerLight => translate('drawer_light');
  String get drawerDark => translate('drawer_dark');
  String get drawerOcean => translate('drawer_ocean');
  String get drawerForest => translate('drawer_forest');
  String get drawerSunset => translate('drawer_sunset');
  String get drawerMidnight => translate('drawer_midnight');
  String get drawerCustom => translate('drawer_custom');

  // Demo titles
  String get demoMath => translate('demo_math');
  String get demoStreaming => translate('demo_streaming');
  String get demoFootnote => translate('demo_footnote');

  // Language
  String get language => translate('language');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en', 'ja', 'es', 'fr', 'ko'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

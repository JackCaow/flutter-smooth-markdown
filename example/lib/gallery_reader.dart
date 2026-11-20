import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import 'l10n/app_localizations.dart';

typedef RidgeArticle = ({String title, String body});

RidgeArticle ridgeArticle(String language) => switch (language) {
  'zh' => (
    title: '山脊手记',
    body: '''
天刚亮，山谷还留着昨夜的蓝。沿碎石坡走到垭口，第一缕阳光正好从对面的山壁擦过，把岩层照成了铜红色。

## 在风口停一会儿

我们把地图摊在石头上，用水壶压住一角。来时走过的针叶林，从这里看只剩一小块墨绿色。

> 云影移动的时候，没动的山也像在缓缓呼吸。

## 路线笔记

| 路段 | 沿途所见 |
| --- | --- |
| 林线 | 潮湿的苔藓，溪水很轻 |
| 垭口 | 碎石、长风和第一束光 |
| 山脊 | 平行的岩层渐渐消失在云里 |

**留给下次的记号**：在山脊的转弯处回头看。最好的光，落在刚刚走过的那一面。
''',
  ),
  'ja' => (
    title: '稜線の手帖',
    body: '''
夜が明けても谷には青が残っていた。峠に着くと、最初の光が岩壁を銅色に染めた。

## 風の通り道

石の上に地図を広げ、水筒で角を押さえた。通ってきた森が小さな緑の島に見えた。

> 雲の影が動くと、山も呼吸をしているようだ。

## 道の記録

| 場所 | 風景 |
| --- | --- |
| 森林限界 | 苔と小川 |
| 峠 | 砂礫と朝日 |
| 稜線 | 雲に消える地層 |

**次回のために** 曲がり角で振り返る。歩いてきた斜面にいちばん美しい光がある。
''',
  ),
  'fr' => (
    title: 'Carnet de crête',
    body: '''
À l’aube, la vallée gardait encore son bleu de nuit. Au col, la première lumière donnait au rocher une teinte de cuivre.

## Une halte au vent

La gourde retenait notre carte sur une pierre plate. La forêt que nous venions de traverser semblait minuscule.

> Sous les ombres des nuages, la montagne semblait respirer.

## Notes de route

| Étape | Paysage |
| --- | --- |
| Lisière | Mousse et ruisseau |
| Col | Éboulis dans la lumière |
| Crête | Strates perdues dans les nuages |

**À retenir** Au prochain virage, regarder derrière soi. La belle lumière est sur le versant déjà parcouru.
''',
  ),
  'es' => (
    title: 'Cuaderno de la cresta',
    body: '''
Al amanecer el valle conservaba el azul de la noche. En el collado, la primera luz teñía de cobre la pared de roca.

## Una pausa al viento

Sujetamos el mapa con la cantimplora. El bosque que acabábamos de cruzar parecía una pequeña isla verde.

> Al pasar las sombras de las nubes, la montaña parecía respirar.

## Notas de ruta

| Tramo | Paisaje |
| --- | --- |
| Bosque | Musgo y arroyo |
| Collado | Grava y luz temprana |
| Cresta | Estratos entre nubes |

**Para la próxima vez** Mira atrás en la curva. La mejor luz cae sobre la ladera que acabas de cruzar.
''',
  ),
  'ko' => (
    title: '능선 일지',
    body: '''
동이 트는데도 계곡에는 밤의 푸른빛이 남아 있었다. 고갯마루에 서자 첫 햇살이 바위를 구릿빛으로 물들였다.

## 바람길에서

평평한 돌에 지도를 펴고 물병으로 모서리를 눌렀다. 지나온 숲은 작은 초록 섬처럼 보였다.

> 구름 그림자가 움직일 때 산도 천천히 숨 쉬는 듯했다.

## 길 위의 메모

| 구간 | 풍경 |
| --- | --- |
| 수목 한계선 | 이끼와 시냇물 |
| 고개 | 자갈과 아침 햇살 |
| 능선 | 구름에 가린 지층 |

**다음 걸음을 위해** 굽이에서 뒤를 돌아보자. 가장 좋은 빛은 방금 걸어온 비탈에 있다.
''',
  ),
  _ => (
    title: 'Ridgeline notes',
    body: '''
At first light the valley still held the blue of night. By the time we reached the saddle, a thin band of sun had turned the rock face copper.

## A pause in the wind

We spread the map on a flat stone and held one corner with a water bottle. The forest we had crossed looked like a small green island.

> When the cloud shadows moved, the mountain seemed to breathe.

## Trail notes

| Section | In view |
| --- | --- |
| Tree line | Damp moss and a quiet stream |
| Saddle | Loose scree in the first light |
| Ridgeline | Bands of stone fading into cloud |

**For next time** Look back at the bend. The best light is on the slope you just crossed.
''',
  ),
};

class GalleryReader extends StatefulWidget {
  const GalleryReader({
    super.key,
    required this.title,
    required this.markdown,
    required this.style,
    required this.plugins,
    required this.builders,
    this.cover = false,
  });
  final String title, markdown;
  final MarkdownStyleSheet? style;
  final ParserPluginRegistry plugins;
  final BuilderRegistry builders;
  final bool cover;

  @override
  State<GalleryReader> createState() => _GalleryReaderState();
}

class _GalleryReaderState extends State<GalleryReader> {
  bool _source = false;
  bool _fullSelection = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final markdown = widget.cover
        ? '# ${widget.title}\n\n${widget.markdown.trim()}'
        : widget.markdown;
    final large = markdown.length >= 64 * 1024;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (large && !_source)
            IconButton(
              tooltip: Localizations.localeOf(context).languageCode == 'zh'
                  ? '全文选择'
                  : 'Full document selection',
              isSelected: _fullSelection,
              icon: const Icon(Icons.select_all),
              onPressed: () => setState(() => _fullSelection = !_fullSelection),
            ),
          if (_source || large)
            IconButton(
              tooltip: MaterialLocalizations.of(context).copyButtonLabel,
              icon: const Icon(Icons.copy_outlined, size: 20),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: markdown));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.translate('gallery_copied'))),
                  );
                }
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              key: const ValueKey('reader-mode'),
              onPressed: () => setState(() => _source = !_source),
              icon: Icon(
                _source ? Icons.menu_book_outlined : Icons.code,
                size: 19,
              ),
              label: Text(
                l.translate(_source ? 'gallery_read' : 'gallery_source'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              key: PageStorageKey((widget.title, _source)),
              slivers: [
                if (widget.cover && !_source)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 1.95,
                          child: Image.asset(
                            'assets/gallery/ridgeline.jpg',
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 48),
                  sliver: _source
                      ? SliverToBoxAdapter(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: SelectableText(
                                markdown,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  height: 1.65,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ),
                        )
                      : SmoothMarkdown.sliver(
                          data: markdown,
                          styleSheet:
                              widget.style ??
                              MarkdownStyleSheet.fromBrightness(
                                Theme.of(context).brightness,
                              ),
                          plugins: widget.plugins,
                          builderRegistry: widget.builders,
                          useEnhancedComponents: true,
                          selectable: !large || _fullSelection,
                          onTapLink: (url) => ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(url))),
                          onTapImage: (url, alt, title) =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(alt ?? title ?? url)),
                              ),
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

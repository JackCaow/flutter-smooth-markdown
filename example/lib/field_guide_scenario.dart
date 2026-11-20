import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

enum _Chapter {
  overview(Icons.map_outlined),
  meeting(Icons.schedule_outlined),
  packing(Icons.checklist_rounded),
  notes(Icons.edit_note_rounded);

  const _Chapter(this.icon);
  final IconData icon;
}

typedef _Page = ({String title, String body});
typedef _Guide = ({
  String title,
  String contents,
  String trip,
  String openPacking,
  String copyList,
  String copied,
  String packed,
  List<String> items,
  Map<_Chapter, _Page> pages,
});

const _zh = (
  title: '离线行程手册',
  contents: '目录',
  trip: '周六，去看山',
  openPacking: '打开打包清单',
  copyList: '复制清单',
  copied: '已复制打包清单',
  packed: '已装入',
  items: ['离线行程与车票', '水壶和午餐', '外套', '充电宝和线', '速写本或相机'],
  pages: {
    _Chapter.overview: (
      title: '行程总览',
      body: '''
把周六留给山脊。从旧站台集合，沿林缘慢走，在午餐桌交换一路上的速写。这是一份虚构的一日小旅行手册，可以离线翻阅。

| 时间 | 安排 |
| --- | --- |
| 09:00 | 旧站台集合，清点背包 |
| 10:30 | 林缘观察，画一张速写 |
| 12:00 | 野餐桌用午餐 |
| 15:30 | 回旧站台，整理照片 |

**谁在什么时候到？** 翻到[集合与返程](#meeting)，那里也记着回程合照的位置。
''',
    ),
    _Chapter.meeting: (
      title: '集合与返程',
      body: '''
### 出发前

周六 **09:00** 在旧站台的蓝色长椅旁集合。把去程与回程车票放到同一个离线票夹，用当天日期命名，返程时会好找很多。

### 午餐约定

野餐桌是中午的碰头点。到得早的人先铺桌布，给同行者留出放背包的位置。出发前可以在[打包清单](#packing)里核对午餐和水壶。

### 最后一张合影

**15:30** 回到早上的蓝色长椅。从同一个机位再拍一张，傍晚整理照片时，就有了一对能讲完整故事的画面。
''',
    ),
    _Chapter.packing: (
      title: '随身清单',
      body: '装好一件就勾一件。把勾选结果复制到自己的行程笔记里，同行的人也能看到准备进度。',
    ),
    _Chapter.notes: (
      title: '回程手记',
      body: '''
### 挑三张照片

第一张放旧站台出发时的合照，第二张放午餐桌，最后一张放回程的长椅。从三张照片开始，整理起来比翻一整天的相册轻松。

### 给照片留一句话

别只写地名。试着记下画面外的一件事，比如午餐时谁把苹果分成几份、坐在你旁边的人指向哪一面山壁。

> 蓝色长椅在傍晚只剩一半被太阳照着。早上还空着的速写本，已经被我们翻到了第六页。

### 下次出发前

翻回[随身清单](#packing)，看看哪些东西真的用上了。把清单复制一份，再为下次出发做调整。
''',
    ),
  },
);

const _en = (
  title: 'Offline field guide',
  contents: 'Contents',
  trip: 'Saturday on the ridge',
  openPacking: 'Open packing list',
  copyList: 'Copy checklist',
  copied: 'Packing list copied',
  packed: 'packed',
  items: [
    'Offline itinerary and tickets',
    'Water bottle and lunch',
    'Jacket',
    'Power bank and cable',
    'Sketchbook or camera',
  ],
  pages: {
    _Chapter.overview: (
      title: 'Day plan',
      body: '''
Meet at the old platform, walk along the edge of the woods and swap sketches over lunch. This fictional day trip fits in an offline field guide.

| Time | Plan |
| --- | --- |
| 09:00 | Meet at the old platform |
| 10:30 | Pause for a sketch at the tree line |
| 12:00 | Lunch at the picnic table |
| 15:30 | Back to the platform to sort photos |

**Meeting the others?** Check [meeting and return](#meeting) for the morning landmark and the spot for the last photo.
''',
    ),
    _Chapter.meeting: (
      title: 'Meeting and return',
      body: '''
### Before we set off

Meet by the blue bench on the old platform at **09:00 on Saturday**. Keep both tickets in a single offline folder named for the day so the return ticket is easy to find.

### Lunch together

The picnic table is our meeting spot for lunch. Whoever gets there first can spread the cloth and make room for bags. Check off lunch and water in the [packing list](#packing) before heading out.

### One last photo

Return to the blue bench at **15:30**. Take a second photo from the morning's angle. The pair will make bookends for the day's album.
''',
    ),
    _Chapter.packing: (
      title: 'Packing list',
      body:
          'Tick each item as it goes into your bag. Copy the checklist into your trip notes to keep a version with those ticks.',
    ),
    _Chapter.notes: (
      title: 'Notes on the way home',
      body: '''
### Pick three photos

Start with the group at the old platform, follow it with the lunch table, then finish with the bench on the way back.

### Annotate one detail

Write down something outside the frame. Who divided the apple at lunch? Which rock face was your neighbour pointing to?

> Only half the blue bench was still in the sun when we got back. The sketchbook we opened that morning was already on its sixth page.

### Before the next trip

Revisit the [packing list](#packing) and see what you used. Copy it into your notes and adapt it for the next outing.
''',
    ),
  },
);

class FieldGuideScenario extends StatefulWidget {
  const FieldGuideScenario({super.key});

  @override
  State<FieldGuideScenario> createState() => _FieldGuideScenarioState();
}

class _FieldGuideScenarioState extends State<FieldGuideScenario> {
  static const _packingKey = 'field-guide-packed';
  _Chapter _chapter = _Chapter.overview;
  Set<int> _packed = {};
  PageStorageBucket? _bucket;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bucket = PageStorage.maybeOf(context);
    if (identical(_bucket, bucket)) return;
    _bucket = bucket;
    final stored = bucket?.readState(context, identifier: _packingKey);
    _packed = stored is List<int> ? stored.toSet() : {};
  }

  void _pack(int index, bool checked) {
    setState(() {
      if (checked) {
        _packed.add(index);
      } else {
        _packed.remove(index);
      }
    });
    _bucket?.writeState(context, _packed.toList(), identifier: _packingKey);
  }

  void _open(_Chapter chapter) {
    if (chapter != _chapter) setState(() => _chapter = chapter);
  }

  Future<void> _showContents(_Guide guide) async {
    final choice = await showModalBottomSheet<_Chapter>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                guide.contents,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final chapter in _Chapter.values)
              ListTile(
                key: ValueKey('guide-section-${chapter.index}'),
                selected: chapter == _chapter,
                leading: Icon(chapter.icon),
                title: Text(guide.pages[chapter]!.title),
                trailing: chapter == _chapter ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, chapter),
              ),
          ],
        ),
      ),
    );
    if (mounted && choice != null) _open(choice);
  }

  Future<void> _copyPacking(_Guide guide) async {
    final text = [
      '# ${guide.pages[_Chapter.packing]!.title}',
      '',
      for (final (i, item) in guide.items.indexed)
        '- [${_packed.contains(i) ? 'x' : ' '}] $item',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(guide.copied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final _Guide guide = chinese ? _zh : _en;
    final page = guide.pages[_chapter]!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final markdownStyle =
        MarkdownStyleSheet.fromBrightness(
          theme.brightness,
          baseStyle: TextStyle(
            fontSize: 16,
            height: 1.65,
            color: colors.onSurface,
          ),
        ).copyWith(
          linkStyle: TextStyle(
            color: colors.primary,
            decoration: TextDecoration.underline,
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(guide.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              key: const ValueKey('guide-contents'),
              icon: const Icon(Icons.format_list_bulleted, size: 20),
              label: Text(guide.contents),
              onPressed: () => _showContents(guide),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              key: ValueKey(_chapter),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: [
                if (_chapter == _Chapter.overview) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 2.25,
                      child: Image.asset(
                        'assets/gallery/ridgeline.jpg',
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  _chapter == _Chapter.overview ? page.title : guide.trip,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  header: true,
                  child: Text(
                    _chapter == _Chapter.overview ? guide.trip : page.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_chapter == _Chapter.overview) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('guide-packing'),
                      icon: const Icon(Icons.checklist_rounded),
                      label: Text(guide.openPacking),
                      onPressed: () => _open(_Chapter.packing),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SmoothMarkdown(
                  key: ValueKey('guide-markdown-${_chapter.index}'),
                  data: page.body.trim(),
                  styleSheet: markdownStyle,
                  onTapLink: (url) {
                    switch (url) {
                      case '#meeting':
                        _open(_Chapter.meeting);
                      case '#packing':
                        _open(_Chapter.packing);
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_chapter == _Chapter.packing) ...[
                  Text(
                    chinese
                        ? '${guide.packed} ${_packed.length} / ${guide.items.length}'
                        : '${_packed.length} / ${guide.items.length} ${guide.packed}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _packed.length / guide.items.length,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 10),
                  for (final (i, item) in guide.items.indexed)
                    CheckboxListTile(
                      key: ValueKey('guide-item-$i'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item),
                      value: _packed.contains(i),
                      onChanged: (checked) => _pack(i, checked == true),
                    ),
                  const Divider(),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const ValueKey('guide-copy'),
                      onPressed: () => _copyPacking(guide),
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: Text(guide.copyList),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

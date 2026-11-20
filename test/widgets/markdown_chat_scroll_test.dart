import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/widgets/markdown_chat_scroll.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reverse in [false, true]) {
    testWidgets(
      'chat follows growth, preserves history and resumes (reverse=$reverse)',
      (tester) async {
        final scroll = MarkdownChatScrollController();
        addTearDown(scroll.dispose);
        var count = 40;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return ListView.builder(
                    controller: scroll,
                    reverse: reverse,
                    itemExtent: 60,
                    itemCount: count,
                    itemBuilder: (_, i) => Text('message $i'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        double latest() => reverse
            ? scroll.position.minScrollExtent
            : scroll.position.maxScrollExtent;
        expect(scroll.offset, latest());
        update(() => count += 4);
        await tester.pumpAndSettle();
        expect(scroll.offset, latest());
        await tester.drag(find.byType(ListView), const Offset(0, 220));
        await tester.pumpAndSettle();
        expect(scroll.following.value, isFalse);
        final history = scroll.offset;
        update(() => count += 10);
        await tester.pumpAndSettle();
        expect(scroll.offset, history);
        scroll.jumpToLatest();
        await tester.pumpAndSettle();
        expect(scroll.following.value, isTrue);
        expect(scroll.offset, latest());
        scroll.jumpTo(reverse ? 220 : latest() - 220);
        expect(scroll.following.value, isFalse);
        scroll.jumpTo(latest());
        expect(scroll.following.value, isTrue);
        scroll.pauseFollowing();
        expect(scroll.following.value, isFalse);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'reverse chat holds the visible message as the newest answer grows',
    (t) async {
      final scroll = MarkdownChatScrollController();
      addTearDown(scroll.dispose);
      double newestHeight = 60;
      late StateSetter update;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return ListView.builder(
                  controller: scroll,
                  reverse: true,
                  itemCount: 40,
                  itemBuilder: (context, i) => SizedBox(
                    height: i == 0 ? newestHeight : 60,
                    child: Text('msg $i'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      scroll.jumpTo(130);
      await t.pumpAndSettle();
      expect(scroll.following.value, isFalse);
      final anchor = find.text('msg 4');
      final y = t.getTopLeft(anchor).dy;
      update(() => newestHeight += 120);
      await t.pumpAndSettle();

      expect(t.getTopLeft(anchor).dy, y);
    },
  );
}

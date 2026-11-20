import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A scroll controller for one chat viewport. Content follows the newest end
/// until the reader scrolls away. Scrolling back or calling [jumpToLatest]
/// resumes following. Works with a ListView or a CustomScrollView of slivers.
class MarkdownChatScrollController extends ScrollController {
  MarkdownChatScrollController({
    bool initiallyFollowing = true,
    this.resumeDistance = 16,
    super.initialScrollOffset,
    super.keepScrollOffset = false,
    super.debugLabel,
  }) : assert(resumeDistance >= 0),
       _following = ValueNotifier(initiallyFollowing);

  /// Distance in logical pixels at which scrolling toward the end reattaches.
  final double resumeDistance;
  final ValueNotifier<bool> _following;
  bool _scheduled = false;
  bool _disposed = false;

  /// Listen to this to show a jump-to-latest action while reading history.
  ValueListenable<bool> get following => _following;

  /// Stops automatic jumps without changing the current offset.
  void pauseFollowing() => _following.value = false;

  /// Reattaches to the latest content, including content laid out next frame.
  void jumpToLatest() {
    _following.value = true;
    _scheduleFollow();
  }

  void _scheduleFollow() {
    if (!_following.value || _scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed || !_following.value || positions.length != 1) return;
      final chat = position as _ChatPosition;
      if (!chat.hasContentDimensions) return;
      final end = chat.latest;
      if (end.isFinite && (end - chat.pixels).abs() > 0.5) chat.jumpTo(end);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _ChatPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    owner: this,
  );

  @override
  void dispose() {
    _disposed = true;
    _following.dispose();
    super.dispose();
  }
}

class _ChatPosition extends ScrollPositionWithSingleContext {
  _ChatPosition({
    required super.physics,
    required super.context,
    required this.owner,
    super.oldPosition,
  }) : super(
         initialPixels: owner.initialScrollOffset,
         keepScrollOffset: owner.keepScrollOffset,
       );

  final MarkdownChatScrollController owner;
  RenderViewportBase? _viewport;
  RenderBox? _historyRow;
  double _historyOffset = 0;

  // In a reversed list the streaming message precedes older messages in
  // layout order. Pin a visible history row using its measured layout offset.
  // Changes at the far end of the list must not move the reader.
  double? _rowOffset(RenderBox? row) {
    final sliver = row?.parent;
    final data = row?.parentData;
    if (row?.attached != true ||
        sliver is! RenderSliverMultiBoxAdaptor ||
        data is! SliverMultiBoxAdaptorParentData ||
        data.keptAlive ||
        data.layoutOffset == null) {
      return null;
    }
    return sliver.constraints.precedingScrollExtent + data.layoutOffset!;
  }

  void _rememberHistoryRow() {
    if (_viewport?.attached != true) {
      void findViewport(RenderObject object) {
        if (object is RenderViewportBase) {
          if (identical(object.offset, this)) _viewport = object;
          return;
        }
        if (_viewport?.attached != true) object.visitChildren(findViewport);
      }

      final root = context.notificationContext?.findRenderObject();
      if (root != null) findViewport(root);
    }
    _historyRow = null;
    final center = pixels + viewportDimension / 2;
    var nearest = double.infinity;
    void visit(RenderObject object) {
      if (object is RenderSliverMultiBoxAdaptor) {
        for (
          var row = object.firstChild;
          row != null;
          row = object.childAfter(row)
        ) {
          final offset = _rowOffset(row);
          if (offset == null) continue;
          final distance = (offset - center).abs();
          if (distance < nearest) {
            _historyRow = row;
            _historyOffset = offset;
            nearest = distance;
          }
        }
      } else if (object is RenderSliver) {
        object.visitChildren(visit);
      }
    }

    _viewport?.visitChildren(visit);
  }

  bool get _reversed =>
      axisDirection == AxisDirection.up || axisDirection == AxisDirection.left;
  double get latest => _reversed ? minScrollExtent : maxScrollExtent;

  void _trackMove(double previous) {
    if (!hasContentDimensions || pixels == previous || owner._disposed) return;
    final oldDistance = (latest - previous).abs();
    final distance = (latest - pixels).abs();
    if (outOfRange) return;
    if (distance > oldDistance) {
      owner.pauseFollowing();
    } else if (distance <= owner.resumeDistance) {
      owner._following.value = true;
    }
  }

  @override
  double setPixels(double newPixels) {
    final previous = pixels;
    final overscroll = super.setPixels(newPixels);
    _trackMove(previous);
    return overscroll;
  }

  @override
  void pointerScroll(double delta) {
    final previous = pixels;
    super.pointerScroll(delta);
    _trackMove(previous);
  }

  @override
  void jumpTo(double value) {
    final previous = pixels;
    super.jumpTo(value);
    _trackMove(previous);
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (_reversed && !owner._following.value) {
      final offset = _rowOffset(_historyRow);
      if (offset != null && (offset - _historyOffset).abs() > 0.01) {
        final adjusted = (pixels + offset - _historyOffset).clamp(
          minScrollExtent,
          maxScrollExtent,
        );
        _historyOffset = offset;
        if (adjusted != pixels) {
          correctBy(adjusted - pixels);
          return false;
        }
      }
      _rememberHistoryRow();
    } else {
      _historyRow = null;
    }
    final changed =
        !hasContentDimensions ||
        (_reversed
            ? this.minScrollExtent != minScrollExtent
            : this.maxScrollExtent != maxScrollExtent);
    final applied = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    if (changed) owner._scheduleFollow();
    return applied;
  }
}

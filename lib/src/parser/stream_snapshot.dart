import 'dart:collection';

/// Package-internal immutable publication of an incremental parser's nodes.
/// Completed pages belong to snapshots, never to a mutable parser buffer.
/// Replacing a tail copies at most one retained page plus the page directory.
class StreamSnapshot<T> extends UnmodifiableListView<T> {
  StreamSnapshot._(this._storage) : super(_storage);

  factory StreamSnapshot.empty() =>
      StreamSnapshot._(_SnapshotStorage<T>([], 0));

  final _SnapshotStorage<T> _storage;
  static const _pageShift = 7;
  static const _pageSize = 1 << _pageShift;
  static const _pageMask = _pageSize - 1;

  StreamSnapshot<T> replaceTail(int retained, List<T> tail) {
    RangeError.checkValueInInterval(retained, 0, length, 'retained');
    final complete = retained >> _pageShift;
    final partial = retained & _pageMask;
    final pages = <List<T>>[
      for (var i = 0; i < complete; i++) _storage.pages[i],
    ];
    var offset = 0;
    if (partial != 0) {
      final count = tail.length < _pageSize - partial
          ? tail.length
          : _pageSize - partial;
      final previous = _storage.pages[complete];
      pages.add(
        List<T>.generate(
          partial + count,
          (i) => i < partial ? previous[i] : tail[i - partial],
          growable: false,
        ),
      );
      offset = count;
    }
    while (offset < tail.length) {
      final end = offset + _pageSize < tail.length
          ? offset + _pageSize
          : tail.length;
      final begin = offset;
      pages.add(
        List<T>.generate(end - begin, (i) => tail[begin + i], growable: false),
      );
      offset = end;
    }
    return StreamSnapshot._(_SnapshotStorage(pages, retained + tail.length));
  }
}

class _SnapshotStorage<T> extends ListBase<T> {
  _SnapshotStorage(this.pages, this.length);
  final List<List<T>> pages;
  @override
  final int length;
  @override
  set length(int value) => throw UnsupportedError('Immutable stream snapshot');

  @override
  T operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return pages[index >> StreamSnapshot._pageShift][index &
        StreamSnapshot._pageMask];
  }

  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('Immutable stream snapshot');
}

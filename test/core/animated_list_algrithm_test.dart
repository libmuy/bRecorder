import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

_ListModel<String> _list = _ListModel<String>();

bool _isVisible(o) {
  return true;
}

Future<void> _waitListItemAnimation() async {}

Future<void> _listListener(List<String> newItems) async {
  // Remove items not exists in new folder
  // final newItems = widget.listNotifier.value;
  final itemsForRemove = [];
  for (var item in _list.items) {
    if (!newItems.contains(item)) itemsForRemove.add(item);
  }
  for (var item in itemsForRemove.reversed) {
    _list.removeAt(_list.indexOf(item));
    if (_isVisible(item)) await _waitListItemAnimation();
  }

  // Divide new list into ranges
  List<_Range> ranges = [];
  int rangeStart = 0;
  int rangeStartInOldList = 0;
  _RangeType rangeType = _RangeType.init;

  void addRange(int index, int indexInOldList) {
    ranges.add(_Range(
      start: rangeStart,
      startInOldList: rangeStartInOldList,
      len: index - rangeStart,
      type: rangeType,
    ));
    rangeStart = index;
    rangeStartInOldList = indexInOldList;
  }

  void dumpRanges() {
    debugPrint("Old List:${_list.items}");
    debugPrint("New List:$newItems");
    debugPrint("============= DUMP RANGES ================");
    for (final r in ranges) {
      String val = "";
      for (var i = r.start; i < r.start + r.len; i++) {
        val += "${newItems[i]}, ";
      }
      String oldListVal = "";
      if (r.type == _RangeType.existInList) {
        oldListVal =
            "In old list:(${r.startInOldList} - ${r.startInOldList + r.len - 1}): ";
        for (var i = r.startInOldList; i < r.startInOldList + r.len; i++) {
          oldListVal += "${_list.items[i]}, ";
        }
      }
      debugPrint(
          "Range(${r.start} - ${r.start + r.len - 1}): ${val.padRight(20)} $oldListVal");
    }
  }

  for (var i = 0; i < newItems.length; i++) {
    final indexInRange = i - rangeStart;
    final newItem = newItems[i];
    final indexInOldList = _list.items.indexOf(newItem);
    var newType = indexInOldList >= 0
        ? _RangeType.existInList
        : _RangeType.notExistInList;

    // First item
    if (rangeType == _RangeType.init) {
      rangeType = newType;
      continue;
    }

    if (rangeType == newType) {
      if (newType == _RangeType.existInList &&
          rangeStartInOldList + indexInRange != indexInOldList) {
        addRange(i, indexInOldList);
      }
      continue;
    }
    addRange(i, indexInOldList);
    rangeType = newType;
  }
  addRange(newItems.length, 0);

  dumpRanges();

  // // add new item not exists in current list
  // for (var i = 0; i < newItems.length; i++) {
  //   final item = newItems[i];
  //   if (!_list.items.contains(item)) {
  //     // final pos = i == 0 ? 0 : _list.indexOf(newItems[i - 1]);
  //     _list.insert(i, item);
  //     await _waitListItemAnimation();
  //   }
  // }
}

void main() {
  test("", () async {
    final items = ["1", "5", "6", "7", "8", "3", "0"];
    final newItems = ["1", "5", "3", "4", "2", "6", "7"];

    _list.items = items;
    _listListener(newItems);
    // expect(_list.items, newItems);
  });
}

class _ListModel<E> {
  _ListModel({
    Iterable<E>? initialItems,
  }) : items = List<E>.from(initialItems ?? <E>[]);
  List<E> items;

  void insert(int index, E item) {
    items.insert(index, item);
  }

  E removeAt(int index) {
    // log.debug("remove item:$index");

    final E removedItem = items.removeAt(index);
    return removedItem;
  }

  E removeEnd() {
    return removeAt(length - 1);
  }

  void add(E item) {
    insert(length, item);
  }

  int get length => items.length;

  E operator [](int index) => items[index];

  int indexOf(E item) => items.indexOf(item);
}

class _Range {
  // int count;
  int start;
  int startInOldList;
  int len;
  _RangeType type;

  _Range({
    // required this.count,
    required this.start,
    required this.startInOldList,
    required this.len,
    this.type = _RangeType.init,
  });
}

enum _RangeType {
  init,
  existInList,
  notExistInList,
}

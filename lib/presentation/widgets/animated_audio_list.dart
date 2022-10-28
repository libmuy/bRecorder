import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/utils/notifiers.dart';
import '../../core/utils/task_queue.dart';
import '../../core/utils/utils.dart';
import '../../data/repository.dart';
import '../../domain/entities.dart';
import '../ploc/browser_view_state.dart';
import 'audio_list_item/audio_widget.dart';
import 'audio_list_item/audio_widget_state.dart';

final log = Logger('AudioList');

/*=======================================================================*\ 
  Widget
\*=======================================================================*/
class AnimatedAudioSliver extends StatefulWidget {
  // final ValueNotifier<bool> showingNotifier;
  final RepoType repoType;
  final bool editable;
  final ForcibleValueNotifier<List<AudioObject>> listNotifier;
  const AnimatedAudioSliver({
    Key? key,
    required this.repoType,
    this.editable = true,
    // required this.showingNotifier,
    required this.listNotifier,
  }) : super(key: key);

  @override
  State<AnimatedAudioSliver> createState() => _AnimatedAudioSliverState();
}

/*=======================================================================*\ 
  State
\*=======================================================================*/
class _AnimatedAudioSliverState extends State<AnimatedAudioSliver> {
  late BrowserViewState state = sl.getBrowserViewState(widget.repoType);
  final GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();
  final modeNotifier = sl.get<GlobalModeNotifier>();
  final TaskQueue _taskQueue = TaskQueue();
  late _ListModel _list;
  final _listItemAnimationDurationMS = 300.0;
  bool _cancelUpdateList = false;

  @override
  void initState() {
    super.initState();
    widget.listNotifier.addListener(_listListener);
    SchedulerBinding.instance.addPostFrameCallback(_postFrameCallback);

    _list = _ListModel(
      listKey: _listKey,
      removedItemBuilder: _buildRemovedItem,
      copyForRemovedItem: _copyRemovedItem,
      durationMS: _listItemAnimationDurationMS.toInt(),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _postFrameCallback(_) {
    _listListener();
  }

  /*=======================================================================*\ 
    LIST UPDATE: 
  \*=======================================================================*/
  /*===========================================================*\ 
    LIST UPDATE: DEBUG: dump range functions
  \*===========================================================*/
  // String _dumpRange(_Range r) {
  //   final newItems = widget.listNotifier.value;
  //   String val = "";
  //   for (var i = r.start; i < r.start + r.len; i++) {
  //     val += "${newItems[i]}, ";
  //   }
  //   String oldListVal = "";
  //   if (r.type == _RangeType.existInList) {
  //     oldListVal =
  //         "In old list:(${r.startInOldList} - ${r.startInOldList + r.len - 1}): ";
  //     for (var i = r.startInOldList; i < r.startInOldList + r.len; i++) {
  //       if (i < _list.items.length) oldListVal += "${_list.items[i]}, ";
  //     }
  //   }
  //   final preserveStr = "preserve: ${r.preserve}";
  //   return ("Range(${r.start} - ${r.start + r.len - 1}): "
  //       "${preserveStr.padRight(20)}"
  //       "${val.padRight(20)} $oldListVal");
  // }

  // void _dumpRanges(List<_Range> ranges) {
  //   final newItems = widget.listNotifier.value;
  //   log.debug("Old List:${_list.items}");
  //   log.debug("New List:$newItems");
  //   log.debug("Dump Ranges:-----------------");
  //   for (final r in ranges) {
  //     log.debug(_dumpRange(r));
  //   }
  // }

  String _dumpNewRange(_Range r) {
    final newItems = widget.listNotifier.value;
    String val = "";
    for (var i = r.start; i < r.start + r.len; i++) {
      val += "${newItems[i]}, ";
    }
    final preserveStr = "preserve: ${r.preserve}";
    return ("New Range(${r.start} - ${r.start + r.len - 1}): "
        "${preserveStr.padRight(20)}"
        "${val.padRight(20)}");
  }

  String _dumpOldRange(_Range r) {
    String oldListVal = "";
    if (r.type == _RangeType.existInList) {
      for (var i = r.startInOldList; i < r.startInOldList + r.len; i++) {
        if (i < _list.items.length) oldListVal += "${_list.items[i]}, ";
      }
    }
    return ("Old Range(${r.start} - ${r.start + r.len - 1}): "
        "${oldListVal.padRight(20)}");
  }

  /*===========================================================*\ 
    LIST UPDATE: List change listener
  \*===========================================================*/
  Future<void> _listListener() async {
    _taskQueue.replaceAll(Task(
      (_) => _updateList(List.of(widget.listNotifier.value)),
      cancel: () => _cancelUpdateList = true,
    ));
  }

  Future<void> _updateList(List<AudioObject> newItems) async {
    final oldItems = List.of(_list.items);
    if (_cancelUpdateList) _cancelUpdateList = false;
    log.debug("Update list Start");
    // Divide new list into ranges
    List<_Range> ranges = [];
    int rangeStart = 0;
    int rangeStartInOldList = 0;
    _RangeType rangeType = _RangeType.init;

    /*===========================================================*\ 
      LIST UPDATE: Range Operation functions
    \*===========================================================*/
    /* ------------------ Create a new range ------------------ */
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

    /* ------------------ Find preserve range ------------------ */
    // Find out ranges which shoud not be removed (be preserved)
    void findPreserveRanges(List<_Range> ranges, int? start, int? end) {
      final startIndex = start ?? 0;
      final endIndex = end ?? ranges.length - 1;
      int biggest = -1;

      for (int i = startIndex; i <= endIndex; i++) {
        final r = ranges[i];
        if (start != null) {
          final startRange = ranges[start];
          if (startRange.preserve) {
            if (r.startInOldList <= startRange.startInOldList) continue;
          }
        }
        if (end != null) {
          final endRange = ranges[end];
          if (endRange.preserve) {
            if (r.startInOldList >= endRange.startInOldList) continue;
          }
        }

        if (biggest < 0) {
          biggest = i;
        } else {
          final biggestRange = ranges[biggest];
          if (r.len > biggestRange.len) biggest = i;
        }
      }

      if (biggest >= 0) {
        ranges[biggest].preserve = true;
        findPreserveRanges(ranges, start, biggest);
        findPreserveRanges(ranges, biggest, end);
      }
    }

    /* ------------------ Remove other ranges ------------------ */
    // Remove ranges its order is inconsistent with preserved one
    Future<void> removeRangeInOldList(_Range range) async {
      var times = range.len;
      while (times-- > 0) {
        await _list.removeAt(range.startInOldList);
        if (_cancelUpdateList) return;
      }
      range.type = _RangeType.notExistInList;

      for (final r in ranges.where((e) => e.type == _RangeType.existInList)) {
        if (range.startInOldList < r.startInOldList) {
          r.startInOldList -= range.len;
        }
      }
    }

    /* ------------------ Insert ranges ------------------ */
    // Insert ranges which is not exists in current list
    Future<void> insertRangeIntoOldListAt(int index) async {
      final rangeInsert = ranges[index];
      var dumpStr = _dumpNewRange(rangeInsert);
      final rangesBefore = ranges.sublist(0, index).where((r) => r.preserve);
      final rangesAfter = ranges.sublist(index + 1).where((r) => r.preserve);

      if (rangesAfter.isNotEmpty) {
        final rangeNext = rangesAfter.first;
        final rangeNextStr = _dumpOldRange(rangeNext);
        log.debug("Insert $dumpStr before: $rangeNextStr");

        for (var i = 0; i < rangeInsert.len; i++) {
          final index = rangeNext.startInOldList + i;
          final item = newItems[rangeInsert.start + i];
          await _list.insert(index, item);
          if (_cancelUpdateList) return;
        }
        log.debug("Old List:${_list.items}");

        for (final r in rangesAfter) {
          r.startInOldList += rangeInsert.len;
        }
      } else if (rangesBefore.isNotEmpty) {
        final rangePrev = rangesBefore.last;
        final rangePrevStr = _dumpOldRange(rangePrev);
        log.debug("Insert $dumpStr after: $rangePrevStr");
        for (var i = 0; i < rangeInsert.len; i++) {
          final index = rangePrev.startInOldList + rangePrev.len + i;
          final item = newItems[rangeInsert.start + i];
          await _list.insert(index, item);
          if (_cancelUpdateList) return;
        }
        log.debug("Old List:${_list.items}");
        rangePrev.len += rangeInsert.len;
      } else {
        log.debug("Insert: $dumpStr ");
        assert(index == 0 && _list.length == 0);
        for (var i = 0; i < rangeInsert.len; i++) {
          final item = newItems[rangeInsert.start + i];
          await _list.insert(i, item);
          if (_cancelUpdateList) return;
        }
        log.debug("Old List:${_list.items}");
        rangeInsert.startInOldList = 0;
        rangeInsert.preserve = true;
      }
    }

    /*===========================================================*\ 
      Remove items not exists in new folder
    \*===========================================================*/
    final itemsForRemove = [];
    for (var item in oldItems) {
      if (!newItems.contains(item)) itemsForRemove.add(item);
    }
    for (var item in itemsForRemove.reversed) {
      oldItems.remove(item);
      if (_cancelUpdateList) {
        _cancelUpdateList = false;
        log.debug("Update list End: canceled");
        return;
      }
    }

    /*===========================================================*\ 
      Create ranges
    \*===========================================================*/
    for (var i = 0; i < newItems.length; i++) {
      final indexInRange = i - rangeStart;
      final newItem = newItems[i];
      final indexInOldList = oldItems.indexOf(newItem);
      var newType = indexInOldList >= 0
          ? _RangeType.existInList
          : _RangeType.notExistInList;

      // First item
      if (rangeType == _RangeType.init) {
        rangeType = newType;
        rangeStartInOldList = indexInOldList;
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

    // log.debug("========== "
    //     "Detected Ranges:"
    //     " ========== ");
    // _dumpRanges(ranges);

    /*===========================================================*\ 
      Find out ranges which shoud not be removed
    \*===========================================================*/
    final rangesInOldList =
        ranges.where((g) => g.type == _RangeType.existInList).toList();
    findPreserveRanges(rangesInOldList, null, null);
    // log.debug("========== "
    //     "Checked Ranges:"
    //     " ========== ");
    // _dumpRanges(ranges);

    /*===========================================================*\ 
      Decide algorithm to update list
      -------------------------------
      preserve item count < others : Update list with Ranges
      preserve item count >= others: Remove all items and add new ones
    \*===========================================================*/
    final removeCount = itemsForRemove.length;
    var insertCount = 0;
    ranges
        .where((r) => r.type == _RangeType.notExistInList || !r.preserve)
        .forEach((r) => insertCount += r.len);
    var preserveCount = 0;
    ranges
        .where((r) => r.type == _RangeType.existInList && r.preserve)
        .forEach((r) => preserveCount += r.len);

    /*===========================================================*\ 
      Remove all items and add new ones
    \*===========================================================*/
    if (removeCount + insertCount > preserveCount) {
      await _list.clear();
      await Future.delayed(
          Duration(milliseconds: _listItemAnimationDurationMS.toInt()));

      for (var item in newItems) {
        await _list.add(item);
      }
      return;
    }

    /*===========================================================*\ 
      Remove items not exists in new folder
    \*===========================================================*/
    for (var item in itemsForRemove.reversed) {
      await _list.removeItem(item);

      if (_cancelUpdateList) {
        _cancelUpdateList = false;
        log.debug("Update list End: canceled");
        return;
      }
    }
    /*===========================================================*\ 
      Remove ranges its order is inconsistent with preserved one
    \*===========================================================*/
    final rangesForRemove = ranges
        .where((r) => r.type == _RangeType.existInList && r.preserve == false);

    for (var r in rangesForRemove) {
      await removeRangeInOldList(r);
      if (_cancelUpdateList) {
        _cancelUpdateList = false;
        log.debug("Update list End: canceled");
        return;
      }
    }

    await Future.delayed(
        Duration(milliseconds: _listItemAnimationDurationMS.toInt()));
    // log.debug("=================== "
    //     "Removed Ranges in Old list"
    //     " ================= ");
    // _dumpRanges(ranges);

    /*===========================================================*\ 
      Insert ranges which is not exists in current list
    \*===========================================================*/
    for (var i = 0; i < ranges.length; i++) {
      if (!ranges[i].preserve) await insertRangeIntoOldListAt(i);
      if (_cancelUpdateList) {
        _cancelUpdateList = false;
        log.debug("Update list End: canceled");
        return;
      }
    }
    if (_cancelUpdateList) _cancelUpdateList = false;
    // log.debug("==================="
    //     " Inserted Ranges into Old list "
    //     "================= ");
    // log.debug("Old List:${_list.items}");
    // log.debug("New List:$newItems");
    log.debug("Update list End");
  }

  /*=======================================================================*\ 
    Build Items
  \*=======================================================================*/
  // Used to build list items that haven't been removed.
  Widget _buildItem(
      BuildContext context, int index, Animation<double> animation) {
    final obj = _list[index];
    final itemState = obj.displayData as AudioWidgetState;
    return FadeTransition(
      opacity: animation,
      child: AudioWidget(
        key: itemState.key,
        audioItem: obj,
        state: itemState,
        onTap: (iconOnTapped) {
          if (obj is FolderInfo) {
            state.folderOnTap(obj);
          } else if (obj is AudioInfo) {
            state.audioOnTap(obj, iconOnTapped);
          }
        },
        onLongPressed: state.onListItemLongPressed,
      ),
    );
  }

  // Used to build an item after it has been removed from the list. This
  // method is needed because a removed item remains visible until its
  // animation has completed (even though it's gone as far this ListModel is
  // concerned). The widget will be used by the
  // [AnimatedListState.removeItem] method's
  // [AnimatedListRemovedItemBuilder] parameter.
  Widget _buildRemovedItem(
      int index, BuildContext context, Animation<double> animation) {
    final obj = _list.removedItem(index);
    if (obj == null) {
      log.debug("build removed item:$index, item not exists");

      return const Text("Audio Object not exists");
    }

    final itemState = obj.displayData as AudioWidgetState;
    return FadeTransition(
      opacity: animation,
      child: AudioWidget(
        audioItem: obj,
        state: itemState,
      ),
    );
  }

  AudioObject _copyRemovedItem(AudioObject obj) {
    AudioObject ret;
    if (obj is AudioInfo) {
      final audio = obj;
      ret = audio.copyWith(parent: null);
    } else {
      final folder = obj as FolderInfo;
      ret = folder.copyWith(parent: null, deep: false);
    }
    var itemState = AudioListItemMode.normal;
    if (modeNotifier.value == GlobalMode.edit && widget.editable) {
      itemState = AudioListItemMode.notSelected;
    }

    GlobalKey? key;
    if (ret.displayData != null) {
      final newItemState = ret.displayData as AudioWidgetState;
      key = newItemState.key;
    }
    ret.displayData = AudioWidgetState(ret, mode: itemState, key: key);
    return ret;
  }

  /*=======================================================================*\ 
    Build method
  \*=======================================================================*/
  @override
  Widget build(BuildContext context) {
    return SliverAnimatedList(
      key: _listKey,
      // initialItemCount: _list.length,
      itemBuilder: _buildItem,
    );
  }
}

typedef RemovedItemBuilder = Widget Function(
    int item, BuildContext context, Animation<double> animation);

// Keeps a Dart [List] in sync with an [AnimatedList].
//
// The [insert] and [removeAt] methods apply to both the internal list and
// the animated list that belongs to [listKey].
//
// This class only exposes as much of the Dart List API as is needed by the
// sample app. More list methods are easily added, however methods that
// mutate the list must make the same changes to the animated list in terms
// of [AnimatedListState.insertItem] and [AnimatedList.removeItem].
class _ListModel {
  _ListModel({
    required this.listKey,
    required this.removedItemBuilder,
    Iterable<AudioObject>? initialItems,
    required this.copyForRemovedItem,
    this.durationMS = 300,
  }) : _items = List<AudioObject>.from(initialItems ?? <AudioObject>[]);

  final GlobalKey<SliverAnimatedListState> listKey;
  final RemovedItemBuilder removedItemBuilder;
  final AudioObject Function(AudioObject) copyForRemovedItem;
  final List<AudioObject> _items;
  final _removedItems = <int, AudioObject?>{};
  final int durationMS;
  FolderInfo? currentFolder;
  // bool _showChildOffset = true;

  SliverAnimatedListState get _animatedList => listKey.currentState!;

  // Future<void> _waitListItemAnimation() async {
  //   // await Future.delayed(Duration(
  //   //     microseconds: (_listItemAnimationDurationMS.toDouble() * 0.7).toInt()));
  //   final ms = durationMS ~/ 10;
  //   await Future.delayed(Duration(milliseconds: ms));
  // }

  bool _isVisible(AudioObject obj) {
    final itemState = obj.displayData as AudioWidgetState;
    final box = itemState.key.currentContext?.findRenderObject() as RenderBox?;
    return box != null;
  }

  Future<void> insert(int index, AudioObject item) async {
    _items.insert(index, item);
    _animatedList.insertItem(index,
        duration: Duration(milliseconds: durationMS));
    // bool isVisible = _isVisible(_items[index]);
    // if (!isVisible && index > 0) isVisible = _isVisible(_items[index - 1]);

    // if (isVisible) await _waitListItemAnimation();

    // if (_items.length > 5 && _showChildOffset) {
    //   final firstItem = items[0].displayData as AudioListItemState;
    //   final secondItem = items[1].displayData as AudioListItemState;

    //   // final boxParent = context.findRenderObject() as RenderBox?;
    //   final boxChild1 =
    //       firstItem.key.currentContext?.findRenderObject() as RenderBox?;
    //   final boxChild2 =
    //       secondItem.key.currentContext?.findRenderObject() as RenderBox?;
    //   // log.debug("parent Offset:${boxParent}");
    //   log.debug("first  List Item Offset:$boxChild1");
    //   log.debug("second List Item Offset:$boxChild2");
    //   _showChildOffset = false;
    // }
  }

  Future<AudioObject> removeAt(int index) async {
    // log.debug("remove item:$index");

    final AudioObject removedItem = _items.removeAt(index);
    _removedItems[index] = copyForRemovedItem(removedItem);
    _animatedList.removeItem(
      index,
      duration: Duration(milliseconds: durationMS),
      (BuildContext context, Animation<double> animation) {
        final ret = removedItemBuilder(index, context, animation);
        // _removedItems[index] = null;
        return ret;
      },
    );
    // if (_isVisible(removedItem)) await _waitListItemAnimation();

    return removedItem;
  }

  Future<AudioObject> removeEnd() {
    return removeAt(length - 1);
  }

  Future<AudioObject> removeItem(AudioObject item) {
    final index = indexOf(item);
    assert(index >= 0);
    return removeAt(index);
  }

  Future<void> clear() async {
    for (var i = items.length - 1; i >= 0; i--) {
      if (!_isVisible(items[i])) await removeAt(i);
    }
    for (var i = items.length - 1; i >= 0; i--) {
      await removeAt(i);
    }
  }

  Future<void> add(AudioObject item) async {
    await insert(length, item);
  }

  AudioObject? removedItem(int index) => _removedItems[index];

  int get length => _items.length;

  AudioObject operator [](int index) => _items[index];

  int indexOf(AudioObject item) => _items.indexOf(item);

  List<AudioObject> get items => _items;
}

class _Range {
  // int count;
  int start;
  int startInOldList;
  int len;
  _RangeType type;
  bool preserve = false;

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

import 'package:brecorder/core/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../data/repository_type.dart';
import '../../domain/entities.dart';
import '../ploc/browser_view_state.dart';
import 'audio_list_item/audio_list_item.dart';
import 'audio_list_item/audio_list_item_state.dart';

final log = Logger('AudioList', level: LogLevel.debug);

class AnimatedAudioSliver extends StatefulWidget {
  // final ValueNotifier<bool> showingNotifier;
  final RepoType repoType;
  final bool editable;
  final ValueNotifier<List<AudioObject>> listNotifier;
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

class _AnimatedAudioSliverState extends State<AnimatedAudioSliver> {
  late BrowserViewState state = sl.getBrowserViewState(widget.repoType);
  final GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();
  final modeNotifier = sl.get<GlobalModeNotifier>();

  late ListModel<AudioObject> _list;
  final _listItemAnimationDurationMS = 300.0;

  @override
  void initState() {
    super.initState();
    widget.listNotifier.addListener(_listListener);
    SchedulerBinding.instance.addPostFrameCallback(_postFrameCallback);

    _list = ListModel<AudioObject>(
      listKey: _listKey,
      removedItemBuilder: _buildRemovedItem,
      copyForRemovedItem: _copyRemovedItem,
      duration: Duration(milliseconds: _listItemAnimationDurationMS.toInt()),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _postFrameCallback(_) {
    _listListener();
  }

  @override
  Future<void> _waitListItemAnimation() async {
    // await Future.delayed(Duration(
    //     microseconds: (_listItemAnimationDurationMS.toDouble() * 0.7).toInt()));
    final ms = _listItemAnimationDurationMS ~/ 10;
    await Future.delayed(Duration(milliseconds: ms));
  }

  bool _isVisible(AudioObject obj) {
    final itemState = obj.displayData as AudioListItemState;
    final box = itemState.key.currentContext?.findRenderObject() as RenderBox?;
    return box != null;
  }

  Future<void> _listListener() async {
    // if (_list.currentFolder == null ||
    //     _list.currentFolder != _folderNotifier.value) {
    //   if (_list.items.isNotEmpty) {
    //     //check the showing part(start and end index)
    //     var showingStart = 10000000;
    //     var showingEnd = -1;
    //     _list._items.asMap().forEach((index, item) {
    //       if (_isVisible(item)) {
    //         if (index < showingStart) showingStart = index;
    //         if (index > showingEnd) showingEnd = index;
    //       }
    //     });

    //     // remove not showing tail part
    //     for (var i = _list.length - 1; i > showingEnd; i--) {
    //       _list.removeAt(i);
    //     }
    //     //remove not showing head part
    //     for (var i = 0; i < showingStart; i++) {
    //       _list.removeAt(0);
    //     }
    //     //remove showing part
    //     while (_list.items.isNotEmpty) {
    //       _list.removeEnd();
    //       await _waitListItemAnimation();
    //     }

    //     //  var i = _list.length;
    //     // while (--i >= 0) {
    //     //   _list.removeAt(i);
    //     //   if (i >= showingStart && i <= showingEnd) {
    //     //     await _waitListItemAnimation();
    //     //   }
    //     // }
    //     final animationDoneDuration =
    //         Duration(milliseconds: _listItemAnimationDurationMS.toInt());
    //     await Future.delayed(animationDoneDuration);
    //   }
    //   for (var obj in _folderNotifier.value.subObjects) {
    //     _list.add(obj);
    //     await _waitListItemAnimation();
    //   }
    //   _list.currentFolder = _folderNotifier.value;
    //   return;
    // }

    // // remove items not exists in new folder
    // final newItems = _folderNotifier.value.subObjects;
    // final itemsForRemove = [];
    // _list.items.forEach((item) {
    //   if (!newItems.contains(item)) itemsForRemove.add(item);
    // });
    // for (var item in itemsForRemove) {
    //   _list.removeAt(_list.indexOf(item));
    //   await _waitListItemAnimation();
    // }

    // // add new item not exists in current list
    // for (var i = 0; i < newItems.length; i++) {
    //   final item = newItems[i];
    //   if (!_list.items.contains(item)) {
    //     // final pos = i == 0 ? 0 : _list.indexOf(newItems[i - 1]);
    //     _list.insert(i, item);
    //     await _waitListItemAnimation();
    //   }
    // }

    // remove items not exists in new folder
    final newItems = widget.listNotifier.value;
    final itemsForRemove = [];
    for (var item in _list.items) {
      if (!newItems.contains(item)) itemsForRemove.add(item);
    }
    for (var item in itemsForRemove.reversed) {
      _list.removeAt(_list.indexOf(item));
      if (_isVisible(item)) await _waitListItemAnimation();
    }

    // add new item not exists in current list
    for (var i = 0; i < newItems.length; i++) {
      final item = newItems[i];
      if (!_list.items.contains(item)) {
        // final pos = i == 0 ? 0 : _list.indexOf(newItems[i - 1]);
        _list.insert(i, item);
        await _waitListItemAnimation();
      }
    }
  }

  // Used to build list items that haven't been removed.
  Widget _buildItem(
      BuildContext context, int index, Animation<double> animation) {
    final obj = _list[index];
    final itemState = obj.displayData as AudioListItemState;
    return FadeTransition(
      opacity: animation,
      child: AudioListItem(
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

    final itemState = obj.displayData as AudioListItemState;
    return FadeTransition(
      opacity: animation,
      child: AudioListItem(
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
      final newItemState = ret.displayData as AudioListItemState;
      key = newItemState.key;
    }
    ret.displayData = AudioListItemState(ret, mode: itemState, key: key);
    return ret;
  }

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
class ListModel<E> {
  ListModel({
    required this.listKey,
    required this.removedItemBuilder,
    Iterable<E>? initialItems,
    required this.copyForRemovedItem,
    this.duration = const Duration(milliseconds: 300),
  }) : _items = List<E>.from(initialItems ?? <E>[]);

  final GlobalKey<SliverAnimatedListState> listKey;
  final RemovedItemBuilder removedItemBuilder;
  final E Function(E) copyForRemovedItem;
  final List<E> _items;
  final _removedItems = <int, E?>{};
  final Duration duration;
  FolderInfo? currentFolder;

  SliverAnimatedListState get _animatedList => listKey.currentState!;

  void insert(int index, E item) {
    _items.insert(index, item);
    _animatedList.insertItem(index, duration: duration);
  }

  E removeAt(int index) {
    // log.debug("remove item:$index");

    final E removedItem = _items.removeAt(index);
    if (removedItem != null) {
      _removedItems[index] = copyForRemovedItem(removedItem);
      _animatedList.removeItem(
        index,
        duration: duration,
        (BuildContext context, Animation<double> animation) {
          final ret = removedItemBuilder(index, context, animation);
          // _removedItems[index] = null;
          return ret;
        },
      );
    }
    return removedItem;
  }

  E removeEnd() {
    return removeAt(length - 1);
  }

  void add(E item) {
    insert(length, item);
  }

  E? removedItem(int index) => _removedItems[index];

  int get length => _items.length;

  E operator [](int index) => _items[index];

  int indexOf(E item) => _items.indexOf(item);

  List<E> get items => _items;
}

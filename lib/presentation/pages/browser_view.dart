import 'dart:async';

import 'package:brecorder/presentation/widgets/audio_list_item/audio_list_item_state.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/utils/notifiers.dart';
import '../../data/repository_type.dart';
import '../../domain/entities.dart';
import '../ploc/browser_view_state.dart';
import '../widgets/animated_audio_list.dart';
import '../widgets/dialogs.dart';
import '../widgets/search_box.dart';

final log = Logger('BrowserView', level: LogLevel.debug);

/*=======================================================================*\ 
  Widget
\*=======================================================================*/
class BrowserView extends StatefulWidget {
  final RepoType repoType;
  final bool folderOnly;
  final bool groupByDate;
  final bool editable;
  final bool persistPath;
  final bool destoryRepoCache;
  final ValueNotifier<String> titleNotifier;
  final void Function(FolderInfo folder)? onFolderChanged;
  const BrowserView({
    Key? key,
    required this.repoType,
    required this.titleNotifier,
    this.folderOnly = false,
    this.persistPath = true,
    this.destoryRepoCache = false,
    this.editable = true,
    this.onFolderChanged,
    this.groupByDate = false,
  }) : super(key: key);

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

/*=======================================================================*\ 
  State
\*=======================================================================*/
class _BrowserViewState extends State<BrowserView>
    with
        AutomaticKeepAliveClientMixin<BrowserView>,
        SingleTickerProviderStateMixin {
  late BrowserViewState state;
  final _folderNotifier = ForcibleValueNotifier(FolderInfo.empty);
  final modeNotifier = sl.get<GlobalModeNotifier>();
  late ScrollController _scrollController;
  bool _scrollSwitch = false;
  Map<String, _AudioItemGroup>? _groups;
  final _scrollViewKey = GlobalKey();

// For Search Header
  final _searchCancelNotifier = SimpleNotifier();
  final _searchBoxHeightNotifier = ValueNotifier(0.0);
  double _lastScrollPosition = 0.0;
  static const _ksearchBoxTopPadding = 10.0;
  static const _ksearchBoxHeight = 35.0;
  static const _ksearchBoxPadding = 4.0;
  static const _kSearchBoxMaxHeight =
      _ksearchBoxHeight + (_ksearchBoxPadding * 2);

  @override
  bool get wantKeepAlive => widget.persistPath;

  /*=======================================================================*\ 
    Initialization / Finalization
  \*=======================================================================*/
  @override
  void initState() {
    // log.debug("initState");
    super.initState();
    state = sl.getBrowserViewState(widget.repoType);
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    state.init(
        editable: widget.editable,
        folderOnly: widget.folderOnly,
        titleNotifier: widget.titleNotifier,
        folderNotifier: _folderNotifier,
        onFolderChanged: widget.onFolderChanged,
        scrollTo: _scrollToIndex);
    _folderNotifier.addListener(_folderListener);
  }

  @override
  void dispose() {
    log.debug("dispose");
    if (widget.destoryRepoCache) state.destoryRepositoryCache();
    state.dispose();
    _scrollController.dispose();
    _folderNotifier.removeListener(_folderListener);
    super.dispose();
  }

  /*=======================================================================*\ 
    Folder Changed Listener
    -----------------------
    Group/Sort the items
  \*=======================================================================*/
  Future<void> _folderListener() async {
    bool needRebuild = false;

    // Cancel when folder changed
    _searchCancelNotifier.notify();

    Map<String, List<AudioObject>> groupMap;
    if (widget.groupByDate) {
      final allAudios = _folderNotifier.value.allAudios;
      if (allAudios == null) return;
      DateFormat dateFormat = DateFormat('yyyy-MM-dd');

      // final groups = allAudios?.
      groupMap = groupBy(
          allAudios, (AudioObject audio) => dateFormat.format(audio.timestamp));
    } else {
      groupMap = {"/": _folderNotifier.value.subObjects};
    }

    for (final items in groupMap.values) {
      for (final item in items) {
        state.resetAudioItemDisplayData(item);
      }
    }

    // the first time got a folder
    if (_groups == null) {
      _groups = groupMap.map((key, items) => MapEntry(
          key,
          _AudioItemGroup(
              key: key, items: items, headerEnding: _buildHeaderEnding(key))));
      needRebuild = true;

      // folder update
    } else {
      // remove all groups not exist in the new list
      var groupForRemove = [];
      _groups!.forEach((key, value) {
        if (!groupMap.containsKey(key)) groupForRemove.add(key);
      });
      for (var key in groupForRemove) {
        _groups!.remove(key);
        needRebuild = true;
      }

      // update groups
      groupMap.forEach((key, items) {
        if (_groups!.containsKey(key)) {
          _groups![key]!.items = items;
        } else {
          _groups![key] = _AudioItemGroup(key: key, items: items);
          needRebuild = true;
        }
      });
    }

    if (needRebuild) setState(() {});
  }

  /*=======================================================================*\ 
    Scroll Listener
    ----------------
    Adjust the headers/Search box's height
  \*=======================================================================*/
  void _scrollListener() {
    //This is a folder selector? There is no header, search box, so do nothing
    if (widget.folderOnly) return;

    void setSearchBoxHeight(double offset) {
      if (_searchBoxHeightNotifier.value >= _kSearchBoxMaxHeight) return;
      if (offset >= _lastScrollPosition) return;
      final heightOffset = _lastScrollPosition - offset;
      _searchBoxHeightNotifier.value += heightOffset;
    }

    final offset = _scrollController.offset;

    // log.debug("offset:$offset, sw:$_scrollSwitch");
    if (_scrollSwitch == false) {
      if (offset < -50.0) {
        _scrollSwitch = true;
        _folderNotifier.value.dump();
      }
    } else {
      if (offset > -50.0) _scrollSwitch = false;
    }

    setSearchBoxHeight(offset);
    _lastScrollPosition = offset;

    if (_groups == null || _groups!.length < 2) return;
    //Headers processing
    final gropus = _groups!.values.toList();
    final currentHeader = gropus.firstWhere((e) => e.headerHeight > 0);
    final box = currentHeader.headerBox;

    if (box == null) return;

    final isScrollUp =
        box.constraints.userScrollDirection == ScrollDirection.reverse;
    if (isScrollUp) {
      // ヘッダー同士が接触した後の高さ更新
      if (gropus.length > gropus.indexOf(currentHeader) + 1) {
        final nextHeader = gropus[gropus.indexOf(currentHeader) + 1];
        final nextBox = nextHeader.headerBox;

        if (nextBox != null) {
          final double currentHeight =
              nextBox.constraints.precedingScrollExtent -
                  _scrollController.offset;

          // 高さ更新
          log.debug("ScrollDown, Update height:$currentHeight");
          currentHeader.headerHeight = currentHeight;
        }
      }
    } else if (!isScrollUp) {
      // ヘッダー同士が接触した後の高さ更新
      if (currentHeader.headerHeight < _AudioListHeader._kDefaultHeight) {
        // 上部ヘッダーの高さを変更

        if (gropus.length > gropus.indexOf(currentHeader) + 1) {
          final nextKey = gropus[gropus.indexOf(currentHeader) + 1];
          final nextHeader = nextKey.headerBox;
          if (nextHeader != null) {
            final currentHeight = nextHeader.constraints.precedingScrollExtent -
                _scrollController.offset;

            // 高さ更新
            log.debug("ScrollUp, Update height:$currentHeight");
            currentHeader.headerHeight = currentHeight;
          }
        }
      } else if (0 <= gropus.indexOf(currentHeader) - 1) {
        // 上部ヘッダーより前にあるヘッダーを表示
        final previousHeader = gropus[gropus.indexOf(currentHeader) - 1];
        final previousHeight =
            box.constraints.precedingScrollExtent - _scrollController.offset;

        // 高さ更新
        log.debug("ScrollDown, Update prev height:$previousHeight");
        previousHeader.headerHeight = previousHeight;
      }
    }
  }

  /*=======================================================================*\ 
    Sort Button
  \*=======================================================================*/
  Widget _buildHeaderEnding(String key) {
    void sortItems(_AudioItemGroup group,
        int Function(AudioObject, AudioObject)? compare) {
      List<AudioObject> folders = List.of(group.items.whereType<FolderInfo>());
      List<AudioObject> audios = List.of(group.items.whereType<AudioInfo>());

      folders.sort(compare);
      audios.sort(compare);
      group.items = folders + audios;
    }

    return widget.groupByDate
        ? Text(key)
        : _SortButton(
            onSorted: (type, reverse) {
              final group = _groups![key];
              setState(() {
                int Function(AudioObject, AudioObject)? compare;
                switch (type) {
                  case _SortType.dateTime:
                    compare = (a, b) => reverse
                        ? b.timestamp.compareTo(a.timestamp)
                        : a.timestamp.compareTo(b.timestamp);
                    break;
                  case _SortType.name:
                    compare = (a, b) {
                      final nameA = basename(a.path);
                      final nameB = basename(b.path);

                      return reverse
                          ? nameB.compareTo(nameA)
                          : nameA.compareTo(nameB);
                    };
                    break;
                  case _SortType.size:
                    compare = (a, b) => reverse
                        ? b.bytes.compareTo(a.bytes)
                        : a.bytes.compareTo(b.bytes);
                    break;
                }

                sortItems(group!, compare);
              });
            },
          );
  }

  /*=======================================================================*\ 
    Search Box text changed
  \*=======================================================================*/
  void _onSearchBoxTextChanged(String text) {
    for (final group in _groups!.values) {
      group.filter = text;
    }
  }

  /*=======================================================================*\ 
    Search Header Builder
  \*=======================================================================*/
  List<Widget> _buildSearchHeader(context) {
    return [
      SliverPersistentHeader(
        pinned: true,
        floating: false,
        delegate: _AudioListHeaderDelegate(
            child: Container(
              color: Theme.of(context).primaryColor,
              child: Center(child: Container()),
            ),
            minHeight: _ksearchBoxTopPadding,
            maxHeight: _ksearchBoxTopPadding),
      ),
      ValueListenableBuilder<double>(
          valueListenable: _searchBoxHeightNotifier,
          builder: ((context, height, _) {
            return SliverPersistentHeader(
              pinned: false,
              floating: false,
              delegate: _AudioListHeaderDelegate(
                  child: SearchBox(
                    height: _ksearchBoxHeight,
                    padding: _ksearchBoxPadding,
                    cancelNotifier: _searchCancelNotifier,
                    onTextChanged: _onSearchBoxTextChanged,
                  ),
                  minHeight: 0,
                  maxHeight: height),
            );
          })),
    ];
  }

  List<Widget> _buildSubLists(BuildContext context) {
    if (_groups == null) return [];
    List<Widget> slivers = [];
    for (final group in _groups!.values) {
      slivers.add(group.buildHeaderWidget(context));
      slivers.add(
          group.buildListWidget(context, widget.repoType, widget.editable));
    }

    return slivers;
  }

  /*=======================================================================*\ 
    Scroll to AudioObject item index
  \*=======================================================================*/
  void _scrollToIndex(
    AudioObject audioObject, {
    required Duration duration,
    required Curve curve,
  }) {
    if (AudioListItemState.height == null) {
      log.warning("AudioListeItem's height is unknow, can't scroll to it");
      return;
    }
    int index = 0;
    for (final group in _groups!.values) {
      final i = group.items.indexOf(audioObject);
      if (i < 0) {
        index += group.items.length;
      } else {
        index += i;
        break;
      }
    }
    final offset = _searchBoxHeightNotifier.value +
        _ksearchBoxTopPadding +
        _AudioListHeader._kDefaultHeight +
        (AudioListItemState.height! * index);

    _scrollController.animateTo(offset,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  /*=======================================================================*\ 
    Build method
  \*=======================================================================*/
  @override
  Widget build(BuildContext context) {
    super.build(context);
    log.debug("group count:${_groups?.length}");
    late List<Widget> slivers;
    if (widget.folderOnly) {
      slivers = _groups == null
          ? []
          : [
              _groups!.values.first
                  .buildListWidget(context, widget.repoType, widget.editable),
            ];
    } else {
      slivers = _buildSearchHeader(context) + _buildSubLists(context);
    }
    slivers.add(
      SliverList(
        delegate: SliverChildListDelegate([
          ValueListenableBuilder<double>(
              valueListenable: state.bottomPanelPlaceholderHeightNotifier,
              builder: (context, height, _) {
                return SizedBox(
                  height: height,
                );
              }),
        ]),
      ),
    );
    return Stack(
      children: [
        CustomScrollView(
          key: _scrollViewKey,
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: slivers,
          // sl: _listItemWidgets(folderInfo),
        ),
        // Center(
        //   child: MaterialButton(
        //     onPressed: () {
        //       final ret =
        //           showAudioItemSortDialog(context, title: "Sort", options: {
        //         "option1": 1,
        //         "option2": 2,
        //         "option3": 3,
        //       });
        //       ret.then((value) => log.debug("Dialog return:$value"));
        //     },
        //     child: Container(
        //       color: Colors.blue,
        //       width: 100,
        //       height: 50,
        //       child: const Text("Test"),
        //     ),
        //   ),
        // ),
      ],
    );
  }
}

/*=======================================================================*\ 
  Group
\*=======================================================================*/
class _AudioItemGroup {
  late final _AudioListHeader _header;
  final String key;
  final ForcibleValueNotifier<List<AudioObject>> _itemsNotifier;
  List<AudioObject>? _beforeFilterItems;

  _AudioItemGroup({
    required this.key,
    GlobalKey? headerKey,
    Widget? headerEnding,
    required List<AudioObject> items,
  }) : _itemsNotifier = ForcibleValueNotifier(items) {
    _header = _AudioListHeader(
        headerKey: headerKey,
        itemsNotifier: _itemsNotifier,
        headerEnding: headerEnding ?? const SizedBox());
  }

  set headerHeight(double height) => _header.height = height;

  double get headerHeight => _header.height;
  RenderSliverPersistentHeader? get headerBox => _header.box;

  set items(List<AudioObject> newValue) {
    _itemsNotifier.value = newValue;
  }

  List<AudioObject> _filterItems(String text, List<AudioObject> items) {
    List<AudioObject> folders = List.of(items.whereType<FolderInfo>());
    List<AudioObject> audios = List.of(items.whereType<AudioInfo>());
    filter(obj) => basename(obj.path).contains(text);
    final ret1 = folders.where(filter).toList();
    final ret2 = audios.where(filter).toList();
    return ret1 + ret2;
  }

  set filter(String text) {
    if (text.isEmpty) {
      _itemsNotifier.value = _beforeFilterItems!;
      _beforeFilterItems = null;
    } else {
      _beforeFilterItems ??= _itemsNotifier.value;
      _itemsNotifier.value = _filterItems(text, _beforeFilterItems!);
    }
  }

  List<AudioObject> get items => _itemsNotifier.value;
  void forceRebuild() {
    _itemsNotifier.update(forceNotify: true);
  }

  Widget buildHeaderWidget(BuildContext context) =>
      _header.buildHeaderWidget(context);

  Widget buildListWidget(
      BuildContext context, RepoType repoType, bool editable) {
    return AnimatedAudioSliver(
        repoType: repoType, editable: editable, listNotifier: _itemsNotifier);
  }
}

/*=======================================================================*\ 
  Header
\*=======================================================================*/
class _AudioListHeader {
  final ForcibleValueNotifier<List<AudioObject>> itemsNotifier;
  final GlobalKey headerKey;
  final _headerHeightNotifier = ValueNotifier(_kDefaultHeight);
  static const _kDefaultHeight = 30.0;
  final Widget headerEnding;

  _AudioListHeader({
    GlobalKey? headerKey,
    required this.itemsNotifier,
    required this.headerEnding,
  }) : headerKey = headerKey ?? GlobalKey();

  set height(double height) {
    if (height < 0) {
      log.error("height: $height < 0, set to 0");
      _headerHeightNotifier.value = 0;
    } else if (height > _kDefaultHeight) {
      log.error("height: $height > $_kDefaultHeight, set to $_kDefaultHeight");
      _headerHeightNotifier.value = _kDefaultHeight;
    } else {
      _headerHeightNotifier.value = height;
    }
  }

  double get height => _headerHeightNotifier.value;

  RenderSliverPersistentHeader? get box =>
      headerKey.currentContext?.findRenderObject()
          as RenderSliverPersistentHeader?;

  Widget _buildHeaderWidget(List<AudioObject> items) {
    int bytes = 0;
    int count = 0;
    for (var item in items) {
      bytes += item.bytes;

      if (item is FolderInfo) {
        count += item.allAudioCount;
      } else if (item is AudioInfo) {
        count++;
      }
    }

    final kB = bytes / 1000;
    final mB = kB / 1000;
    String sizeStr = "";
    if (mB > 1) {
      sizeStr = "${mB.toStringAsFixed(1)} MB";
    } else {
      sizeStr = "${kB.toStringAsFixed(1)} KB";
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("$count Audios"
            " - "
            "$sizeStr"),
        headerEnding,
      ],
    );
  }

  Widget buildHeaderWidget(BuildContext context) {
    return ValueListenableBuilder<double>(
        valueListenable: _headerHeightNotifier,
        builder: ((context, value, _) {
          return SliverPersistentHeader(
            key: headerKey,
            pinned: true,
            floating: true,
            delegate: _AudioListHeaderDelegate(
              minHeight: value,
              child: Container(
                  color: Theme.of(context).primaryColor,
                  child: Center(
                      child: ValueListenableBuilder<List<AudioObject>>(
                          valueListenable: itemsNotifier,
                          builder: ((context, items, _) {
                            return _buildHeaderWidget(items);
                          })))),
            ),
          );
        }));
  }
}

class _AudioListHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _AudioListHeaderDelegate(
      {required this.minHeight,
      required this.child,
      this.maxHeight = _AudioListHeader._kDefaultHeight});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // log.debug(
    //     "$headerTitle: shrinkOffset:${shrinkOffset.toStringAsFixed(2)}, overlapsContent:$overlapsContent");
    return child;
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) =>
      minExtent != oldDelegate.minExtent || maxExtent != oldDelegate.maxExtent;
}

/*=======================================================================*\ 
  Sort Button
\*=======================================================================*/
enum _SortType { dateTime, name, size }

class _SortButton extends StatefulWidget {
  final void Function(_SortType type, bool reverse)? onSorted;
  const _SortButton({this.onSorted});
  @override
  State<_SortButton> createState() => _SortButtonState();
}

class _SortButtonState extends State<_SortButton> {
  _SortType type = _SortType.name;
  bool reverseOrder = false;

  String sortName(_SortType type) {
    switch (type) {
      case _SortType.dateTime:
        return "Date";
      case _SortType.name:
        return "Name";
      case _SortType.size:
        return "Size";
    }
  }

  Widget get orderIcon {
    if (reverseOrder) return const Icon(Icons.arrow_drop_down);
    return const Icon(Icons.arrow_drop_up);
  }

  void onPressed(context) {
    log.debug("show sort dialog");
    final options = _SortType.values
        .asMap()
        .map((_, sortType) => MapEntry(sortName(sortType), sortType));
    final ret =
        showAudioItemSortDialog(context, title: "Sort", options: options);
    ret.then((newType) {
      log.debug("sort dialog end");
      if (newType == null) return;
      if (newType == type) {
        reverseOrder = !reverseOrder;
      } else {
        type = newType;
        reverseOrder = false;
      }
      setState(() {});
      widget.onSorted?.call(type, reverseOrder);
      log.debug("Dialog return:$type");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      onPressed: () => onPressed(context),
      child: Row(
        children: [Text(sortName(type)), orderIcon],
      ),
    );
  }
}

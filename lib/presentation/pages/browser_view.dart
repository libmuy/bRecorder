import 'package:brecorder/core/utils.dart';
import 'package:brecorder/presentation/widgets/animated_audio_list.dart';
import 'package:brecorder/presentation/widgets/search_box.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../data/repository_type.dart';
import '../../domain/entities.dart';
import '../ploc/browser_view_state.dart';

final log = Logger('BrowserView', level: LogLevel.debug);

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
        onFolderChanged: widget.onFolderChanged);
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

  @override
  bool get wantKeepAlive => widget.persistPath;

  List<AudioObject>? get _itemList => widget.folderOnly
      ? _folderNotifier.value.subfolders
      : _folderNotifier.value.audios;

  Future<void> _folderListener() async {
    bool needRebuild = false;
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

    if (_groups == null) {
      _groups = groupMap.map((key, items) =>
          MapEntry(key, _AudioItemGroup(key: key, items: items)));
      needRebuild = true;
    } else {
      _groups = {};
      groupMap.forEach((key, items) {
        if (_groups!.containsKey(key)) {
          _groups![key]!.items = items;
        } else {
          _groups![key] = _AudioItemGroup(key: key, items: items);
          needRebuild = true;
        }
      });
    }
    _groups!.values.forEach((group) {
      for (final item in group.items) {
        state.resetAudioItemDisplayData(item);
      }
    });

    if (needRebuild) setState(() {});
  }

  void _scrollListener() {
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

    if (_groups == null || _groups!.length < 2) return;
    //Headers processing
    final gropus = _groups!.values.toList();
    final currentHeader = gropus.firstWhere((e) => e.headerHeight > 0);
    final box = currentHeader.headerKey.currentContext?.findRenderObject()
        as RenderSliverPersistentHeader?;

    if (box == null) return;

    final isDownScroll =
        box.constraints.userScrollDirection == ScrollDirection.reverse;
    if (isDownScroll) {
      // 下スクロール時

      // ヘッダー同士が接触した後の高さ更新
      if (gropus.length > gropus.indexOf(currentHeader) + 1) {
        final nextHeader = gropus[gropus.indexOf(currentHeader) + 1];
        final nextBox = nextHeader.headerKey.currentContext?.findRenderObject()
            as RenderSliverPersistentHeader?;

        if (nextBox != null) {
          final double currentHeight =
              nextBox.constraints.precedingScrollExtent -
                  _scrollController.offset;

          // 高さ更新
          log.debug("ScrollDown, Update height:$currentHeight");
          currentHeader.headerHeight = currentHeight;
        }
      }
    } else if (!isDownScroll) {
      // 上スクロール時

      // ヘッダー同士が接触した後の高さ更新
      if (currentHeader.headerHeight < _AudioItemGroup._kDefaultHeight) {
        // 上部ヘッダーの高さを変更

        if (gropus.length > gropus.indexOf(currentHeader) + 1) {
          final nextKey = gropus[gropus.indexOf(currentHeader) + 1];
          final nextHeader = nextKey.headerKey.currentContext
              ?.findRenderObject() as RenderSliverPersistentHeader?;
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

  final _ksearchBoxHeight = 35.0;
  final _ksearchBoxPadding = 4.0;

  List<Widget> _buildSearchHeader() {
    return [
      SliverPersistentHeader(
        pinned: true,
        floating: false,
        delegate: _AudioListHeaderDelegate(
            child: Container(
              color: Theme.of(context).primaryColor,
              child: Center(child: Container()),
            ),
            minHeight: 10,
            maxHeight: 10),
      ),
      SliverPersistentHeader(
        pinned: false,
        floating: false,
        delegate: _AudioListHeaderDelegate(
            child: SearchBox(
              height: _ksearchBoxHeight,
              padding: _ksearchBoxPadding,
            ),
            minHeight: 0,
            maxHeight: _ksearchBoxHeight + (_ksearchBoxPadding * 2)),
      ),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    log.debug("group count:${_groups?.length}");
    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: _buildSearchHeader() + _buildSubLists(context),
          // sl: _listItemWidgets(folderInfo),
        ),
        // Center(
        //   child: MaterialButton(
        //     onPressed: () {
        //       _list.removeAt(0);
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

class _AudioItemGroup {
  final String key;
  final GlobalKey headerKey;
  final _headerHeightNotifier = ValueNotifier(_kDefaultHeight);
  final ValueNotifier<List<AudioObject>> _itemsNotifier;
  static const _kDefaultHeight = 30.0;

  _AudioItemGroup(
      {required this.key,
      GlobalKey? headerKey,
      required List<AudioObject> items})
      : _itemsNotifier = ValueNotifier(items),
        headerKey = headerKey ?? GlobalKey();

  set headerHeight(double height) {
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

  double get headerHeight => _headerHeightNotifier.value;

  set items(List<AudioObject> newValue) {
    _itemsNotifier.value = newValue;
  }

  List<AudioObject> get items => _itemsNotifier.value;

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
                  child: Center(child: Text(key))),
            ),
          );
        }));
  }

  Widget buildListWidget(
      BuildContext context, RepoType repoType, bool editable) {
    return AnimatedAudioSliver(
        repoType: repoType, editable: editable, listNotifier: _itemsNotifier);
  }
}

class _AudioListHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _AudioListHeaderDelegate(
      {required this.minHeight,
      required this.child,
      this.maxHeight = _AudioItemGroup._kDefaultHeight});

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

import 'package:brecorder/core/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../data/repository_type.dart';
import '../../domain/entities.dart';
import '../ploc/browser_view_state.dart';
import '../widgets/audio_list_item/audio_list_item.dart';
import '../widgets/audio_list_item/audio_list_item_state.dart';

final log = Logger('BrowserView');

class BrowserView extends StatefulWidget {
  final RepoType repoType;
  final bool folderOnly;
  final bool editable;
  final bool persistPath;
  final bool destoryRepoCache;
  final ValueNotifier<String> titleNotifier;
  final void Function(FolderInfo folder)? onFolderChanged;
  const BrowserView(
      {Key? key,
      required this.repoType,
      required this.titleNotifier,
      this.folderOnly = false,
      this.persistPath = true,
      this.destoryRepoCache = false,
      this.editable = true,
      this.onFolderChanged})
      : super(key: key);

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView>
    with
        AutomaticKeepAliveClientMixin<BrowserView>,
        SingleTickerProviderStateMixin {
  late BrowserViewState state;

  final _folderNotifier = ForcibleValueNotifier(FolderInfo.empty);
  final modeNotifier = sl.get<BrowserViewModeNotifier>();
  late ScrollController _scrollController;
  bool _scrollSwitch = false;
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
  }

  @override
  void dispose() {
    log.debug("dispose");
    if (widget.destoryRepoCache) state.destoryRepositoryCache();
    state.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => widget.persistPath;

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
  }

  List<Widget> _listItemWidgets(FolderInfo folder) {
    List<AudioObject> list;
    if (widget.folderOnly) {
      list = folder.subfolders as List<AudioObject>;
    } else {
      list = folder.subObjects;
    }
    List<Widget> ret = list.map((obj) {
      final itemState = obj.displayData as AudioListItemState;
      // ignore: unnecessary_cast
      return AudioListItem(
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
      ) as Widget;
    }).toList();

    ret.add(
      ValueListenableBuilder<double>(
          valueListenable: state.bottomPanelPlaceholderHeightNotifier,
          builder: (context, height, _) {
            return SizedBox(
              height: height,
            );
          }),
    );

    return ret;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<FolderInfo>(
        valueListenable: _folderNotifier,
        builder: (context, folderInfo, _) {
          return Column(
            children: [
              // Audio Item List
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  children: folderInfo.subObjects.isEmpty ||
                          (widget.folderOnly &&
                              folderInfo.subfoldersMap == null)
                      ? [
                          Container(
                              alignment: Alignment.center,
                              child: const Text(
                                "Here is nothing...",
                                style: TextStyle(fontSize: 40),
                              ))
                        ]
                      : _listItemWidgets(folderInfo),
                ),
              ),
            ],
          );
        });
  }
}

class BrowserViewModeNotifier extends ChangeNotifier
    implements ValueListenable<BrowserViewMode> {
  BrowserViewModeNotifier(this._value);

  @override
  BrowserViewMode get value => _value;
  BrowserViewMode _value;

  set value(BrowserViewMode newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }
}

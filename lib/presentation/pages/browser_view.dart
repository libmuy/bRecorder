import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:brecorder/presentation/widgets/audio_list_item/audio_list_item_state.dart';
import 'package:brecorder/presentation/widgets/folder_selector.dart';
import 'package:brecorder/presentation/widgets/new_folder_dialog.dart';
import 'package:flutter/material.dart';

import '../../domain/entities.dart';
import '../ploc/browser_view_state.dart';
import '../widgets/audio_list_item/audio_list_item.dart';
import '../widgets/playback_panel.dart';

final log = Logger('BrowserView');

class BrowserView extends StatefulWidget {
  final RepoType repoType;
  final bool folderOnly;
  final bool persistPath;
  final bool destoryRepoCache;
  final ValueNotifier<String> titleNotifier;
  final void Function(FolderInfo folder)? onFolderChanged;
  final ValueNotifier<BrowserViewMode>? modeNotifier;
  const BrowserView(
      {Key? key,
      required this.repoType,
      required this.titleNotifier,
      this.folderOnly = false,
      this.persistPath = true,
      this.modeNotifier,
      this.destoryRepoCache = false,
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
  final _selectStateNotifier =
      ValueNotifier(AudioListItemSelectedState.noSelected);
  final _folderNotifier = FolderChangeNotifier(FolderInfo.empty);
  late ValueNotifier<BrowserViewMode> modeNotifier;
  late ScrollController _scrollController;
  bool _scrollSwitch = false;
  late AnimationController _controller;

  @override
  bool get wantKeepAlive => widget.persistPath;

  @override
  void initState() {
    // log.debug("initState");
    super.initState();
    state = sl.getBrowserViewState(widget.repoType);
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    //     if (persistPath) {
    //   folderNotifier = ValueNotifier(FolderInfo.empty);
    // }
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    modeNotifier = widget.modeNotifier ?? ValueNotifier(BrowserViewMode.normal);
    state.init(
        folderOnly: widget.folderOnly,
        modeNotifier: modeNotifier,
        titleNotifier: widget.titleNotifier,
        selectStateNotifier: _selectStateNotifier,
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

  Widget playbackModeBottomPanel() {
    return PlaybackPanel(
      onClose: state.onPlaybackPanelClosed,
      onPlayNext: state.playNext,
      onPlayPrevious: state.playPrevious,
      loopNotifier: state.loopNotifier,
    );
  }

  void _showNewFolderDialog(BuildContext context) {
    showModalBottomSheet<void>(
      elevation: 20,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      builder: (BuildContext context) {
        return SizedBox(
            // decoration: BoxDecoration(
            //   color: Theme.of(context).primaryColor,
            //   borderRadius: const BorderRadius.only(
            //     topLeft: Radius.circular(10),
            //     topRight: Radius.circular(10),
            //     // bottomLeft: Radius.circular(10),
            //     // bottomRight: Radius.circular(10)
            //   ),
            //   boxShadow: [
            //     BoxShadow(
            //       color: Theme.of(context)
            //           .primaryColor
            //           .withOpacity(0.4),
            //       spreadRadius: 8,
            //       blurRadius: 8,
            //       // offset: Offset(0, 2), // changes position of shadow
            //     ),
            //   ],
            // ),
            height: 400,
            // color: Colors.amber,
            child: FolderSelector(
              folderNotify: (folder) {
                log.debug("selected folder:${folder.path}");
                state.moveSelectedToFolder(folder);
              },
            ));
      },
    );
  }

  Widget editModeBottomPanel(BuildContext context) {
    return ValueListenableBuilder<AudioListItemSelectedState>(
        valueListenable: _selectStateNotifier,
        builder: (context, selectState, _) {
          return SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MaterialButton(
                      onPressed: selectState.audioSelected ||
                              selectState.folderSelected
                          ? () {
                              _showNewFolderDialog(context);
                            }
                          : null,
                      child: const Icon(Icons.drive_file_move_outline)),
                  MaterialButton(
                      onPressed: selectState.audioSelected ||
                              selectState.folderSelected
                          ? () {
                              state.deleteSelected();
                            }
                          : null,
                      child: const Icon(Icons.delete_outlined)),
                  MaterialButton(
                      child: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () {
                        //New Folder Dialog
                        showNewFolderDialog(context, (value) {
                          state.newFolder(value);
                        });
                      }),
                ],
              ));
        });
  }

  List<Widget> _listItemWidgets(FolderInfo folder) {
    List<AudioObject> list;
    if (widget.folderOnly) {
      list = folder.subfolders as List<AudioObject>;
    } else {
      list = folder.subObjects;
    }
    return list.map((obj) {
      final itemState = obj.displayData as AudioListItemState;
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
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<FolderInfo>(
        valueListenable: _folderNotifier,
        builder: (context, folderInfo, _) {
          return Column(
            children: [
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
              // Bottom Panels
              ValueListenableBuilder<BrowserViewMode>(
                  valueListenable: modeNotifier,
                  builder: (context, mode, _) {
                    switch (mode) {
                      case BrowserViewMode.normal:
                        return Container();

                      case BrowserViewMode.edit:
                        return editModeBottomPanel(context);

                      case BrowserViewMode.playback:
                        return playbackModeBottomPanel();
                    }
                  }),
            ],
          );
        });
  }
}

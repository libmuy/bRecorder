import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:brecorder/presentation/widgets/folder_selector.dart';
import 'package:brecorder/presentation/widgets/new_folder_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities.dart';
import '../ploc/browser_view_state.dart';
import '../widgets/audio_list_item/audio_list_item.dart';
import '../widgets/playback_panel.dart';

final log = Logger('BrowserView');

class BrowserView extends StatefulWidget {
  final RepoType repoType;
  final bool folderOnly;
  final bool persistPath;
  final ValueNotifier<String>? titleNotifier;
  final void Function(String path)? onFolderChanged;
  final ValueNotifier<BrowserViewMode>? modeNotifier;
  const BrowserView(
      {Key? key,
      required this.repoType,
      this.folderOnly = false,
      this.persistPath = true,
      this.titleNotifier,
      this.modeNotifier,
      this.onFolderChanged})
      : super(key: key);

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView>
    with AutomaticKeepAliveClientMixin<BrowserView> {
  late BrowserViewState state;
  late ValueNotifier<BrowserViewMode> modeNotifier;
  late ValueNotifier<AudioListItemSelectedState> _selectStateNotifier;
  @override
  bool get wantKeepAlive => widget.persistPath;

  @override
  void initState() {
    super.initState();
    _selectStateNotifier = ValueNotifier(AudioListItemSelectedState.noSelected);
    state = sl.getBrowserViewState(widget.repoType);
    log.debug("initState");
    //     if (persistPath) {
    //   folderNotifier = ValueNotifier(FolderInfo.empty);
    // }

    modeNotifier = widget.modeNotifier ?? ValueNotifier(BrowserViewMode.normal);
    state.init(
        folderOnly: widget.folderOnly,
        modeNotifier: modeNotifier,
        titleNotifier: widget.titleNotifier,
        selectStateNotifier: _selectStateNotifier,
        onFolderChanged: widget.onFolderChanged);
  }

  @override
  void dispose() {
    super.dispose();
    state.dispose();
  }

  // Widget _positionBar(String fullPath) {
  //   List<Widget> buttons = List.empty(growable: true);
  //   String path = "/";
  //   bool addSeparator = false;

  //   log.debug("generating position bar: $fullPath");

  //   for (final d in split(fullPath)) {
  //     if (d.isEmpty) continue;
  //     path = join(path, d);
  //     final buttonPath = path;
  //     log.debug("sub dir:$path");

  //     if (addSeparator) {
  //       buttons.add(const Text("/"));
  //     }

  //     buttons.add(TextButton(
  //       style: ButtonStyle(
  //         // padding: MaterialStateProperty.all(EdgeInsets.zero),
  //         minimumSize: MaterialStateProperty.all(Size.zero),
  //         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  //       ),
  //       onPressed: () {
  //         log.info("Path button:$buttonPath clicked");
  //         state.cd(buttonPath);
  //       },
  //       child: Text(d),
  //     ));

  //     if (d != separator && addSeparator == false) {
  //       addSeparator = true;
  //     }
  //   }

  //   return Padding(
  //     padding: const EdgeInsets.only(left: 15, top: 15, right: 15, bottom: 0),
  //     child: Row(
  //       children: buttons,
  //     ),
  //   );
  // }

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
              folderNotify: (dstRepo, dstPath) {
                log.debug("selected folder:$dstPath");
                state.moveSelectedToFolder(dstRepo, dstPath);
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
                      child: const Icon(Icons.delete_outlined),
                      onPressed: selectState.audioSelected ||
                              selectState.folderSelected
                          ? () {
                              state.deleteSelected();
                            }
                          : null),
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FolderInfo>(
        valueListenable: state.folderNotifier,
        builder: (context, folderInfo, _) {
          List<AudioObject> tmpList =
              // ignore: unnecessary_cast
              folderInfo.subfolders.map((e) => e as AudioObject).toList();
          final audioItems = tmpList + folderInfo.audios;
          return Column(
            children: [
              Expanded(
                child: ListView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    children: audioItems.isEmpty
                        ? [
                            Container(
                                alignment: Alignment.center,
                                child: const Text(
                                  "Here is nothing...",
                                  style: TextStyle(fontSize: 70),
                                ))
                          ]
                        : audioItems
                            .asMap()
                            .map((i, v) {
                              final itemState = state.itemStateList[i];
                              return MapEntry(
                                  i,
                                  AudioListItem(
                                    key: itemState.key,
                                    audioItem: v,
                                    state: itemState,
                                    onTap: (iconOnTapped) {
                                      if (v is FolderInfo) {
                                        state.folderOnTap(itemState);
                                      } else if (v is AudioInfo) {
                                        state.audioOnTap(
                                            itemState, iconOnTapped);
                                      }
                                    },
                                    onLongPressed: state.onListItemLongPressed,
                                  ));
                            })
                            .values
                            .toList()),
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

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/global_info.dart';
import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/utils/notifiers.dart';
import '../../core/utils/utils.dart';
import '../ploc/browser_view_state.dart';
import '../ploc/home_page_state.dart';
import 'animated_sized_panel.dart';
import 'dialogs.dart';
import 'playback_panel.dart';

final _log = Logger('BottomPanel');
const _kBorderRadius = GlobalInfo.kDialogBorderRadius;

class BottomPanel extends StatefulWidget {
  const BottomPanel({
    super.key,
  });

  @override
  State<BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<BottomPanel> {
  GlobalMode _lastMode = GlobalMode.normal;
  late BrowserViewState state;

  void _bottomPanelAnimationStatusChanged(
      AnimationStatus from, AnimationStatus to) {
    switch (to) {
      case AnimationStatus.dismissed:
        _log.debug("bottompanel closed");
        state.onBottomPanelClosed();
        break;
      case AnimationStatus.completed:
        break;
      case AnimationStatus.reverse:
        break;
      case AnimationStatus.forward:
        break;
    }
  }

  Widget _buildBottomPanelInternal(BuildContext context, GlobalMode mode) {
    _log.debug("show playback panel, mode:$mode");
    var judgMode = mode == GlobalMode.normal ? _lastMode : mode;
    _lastMode = mode;

    if (judgMode != GlobalMode.playback && judgMode != GlobalMode.edit) {
      return Container();
    }

    if (judgMode == GlobalMode.playback) {
      return PlaybackPanel(
        onClose: state.onBottomPanelClosed,
        onPlayNext: state.playNext,
        onPlayPrevious: state.playPrevious,
        loopNotifier: state.loopNotifier,
      );
    }

    return ValueListenableBuilder<AudioListItemSelectedState>(
        valueListenable: state.selectStateNotifier,
        builder: (context, selectState, _) {
          return SizedBox(
              height: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MaterialButton(
                      onPressed: selectState.audioSelected &&
                              (!selectState.folderSelected)
                          ? () {
                              showFolderSelecter(context, 
                              
                              (folder) {
                                _log.debug("selected folder:${folder.path}");
                                state.moveSelectedToFolder(folder);
                              });
                            }
                          : null,
                      child: const Icon(Icons.playlist_add)),
                  MaterialButton(
                      onPressed: selectState.audioSelected ||
                              selectState.folderSelected
                          ? () {
                              showFolderSelecter(context, (folder) {
                                _log.debug("selected folder:${folder.path}");
                                state.moveSelectedToFolder(folder);
                              });
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

  Widget _buildBottomPanel(BuildContext context, GlobalMode mode) {
    // return Container(
    //   // color: Colors.black,
    //   decoration: BoxDecoration(
    //     // color: Colors.black,
    //     color: Theme.of(context).primaryColor,
    //     borderRadius: const BorderRadius.only(
    //       topLeft: Radius.circular(20),
    //       topRight: Radius.circular(20),
    //       // bottomLeft: Radius.circular(10),
    //       // bottomRight: Radius.circular(10)
    //     ),
    //     // boxShadow: [
    //     //   BoxShadow(
    //     //     color: Colors.black.withOpacity(0.5),
    //     //     spreadRadius: 1,
    //     //     blurRadius: 10,
    //     //     offset: const Offset(0, -2), // changes position of shadow
    //     //   ),
    //     // ],
    //   ),
    return Material(
      color: Theme.of(context).primaryColor,
      shadowColor: Colors.black,
      // surfaceTintColor: Colors.red,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(_kBorderRadius),
        topRight: Radius.circular(_kBorderRadius),
        // bottomLeft: Radius.circular(10),
        // bottomRight: Radius.circular(10)
      ),
      elevation: 20,
      child: AnimatedSizedPanel(
          debugLabel: "BottomPanel",
          show: mode == GlobalMode.normal ? false : true,
          dragListenerPriority: 10,
          dragNotifier: sl.playbackPanelDragNotifier,
          onHeightChanged: (height) {
            Timer.run(() {
              // log.debug("placeholder height:$height");
              state.bottomPanelPlaceholderHeightNotifier.value = height;
            });
          },
          onAnimationStatusChanged: _bottomPanelAnimationStatusChanged,
          child: _buildBottomPanelInternal(context, mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    state = sl.get<HomePageState>().currentBrowserState;
    return ValueListenableBuilder<GlobalMode>(
        valueListenable: sl.get<GlobalModeNotifier>(),
        builder: (context, mode, _) {
          if (mode != GlobalMode.playback) {
            sl.playbackPanelExpandNotifier.value = false;
          }
          final panel = _buildBottomPanel(context, mode);
          return panel;
        });
  }
}

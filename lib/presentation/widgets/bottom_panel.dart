import 'dart:async';

import 'package:brecorder/presentation/ploc/home_page_state.dart';
import 'package:flutter/material.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/utils.dart';
import '../pages/browser_view.dart';
import '../ploc/browser_view_state.dart';
import 'animated_sized_panel.dart';
import 'folder_selector.dart';
import 'new_folder_dialog.dart';
import 'playback_panel.dart';

final log = Logger('BottomPanel', level: LogLevel.debug);

class BottomPanel extends StatefulWidget {
  const BottomPanel({
    Key? key,
  }) : super(key: key);

  @override
  State<BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<BottomPanel> {
  BrowserViewMode _lastMode = BrowserViewMode.normal;
  late BrowserViewState state;

  void _bottomPanelAnimationStatusChanged(
      AnimationStatus from, AnimationStatus to) {
    switch (to) {
      case AnimationStatus.dismissed:
        log.debug("bottompanel closed");
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

  Widget _buildBottomPanelInternal(BuildContext context, BrowserViewMode mode) {
    log.debug("show playback panel, mode:$mode");
    var judgMode = mode == BrowserViewMode.normal ? _lastMode : mode;
    _lastMode = mode;

    if (judgMode != BrowserViewMode.playback &&
        judgMode != BrowserViewMode.edit) {
      return Container();
    }

    if (judgMode == BrowserViewMode.playback) {
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

  Widget _buildBottomPanel(BuildContext context, BrowserViewMode mode) {
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
        topLeft: Radius.circular(15),
        topRight: Radius.circular(15),
        // bottomLeft: Radius.circular(10),
        // bottomRight: Radius.circular(10)
      ),
      elevation: 20,
      child: AnimatedSizedPanel(
          debugLabel: "BottomPanel",
          show: mode == BrowserViewMode.normal ? false : true,
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
    return ValueListenableBuilder<BrowserViewMode>(
        valueListenable: sl.get<BrowserViewModeNotifier>(),
        builder: (context, mode, _) {
          final panel = _buildBottomPanel(context, mode);
          return panel;
        });
  }
}

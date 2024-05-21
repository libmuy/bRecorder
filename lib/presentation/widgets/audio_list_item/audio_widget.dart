import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
// import 'package:share_plus/share_plus.dart';

import '../../../core/logging.dart';
import '../../../data/google_drive_repository.dart';
import '../../../domain/entities.dart';
import 'audio_widget_state.dart';

final _log = Logger('AudioListItem');

class AudioWidget extends StatefulWidget {
  final AudioObject audioItem;
  final AudioWidgetState state;
  final double padding;
  final double titlePadding;
  final double iconPadding;
  final double detailPadding;
  final void Function(bool)? onTap;
  final void Function(AudioWidgetState state)? onLongPressed;

  const AudioWidget(
      {super.key,
      required this.audioItem,
      required this.state,
      this.padding = 5,
      this.titlePadding = 5,
      this.iconPadding = 5,
      this.detailPadding = 5,
      this.onTap,
      this.onLongPressed});

  @override
  State<AudioWidget> createState() => _AudioWidgetState();
}

class _AudioWidgetState extends State<AudioWidget> {
  @override
  void initState() {
    super.initState();
    widget.state.updateWidget = () => setState(() {});
  }

  @override
  void dispose() {
    widget.state.updateWidget = null;
    super.dispose();
  }

  bool get _isFolder {
    return widget.audioItem is FolderInfo;
  }

  bool get selected {
    return widget.state.itemModeNotifier.value == AudioListItemMode.selected;
  }

  String get _sizeInfo {
    if (widget.audioItem.bytes == null) return "-- KB";
    return "${(widget.audioItem.bytes! / 1024).toStringAsFixed(0)} KB";
  }

  String get _timestampInfo {
    final timestamp = widget.audioItem.timestamp;
    if (timestamp == null) {
      return "----/--/--";
    }
    DateFormat dateFormat = DateFormat('MM/dd HH:mm:ss');
    final timeInfo = dateFormat.format(timestamp);

    return timeInfo;
  }

  String get _audioCountInfo {
    final folder = widget.audioItem as FolderInfo;
    return "${folder.allAudioCount} Audios";
  }

  String get _durationInfo {
    final audio = widget.audioItem as AudioInfo;
    if (audio.durationMS == null) return "--";
    int sec = audio.durationMS! ~/ 1000;
    final min = sec ~/ 60;
    sec = sec % 60;

    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  Widget _cloudIcon() {
    if (!widget.audioItem.repo!.isCloud) return Container();
    final cloudData = widget.audioItem.cloudData;
    if (cloudData == null) return Container();
    switch (cloudData.state) {
      case CloudFileState.init:
        return const Icon(Icons.sync_problem);
      case CloudFileState.downloading:
        return const Icon(Icons.cloud_download);
      case CloudFileState.uploading:
        return const Icon(Icons.cloud_upload);
      case CloudFileState.syncing:
        return const Icon(Icons.cloud_sync);
      case CloudFileState.synced:
        return const Icon(Icons.cloud_done);
      case CloudFileState.conflict:
        return const Icon(Icons.cloud_off);
    }
  }

  void doNothing(BuildContext context) {}

  @override
  Widget build(context) {
    if (AudioWidgetState.height == null) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) {
          if (AudioWidgetState.height != null) return;
          final box = context.findRenderObject() as RenderBox?;
          AudioWidgetState.height = box?.size.height;
          _log.debug("Audio Item Height:${AudioWidgetState.height}");
        },
      );
    }

    return Slidable(
      // Specify a key if the Slidable is dismissible.
      key: const ValueKey(0),

      // The start action pane is the one at the left or the top side.
      startActionPane: ActionPane(
        // A motion is a widget used to control how the pane animates.
        motion: const ScrollMotion(),

        // A pane can dismiss the Slidable.
        dismissible: DismissiblePane(onDismissed: () {}),

        // All actions are defined in the children parameter.
        children: [
          // A SlidableAction can have an icon and/or a label.
          SlidableAction(
            onPressed: doNothing,
            backgroundColor: const Color(0xFFFE4A49),
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
          SlidableAction(
            onPressed: (context) async {
              // Share.shareXFiles([XFile(await widget.audioItem.realPath)],
              //     text: basename(widget.audioItem.path));
            },
            backgroundColor: const Color(0xFF21B7CA),
            foregroundColor: Colors.white,
            icon: Icons.share,
            label: 'Share',
          ),
        ],
      ),

      // The end action pane is the one at the right or the bottom side.
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            // An action can be bigger than the others.
            flex: 2,
            onPressed: doNothing,
            backgroundColor: const Color(0xFF7BC043),
            foregroundColor: Colors.white,
            icon: Icons.archive,
            label: 'Archive',
          ),
          SlidableAction(
            onPressed: doNothing,
            backgroundColor: const Color(0xFF0392CF),
            foregroundColor: Colors.white,
            icon: Icons.save,
            label: 'Save',
          ),
        ],
      ),

      // The child of the Slidable is what the user sees when the
      // component is not dragged.
      child: InkWell(
        onTap: () {
          widget.onTap?.call(false);
        },
        onLongPress: () {
          widget.onLongPressed?.call(widget.state);
        },
        child: ValueListenableBuilder<bool>(
            valueListenable: widget.state.highlightNotifier,
            builder: (context, highlight, _) {
              // log.debug(
              //     "build highlight:$highlight, item:${widget.audioItem.path}");
              return Container(
                // Overall Border, Padding
                decoration: BoxDecoration(
                  color: highlight ? Theme.of(context).highlightColor : null,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 1,
                    ),
                  ),
                ),

                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // Icons
                      GestureDetector(
                        onTap: () {
                          widget.onTap?.call(true);
                        },
                        child: Container(
                          color: Colors.transparent,
                          height: double.infinity,
                          // color: Colors.red,
                          padding: EdgeInsets.only(
                            left: widget.padding + widget.iconPadding,
                            right: widget.iconPadding,
                            // top: widget.padding + widget.iconPadding,
                            // bottom: widget.padding + widget.iconPadding,
                          ),
                          child: ValueListenableBuilder<AudioListItemMode>(
                              valueListenable: widget.state.itemModeNotifier,
                              builder: (context, mode, _) {
                                Widget? selectIcon;
                                switch (mode) {
                                  case AudioListItemMode.normal:
                                    break;
                                  case AudioListItemMode.notSelected:
                                    selectIcon =
                                        const Icon(Icons.circle_outlined);
                                    break;
                                  case AudioListItemMode.selected:
                                    selectIcon =
                                        const Icon(Icons.check_circle_outline);
                                    break;
                                }
                                final audioIcon = _isFolder
                                    ? const Icon(Icons.folder_outlined)
                                    : ValueListenableBuilder<bool>(
                                        valueListenable:
                                            widget.state.playingNotifier,
                                        builder: (context, playing, _) {
                                          return playing
                                              ? const Icon(Icons.pause)
                                              : const Icon(
                                                  Icons.play_arrow_outlined);
                                        });
                                if (selectIcon == null) {
                                  return audioIcon;
                                } else {
                                  return Row(
                                    children: [
                                      selectIcon,
                                      SizedBox(
                                        width: widget.padding,
                                      ),
                                      audioIcon
                                    ],
                                  );
                                }
                              }),
                        ),
                      ),

                      // Right Part
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: widget.padding,
                            bottom: widget.padding,
                          ),
                          child: Column(
                            children: [
                              // Title
                              Padding(
                                  padding: EdgeInsets.all(widget.titlePadding),
                                  child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(widget.audioItem.mapKey),
                                        _cloudIcon()
                                      ])),

                              // Details
                              Padding(
                                padding: EdgeInsets.all(widget.detailPadding),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        _isFolder
                                            ? Text(
                                                _audioCountInfo,
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .hintColor),
                                              )
                                            : Container(
                                                margin: const EdgeInsets.only(
                                                    right: 3),
                                                alignment: Alignment.center,
                                                padding: const EdgeInsets.only(
                                                    left: 5,
                                                    top: 2,
                                                    right: 3,
                                                    bottom: 2),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: Theme.of(context)
                                                          .hintColor),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  _durationInfo,
                                                  style: TextStyle(
                                                      color: Theme.of(context)
                                                          .hintColor),
                                                )),
                                        Text(
                                          " - $_sizeInfo",
                                          style: TextStyle(
                                              color:
                                                  Theme.of(context).hintColor),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _timestampInfo,
                                      style: TextStyle(
                                          color: Theme.of(context).hintColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              );
            }),
      ),
    );
  }
}

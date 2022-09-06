import 'package:brecorder/core/logging.dart';
import 'package:brecorder/domain/entities.dart';
import 'package:brecorder/presentation/widgets/audio_list_item/audio_list_item_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final log = Logger('AudioListItem');

class AudioListItem extends StatefulWidget {
  final AudioObject audioItem;
  final AudioListItemState state;
  final double padding;
  final double titlePadding;
  final double iconPadding;
  final double detailPadding;
  final void Function(bool)? onTap;
  final void Function(AudioListItemState state)? onLongPressed;

  const AudioListItem(
      {Key? key,
      required this.audioItem,
      required this.state,
      this.padding = 5,
      this.titlePadding = 5,
      this.iconPadding = 5,
      this.detailPadding = 5,
      this.onTap,
      this.onLongPressed})
      : super(key: key);

  @override
  State<AudioListItem> createState() => _AudioListItemState();
}

class _AudioListItemState extends State<AudioListItem> {
  bool get _isFolder {
    return widget.audioItem is FolderInfo;
  }

  bool get selected {
    return widget.state.modeNotifier.value == AudioListItemMode.selected;
  }

  String get _sizeInfo {
    return "${(widget.audioItem.bytes / 1024).toStringAsFixed(0)} KB";
  }

  String get _timestampInfo {
    DateFormat dateFormat = DateFormat('MM/dd HH:mm:ss');
    final timeInfo = dateFormat.format(widget.audioItem.timestamp);

    return timeInfo;
  }

  String get _audioCountInfo {
    final folder = widget.audioItem as FolderInfo;
    return "${folder.allAudioCount} Audios";
  }

  String get _durationInfo {
    final audio = widget.audioItem as AudioInfo;
    int sec = audio.durationMS ~/ 1000;
    final min = sec ~/ 60;
    sec = sec % 60;

    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(context) {
    return InkWell(
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
                        height: double.infinity,
                        // color: Colors.red,
                        padding: EdgeInsets.only(
                          left: widget.padding + widget.iconPadding,
                          right: widget.iconPadding,
                          // top: widget.padding + widget.iconPadding,
                          // bottom: widget.padding + widget.iconPadding,
                        ),
                        child: ValueListenableBuilder<AudioListItemMode>(
                            valueListenable: widget.state.modeNotifier,
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
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(widget.audioItem.mapKey))),

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
                                            color: Theme.of(context).hintColor),
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
    );
  }
}

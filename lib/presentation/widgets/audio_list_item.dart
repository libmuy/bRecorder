import 'package:brecorder/core/logging.dart';
import 'package:brecorder/domain/entities.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

final log = Logger('AudioListItem');

class AudioListItem extends StatefulWidget {
  final AudioObject audioItem;
  final bool selectable;
  final double padding;
  final double titlePadding;
  final double iconPadding;
  final double detailPadding;
  final void Function()? onTap;

  const AudioListItem(
      {Key? key,
      required this.audioItem,
      this.selectable = false,
      this.padding = 5,
      this.titlePadding = 5,
      this.iconPadding = 5,
      this.detailPadding = 5,
      this.onTap})
      : super(key: key);

  @override
  State<AudioListItem> createState() => _AudioListItemState();
}

class _AudioListItemState extends State<AudioListItem> {
  bool selected = false;

  bool get _isFolder {
    return widget.audioItem is FolderInfo;
  }

  Widget get _selectWidget {
    if (!widget.selectable) {
      return Container();
    }

    if (selected) {
      return const Icon(Icons.check_circle_outline);
    }

    return const Icon(Icons.circle_outlined);
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
    return "${folder.audioCount} Audios";
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
        if (widget.selectable) {
          setState(() {
            selected = !selected;
          });
        }
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      child: Container(
        // Overall Border, Padding
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 1,
            ),
          ),
        ),
        padding: EdgeInsets.all(widget.padding),

        child: Row(
          children: [
            // Icons
            Padding(
              padding: EdgeInsets.all(widget.iconPadding),
              child: _selectWidget,
            ),
            Padding(
              padding: EdgeInsets.all(widget.iconPadding),
              child: _isFolder
                  ? const Icon(Icons.folder_outlined)
                  : const Icon(Icons.play_arrow_outlined),
            ),

            // Right Part
            Expanded(
              child: Column(
                children: [
                  // Title
                  Padding(
                      padding: EdgeInsets.all(widget.titlePadding),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(basename(widget.audioItem.path)))),

                  // Details
                  Padding(
                    padding: EdgeInsets.all(widget.detailPadding),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _isFolder
                                ? Text(
                                    _audioCountInfo,
                                    style: TextStyle(
                                        color: Theme.of(context).hintColor),
                                  )
                                : Container(
                                    margin: const EdgeInsets.only(right: 3),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.only(
                                        left: 5, top: 2, right: 3, bottom: 2),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Theme.of(context).hintColor),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _durationInfo,
                                      style: TextStyle(
                                          color: Theme.of(context).hintColor),
                                    )),
                            Text(
                              " - $_sizeInfo",
                              style:
                                  TextStyle(color: Theme.of(context).hintColor),
                            ),
                          ],
                        ),
                        Text(
                          _timestampInfo,
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

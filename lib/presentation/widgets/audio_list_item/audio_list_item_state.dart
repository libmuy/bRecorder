import 'package:brecorder/domain/entities.dart';
import 'package:flutter/cupertino.dart';

class AudioListItemState {
  final AudioObject audioObject;
  var modeNotifier = ValueNotifier(AudioListItemMode.normal);
  var highlightNotifier = ValueNotifier(false);
  var playingNotifier = ValueNotifier(false);
  late GlobalKey key;

  AudioListItemState(this.audioObject) {
    key = GlobalKey(debugLabel: audioObject.path);
  }

  void toggleSelected() {
    if (modeNotifier.value == AudioListItemMode.selected) {
      modeNotifier.value = AudioListItemMode.notSelected;
      highlightNotifier.value = false;
    } else {
      modeNotifier.value = AudioListItemMode.selected;
      highlightNotifier.value = true;
    }
  }

  set playing(bool value) {
    playingNotifier.value = value;
  }

  set highlight(bool value) {
    highlightNotifier.value = value;
  }

  set mode(AudioListItemMode value) {
    modeNotifier.value = value;
    if (value == AudioListItemMode.selected) {
      highlight = true;
    }
  }

  bool get selected {
    return modeNotifier.value == AudioListItemMode.selected;
  }

  void resetHighLight() {
    if (highlightNotifier.value) {
      highlightNotifier.value = false;
    }
  }
}

enum AudioListItemMode {
  selected,
  notSelected,
  normal,
}

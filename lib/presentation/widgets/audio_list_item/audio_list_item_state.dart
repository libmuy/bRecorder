import 'package:brecorder/domain/entities.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/logging.dart';

class AudioListItemState {
  final AudioObject audioObject;
  var modeNotifier = ValueNotifier(AudioListItemMode.normal);
  var highlightNotifier = ValueNotifier(false);
  var playingNotifier = ValueNotifier(false);
  late GlobalKey key;

  final log = Logger('AudioListItemState');

  AudioListItemState(this.audioObject, {AudioListItemMode? mode}) {
    key = GlobalKey();
    if (mode != null) modeNotifier.value = mode;
    if (audioObject is AudioInfo) {
      final audio = audioObject as AudioInfo;
      audio.onPlayStarted = () {
        log.debug("play started: ${audio.path}");
        highlight = true;
        playing = true;
        try {
          Scrollable.ensureVisible(key.currentContext!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut);
        } catch (e) {
          log.warning("cannot show Audio list item, error:$e");
        }
      };
      audio.onPlayPaused = () {
        // log.debug("play paused: ${audio.path}");
        playing = false;
      };
      audio.onPlayStopped = () {
        // log.debug("play stopped: ${audio.path}");
        playing = false;
        highlight = false;
      };
    }
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
    // log.debug("set highlight: "
    //     "${highlightNotifier.value} -> "
    //     "$value, item:${audioObject.path}");
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

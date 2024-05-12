import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../../../core/logging.dart';
import '../../../core/service_locator.dart';
import '../../../domain/entities.dart';

class AudioWidgetState {
  static double? height;
  final AudioObject audioObject;
  var itemModeNotifier = ValueNotifier(AudioListItemMode.normal);
  var highlightNotifier = ValueNotifier(false);
  var playingNotifier = ValueNotifier(false);
  late GlobalKey key;
  Float32List? waveformData;
  void Function()? updateWidget;
  void Function()? onPlayStopped;
  void Function()? onPlayPaused;
  void Function()? onPlayStarted;

  final log = Logger('AudioListItemState', level: LogLevel.debug);

  void ensureVisible() async {
    const duration = Duration(milliseconds: 400);
    const curve = Curves.easeInOut;

    try {
      Scrollable.ensureVisible(key.currentContext!,
          duration: duration, curve: curve);
    } catch (e) {
      log.warning("cannot show Audio list item, error:$e");
      final browserViewState = sl.getBrowserViewState(audioObject.repo!.type);
      browserViewState.scrollTo(audioObject, duration: duration, curve: curve);
      await Future.delayed(duration);
      ensureVisible();
    }
  }

  AudioWidgetState(this.audioObject,
      {AudioListItemMode? mode, GlobalKey? key}) {
    this.key = key ?? GlobalKey();
    if (mode != null) itemModeNotifier.value = mode;
    if (audioObject is AudioInfo) {
      final audio = audioObject as AudioInfo;
      onPlayStarted = () {
        log.debug("play started: ${audio.path}");
        highlight = true;
        playing = true;
        //ensureVisible();
      };
      onPlayPaused = () {
        log.debug("play paused: ${audio.path}");
        playing = false;
      };
      onPlayStopped = () {
        log.debug("play stopped: ${audio.path}");
        playing = false;
        // highlight = false;
      };
    }
  }

  void toggleSelected() {
    if (itemModeNotifier.value == AudioListItemMode.selected) {
      itemModeNotifier.value = AudioListItemMode.notSelected;
      highlightNotifier.value = false;
    } else {
      itemModeNotifier.value = AudioListItemMode.selected;
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
    itemModeNotifier.value = value;
    if (value == AudioListItemMode.selected) {
      highlight = true;
    }
  }

  bool get selected {
    return itemModeNotifier.value == AudioListItemMode.selected;
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

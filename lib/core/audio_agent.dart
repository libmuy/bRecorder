import 'dart:async';

import 'package:brecorder/core/global_info.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/result.dart';
import 'package:brecorder/domain/entities.dart';
import 'package:flutter/services.dart';

final log = Logger('Audio-Agent');

typedef AudioEventListener = void Function(AudioEventType event, dynamic data);

class AudioServiceAgent {
  /*=======================================================================*\ 
    Variables
  \*=======================================================================*/
  static const _methodChannel =
      MethodChannel('libmuy.com/brecorder/methodchannel');
  static const _eventChannel =
      EventChannel('libmuy.com/brecorder/eventchannel');

  AudioInfo? currentAudio;
  StreamSubscription? _eventStream;
  bool _gotPlatformParams = false;
  Completer? _platformParamCompleter;
  AudioState state = AudioState.idle;
  final Map<AudioEventType, List<AudioEventListener>> _playEventListeners = {};

  /*=======================================================================*\ 
    Contructor
  \*=======================================================================*/
  AudioServiceAgent() {
    _startListenEvent();
    setParams();
  }

  /*=======================================================================*\ 
    Event Listeners
  \*=======================================================================*/
  void addAudioEventListener(
      AudioEventType eventType, AudioEventListener listener) {
    if (_playEventListeners.containsKey(eventType)) {
      _playEventListeners[eventType]!.add(listener);
    } else {
      _playEventListeners[eventType] = [listener];
    }
  }

  void removeAudioEventListener(
      AudioEventType eventType, AudioEventListener listener) {
    if (_playEventListeners.containsKey(eventType)) {
      _playEventListeners[eventType]!.remove(listener);
    }
  }

  void _notifyAudioEventListeners(AudioEventType eventType, dynamic data) {
    if (!_playEventListeners.containsKey(eventType)) {
      return;
    }

    Timer.run(() {
      for (final listener in _playEventListeners[eventType]!) {
        listener(eventType, data);
      }
    });
  }

  /*=======================================================================*\ 
    Event Channel
    ---------------
  \*=======================================================================*/
  void _startListenEvent() {
    if (_eventStream != null) {
      log.warning("Waveform sample already listening");
      return;
    }

    try {
      _eventStream =
          _eventChannel.receiveBroadcastStream().listen((dynamic map) {
        _eventHandler(map);
      }, onError: (dynamic error) {
        log.error("event channel error${error.message}");
      }, onDone: () async {
        log.info("eventchannel done: retry");
        await _stopListenEvent();
        _startListenEvent();
      }, cancelOnError: false);
    } catch (e) {
      log.error("register event channel failed");
    }
  }

  Future<void> _stopListenEvent() async {
    await _eventStream?.cancel();
    _eventStream = null;
  }

  void _eventHandler(dynamic map) {
    if (map.containsKey("waveform")) {
      _waveformEventHandler(map["waveform"]);
    }

    if (map.containsKey("playEvent")) {
      _playbackEventHandler(map["playEvent"]);
    }

    if (map.containsKey("platformPametersEvent")) {
      _parameterEventHandler(map["platformPametersEvent"]);
    }

    if (map.containsKey("testEvent")) {
      log.debug("Got Test Event:${map['testEvent']}");
      // final floatArray = map['testEvent'] as Float64List;
      // log.debug("array len:" + floatArray.length.toString());
    }
  }

  void _waveformEventHandler(dynamic data) {
    _notifyAudioEventListeners(AudioEventType.waveform, data);
  }

  void _playbackEventHandler(dynamic data) {
    // log.debug("Got Player Event:${map['playEvent']}");
    switch (data["event"]) {
      case "PlayComplete":
        _notifyAudioEventListeners(
            AudioEventType.positionUpdate, currentAudio!.durationMS);
        _notifyAudioEventListeners(AudioEventType.stopped, null);
        state = AudioState.idle;
        break;
      case "PositionUpdate":
        int? positionMs = data["position"];
        if (positionMs == null) {
          positionMs = 0;
          log.error("position updated with null");
        }
        currentAudio?.currentPosition = positionMs;
        _notifyAudioEventListeners(AudioEventType.positionUpdate, positionMs);
        // log.debug("position update notification: $positionMs ms");
        break;
      default:
    }
  }

  void _parameterEventHandler(dynamic data) {
    GlobalInfo.PLATFORM_PITCH_MAX_VALUE = data["PLATFORM_PITCH_MAX_VALUE"];
    GlobalInfo.PLATFORM_PITCH_MIN_VALUE = data["PLATFORM_PITCH_MIN_VALUE"];
    GlobalInfo.PLATFORM_PITCH_DEFAULT_VALUE =
        data["PLATFORM_PITCH_DEFAULT_VALUE"];
    _gotPlatformParams = true;
    if (_platformParamCompleter != null) {
      _platformParamCompleter!.complete();
      _platformParamCompleter = null;
    }
  }

  Future waitPlatformParams() async {
    if (_gotPlatformParams) return;

    _platformParamCompleter = Completer();
    return _platformParamCompleter!.future;
  }

  /*=======================================================================*\ 
    Method Channel
    ---------------
  \*=======================================================================*/
  // true: Success
  // false: Fail
  Future<bool> _callVoidPlatformMethod(String method, [dynamic args]) async {
    try {
      await _methodChannel.invokeMethod(method, args);
    } on PlatformException catch (e) {
      log.critical("Platform Method:$method Got exception: $e, args:$args");
      return false;
    }

    return true;
  }

  /*=======================================================================*\ 
    Recording
  \*=======================================================================*/
  Future<Result> startRecord(String path) async {
    final ret = await _callVoidPlatformMethod("startRecord", {
      "path": path,
    });
    if (ret == false) {
      return Fail(PlatformFailure());
    }
    state = AudioState.recording;

    return Succeed();
  }

  Future<Result> stopRecord() async {
    if (!await _callVoidPlatformMethod("stopRecord")) {
      return Fail(PlatformFailure());
    }
    state = AudioState.idle;
    return Succeed();
  }

  Future<Result> pauseRecord() async {
    if (!await _callVoidPlatformMethod("pauseRecord")) {
      return Fail(PlatformFailure());
    }
    state = AudioState.recordPaused;
    return Succeed();
  }

  Future<Result> resumeRecord() async {
    if (!await _callVoidPlatformMethod("resumeRecord")) {
      return Fail(PlatformFailure());
    }
    state = AudioState.recording;
    return Succeed();
  }

  /*=======================================================================*\ 
    Playing
  \*=======================================================================*/
  Future<Result> startPlay(AudioInfo audio,
      {int positionNotifyIntervalMs = 10}) async {
    final path = await audio.realPath;
    audio.currentPosition = 0;
    switch (state) {
      case AudioState.idle:
        break;
      case AudioState.playPaused:
      case AudioState.playing:
        final stopRet = await stopPlay();
        if (stopRet.failed) {
          return stopRet;
        }
        break;
      case AudioState.recordPaused:
      case AudioState.recording:
        return Fail(ErrMsg("AudioServiceAgent State error, now:$state"));
    }
    if (!await _callVoidPlatformMethod("startPlay", {
      "path": path,
      "positionNotifyIntervalMs": positionNotifyIntervalMs,
    })) {
      return Fail(PlatformFailure());
    }
    currentAudio = audio;
    _notifyAudioEventListeners(AudioEventType.started, audio);
    state = AudioState.playing;

    return Succeed();
  }

  Future<Result> stopPlay() async {
    if (!await _callVoidPlatformMethod("stopPlay")) {
      return Fail(PlatformFailure());
    }
    _notifyAudioEventListeners(AudioEventType.stopped, null);
    currentAudio = null;
    state = AudioState.idle;
    return Succeed();
  }

  Future<Result> stopPlayIfPlaying() async {
    if (state == AudioState.playing || state == AudioState.playPaused) {
      return stopPlay();
    }
    return Succeed();
  }

  Future<Result> pausePlay() async {
    if (!await _callVoidPlatformMethod("pausePlay")) {
      return Fail(PlatformFailure());
    }
    _notifyAudioEventListeners(AudioEventType.paused, null);
    state = AudioState.playPaused;
    return Succeed();
  }

  Future<Result> pausePlayIfPlaying() async {
    if (state != AudioState.playing) {
      return Succeed();
    }
    return pausePlay();
  }

  Future<Result> resumePlay() async {
    if (!await _callVoidPlatformMethod("resumePlay")) {
      return Fail(PlatformFailure());
    }
    _notifyAudioEventListeners(AudioEventType.started, currentAudio);
    state = AudioState.playing;
    return Succeed();
  }

  Future<Result> togglePlay(AudioInfo audio) async {
    switch (state) {
      case AudioState.idle:
        return startPlay(audio);
      case AudioState.playPaused:
        return resumePlay();
      case AudioState.playing:
        return pausePlay();
      case AudioState.recordPaused:
      case AudioState.recording:
        return Fail(ErrMsg("AudioServiceAgent State error, now:$state"));
    }
  }

  Future<Result> _seekTo(int positionMs, bool sync) async {
    if (!await _callVoidPlatformMethod("seekTo", {
      "position": positionMs,
      "sync": sync,
    })) {
      return Fail(PlatformFailure());
    }
    return Succeed();
  }

  Future<Result> seekTo(int positionMs) async {
    return _seekTo(positionMs, false);
  }

  Future<Result> seekToSync(int positionMs) async {
    return _seekTo(positionMs, true);
  }

  Future<Result> seekToRelative(int positionMs) async {
    if (currentAudio == null) {
      return Fail(ErrMsg("current position is null, " "Not Playing?"));
    }

    var pos = currentAudio!.currentPosition + positionMs;
    return _seekTo(pos, false);
  }

// Set playback parameters
  Future<Result> setPitch(double pitch) async {
    if (!await _callVoidPlatformMethod("setPitch", {"pitch": pitch})) {
      return Fail(PlatformFailure());
    }
    return Succeed();
  }

  Future<Result> setSpeed(double speed) async {
    if (!await _callVoidPlatformMethod("setSpeed", {"speed": speed})) {
      return Fail(PlatformFailure());
    }
    return Succeed();
  }

  Future<Result> setVolume(double volume) async {
    if (!await _callVoidPlatformMethod("setVolume", {"volume": volume})) {
      return Fail(PlatformFailure());
    }
    return Succeed();
  }

  /*=======================================================================*\ 
    Other
  \*=======================================================================*/
  Future<Result> getDuration(String path) async {
    var ret = 0;
    try {
      ret = await _methodChannel.invokeMethod('getDuration', {"path": path});
    } on PlatformException catch (e) {
      log.critical("Got exception: $e");
      ret = -1;
    }

    if (ret < 0) return Fail(PlatformFailure());

    return Succeed(ret);
  }

  Future<Result> getCurrentDuration() async {
    if (currentAudio == null) {
      return Fail(ErrMsg("current audio is null"));
    }
    var ret = 0;
    try {
      ret = await _methodChannel
          .invokeMethod('getDuration', {"path": currentAudio!.path});
    } on PlatformException catch (e) {
      log.critical("Got exception: $e");
      ret = -1;
    }

    if (ret < 0) return Fail(PlatformFailure());

    return Succeed(ret);
  }

  Future<Result> setParams() async {
    final ret = await _callVoidPlatformMethod("setParams", {
      //Recording
      "samplesPerSecond": GlobalInfo.WAVEFORM_SAMPLES_PER_SECOND,
      "sendPerSecond": GlobalInfo.WAVEFORM_SEND_PER_SECOND,
      "recordFormat": GlobalInfo.RECORD_FORMAT,
      "recordChannelCount": GlobalInfo.RECORD_CHANNEL_COUNT,
      "recordSampleRate": GlobalInfo.RECORD_SAMPLE_RATE,
      "recordBitRate": GlobalInfo.RECORD_BIT_RATE,
      "recordFrameReadPerSecond": GlobalInfo.RECORD_FRAME_READ_PER_SECOND,

      //Playback
      "playbackPositionNotifyIntervalMS":
          GlobalInfo.PLAYBACK_POSITION_NOTIFY_INTERVAL_MS,
    });
    if (ret == false) {
      return Fail(PlatformFailure());
    }
    return Succeed();
  }

  /*=======================================================================*\ 
    For Debugging
  \*=======================================================================*/
  Future<Result> startRecordWav(String path) async {
    var ret = 0;
    try {
      await _methodChannel.invokeMethod('recordWav', path);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      ret = -1;
    }

    if (ret < 0) return Fail(PlatformFailure());

    return Succeed(ret);
  }

  Future<Result> stopRecordWav() async {
    var ret = 0;
    try {
      await _methodChannel.invokeMethod('stopRecordWav');
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      ret = -1;
    }

    if (ret < 0) return Fail(PlatformFailure());

    return Succeed(ret);
  }

  Future<Result> test(String path) async {
    String ret = "";
    try {
      ret = await _methodChannel.invokeMethod('test', {"name": "Jhon"});
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
    }

    return Succeed(ret);
  }
}

enum AudioEventType {
  started,
  paused,
  positionUpdate,
  stopped,
  waveform,
}

enum AudioState {
  playing,
  playPaused,
  recording,
  recordPaused,
  idle,
}

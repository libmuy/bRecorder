import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/entities.dart';
import 'global_info.dart';
import 'logging.dart';
import 'result.dart';

final _log = Logger('Audio-Agent', 
level: LogLevel.debug
);

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
  Completer? _methodLockCompleter;
  Completer? _playbackCompleter;
  AudioState state = AudioState.idle;
  final Map<AudioEventType, List<AudioEventListener>> _playEventListeners = {};
  double _currentPitch = 0;
  double _currentSpeed = 0;
  double _currentVolume = 0;

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
    _log.verbose("Audio EVENT: $eventType, data:$data");
    if (eventType == AudioEventType.started) {
      final audio = currentAudio!;
      // Timer.run(() {
        audio.onPlayStarted?.call();
      // });
    } else if (eventType == AudioEventType.paused) {
      final audio = currentAudio!;
      // Timer.run(() {
        audio.onPlayPaused?.call();
      // });
    } else if (eventType == AudioEventType.stopped) {
        currentAudio!.onPlayStopped?.call();
    } else if (eventType == AudioEventType.complete) {
      // Timer.run(() {
        currentAudio!.onPlayStopped?.call();
      // });
      final tmp = _playbackCompleter;
      _playbackCompleter = null;
      tmp?.complete();
    } else if (eventType == AudioEventType.positionUpdate) {
      currentAudio?.currentPosition = data;
    }

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
      _log.warning("Waveform sample already listening");
      return;
    }

    try {
      _eventStream =
          _eventChannel.receiveBroadcastStream().listen((dynamic map) {
        _eventHandler(map);
      }, onError: (dynamic error) {
        _log.error("event channel error${error.message}");
      }, onDone: () async {
        _log.info("eventchannel done: retry");
        await _stopListenEvent();
        _startListenEvent();
      }, cancelOnError: false);
    } catch (e) {
      _log.error("register event channel failed");
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
      _log.debug("Got Test Event:${map['testEvent']}");
      // final floatArray = map['testEvent'] as Float64List;
      // log.debug("array len:" + floatArray.length.toString());
    }
  }

  void _waveformEventHandler(dynamic data) {
    _notifyAudioEventListeners(AudioEventType.waveform, data);
  }

  void _playbackEventHandler(dynamic data) {
    // log.debug("Got Player Event:${map['playEvent']}");
    if (currentAudio == null) return;

    switch (data["event"]) {
      case "PlayComplete":
        // _notifyAudioEventListeners(
        //     AudioEventType.positionUpdate, currentAudio!.durationMS);
        _notifyAudioEventListeners(AudioEventType.complete, null);
        state = AudioState.idle;
        break;
      case "PositionUpdate":
        int? positionMs = data["position"];
        if (positionMs == null) {
          positionMs = 0;
          _log.error("position updated with null, ignore this");
          return;
        }
        _notifyAudioEventListeners(AudioEventType.positionUpdate, positionMs);
        // log.debug("position update notification: $positionMs ms");
        break;
      default:
    }
  }

  void _parameterEventHandler(dynamic data) {
    _log.debug("Platofrm parameters notifier");
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

  Future _platformMethodLock([caller = ""]) async {
    _log.verboseWithParentInfo("PLTFM-CALL $caller locking");
    while(_methodLockCompleter != null) {
      await _methodLockCompleter!.future;
    }
      _methodLockCompleter = Completer();
    _log.verboseWithParentInfo("PLTFM-CALL $caller locked");
  }

  void _platformMethodUnlock([caller = ""]) {
    _log.verboseWithParentInfo("PLTFM-CALL $caller unlock");
    final tmp = _methodLockCompleter;
    _methodLockCompleter = null;
    tmp!.complete();
  }

  /*=======================================================================*\ 
    Method Channel
  \*=======================================================================*/
  Future<Result> _callPlatformMethod(String method, [dynamic args]) async {
    dynamic retMethodCall;
    dynamic ret;

    _log.debug("START $method: $args");

    try {
      retMethodCall = await _methodChannel.invokeMethod(method, args);
      ret = Succeed(retMethodCall);
    } on PlatformException catch (e) {
      _log.critical("Platform Method:$method Got exception: $e, args:$args");
      ret = const Fail(PlatformFailure());
    } catch (e, stackTrace) {
      _log.critical("exception: $e");
      _log.critical("stack trace: $stackTrace");
    }

    _log.debug("END   $method: $args");
    return ret;
  }

  /*=======================================================================*\ 
    Recording
  \*=======================================================================*/
  Future<Result> startRecord(String path) async {
    await _platformMethodLock();
    Result ret = await _callPlatformMethod("startRecord", {
      "path": path,
    });
    if (ret is Succeed) {
      state = AudioState.recording;
    }

    _platformMethodUnlock();
    return ret;
  }

  Future<Result> stopRecord() async {
    await _platformMethodLock();
    Result ret = await _callPlatformMethod("stopRecord");
    if (ret is Succeed) {
      state = AudioState.idle;
    }
    _platformMethodUnlock();

    return ret;
  }

  Future<Result> pauseRecord() async {
    await _platformMethodLock();
    Result ret = await _callPlatformMethod("pauseRecord");
    if (ret is Succeed) {
      state = AudioState.idle;
    }
    _platformMethodUnlock();
    return ret;
  }

  Future<Result> resumeRecord() async {
    await _platformMethodLock();
    Result ret = await _callPlatformMethod("resumeRecord");
    if (ret is Succeed) {
      state = AudioState.recording;
    }
    _platformMethodUnlock();
    return ret;
  }

  /*=======================================================================*\ 
    Playing
  \*=======================================================================*/
  Future<Result> startPlay(AudioInfo audio,
      {int positionNotifyIntervalMs = 10}) async {
    final path = await audio.realPath;
    audio.currentPosition = 0;
    await _platformMethodLock();
    switch (state) {
      case AudioState.idle:
        break;
      case AudioState.playPaused:
      case AudioState.playing:
        final stopRet = await stopPlay(lock: false);
        if (stopRet.failed) {
          _platformMethodUnlock();
          return stopRet;
        }
        break;
      case AudioState.recordPaused:
      case AudioState.recording:
        _platformMethodUnlock();
        return Fail(ErrMsg("AudioServiceAgent State error, now:$state"));
    }

    Result ret = await _callPlatformMethod("startPlay", {
      "path": path,
      "positionNotifyIntervalMs": positionNotifyIntervalMs,
    });
    if (ret is Succeed) {
      currentAudio = audio;
      _notifyAudioEventListeners(AudioEventType.started, audio);
      state = AudioState.playing;
    }
    _playbackCompleter = Completer();
    _platformMethodUnlock();

    return ret;
  }

  Future<Result> stopPlay({bool lock = true}) async {
    if (lock) await _platformMethodLock();
    if (state == AudioState.idle) {
      if (lock) _platformMethodUnlock();
      return const Succeed();
    }
    Result ret = await _callPlatformMethod("stopPlay");
    await _playbackCompleter?.future;
    if (ret is Succeed) {
      _notifyAudioEventListeners(AudioEventType.stopped, null);
      // currentAudio = null;
      state = AudioState.idle;
      ret = const Succeed();
    }
    if (lock) _platformMethodUnlock();
    return ret;
  }

  Future<Result> pausePlay({bool lock = true}) async {
    if (lock) await _platformMethodLock();
    if (state != AudioState.playing) {
      if (lock) _platformMethodUnlock();
      return const Succeed();
    }
    Result ret = await _callPlatformMethod("pausePlay");
    if (ret is Succeed) {
      _notifyAudioEventListeners(AudioEventType.stopped, null);
      state = AudioState.playPaused;
      ret = const Succeed();
    }
    if (lock) _platformMethodUnlock();

    return ret;
  }

  Future<Result> resumePlay() async {
    await _platformMethodLock();
    Result ret = await _callPlatformMethod("resumePlay");
    if (ret is Succeed) {
      _notifyAudioEventListeners(AudioEventType.started, currentAudio!);
      state = AudioState.playing;
      ret = const Succeed();
    }
    _platformMethodUnlock();

    return ret;
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

  Future<Result> _seekTo(int positionMs) async {
    await _platformMethodLock();
    if (currentAudio == null) {
      _platformMethodUnlock();
      return Fail(ErrMsg("current position is null, " "Not Playing?"));
    }
    if (positionMs >= currentAudio!.durationMS!) {
      positionMs = currentAudio!.durationMS!;
      await pausePlay(lock: false);
    } else if (positionMs < 0) {
      positionMs = 0;
    }

    Result ret = await _callPlatformMethod("seekTo", {
      "position": positionMs,
    });
    if (ret is Succeed) {
      if (state != AudioState.playing) {
        _notifyAudioEventListeners(AudioEventType.positionUpdate, positionMs);
      }
    }
    _platformMethodUnlock();

    return ret;
  }

  Future<Result> seekTo(int positionMs) async {
    return _seekTo(positionMs);
  }

  Future<Result> seekToRelative(int positionMs) async {
    if (currentAudio == null) {
      return Fail(ErrMsg("current position is null, " "Not Playing?"));
    }

    final pos = currentAudio!.currentPosition + positionMs;
    return _seekTo(pos);
  }

// Set playback parameters
  Future<Result> setPitch(double pitch) async {
    if (pitch > GlobalInfo.PLATFORM_PITCH_MAX_VALUE) {
      pitch = GlobalInfo.PLATFORM_PITCH_MAX_VALUE;
    }
    if (pitch < GlobalInfo.PLATFORM_PITCH_MIN_VALUE) {
      pitch = GlobalInfo.PLATFORM_PITCH_MIN_VALUE;
    }

    await _platformMethodLock();
    if (pitch == _currentPitch) {
      _platformMethodUnlock();
      return const Succeed();
    }
    Result ret = await _callPlatformMethod("setPitch", {"pitch": pitch});
    if (ret is Succeed) _currentPitch = pitch;
    _platformMethodUnlock();

    return ret;
  }

  Future<Result> setSpeed(double speed) async {
    await _platformMethodLock();
    if (speed == _currentSpeed) {
      _platformMethodUnlock();
      return const Succeed();
    }
    Result ret = await _callPlatformMethod("setSpeed", {"speed": speed});
    if (ret is Succeed) _currentSpeed = speed;
    _platformMethodUnlock();

    return ret;
  }

  Future<Result> setVolume(double volume) async {
    await _platformMethodLock();
    if (volume == _currentVolume) {
      _platformMethodUnlock();
      return const Succeed();
    }
    Result ret = await _callPlatformMethod("setVolume", {"volume": volume});
    if (ret is Succeed) _currentVolume = volume;
    _platformMethodUnlock();

    return ret;
  }

  /*=======================================================================*\ 
    Other
  \*==============================ƒ=========================================*/
  Future<Result> getDuration(String path) async {
    await _platformMethodLock();
    Result ret = await _callPlatformMethod('getDuration', {"path": path});
    if (ret is Succeed) {
      state = AudioState.idle;
    }
    _platformMethodUnlock();
    return ret;
  }

  Future<Result> getCurrentDuration() async {
    if (currentAudio == null) {
      return Fail(ErrMsg("current audio is null"));
    }

    return getDuration(currentAudio!.path);
  }

  Future<Result> setParams() async {
    await _platformMethodLock();
    Result ret = await _callPlatformMethod("setParams", {
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
    _platformMethodUnlock();
    return ret;
  }

  /*=======================================================================*\ 
    Others
  \*=======================================================================*/
  bool methodCallPending() {
    return _methodLockCompleter != null;
  }

  Future waitPendingMethodCall() async {
    while(_methodLockCompleter != null) {
      await _methodLockCompleter!.future;
    }
  }

  /*=======================================================================*\ 
    For Debugging
  \*=======================================================================*/
  Future<Result> test(String path) async {
    String ret = "";
    try {
      ret = await _methodChannel.invokeMethod('test', {"name": "Jhon"});
    } on PlatformException catch (e) {
      _log.critical("Got exception: ${e.message}");
    }

    return Succeed(ret);
  }
}

enum AudioEventType {
  started,
  paused,
  positionUpdate,
  complete,
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

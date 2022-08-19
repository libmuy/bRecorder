import 'dart:async';
import 'dart:typed_data';

import 'package:brecorder/core/global_info.dart';
import 'package:brecorder/core/result.dart';
import 'package:brecorder/core/logging.dart';
import 'package:flutter/services.dart';

final log = Logger('Audio-Agent');

class AudioServiceAgent {
  static const _methodChannel =
      MethodChannel('libmuy.com/brecorder/methodchannel');
  static const _eventChannel =
      EventChannel('libmuy.com/brecorder/eventchannel');

  StreamSubscription? _eventStream;
  Function(Float32List eventData)? _onWaveformData;
  Function(dynamic)? _onPlayEvent;
  bool _gotPlatformParams = false;
  Completer? _platformParamCompleter;

  AudioServiceAgent() {
    _startListenEvent();
    setParams();
  }

  void _startListenEvent() {
    if (_eventStream != null) {
      log.warning("Waveform sample already listening");
      return;
    }

    try {
      _eventStream =
          _eventChannel.receiveBroadcastStream().listen((dynamic map) {
        if (map.containsKey("waveform")) {
          _onWaveformData?.call(map["waveform"]);
        }

        if (map.containsKey("playEvent")) {
          // log.debug("Got Player Event:${map['playEvent']}");
          _onPlayEvent?.call(map["playEvent"]);
        }

        if (map.containsKey("platformPametersEvent")) {
          final params = map["platformPametersEvent"];
          GlobalInfo.PLATFORM_PITCH_MAX_VALUE =
              params["PLATFORM_PITCH_MAX_VALUE"];
          GlobalInfo.PLATFORM_PITCH_MIN_VALUE =
              params["PLATFORM_PITCH_MIN_VALUE"];
          GlobalInfo.PLATFORM_PITCH_DEFAULT_VALUE =
              params["PLATFORM_PITCH_DEFAULT_VALUE"];
          _gotPlatformParams = true;
          if (_platformParamCompleter != null) {
            _platformParamCompleter!.complete();
            _platformParamCompleter = null;
          }
        }

        if (map.containsKey("testEvent")) {
          log.debug("Got Test Event:${map['testEvent']}");
          // final floatArray = map['testEvent'] as Float64List;
          // log.debug("array len:" + floatArray.length.toString());
        }
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

  Future waitPlatformParams() async {
    if (_gotPlatformParams) return;

    _platformParamCompleter = Completer();
    return _platformParamCompleter!.future;
  }

  Future<void> _stopListenEvent() async {
    await _eventStream?.cancel();
    _eventStream = null;
  }

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
  Future<Result<Void, ErrInfo>> startRecord(String path,
      {Function(Float32List eventData)? onWaveformData}) async {
    final ret = await _callVoidPlatformMethod("startRecord", {
      "path": path,
    });
    if (ret == false) {
      return Fail(PlatformFailure());
    }

    _onWaveformData = onWaveformData;

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> stopRecord() async {
    if (!await _callVoidPlatformMethod("stopRecord")) {
      return Fail(PlatformFailure());
    }
    _onWaveformData = null;

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> pauseRecord() async {
    if (!await _callVoidPlatformMethod("pauseRecord")) {
      return Fail(PlatformFailure());
    }
    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> resumeRecord() async {
    if (!await _callVoidPlatformMethod("resumeRecord")) {
      return Fail(PlatformFailure());
    }
    return Succeed(Void());
  }

  /*=======================================================================*\ 
    Playing
  \*=======================================================================*/
  Future<Result<Void, ErrInfo>> startPlay(String path,
      {Function(dynamic)? onPlayEvent,
      int positionNotifyIntervalMs = 0}) async {
    if (!await _callVoidPlatformMethod("startPlay", {
      "path": path,
    })) {
      return Fail(PlatformFailure());
    }
    _onPlayEvent = onPlayEvent;

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> stopPlay() async {
    if (!await _callVoidPlatformMethod("stopPlay")) {
      return Fail(PlatformFailure());
    }
    _onPlayEvent = null;

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> pausePlay() async {
    if (!await _callVoidPlatformMethod("pausePlay")) {
      return Fail(PlatformFailure());
    }
    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> resumePlay() async {
    if (!await _callVoidPlatformMethod("resumePlay")) {
      return Fail(PlatformFailure());
    }
    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> _seekTo(int positionMs, bool sync) async {
    if (!await _callVoidPlatformMethod("seekTo", {
      "position": positionMs,
      "sync": sync,
    })) {
      return Fail(PlatformFailure());
    }
    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> seekTo(int positionMs) async {
    return _seekTo(positionMs, false);
  }

  Future<Result<Void, ErrInfo>> seekToSync(int positionMs) async {
    return _seekTo(positionMs, true);
  }

// Set playback parameters
  Future<Result<Void, ErrInfo>> setPitch(double pitch) async {
    if (!await _callVoidPlatformMethod("setPitch", {"pitch": pitch})) {
      return Fail(PlatformFailure());
    }
    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> setSpeed(double speed) async {
    if (!await _callVoidPlatformMethod("setSpeed", {"speed": speed})) {
      return Fail(PlatformFailure());
    }
    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> setVolume(double volume) async {
    if (!await _callVoidPlatformMethod("setVolume", {"volume": volume})) {
      return Fail(PlatformFailure());
    }
    return Succeed(Void());
  }

  /*=======================================================================*\ 
    Other
  \*=======================================================================*/
  Future<Result<int, ErrInfo>> getDuration(String path) async {
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

  Future<Result<Void, ErrInfo>> setParams() async {
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
    return Succeed(Void());
  }

  /*=======================================================================*\ 
    For Debugging
  \*=======================================================================*/
  Future<Result<int, ErrInfo>> startRecordWav(String path) async {
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

  Future<Result<int, ErrInfo>> stopRecordWav() async {
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

  Future<Result<String, ErrInfo>> test(String path) async {
    String ret = "";
    try {
      ret = await _methodChannel.invokeMethod('test', {"name": "Jhon"});
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
    }

    return Succeed(ret);
  }
}

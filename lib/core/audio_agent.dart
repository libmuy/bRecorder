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
  Function(Float32List eventData)? onWaveformData;
  Function(dynamic)? onPlayEvent;

  AudioServiceAgent() {
    _startListenEvent();
  }

  void _startListenEvent() {
    if (_eventStream != null) {
      log.warning("Waveform sample already listening");
      return;
    }

    var args = {
      "samplesPerSecond": GlobalInfo.WAVEFORM_SAMPLES_PER_SECOND,
      "sendPerSecond": GlobalInfo.WAVEFORM_SEND_PER_SECOND,
    };

    try {
      _eventStream =
          _eventChannel.receiveBroadcastStream(args).listen((dynamic map) {
        if (map.containsKey("waveform")) {
          if (onWaveformData != null) {
            onWaveformData!(map["waveform"]);
          }
        }
        if (map.containsKey("playEvent")) {
          log.debug("Got Player Event:${map['playEvent']}");
          if (onPlayEvent != null) {
            onPlayEvent!(map["playEvent"]);
          }
        }
      }, onError: (dynamic error) {
        log.error("event channel error" + error.message);
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
    if (_eventStream != null) {
      await _eventStream!.cancel();
      _eventStream = null;
    }
  }

  Future<Result<int, ErrInfo>> getDuration(String path) async {
    var ret = 0;
    try {
      ret = await _methodChannel.invokeMethod('getDuration', path);
    } on PlatformException catch (e) {
      log.critical("Got exception: $e");
      ret = -1;
    }

    if (ret < 0) return Fail(PlatformFailure());

    return Succeed(ret);
  }

// Recording
  Future<Result<Void, ErrInfo>> startRecord(String path) async {
    try {
      await _methodChannel.invokeMethod('startRecord', path);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> stopRecord() async {
    try {
      await _methodChannel.invokeMethod('stopRecord');
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

// Playing
  Future<Result<Void, ErrInfo>> startPlay(String path) async {
    try {
      await _methodChannel.invokeMethod('startPlay', path);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> stopPlay() async {
    try {
      await _methodChannel.invokeMethod('stopPlay');
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> pausePlay() async {
    try {
      await _methodChannel.invokeMethod('pausePlay');
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> resumePlay() async {
    try {
      await _methodChannel.invokeMethod('resumePlay');
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> seekTo(int ms) async {
    try {
      await _methodChannel.invokeMethod('seekTo', ms);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

// Set playback parameters
  Future<Result<Void, ErrInfo>> setPitch(double pitch) async {
    try {
      await _methodChannel.invokeMethod('setPitch', pitch);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> setSpeed(double speed) async {
    try {
      await _methodChannel.invokeMethod('setSpeed', speed);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

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

  Future<Result<int, ErrInfo>> test(String path) async {
    var ret = 0;
    try {
      ret = await _methodChannel.invokeMethod('test', path);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      ret = -1;
    }

    if (ret < 0) return Fail(PlatformFailure());

    return Succeed(ret);
  }
}

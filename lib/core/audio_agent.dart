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

  StreamSubscription? _streamSubscription;

  // true : success
  // false: failure
  bool startListenWaveformSample(
      Function(Float32List eventData) onEvent, Function(String error) onError) {
    bool ret = true;
    if (_streamSubscription != null) {
      log.warning("Waveform sample already listening");
      return ret;
    }

    var arguments = "waveform";
    arguments += ",${GlobalInfo.WAVEFORM_SAMPLES_PER_SECOND}";
    arguments += ",${GlobalInfo.WAVEFORM_SEND_PER_SECOND}";

    try {
      _streamSubscription = _eventChannel
          .receiveBroadcastStream(arguments)
          .listen((dynamic event) {
        onEvent(event);
      }, onError: (dynamic error) {
        onError(error.message);
        log.error("event channel error" + error.message);
      }, onDone: () async {
        log.info("eventchannel done: retry");
        await stopListenWaveformSample();
        startListenWaveformSample(onEvent, onError);
      }, cancelOnError: false);
    } catch (e) {
      log.error("register event channel failed");
      ret = false;
    }

    return ret;
  }

  Future<void> stopListenWaveformSample() async {
    if (_streamSubscription != null) {
      await _streamSubscription!.cancel();
      _streamSubscription = null;
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

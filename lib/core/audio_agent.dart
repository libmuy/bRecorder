import 'package:brecorder/core/result.dart';
import 'package:brecorder/core/utils.dart';
import 'package:flutter/services.dart';

final log = Logger('Audio-Agent');

class AudioServiceAgent {
  final platform = const MethodChannel('libmuy.com/brecorder');

  Future<Result<int, ErrInfo>> getDuration(String path) async {
    var ret = 0;
    try {
      ret = await platform.invokeMethod('getDuration', path);
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
      await platform.invokeMethod('startRecord', path);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> stopRecord() async {
    try {
      await platform.invokeMethod('stopRecord');
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

// Playing
  Future<Result<Void, ErrInfo>> startPlay(String path) async {
    try {
      await platform.invokeMethod('startPlay', path);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> stopPlay() async {
    try {
      await platform.invokeMethod('stopPlay');
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

// Set playback parameters
  Future<Result<Void, ErrInfo>> setPitch(double pitch) async {
    try {
      await platform.invokeMethod('setPitch', pitch);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> setSpeed(double speed) async {
    try {
      await platform.invokeMethod('setSpeed', speed);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      return Fail(PlatformFailure());
    }

    return Succeed(Void());
  }

  Future<Result<int, ErrInfo>> test(String path) async {
    var ret = 0;
    try {
      ret = await platform.invokeMethod('test', path);
    } on PlatformException catch (e) {
      log.critical("Got exception: ${e.message}");
      ret = -1;
    }

    if (ret < 0) return Fail(PlatformFailure());

    return Succeed(ret);
  }
}

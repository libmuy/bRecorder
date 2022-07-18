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
  Future<Result<Void, ErrInfo>> startRecording(String path) async {
    var ret = 0;
    try {
      ret = await platform.invokeMethod('startRecording', path);
    } on PlatformException catch (e) {
      log.critical("Got exception: $e");
      ret = -1;
    }

    if (ret < 0) return Fail(PlatformFailure());

    return Succeed(Void());
  }

  Future<Result<Void, ErrInfo>> stopRecording() async {
    var ret = 0;
    try {
      ret = await platform.invokeMethod('stopRecording');
    } on PlatformException catch (e) {
      log.critical("Got exception: $e");
      ret = -1;
    }

    if (ret < 0) return Fail(PlatformFailure());

    return Succeed(Void());
  }

  Future<Result<int, ErrInfo>> test(String path) async {
    var ret = 0;
    try {
      ret = await platform.invokeMethod('test', path);
    } on PlatformException catch (e) {
      log.critical("Got exception: $e");
      ret = -1;
    }

    if (ret < 0) return Fail(PlatformFailure());

    return Succeed(ret);
  }
}

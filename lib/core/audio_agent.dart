import 'package:bb_recorder/core/result.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final log = Logger('Audio-Agent');

class AudioServiceAgent {
  final platform = const MethodChannel('libmuy.com/bb_recorder');

  Future<Result<int, ErrInfo>> getDuration(String path) async {
    var ret = 0;
    try {
      ret = await platform.invokeMethod('getDuration', path);
    } on PlatformException catch (e) {
      log.severe("Got exception: $e");
      ret = -1;
    }

    if (ret < 0) return Fail(PlatformFailure());

    return Succeed(ret);
  }
}

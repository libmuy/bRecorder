import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

final log = Logger('ExampleLogger');

void main() {
  setUp(() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      final h = record.time.hour.toString().padLeft(2, "0");
      final m = record.time.minute.toString().padLeft(2, "0");
      final s = record.time.second.toString().padLeft(2, "0");
      final ms = record.time.millisecond.toString().padLeft(3, "0");
      debugPrint(
          '[$h:$m:$s.$ms][${record.loggerName.padRight(10)}][${record.level.name.padRight(5)}] ${record.message}');
    });
  });

  test("log test", () {
    log.info("info test1");
    log.info("info test2");
    log.info("info test3");
    log.info("info test4");
  });
}

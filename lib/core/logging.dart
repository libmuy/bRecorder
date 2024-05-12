import 'package:flutter/foundation.dart';

enum LogLevel {
  critical(1, "CRITICAL"),
  error(2, "ERROR   "),
  warning(3, "WARNING "),
  info(4, "INFO    "),
  debug(5, "DEBUG   "),
  verbose(6, "VERBOSE "),
  verbose2(7, "VERBOSE2"),
  verbose3(8, "VERBOSE3"),
  all(9, "ALL"),
  defaultLevel(4, "DEFAULT"),
  disabledLevel(0, "DISABLED_LEVEL"),
  noForce(-1, "NO_FORCE"),
  ;

  const LogLevel(this.level, this.name);
  final int level;
  final String name;
}

class _FileInfo {
  String name;
  String lineno;
  String parentName;
  String parentLineno;

  _FileInfo(this.name, this.lineno, this.parentName, this.parentLineno);
}

class Logger {
  static var defaultLevel = LogLevel.defaultLevel;
  static var forceLevel = LogLevel.noForce;
  String name;

  LogLevel level;

  Logger(this.name, {this.level = LogLevel.defaultLevel});

  // String _timestampStr(DateTime time) {
  //   final h = time.hour.toString().padLeft(2, "0");
  //   final m = time.minute.toString().padLeft(2, "0");
  //   final s = time.second.toString().padLeft(2, "0");
  //   final ms = time.millisecond.toString().padLeft(3, "0");

  //   return "$h:$m:$s.$ms";
  // }

  _FileInfo _fileinfo() {
    final tracstr = StackTrace.current.toString();
    var frameStart = tracstr.indexOf("#3");
    var colNumberEnd = tracstr.indexOf(")", frameStart);
    var lineNumberEnd = tracstr.lastIndexOf(":", colNumberEnd);
    var lineNumberStart = tracstr.lastIndexOf(":", lineNumberEnd - 1) + 1;
    var filenameStart = tracstr.lastIndexOf("/", lineNumberStart) + 1;
    final filename = tracstr.substring(filenameStart, lineNumberStart - 1);
    final lineNumber = tracstr.substring(lineNumberStart, lineNumberEnd);
    var parentFilename = "async gap";
    var parentLineNumber = "";
    frameStart = tracstr.indexOf("#4");
    if (frameStart > 0) {
      colNumberEnd = tracstr.indexOf(")", frameStart);
      lineNumberEnd = tracstr.lastIndexOf(":", colNumberEnd);
      lineNumberStart = tracstr.lastIndexOf(":", lineNumberEnd - 1) + 1;
      filenameStart = tracstr.lastIndexOf("/", lineNumberStart) + 1;
      parentFilename = tracstr.substring(filenameStart, lineNumberStart - 1);
      parentLineNumber = tracstr.substring(lineNumberStart, lineNumberEnd);
    }

    return _FileInfo(filename, lineNumber, parentFilename, parentLineNumber);
  }

  void _printLogByLevel(LogLevel outputLv, String msg, {bool parentInfo = false}) {
    int filterLv = level.level;
    if (forceLevel.level != LogLevel.noForce.level) filterLv = forceLevel.level;
    if (filterLv < outputLv.level) return;

    final fileInfo = _fileinfo();
    var fileInfoStr = "";
    if (parentInfo) {
      if (fileInfo.parentName == fileInfo.name) {
        fileInfoStr = "${fileInfo.name}:${fileInfo.parentLineno} -> ${fileInfo.lineno}";
      } else {
        fileInfoStr = "${fileInfo.parentName}:${fileInfo.parentLineno} -> ${fileInfo.name}:${fileInfo.lineno}";
      }
    } else {
      fileInfoStr = "${fileInfo.name}:${fileInfo.lineno}";
    }
    final prefix =
        // "[${_timestampStr(DateTime.now())}]"
        "[${fileInfoStr.padRight(35)}]"
        "[${name.padRight(15)}]"
        "[${outputLv.name}]";

    debugPrint("$prefix $msg");
  }

  void critical(String msg) => _printLogByLevel(LogLevel.critical, msg);
  void error(String msg) => _printLogByLevel(LogLevel.error, msg);
  void warning(String msg) => _printLogByLevel(LogLevel.warning, msg);
  void info(String msg) => _printLogByLevel(LogLevel.info, msg);
  void debug(String msg) => _printLogByLevel(LogLevel.debug, msg);
  void verbose(String msg) => _printLogByLevel(LogLevel.verbose, msg);
  void verbose2(String msg) => _printLogByLevel(LogLevel.verbose2, msg);
  void verbose3(String msg) => _printLogByLevel(LogLevel.verbose3, msg);

  void criticalWithParentInfo(String msg) => _printLogByLevel(LogLevel.critical, msg, parentInfo: true);
  void errorWithParentInfo(String msg) => _printLogByLevel(LogLevel.error, msg, parentInfo: true);
  void warningWithParentInfo(String msg) => _printLogByLevel(LogLevel.warning, msg, parentInfo: true);
  void infoWithParentInfo(String msg) => _printLogByLevel(LogLevel.info, msg, parentInfo: true);
  void debugWithParentInfo(String msg) => _printLogByLevel(LogLevel.debug, msg, parentInfo: true);
  void verboseWithParentInfo(String msg) => _printLogByLevel(LogLevel.verbose, msg, parentInfo: true);
  void verbose2WithParentInfo(String msg) => _printLogByLevel(LogLevel.verbose2, msg, parentInfo: true);
  void verbose3WithParentInfo(String msg) => _printLogByLevel(LogLevel.verbose3, msg, parentInfo: true);
}

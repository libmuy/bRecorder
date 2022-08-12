import 'package:brecorder/core/logging.dart';
import 'package:brecorder/home/domain/entities.dart';
import 'package:flutter/foundation.dart';

final log = Logger('HomeState');

class RecordingPageState {
  ValueNotifier<FolderInfo> filesystemFolderNotifier = ValueNotifier(FolderInfo(
    "",
    List.empty(),
    List.empty(),
  ));
  ValueNotifier<FolderInfo> iCloudFolderNotifier = ValueNotifier(FolderInfo(
    "",
    List.empty(),
    List.empty(),
  ));
}

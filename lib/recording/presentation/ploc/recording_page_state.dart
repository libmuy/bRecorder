import 'package:brecorder/core/logging.dart';
import 'package:brecorder/home/data/repository_type.dart';
import 'package:brecorder/home/domain/entities.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

final log = Logger('HomeState');

class RecordingPageState {
  final RepoType _dataSourceType = RepoType.filesystem;
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

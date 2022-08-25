import 'package:brecorder/core/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../data/repository_type.dart';
import '../../domain/entities.dart';
import '../../domain/entities_manager.dart';

final log = Logger('HomeState');

class BrowserViewState {
  final RepoType _dataSourceType = RepoType.filesystem;
  late final EntitiesManager _uscases = GetIt.instance.get<EntitiesManager>();
  ValueNotifier<FolderInfo> filesystemFolderNotifier = ValueNotifier(FolderInfo(
    "",
    0,
    DateTime(1907),
    List.empty(),
    List.empty(),
  ));
  ValueNotifier<FolderInfo> iCloudFolderNotifier = ValueNotifier(FolderInfo(
    "",
    0,
    DateTime(1907),
    List.empty(),
    List.empty(),
  ));

  void cd(String path) {
    _uscases.getFolderInfo(_dataSourceType, path).then((result) {
      result.fold((folderInfo) {
        filesystemFolderNotifier.value = folderInfo;
      }, (err) {
        log.critical("Failed to get folder($path) info");
      });
    });
  }
}

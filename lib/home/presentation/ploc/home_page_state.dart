import 'package:brecorder/home/data/repository_type.dart';
import 'package:brecorder/home/domain/entities.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../../domain/entities_manager.dart';

final log = Logger('HomeState');

class HomePageState {
  final RepoType _dataSourceType = RepoType.filesystem;
  late final EntitiesManager _uscases = GetIt.instance.get<EntitiesManager>();
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

  void cd(String path) {
    _uscases.getFolderInfo(_dataSourceType, path).then((result) {
      result.fold((folderInfo) {
        filesystemFolderNotifier.value = folderInfo;
      }, (err) {
        log.severe("Failed to get folder($path) info");
      });
    });
  }
}

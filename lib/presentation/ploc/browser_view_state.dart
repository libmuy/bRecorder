import 'package:brecorder/core/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../data/filesystem_repository.dart';
import '../../data/repository_type.dart';
import '../../domain/entities.dart';
import '../../domain/entities_manager.dart';

final log = Logger('HomeState');

abstract class BrowserViewState {
  final RepoType dataSourceType;
  late final EntitiesManager _uscases = GetIt.instance.get<EntitiesManager>();
  ValueNotifier<FolderInfo> folderNotifier = ValueNotifier(FolderInfo(
    "",
    0,
    DateTime(1907),
    List.empty(),
    List.empty(),
  ));

  BrowserViewState(this.dataSourceType);

  void cd(String path) {
    _uscases.getFolderInfo(dataSourceType, path).then((result) {
      result.fold((folderInfo) {
        folderNotifier.value = folderInfo;
      }, (err) {
        log.critical("Failed to get folder($path) info");
      });
    });
  }
}

class FilesystemBrowserViewState extends BrowserViewState {
  FilesystemBrowserViewState() : super(RepoType.filesystem);
}

class ICloudBrowserViewState extends BrowserViewState {
  ICloudBrowserViewState() : super(RepoType.iCloud);
}

class PlaylistBrowserViewState extends BrowserViewState {
  PlaylistBrowserViewState() : super(RepoType.playlist);
}

class TrashBrowserViewState extends BrowserViewState {
  TrashBrowserViewState() : super(RepoType.trash);
}

import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:brecorder/domain/abstract_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

import '../../data/repository_type.dart';
import '../../domain/entities.dart';

final log = Logger('HomeState');

abstract class BrowserViewState {
  final RepoType dataSourceType;
  late final Repository _repo;
  Map<AudioObject, bool> selectedItems = {};
  ValueNotifier<FolderInfo> folderNotifier = ValueNotifier(FolderInfo(
    "",
    0,
    DateTime(1907),
    List.empty(),
    List.empty(),
    0,
  ));
  bool editMode = false;
  String newFolderName = "";

  BrowserViewState(this.dataSourceType) {
    _repo = sl.getRepository(dataSourceType);
  }
  void init() {
    if (folderNotifier.value.path == "") {
      cd("/");
    } else {
      cd(folderNotifier.value.path);
    }
  }

  void cd(String path) {
    _repo.getFolderInfo(path).then((result) {
      result.fold((folderInfo) {
        for (final folder in folderInfo.subfolders) {
          selectedItems[folder] = false;
        }
        for (final audio in folderInfo.audios) {
          selectedItems[audio] = false;
        }
        folderNotifier.value = folderInfo;
      }, (err) {
        log.critical("Failed to get folder($path) info");
      });
    });
  }

  bool itemIsSelected(AudioObject key) {
    if (!selectedItems.containsKey(key)) {
      return false;
    }
    return selectedItems[key]!;
  }

  void toggleSelected(AudioObject key) {
    if (!selectedItems.containsKey(key)) {
      selectedItems[key] = true;
    }
    selectedItems[key] = !selectedItems[key]!;
  }

  void cdParent() {
    final path = dirname(folderNotifier.value.path);
    cd(path);
  }

  void newFolder() async {
    final path = join(folderNotifier.value.path, newFolderName);
    final ret = await _repo.newFolder(path);
    ret.fold((ok) {
      log.debug("create folder ok");
    }, (ng) {
      log.debug("create folder failed: $ng");
    });
  }

  void refresh() {
    cd(folderNotifier.value.path);
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

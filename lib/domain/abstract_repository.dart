import 'package:brecorder/core/result.dart';
import 'package:brecorder/data/trash_repository.dart';
import 'package:get_it/get_it.dart';

import '../data/filesystem_repository.dart';
import '../data/icloud_repository.dart';
import '../data/playlist_repository.dart';
import '../data/repository_type.dart';
import 'entities.dart';

abstract class AbstractRepository {
  static AbstractRepository getRepoFromType(RepoType type) {
    final getIt = GetIt.instance;
    late AbstractRepository ret;
    switch (type) {
      case RepoType.filesystem:
        ret = getIt.get<FilesystemRepository>();
        break;

      case RepoType.iCloud:
        ret = getIt.get<ICloudRepository>();
        break;

      case RepoType.playlist:
        ret = getIt.get<PlaylistRepository>();
        break;

      case RepoType.trash:
        ret = getIt.get<TrashRepository>();
        break;
    }

    return ret;
  }

  Future<Result<FolderInfo, ErrInfo>> getFolderInfo(String path);
  Future<Result<Void, ErrInfo>> moveObjects(
      List<String> srcPath, String dstPath);
}

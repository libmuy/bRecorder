import 'package:brecorder/core/result.dart';
import 'package:brecorder/home/data/filesystem_repository.dart';
import 'package:brecorder/home/data/icloud_repository.dart';
import 'package:brecorder/home/data/playlist_repository.dart';
import 'package:brecorder/home/data/repository_type.dart';
import 'package:brecorder/home/domain/entities.dart';
import 'package:get_it/get_it.dart';

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
    }

    return ret;
  }

  Future<Result<FolderInfo, ErrInfo>> getFolderInfo(String path);
  Future<Result<Void, ErrInfo>> moveObjects(
      List<String> srcPath, String dstPath);
}

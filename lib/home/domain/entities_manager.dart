import 'package:brecorder/core/result.dart';
import 'package:brecorder/home/data/repository_type.dart';
import 'package:brecorder/home/domain/abstract_repository.dart';
import 'package:brecorder/home/domain/entities.dart';

class EntitiesManager {
  const EntitiesManager();

  Future<Result<FolderInfo, ErrInfo>> getFolderInfo(
      RepoType repoType, String path) {
    final repository = AbstractRepository.getRepoFromType(repoType);
    return repository.getFolderInfo(path);
  }

  Future<Result<Void, ErrInfo>> moveObjects(
      RepoType repoType, List<AudioObject> src, FolderSimpleInfo to) {
    final repository = AbstractRepository.getRepoFromType(repoType);
    return repository.moveObjects(src.map((e) => e.path).toList(), to.path);
  }
}

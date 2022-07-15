import 'package:bb_recorder/core/result.dart';
import 'package:bb_recorder/home/domain/entities/fs_entities.dart';
import 'package:bb_recorder/home/domain/repositories/entities_repository.dart';

class EntitiesManager {
  final EntitiesRepository repository;

  EntitiesManager(this.repository);

  Future<Result<FolderInfo, ErrInfo>> getFolderInfo(String path) {
    return repository.getFolderInfo(path);
  }

  Future<Result<Void, ErrInfo>> moveObjects(
      List<FilesystemObject> src, FolderSimpleInfo to) {
    return repository.moveObjects(src.map((e) => e.path).toList(), to.path);
  }
}

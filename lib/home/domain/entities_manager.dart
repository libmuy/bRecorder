import 'package:brecorder/core/result.dart';
import 'package:brecorder/home/domain/entities.dart';
import 'package:brecorder/home/domain/abstract_repository.dart';

class EntitiesManager {
  final AbstractRepository repository;

  EntitiesManager(this.repository);

  Future<Result<FolderInfo, ErrInfo>> getFolderInfo(String path) {
    return repository.getFolderInfo(path);
  }

  Future<Result<Void, ErrInfo>> moveObjects(
      List<FilesystemObject> src, FolderSimpleInfo to) {
    return repository.moveObjects(src.map((e) => e.path).toList(), to.path);
  }
}

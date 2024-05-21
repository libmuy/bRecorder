import '../core/result.dart';
import '../domain/entities.dart';
import 'repository.dart';

class TrashRepository extends Repository {

  @override
  Future<Result> getFolderInfoRealOperation(String relativePath,
      {bool folderOnly = false}) async {
    return Succeed(FolderInfo(
      relativePath,
    ));
  }

  @override
  final type = RepoType.trash;

  @override
  Future<String> get rootPath async {
    return "";
  }

  @override
  Future<Result> moveObjectsRealOperation(AudioObject src, FolderInfo dstFolder,
      {bool updateCloud = true}) async {
    return const Fail(IOFailure());
  }

  @override
  Future<Result> removeObjectRealOperation(AudioObject obj) async {
    return const Fail(IOFailure());
  }

  @override
  Future<Result> newFolderRealOperation(String relativePath) async {
    return const Fail(IOFailure());
  }

  @override
  Future<Result> getAudioInfoRealOperation(String relativePath) async {
    return const Fail(IOFailure());
  }
}

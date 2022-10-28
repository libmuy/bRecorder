import '../core/result.dart';
import '../domain/entities.dart';
import 'repository.dart';

class ICloudRepository extends Repository {
  ICloudRepository() : super() {
    log.name = "RepoICloud";
  }
  @override
  Future<Result> getFolderInfoRealOperation(String relativePath,
      {bool folderOnly = false}) async {
    return Succeed(FolderInfo(
      relativePath,
    ));
  }

  @override
  Future<String> get rootPath async {
    return "";
  }

  @override
  final type = RepoType.iCloud;

  @override
  Future<Result> moveObjectsRealOperation(
      AudioObject src, FolderInfo dstFolder) async {
    return Fail(IOFailure());
  }

  @override
  Future<Result> removeObjectRealOperation(AudioObject obj) async {
    return Fail(IOFailure());
  }

  @override
  Future<Result> newFolderRealOperation(String relativePath) async {
    return Fail(IOFailure());
  }

  @override
  Future<Result> getAudioInfoRealOperation(String relativePath) async {
    return Fail(IOFailure());
  }
}

import 'package:brecorder/core/result.dart';
import 'package:path/path.dart';
import 'entities.dart';

abstract class Repository {
  Future<Result<FolderInfo, ErrInfo>> getFolderInfo(String path);
  Future<Result<Void, ErrInfo>> moveObjects(
      List<String> srcPath, String dstPath);
  Future<Result<Void, ErrInfo>> newFolder(String path);

  Future<String> get rootPath;

  Future<String> absolutePath(String relativePath) async {
    final root = await rootPath;

    String relative = relativePath;
    if (relativePath.startsWith("/")) {
      relative = relative.substring(1);
    }

    return join(root, relative);
  }
}

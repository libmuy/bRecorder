import 'package:brecorder/core/result.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'entities.dart';

abstract class Repository {
  abstract final String name;
  abstract final Icon icon;
  abstract final bool realStorage;
  Future<Result> getFolderInfo(String path, {bool folderOnly});
  Future<Result> moveObjects(List<String> srcPath, String dstPath);
  Future<Result> newFolder(String path);
  Future<Result> removeObject(AudioObject object);

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

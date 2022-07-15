import 'package:brecorder/core/result.dart';
import 'package:brecorder/home/domain/entities.dart';

abstract class AbstractRepository {
  Future<Result<FolderInfo, ErrInfo>> getFolderInfo(String path);
  Future<Result<Void, ErrInfo>> moveObjects(
      List<String> srcPath, String dstPath);
}

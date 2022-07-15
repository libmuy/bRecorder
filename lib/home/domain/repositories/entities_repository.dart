import 'package:bb_recorder/core/result.dart';
import 'package:bb_recorder/home/domain/entities/fs_entities.dart';

abstract class EntitiesRepository {
  Future<Result<FolderInfo, ErrInfo>> getFolderInfo(String path);
  Future<Result<Void, ErrInfo>> moveObjects(
      List<String> srcPath, String dstPath);
}

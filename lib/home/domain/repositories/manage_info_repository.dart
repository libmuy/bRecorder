import 'package:bb_recorder/core/failures.dart';
import 'package:bb_recorder/home/domain/entities/fs_entities.dart';
import 'package:dartz/dartz.dart';

abstract class ManageInfoRepository {
  Future<Either<Failure, FolderInfo>> getFolderInfo(String path);
}

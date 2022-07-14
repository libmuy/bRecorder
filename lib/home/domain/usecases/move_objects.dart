import 'package:bb_recorder/core/failures.dart';
import 'package:bb_recorder/core/usecase.dart';
import 'package:bb_recorder/home/domain/entities/fs_entities.dart';
import 'package:bb_recorder/home/domain/repositories/manage_info_repository.dart';
import 'package:dartz/dartz.dart';

class MoveObjects extends UseCase<void, MoveObjectsParams> {
  final ManageInfoRepository repository;

  MoveObjects(this.repository);

  @override
  Future<Either<Failure, void>> call async (MoveObjectsParams params) {
    return Left(PlatformFailure());
  }
}

class MoveObjectsParams {
  final List<FsEntity> from;
  final FolderSimpleInfo to;

  MoveObjectsParams(this.from, this.to);
}

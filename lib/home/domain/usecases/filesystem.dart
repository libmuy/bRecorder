import 'package:bb_recorder/core/failures.dart';
import 'package:bb_recorder/core/usecase.dart';
import 'package:bb_recorder/home/domain/entities/fs_entities.dart';
import 'package:bb_recorder/home/domain/repositories/manage_info_repository.dart';
import 'package:dartz/dartz.dart';

class GetFolderInfo extends UseCase<FolderInfo, String> {
  final ManageInfoRepository repository;

  GetFolderInfo(this.repository);

  @override
  Future<Either<Failure, FolderInfo>> call(String params) {
    return repository.getFolderInfo(params);
  }
}

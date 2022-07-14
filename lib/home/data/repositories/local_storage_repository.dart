import 'dart:io';

import 'package:bb_recorder/core/audio_agent.dart';
import 'package:bb_recorder/core/failures.dart';
import 'package:bb_recorder/home/domain/entities/fs_entities.dart';
import 'package:bb_recorder/home/domain/repositories/manage_info_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

class LocalStorageRepository extends ManageInfoRepository {
  @override
  Future<Either<Failure, FolderInfo>> getFolderInfo(String path) async {
    final audioAgent = GetIt.instance.get<AudioServiceAgent>();

    Directory dir;
    var subfolders = List<FolderSimpleInfo>.empty();
    var audios = List<AudioInfo>.empty();

    if (path == "/") {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = Directory(path);
    }

    if (!await dir.exists()) {
      return Left(IOFailure());
    }

    dir.listSync().forEach(((e) async {
      if (e is Directory) {
        subfolders.add(FolderSimpleInfo(e.path));
      } else if (e is File) {
        final duration = await audioAgent.getDuration(e.path);
        duration.fold((_) {
          log.warning("failed to get audio(${e.path})'s duration");
        }, (r) {
          audios.add(AudioInfo(r, e.path));
        });
      }
    }));

    return Right(FolderInfo(path, subfolders, audios));
  }
}

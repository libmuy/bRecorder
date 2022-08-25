import 'dart:io';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/result.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/abstract_repository.dart';
import '../domain/entities.dart';

class PlaylistRepository extends AbstractRepository {
  @override
  Future<Result<FolderInfo, ErrInfo>> getFolderInfo(String path) async {
    var files = List<FolderInfo>.empty(growable: true);
    var dirs = List<AudioInfo>.empty(growable: true);

    return Succeed(FolderInfo(path, 0, DateTime(1907), files, dirs));
  }

  @override
  Future<Result<Void, ErrInfo>> moveObjects(
      List<String> srcPath, String dstPath) async {
    var files = List<String>.empty(growable: true);
    var dirs = List<String>.empty(growable: true);
    // check existence
    for (final path in srcPath) {
      final type = FileSystemEntity.typeSync(path);
      switch (type) {
        case FileSystemEntityType.directory:
          dirs.add(path);
          break;

        case FileSystemEntityType.file:
          files.add(path);
          break;

        case FileSystemEntityType.notFound:
        case FileSystemEntityType.link:
          return Fail(IOFailure());
      }
    }

    try {
      for (final f in files) {
        final newPath = join(dstPath, f);
        File(f).renameSync(newPath);
      }
    } catch (e) {
      log.critical("got a file IO exception: $e");
      return Fail(IOFailure());
    }

    return Succeed(Void());
  }
}

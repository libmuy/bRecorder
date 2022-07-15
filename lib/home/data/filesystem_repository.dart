import 'dart:io';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/result.dart';
import 'package:brecorder/home/domain/entities.dart';
import 'package:brecorder/home/domain/abstract_repository.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class FilesystemRepository extends AbstractRepository {
  @override
  Future<Result<FolderInfo, ErrInfo>> getFolderInfo(String path) async {
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
      return Fail(IOFailure());
    }

    dir.listSync().forEach(((e) async {
      if (e is Directory) {
        subfolders.add(FolderSimpleInfo(e.path));
      } else if (e is File) {
        final duration = await audioAgent.getDuration(e.path);
        duration.fold((r) {
          audios.add(AudioInfo(r, e.path));
        }, (_) {
          log.warning("failed to get audio(${e.path})'s duration");
        });
      }
    }));

    return Succeed(FolderInfo(path, subfolders, audios));
  }

  @override
  Future<Result<Void, ErrInfo>> moveObjects(
      List<String> srcPath, String dstPath) async {
    var files = List<String>.empty();
    var dirs = List<String>.empty();
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
      log.severe("got a file IO exception: $e");
      return Fail(IOFailure());
    }

    return Succeed(Void());
  }
}

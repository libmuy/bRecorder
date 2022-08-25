import 'dart:io';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/result.dart';
import 'package:brecorder/core/logging.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/abstract_repository.dart';
import '../domain/entities.dart';

final log = Logger('FsRepo');

class FilesystemRepository extends AbstractRepository {
  String? _rootPath;
  final audioAgent = GetIt.instance.get<AudioServiceAgent>();

  Future<String> get rootPath async {
    if (_rootPath != null) {
      return _rootPath!;
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      _rootPath = join(docDir.path, "brecorder/data");
      Directory(_rootPath!).create(recursive: true);
      return _rootPath!;
    }
  }

  Future<String> _trimRoot(String path) async {
    final String root = await rootPath;
    return path.substring(root.length);
  }

  Future<FolderInfo?> _getFolderInfoHelper(String path) async {
    Directory dir;
    var subfolders = List<FolderInfo>.empty(growable: true);
    var audios = List<AudioInfo>.empty(growable: true);
    var folderTimestamp = DateTime(1970);
    var folderBytes = 0;

    if (path == "/") {
      dir = Directory(await rootPath);
    } else {
      dir = Directory("${await rootPath}$path");
    }

    if (!await dir.exists()) {
      log.error("dirctory(${dir.path}) not exists");
      return null;
    }

    for (final e in dir.listSync()) {
      final realtivePath = await _trimRoot(e.path);
      if (e is Directory) {
        log.debug("got directory:${e.path}");
        final folder = await _getFolderInfoHelper(realtivePath);
        if (folder == null) return null;
        subfolders.add(folder);
        if (folder.timestamp.compareTo(folderTimestamp) > 0) {
          folderTimestamp = folder.timestamp;
        }
      } else if (e is File) {
        log.debug("got file:${e.path}");
        final timestamp = await e.lastModified();
        final bytes = await e.length();
        folderBytes += bytes;
        final duration = await audioAgent.getDuration(e.path);
        duration.fold((r) {
          log.debug("duration:$r");
          audios.add(AudioInfo(r, realtivePath, bytes, timestamp));
        }, (_) {
          log.error("failed to get audio(${e.path})'s duration");
        });
        if (timestamp.compareTo(folderTimestamp) > 0) {
          folderTimestamp = timestamp;
        }
      }
    }

    return FolderInfo(path, folderBytes, folderTimestamp, subfolders, audios);
  }

  @override
  Future<Result<FolderInfo, ErrInfo>> getFolderInfo(String path) async {
    final folder = await _getFolderInfoHelper(path);

    if (folder == null) {
      return Fail(IOFailure());
    }

    return Succeed(folder);
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

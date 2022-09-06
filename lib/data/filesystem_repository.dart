import 'dart:io';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/result.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/abstract_repository.dart';
import '../domain/entities.dart';

final log = Logger('FsRepo');

class FilesystemRepository extends Repository {
  String? _rootPath;
  final audioAgent = sl.get<AudioServiceAgent>();

  @override
  final String name = "Local Stroage";

  @override
  final Icon icon = const Icon(Icons.phone_android);

  @override
  final realStorage = true;

  @override
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

  Future<FolderInfo?> _getFolderInfoHelper(String path, bool folderOnly) async {
    Directory dir;
    var subfolders = List<FolderInfo>.empty(growable: true);
    var audios = List<AudioInfo>.empty(growable: true);
    var folderTimestamp = DateTime(1970);
    var audioCount = 0;
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
        final folder = await _getFolderInfoHelper(realtivePath, false);
        if (folder == null) return null;
        subfolders.add(folder);
        if (folder.timestamp.compareTo(folderTimestamp) > 0) {
          folderTimestamp = folder.timestamp;
        }
        audioCount += folder.audioCount;
        folderBytes += folder.bytes;
      } else if (e is File) {
        log.debug("got file:${e.path}");
        final timestamp = await e.lastModified();
        final bytes = await e.length();
        folderBytes += bytes;
        final duration = await audioAgent.getDuration(e.path);
        if (duration.succeed) {
          log.debug("duration:${duration.value}");
          if (!folderOnly) {
            audios.add(AudioInfo(duration.value, realtivePath, bytes, timestamp,
                repo: this));
          }
        } else {
          log.error("failed to get audio(${e.path})'s duration");
        }
        if (timestamp.compareTo(folderTimestamp) > 0) {
          folderTimestamp = timestamp;
        }
        audioCount += 1;
      }
    }

    if (folderTimestamp.compareTo(DateTime(1970)) == 0) {
      final stat = await dir.stat();
      folderTimestamp = stat.modified;
    }

    return FolderInfo(
        path, folderBytes, folderTimestamp, subfolders, audios, audioCount,
        repo: this);
  }

  @override
  Future<Result> getFolderInfo(String path, {bool folderOnly = false}) async {
    final folder = await _getFolderInfoHelper(path, folderOnly);

    if (folder == null) {
      return Fail(IOFailure());
    }

    return Succeed(folder);
  }

  @override
  Future<Result> moveObjects(List<String> srcPath, String dstPath) async {
    var files = List<String>.empty(growable: true);
    var dirs = List<String>.empty(growable: true);
    final absoluteDstPath = await absolutePath(dstPath);
    // check existence
    for (final relativePath in srcPath) {
      final path = await absolutePath(relativePath);
      final type = await FileSystemEntity.type(path);
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
        final newPath = join(absoluteDstPath, basename(f));
        await File(f).rename(newPath);
      }
      for (final d in dirs) {
        final newPath = join(absoluteDstPath, basename(d));
        await Directory(d).rename(newPath);
      }
    } catch (e) {
      log.critical("got a file IO exception: $e");
      return Fail(IOFailure());
    }

    return Succeed();
  }

  @override
  Future<Result> newFolder(String path) async {
    final absPath = await absolutePath(path);
    final dir = Directory(absPath);
    try {
      if (await dir.exists()) {
        return Fail(AlreadExists());
      }
      await dir.create();
    } catch (e) {
      log.critical("got a file IO exception: $e");
      return Fail(IOFailure());
    }

    return Succeed();
  }

  @override
  Future<Result> removeObject(AudioObject object) async {
    FileSystemEntity entity;
    if (object is AudioInfo) {
      entity = File(await object.realPath);
    } else {
      entity = Directory(await object.realPath);
    }
    try {
      await entity.delete(recursive: true);
    } catch (e) {
      log.critical("got a file IO exception: $e");
      return Fail(IOFailure());
    }

    return Succeed();
  }
}

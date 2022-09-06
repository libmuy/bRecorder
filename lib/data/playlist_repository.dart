import 'dart:io';

import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/result.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../domain/abstract_repository.dart';
import '../domain/entities.dart';

class PlaylistRepository extends Repository {
  @override
  Future<Result> getFolderInfo(String path, {bool folderOnly = false}) async {
    var files = List<FolderInfo>.empty(growable: true);
    var dirs = List<AudioInfo>.empty(growable: true);

    return Succeed(FolderInfo(path, 0, DateTime(1907), files, dirs, 0));
  }

  @override
  Future<String> get rootPath async {
    return "";
  }

  @override
  final Icon icon = const Icon(Icons.playlist_play_outlined);
  @override
  final String name = "Playlist";
  @override
  final realStorage = false;

  @override
  Future<Result> moveObjects(List<String> srcPath, String dstPath) async {
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

    return Succeed();
  }

  @override
  Future<Result> newFolder(String path) async {
    return Fail(IOFailure());
  }

  @override
  Future<Result> removeObject(AudioObject object) async {
    return Fail(IOFailure());
  }
}

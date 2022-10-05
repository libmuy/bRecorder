// ignore_for_file: unused_element

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../core/audio_agent.dart';
import '../core/logging.dart';
import '../core/result.dart';
import '../core/service_locator.dart';
import '../domain/entities.dart';
import 'repository.dart';

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

  Future<bool> _isFile(String path) async {
    final type = await FileSystemEntity.type(path);
    return type == FileSystemEntityType.file;
  }

  Future<String> _trimRoot(String path) async {
    final String root = await rootPath;
    var ret = path.substring(root.length);

    if (ret == "") ret = "/";
    return ret;
  }

  Future<AudioInfo> _audioInfoFromFilesystem(String path) async {
    final relativePath = await _trimRoot(path);
    int bytes = 0;
    DateTime timestamp = DateTime(1970);
    try {
      final file = File(path);
      timestamp = await file.lastModified();
      bytes = await file.length();
      final ret = await audioAgent.getDuration(path);
      if (ret.succeed) {
        log.debug("duration:${ret.value}");
      } else {
        log.error("failed to get audio($relativePath)'s duration, set to 0");
      }
      return AudioInfo(ret.value ?? 0, relativePath, bytes, timestamp,
          repo: this);
    } catch (e) {
      log.critical("got a file IO exception: $e");
      return AudioInfo.brokenAudio(
          path: relativePath, bytes: bytes, timestamp: timestamp, repo: this);
    }
  }

  Future<FolderInfo?> _getFolderInfoHelper(String path, bool folderOnly) async {
    Directory dir = Directory(path);
    var subfoldersMap = <String, FolderInfo>{};
    var audiosMap = <String, AudioInfo>{};
    var folderTimestamp = DateTime(1970);
    var audioCount = 0;
    var folderBytes = 0;
    var ret = FolderInfo.empty;

    if (!await dir.exists()) {
      log.error("dirctory(${dir.path}) not exists");
      return null;
    }

    for (final e in dir.listSync()) {
      if (e is Directory) {
        log.debug("got directory:${e.path}");
        final folder = await _getFolderInfoHelper(e.path, false);
        if (folder == null) return null;
        folder.parent = ret;
        subfoldersMap[basename(e.path)] = folder;
        if (folder.timestamp.compareTo(folderTimestamp) > 0) {
          folderTimestamp = folder.timestamp;
        }
        audioCount += folder.allAudioCount;
        folderBytes += folder.bytes;
      } else if (e is File) {
        log.debug("got file:${e.path}");
        final audio = await _audioInfoFromFilesystem(e.path);
        audio.parent = ret;
        audiosMap[basename(e.path)] = audio;
        folderBytes += audio.bytes;
        if (audio.timestamp.compareTo(folderTimestamp) > 0) {
          folderTimestamp = audio.timestamp;
        }
        audioCount += 1;
      }
    }

    if (folderTimestamp.compareTo(DateTime(1970)) == 0) {
      final stat = await dir.stat();
      folderTimestamp = stat.modified;
    }
// FolderInfo(path, folderBytes, folderTimestamp, audioCount,
//         subfolders: subfolders, audios: audios, repo: this)
    ret.path = await _trimRoot(path);
    ret.bytes = folderBytes;
    ret.timestamp = folderTimestamp;
    ret.allAudioCount = audioCount;
    ret.subfoldersMap = subfoldersMap.isEmpty ? null : subfoldersMap;
    ret.audiosMap = audiosMap.isEmpty ? null : audiosMap;
    ret.repo = this;
    return ret;
  }

  @override
  Future<Result> getFolderInfoRealOperation(String relativePath,
      {bool folderOnly = false}) async {
    final path = await absolutePath(relativePath);
    final folder = await _getFolderInfoHelper(path, folderOnly);

    if (folder == null) {
      return Fail(IOFailure());
    }

    return Succeed(folder);
  }

  @override
  Future<Result> moveObjectsRealOperation(
      String srcRelativePath, String dstRelativePath) async {
    final dstPath = await absolutePath(dstRelativePath);
    final srcPath = await absolutePath(srcRelativePath);

    try {
      FileSystemEntity src =
          await _isFile(srcPath) ? File(srcPath) : Directory(srcPath);
      final newPath = join(dstPath, basename(srcPath));
      await src.rename(newPath);
    } catch (e) {
      log.critical("got a file IO exception: $e");
      return Fail(IOFailure());
    }

    return Succeed();
  }

  @override
  Future<Result> newFolderRealOperation(String relativePath) async {
    final absPath = await absolutePath(relativePath);
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
  Future<Result> getAudioInfoRealOperation(String relativePath) async {
    final path = await absolutePath(relativePath);
    final audio = await _audioInfoFromFilesystem(path);
    return Succeed(audio);
  }

  @override
  Future<Result> removeObjectRealOperation(String relativePath) async {
    final path = await absolutePath(relativePath);
    FileSystemEntity entity;
    if (await _isFile(path)) {
      entity = File(path);
    } else {
      entity = Directory(path);
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

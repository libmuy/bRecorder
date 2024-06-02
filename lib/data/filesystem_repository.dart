// ignore_for_file: unused_element

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

import '../core/audio_agent.dart';
import '../core/result.dart';
import '../core/service_locator.dart';
import '../domain/entities.dart';
import 'repository.dart';
import '../core/logging.dart';

final _log = Logger('RepoFs', level: LogLevel.debug);

class FilesystemRepository extends Repository {
  String? _rootPath;
  Future<String>? _rootPathFuture;
  final audioAgent = sl.get<AudioServiceAgent>();

  FilesystemRepository(Future<String> rootPathFuture, {this.type = RepoType.filesystem})
      : _rootPathFuture = rootPathFuture {
    rootPathFuture.then((value) {
      _rootPath = value;
      _rootPathFuture = null;
    });
  }

  @override
  RepoType type;

  @override
  Future<String> get rootPath async {
    if (_rootPath != null) {
      return _rootPath!;
    } else {
      _rootPath = await _rootPathFuture;
      assert(_rootPath != null);
      Directory(_rootPath!).create(recursive: true);
      _rootPathFuture = null;
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

  Future<bool> getAudioInfoFromRepo(AudioInfo request,
      {bool prefetch = false}) async {
    final relativePath = request.path;
    final path = await absolutePath(relativePath);
    int bytes = 0;
    DateTime timestamp = DateTime(1970);
    try {
      final file = File(path);
      final stat = await file.stat();
      await waitUiReqWhilePrefetch(prefetch);
      if (!doingPrefetch && prefetch) return false;
      timestamp = stat.modified;
      bytes = stat.size;
      final ret = await audioAgent.getDuration(path);
      await waitUiReqWhilePrefetch(prefetch);
      if (!doingPrefetch && prefetch) return false;
      if (ret.succeed) {
        _log.verbose("duration:${ret.value}");
      } else {
        _log.error("failed to get audio($relativePath)'s duration, set to 0");
      }
      request.durationMS = ret.value ?? 0;
      request.bytes = bytes;
      request.timestamp = timestamp;
      request.repo = this;
    } catch (e) {
      _log.critical("got a file IO exception: $e");
      return false;
    }

    return true;
  }

  Future<bool> getPlaylistInfoFromRepo(PlaylistInfo request,
      {bool prefetch = false}) async {
    final relativePath = request.path;
    final path = await absolutePath(relativePath);
    try {
      final file = File(path);
      final jsonStr = await file.readAsString();
      final json  = jsonDecode(jsonStr);
      final List<Map<String, dynamic>> jsonAudios = json['audios'];
      List<AudioInfo> audios = [];
      for (final a in jsonAudios) {
        final repo = sl.getRepository(RepoType.fromString(a['repoType']));
        final audio = repo.findObjectFromCache(a['path']);
        if (audio != null) {
          audios.add(audio as AudioInfo);
        } else {
          AudioInfo.brokenAudio(path: a['path']);
        }
      }

      request.audios = audios;
      request.repo = this;
      request.bytes = 0;
    } catch (e) {
      _log.critical("got a file IO exception: $e");
      return false;
    }

    return true;
  }

  Future<bool> preFetchInternalDirStructure() async {
    final queue = Queue<FolderInfo>();
    queue.add(cache == null ? FolderInfo("/") : cache!);

    await waitUiReqWhilePrefetch();
    if (!doingPrefetch) return true;
    while (queue.isNotEmpty && doingPrefetch) {
      final folder = queue.removeFirst();
      final itr = orphans.where((f) => f.path == folder.path);
      if (itr.isNotEmpty) {
        // Get Folder Info from orphans list(UI requested folder info catch)
        _log.debug("get folder from orphan cache: ${folder.path}");
        final orphanFolder = itr.first;
        orphans.remove(orphanFolder);
        folder.subfoldersMap = orphanFolder.subfoldersMap;
        folder.audiosMap = orphanFolder.audiosMap;
        folder.playlistMap = orphanFolder.playlistMap;
        folder.displayData ??= orphanFolder.displayData;
      } else {
        // Get Folder Info from Repo
        _log.debug("get folder from repo: ${folder.path}");
        prefetchingFolderPath = folder.path;
        final result = await fetchFolderInfoFs(folder, prefetch: true);
        await waitUiReqWhilePrefetch();
        if (!doingPrefetch) break;

        if (!result) {
          _log.error("Get Folder Info Failed!(${folder.path})");
          prefetchingFolderPath = null;
          return false;
        }
        if (folder.parent == null && cache == null) cache = folder;
        prefetchingFolderPath = null;
        if (uiRequestNotifier != null) uiRequestNotifier!.complete();
      }

      // Add Sub folders into stack
      if (folder.subfolders != null) queue.addAll(folder.subfolders!);
    }

    return true;
  }

  Future<bool> preFetchInternalStaticsInfo(FolderInfo folder) async {
    int audioCount = 0;
    int bytes = 0;
    DateTime timestamp = DateTime(1970);

    _log.debug("Get statics: ${folder.path}");
    for (final sub in folder.subObjects) {
      if (sub is FolderInfo) {
        await preFetchInternalStaticsInfo(sub);
        audioCount += sub.allAudioCount!;
      } else if (sub is AudioInfo) {
        //UI requested audios have no detail info, gather info here
        if (sub.bytes == null) {
          final result = await getAudioInfoFromRepo(sub, prefetch: true);
          if (!result) {
            _log.error("Get AudioInfo from repo failed: ${sub.path}");
            return false;
          }
          sub.updateUI();
        }
        audioCount++;
      } else if (sub is PlaylistInfo) {
        //UI requested audios have no detail info, gather info here
        if (sub.bytes == null) {
          final result = await getPlaylistInfoFromRepo(sub, prefetch: true);
          if (!result) {
            _log.error("Get AudioInfo from repo failed: ${sub.path}");
            return false;
          }
          sub.updateUI();
        }
      }
      bytes += sub.bytes!;
      if (sub.timestamp != null) {
        if (sub.timestamp!.compareTo(timestamp) > 1) timestamp = sub.timestamp!;
      }
    }
    folder.allAudioCount = audioCount;
    folder.bytes = bytes;
    folder.updateUI();
    folder.timestamp = timestamp;
    return true;
  }

  @override
  Future<bool> preFetchInternal() async {
    _log.debug("============== Prefetch: Dir structure Start ");
    var ret = await preFetchInternalDirStructure();
    _log.debug("============== Prefetch: Dir structure End ");
    if (!ret) return false;

    _log.debug("============== Prefetch: Update statics info Start ");
    ret = await preFetchInternalStaticsInfo(cache!);
    _log.debug("============== Prefetch: Update statics info End ");

    return ret;
  }

  Future<bool> fetchFolderInfoFs(FolderInfo request,
      {bool folderOnly = false, bool prefetch = false}) async {
    final relativePath = request.path;
    final absolautePath = await absolutePath(relativePath);
    Directory dir = Directory(absolautePath);
    var subfoldersMap = <String, FolderInfo>{};
    var audiosMap = <String, AudioInfo>{};
    var playlistMap = <String, PlaylistInfo>{};

    if (!await dir.exists()) {
      _log.error("dirctory(${dir.path}) not exists");
      return false;
    }
    await waitUiReqWhilePrefetch(prefetch);
    if (!doingPrefetch && prefetch) return false;

    await for (final file in dir.list()) {
      await waitUiReqWhilePrefetch(prefetch);
      if (!doingPrefetch && prefetch) return false;
      final name = basename(file.path);
      final path = join(relativePath, name);
      late AudioObject obj;
      if (file is Directory) {
        _log.verbose("got directory:${file.path}");
        obj = FolderInfo(path, repo: this);
        subfoldersMap[name] = obj as FolderInfo;
      } else if (file is File) {
        if (folderOnly) continue;
        _log.verbose("got file:${file.path}");
        if (file.path.endsWith('.playlist')) {
          if (prefetch) {
            obj = PlaylistInfo(path);
            final result =
                await getPlaylistInfoFromRepo(obj as PlaylistInfo, prefetch: prefetch);
            if (!doingPrefetch && prefetch) return false;
            if (result == false) obj = PlaylistInfo.brokenPlaylist(path: path);
          } else {
            obj = PlaylistInfo(path, repo: this);
          }
          playlistMap[name] = obj as PlaylistInfo;
        } else {
          if (prefetch) {
            obj = AudioInfo(path);
            final result =
                await getAudioInfoFromRepo(obj as AudioInfo, prefetch: prefetch);
            if (!doingPrefetch && prefetch) return false;
            if (result == false) obj = AudioInfo.brokenAudio(path: path);
          } else {
            obj = AudioInfo(path, repo: this);
          }
          audiosMap[name] = obj as AudioInfo;
        }
      }
      obj.parent = request;
    }
    request.subfoldersMap = subfoldersMap.isEmpty ? null : subfoldersMap;
    request.audiosMap = audiosMap.isEmpty ? null : audiosMap;
    request.playlistMap = playlistMap.isEmpty ? null : playlistMap;
    request.repo = this;

    return true;
  }

  @override
  Future<Result> getFolderInfoRealOperation(String relativePath,
      {bool folderOnly = false}) async {
    final folder = FolderInfo(relativePath);
    final result = await fetchFolderInfoFs(folder, folderOnly: folderOnly);

    if (!result) {
      _log.error("get folder($relativePath) not exists");
      return const Fail(IOFailure());
    }
    return Succeed(folder);
  }

  Future<bool> _copyBetweenFs(String src, String dst) async {
    final newPath = join(dst, basename(src));
    try {
      if (await _isFile(src)) {
        await File(src).copy(newPath);
      } else {
        await Directory(newPath).create(recursive: true);
        await for (final sub in Directory(src).list()) {
          final ok = await _copyBetweenFs(sub.path, newPath);
          if (!ok) return false;
        }
      }
    } catch (e) {
      _log.error("Copy file failed! src:$src, dst:$dst");
      return false;
    }

    return true;
  }

  @override
  Future<Result> moveObjectsRealOperation(AudioObject src, FolderInfo dstFolder,
      {bool updateCloud = true}) async {
    final srcPath = await src.realPath;
    final dstPath = await dstFolder.realPath;

    FileSystemEntity srcFile =
        await _isFile(srcPath) ? File(srcPath) : Directory(srcPath);
    try {
      final newPath = join(dstPath, basename(srcPath));
      await srcFile.rename(newPath);
    } on FileSystemException {
      final ok = await _copyBetweenFs(srcPath, dstPath);
      if (!ok) return Fail(ErrMsg("Copy file between fs failed!"));
      await srcFile.delete(recursive: true);
    } catch (e) {
      _log.critical("got a file IO exception: $e");
      return const Fail(IOFailure());
    }

    return const Succeed();
  }

  @override
  Future<Result> newFolderRealOperation(String relativePath) async {
    final absPath = await absolutePath(relativePath);
    final dir = Directory(absPath);
    try {
      if (await dir.exists()) {
        return const Fail(AlreadExists());
      }
      await dir.create();
    } catch (e) {
      _log.critical("got a file IO exception: $e");
      return const Fail(IOFailure());
    }

    var newFolder = FolderInfo(relativePath, repo: this);
    final addRet = addObjectIntoCache(newFolder, onlyStruct: true);
    if (addRet == false) {
      return Fail(ErrMsg("Add folder info into cache failed!"));
    }

    return Succeed(newFolder);
  }

  @override
  Future<Result> getAudioInfoRealOperation(String relativePath) async {
    final request = AudioInfo(relativePath);
    final result = await getAudioInfoFromRepo(request);
    if (result == false) Fail(ErrMsg("Get AudioInfo from Repo failed"));
    return Succeed(request);
  }

  @override
  Future<Result> getPlaylistInfoRealOperation(String relativePath) async {
    final request = PlaylistInfo(relativePath);
    final result = await getPlaylistInfoFromRepo(request);
    if (result == false) Fail(ErrMsg("Get AudioInfo from Repo failed"));
    return Succeed(request);
  }

  @override
  Future<Result> removeObjectRealOperation(AudioObject obj) async {
    final relativePath = obj.path;
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
      _log.critical("got a file IO exception: $e");
      return const Fail(IOFailure());
    }

    return const Succeed();
  }
}

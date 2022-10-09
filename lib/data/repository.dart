import 'package:brecorder/data/repository_type.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';

import '../core/logging.dart';
import '../core/result.dart';
import '../domain/entities.dart';
import '../presentation/ploc/browser_view_state.dart';

final la = fs;

abstract class Repository {
  abstract final String name;
  abstract final Icon icon;
  abstract final bool realStorage;
  abstract final RepoType type;
  FolderInfo? cache;
  final log = Logger('Repo');

  void destoryCache() {
    if (cache == null) return;
    _destoryAudioObject(cache!);
    cache = null;
  }

  AudioObject? _findObjectFromCache(String path, {bool folderOnly = false}) {
    final list = split(path);
    FolderInfo? current = cache;

    if (cache == null) return null;
    if (path == "/") return cache;

    for (final p in list) {
      if (p == "/") continue;

      if (current == null) return null;

      if (current.hasSubfolder(p)) {
        current = current.subfoldersMap![p];
        continue;
      }
      if (folderOnly) return null;

      if (current.hasAudio(p)) return current.audiosMap![p];
      return null;
    }

    return current;
  }

  Future<Result> getFolderInfo(String path,
      {bool folderOnly = false, bool forcely = false}) async {
    if (cache == null || forcely) {
      log.info("not cached, get data from real repository");
      final ret = await getFolderInfoRealOperation("/", folderOnly: folderOnly);
      if (ret.succeed) {
        cache = ret.value;
      } else {
        log.error("get data from real repository failed!");
        return ret;
      }
    }

    final folder = _findObjectFromCache(path, folderOnly: true);
    if (folder == null) {
      log.error("get folder($path) info failed!");
      return Fail(ErrMsg("Cannot find the folder in the cache!"));
    }

    return Succeed(folder);
  }

  void _moveObjectForCache(AudioObject src, FolderInfo dst) {
    _removeObjectFromCache(src);
    _addObjectIntoCache(src, dst: dst);
  }

  void _destoryAudioObject(AudioObject obj) {
    log.debug("destroy repo:$name, obj:${obj.path}");
    // if (obj.displayData != null) obj.displayData = null;
    if (obj.copyFrom != null) obj.copyFrom = null;

    try {
      if (obj is FolderInfo) {
        obj.parent?.subfoldersMap?.remove(obj.mapKey);
      } else {
        obj.parent?.audiosMap?.remove(obj.mapKey);
      }
    } catch (e) {
      log.warning("not exist in parent's subobject?, error:$e");
    }

    obj.parent = null;
    obj.destory();
    if (obj is AudioInfo) return;

    final folder = obj as FolderInfo;
    for (var o in folder.subObjects) {
      _destoryAudioObject(o);
    }
    folder.subfoldersMap = null;
    folder.audiosMap = null;
  }

  void _removeObjectFromCache(AudioObject obj, {bool destory = false}) {
    var child = obj;
    var parent = child.parent;
    final key = obj.mapKey;
    if (obj is FolderInfo) {
      parent!.subfoldersMap!.remove(key);
    } else if (obj is AudioInfo) {
      parent!.audiosMap!.remove(key);
    }

    while (parent != null) {
      parent.allAudioCount -= obj is FolderInfo ? obj.allAudioCount : 1;
      parent.bytes -= obj.bytes;

      child = parent;
      parent = parent.parent;
    }

    //break the reference loop
    if (destory) {
      _destoryAudioObject(obj);
    }
    obj.parent = null;
  }

  void _updatePath(AudioObject obj) {
    obj.path = join(obj.parent!.path, obj.mapKey);
    if (obj is AudioInfo) return;

    final folder = obj as FolderInfo;
    for (final o in folder.subObjects) {
      _updatePath(o);
    }
  }

  bool _addObjectIntoCache(AudioObject obj, {FolderInfo? dst}) {
    FolderInfo? parent = dst;
    parent ??= obj.parent;
    parent ??= _findObjectFromCache(dirname(obj.path), folderOnly: true)
        as FolderInfo?;

    if (parent == null) {
      log.error("Can not find parent for ${obj.path}");
      return false;
    }

    obj.parent = parent;
    int audioCount = 0;
    if (obj is AudioInfo) {
      parent.audiosMap ??= {};
      parent.audiosMap![obj.mapKey] = obj;
      audioCount = 1;
    } else if (obj is FolderInfo) {
      parent.subfoldersMap ??= {};
      parent.subfoldersMap![obj.mapKey] = obj;
      audioCount = obj.allAudioCount;
    }

    //update meta data of parents
    while (parent != null) {
      parent.allAudioCount += audioCount;
      parent.timestamp = obj.timestamp;
      parent.bytes += obj.bytes;
      parent = parent.parent;
    }

    //update path
    _updatePath(obj);

    return true;
  }

  Future<Result> moveObjects(
      List<AudioObject> srcObjList, FolderInfo folder) async {
    for (final src in srcObjList) {
      final ret = await moveObjectsRealOperation(src.path, folder.path);
      if (ret.succeed) {
        _moveObjectForCache(src, folder);
      } else {
        log.error("Move Object failed, src:$src, dst:$folder");
        return ret;
      }
    }
    return Succeed();
  }

  Future<Result> newFolder(String path) async {
    final ret = await newFolderRealOperation(path);
    if (ret.failed) {
      log.error("New Folder($path) failed");
      return ret;
    }

    var newFolder = FolderInfo(path, 0, DateTime.now(), 0, repo: this);
    final addRet = _addObjectIntoCache(newFolder);
    if (addRet == false) {
      return Fail(ErrMsg("Add folder info into cache failed!"));
    }

    return Succeed();
  }

  Future<Result> notifyNewAudio(String path) async {
    var ret = await getAudioInfoRealOperation(path);
    if (ret.failed) return ret;
    AudioInfo newAudio = ret.value;
    final addRet = _addObjectIntoCache(newAudio);
    if (addRet == false) {
      return Fail(ErrMsg("Add audio info into cache failed!"));
    }

    return ret;
  }

  Future<Result> removeObject(AudioObject obj) async {
    final ret = await removeObjectRealOperation(obj.path);
    if (ret.succeed) {
      _removeObjectFromCache(obj, destory: true);
    } else {
      log.error("Remove object(${obj.path}) failed");
      return ret;
    }
    return Succeed();
  }

  Future<Result> moveObjectsRealOperation(
      String srcRelativePath, String dstRelativePath);
  Future<Result> newFolderRealOperation(String relativePath);
  Future<Result> removeObjectRealOperation(String relativePath);

  Future<String> get rootPath;
  Future<Result> getFolderInfoRealOperation(String relativePath,
      {bool folderOnly});
  Future<Result> getAudioInfoRealOperation(String relativePath);

  Future<String> absolutePath(String relativePath) async {
    final root = await rootPath;

    String relative = relativePath;
    if (relativePath.startsWith("/")) {
      relative = relative.substring(1);
    }

    return join(root, relative);
  }
}

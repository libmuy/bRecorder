import 'dart:async';

import 'package:brecorder/core/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../core/logging.dart';
import '../core/result.dart';
import '../domain/entities.dart';

abstract class Repository {
  @protected
  final log = Logger('Repo', level: LogLevel.debug);
  abstract final RepoType type;
  String get name => type.title;
  Icon get icon => type.icon;

  ///Could be in Tab
  bool get isTab => type.isTab;

  ///Could browse when selecting move to folder
  bool get browsable => type.browsable;

  ///Notify UI prefetching folder path
  @protected
  String? prefetchingFolderPath;

  ///Prefetching is doing
  @protected
  bool doingRrefetch = false;

  ///Notify UI Prefetching done
  Completer? _prefetchCompleter;

  ///UI requested folder info catch
  @protected
  List<FolderInfo> orphans = [];

  ///Folderinfo cache
  @protected
  FolderInfo? cache;

  //iCloud Drive / Google Drive etc.
  CloudState get cloudState => CloudState.isNotCloud;
  bool get isCloud => cloudState != CloudState.isNotCloud;
  String get cloudErrMessage => "";
  Future<bool> connectCloud({bool background = false}) async => true;
  Future<bool> disconnectCloud() async => true;
  Future<bool> removeFromCloud(AudioObject obj) async => true;
  Future<bool> addToCloud(AudioObject obj) async => true;

  ///UI requesting.
  ///This will be checked by sub classes
  @protected
  Completer? uiRequest;
  @protected
  Completer? uiRequestNotifier;

  void destoryCache() {
    if (cache == null) return;
    _destoryAudioObject(cache!);
    cache = null;
  }

  @protected
  AudioObject? findObjectFromCache(String path, {bool folderOnly = false}) {
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

  ///Clear cached [FolderInfo].
  ///stop prefetching if prefetching is doing
  Future<void> clearCache() async {
    if (doingRrefetch) {
      doingRrefetch = false;
      await _prefetchCompleter!.future;
    }
    cache = null;
    orphans = [];
  }

  @protected
  Future<void> waitUiReqWhilePrefetch([bool prefetch = true]) async {
    if (!prefetch) return;
    if (uiRequest != null) await uiRequest!.future;
  }

  @protected
  Future<bool> preFetchInternal() async => false;

  Future<void> preFetch({bool force = false}) async {
    if (force) {
      await clearCache();
    } else {
      if (doingRrefetch) return;
    }
    doingRrefetch = true;
    _prefetchCompleter = Completer();

    final result = await preFetchInternal();
    if (!result) {
      log.critical("\n"
          "##############################################\n"
          "#            PreFetch FAILED!                #\n"
          "##############################################");
    }
    _prefetchCompleter!.complete();
    doingRrefetch = false;
    _prefetchCompleter = null;
  }

  Future<Result> getFolderInfo(String path,
      {bool folderOnly = false, bool force = false}) async {
    FolderInfo? folder;

    if (force) {
      await clearCache();
    } else {
      //Wait prefetching done
      if (prefetchingFolderPath != null && path == prefetchingFolderPath!) {
        uiRequestNotifier = Completer();
        await uiRequestNotifier!.future;
        uiRequestNotifier = null;
      }

      folder = findObjectFromCache(path, folderOnly: true) as FolderInfo?;
      if (folder == null) {
        final result = orphans.where((f) => f.path == path);
        if (result.isNotEmpty) folder = result.first;
      }
    }
    if (folder == null || force) {
      log.info("Get folder($path) from real repository");
      uiRequest = Completer();
      final ret =
          await getFolderInfoRealOperation(path, folderOnly: folderOnly);
      uiRequest!.complete();
      uiRequest = null;
      if (ret.succeed) {
        folder = ret.value;
      } else {
        log.error("get folder($path) from real repository failed!");
        return ret;
      }

      if (path == "/") {
        cache = folder;
      } else {
        orphans.add(folder!);
      }
    }

    return Succeed(folder);
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

  void removeObjectFromCache(AudioObject obj, {bool destory = false}) {
    var child = obj;
    var parent = child.parent;
    final key = obj.mapKey;
    if (obj is FolderInfo) {
      parent!.subfoldersMap!.remove(key);
    } else if (obj is AudioInfo) {
      parent!.audiosMap!.remove(key);
    }

    while (parent != null) {
      if (parent.allAudioCount != null) {
        final audioCount = obj is FolderInfo ? obj.allAudioCount : 1;
        parent.allAudioCount = parent.allAudioCount! - (audioCount ?? 0);
      }
      if (obj.timestamp != null && parent.timestamp == obj.timestamp) {
        parent.timestamp = DateTime(1970);
        for (var sub in parent.subObjects) {
          if (sub.timestamp != null &&
              sub.timestamp!.compareTo(parent.timestamp!) > 0) {
            parent.timestamp = sub.timestamp!;
          }
        }
      }
      if (parent.bytes != null && obj.bytes != null) {
        parent.bytes = parent.bytes! - obj.bytes!;
      }

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
    obj.updatePath(obj.parent!.repo!, join(obj.parent!.path, obj.mapKey));
    if (obj is AudioInfo) return;

    final folder = obj as FolderInfo;
    for (final o in folder.subObjects) {
      _updatePath(o);
    }
  }

  @protected
  bool addObjectIntoCache(AudioObject obj,
      {FolderInfo? dst, bool onlyStruct = false}) {
    FolderInfo? parent = dst;
    parent ??= obj.parent;
    parent ??=
        findObjectFromCache(dirname(obj.path), folderOnly: true) as FolderInfo?;

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
      audioCount = obj.allAudioCount ?? 0;
    }

    if (onlyStruct) return true;

    //update meta data of parents
    while (parent != null) {
      if (parent.allAudioCount != null) {
        parent.allAudioCount = parent.allAudioCount! + audioCount;
      }
      if (obj.timestamp != null) parent.timestamp = obj.timestamp;
      if (parent.bytes != null && obj.bytes != null) {
        parent.bytes = parent.bytes! + obj.bytes!;
      }
      parent = parent.parent;
    }

    //update path
    _updatePath(obj);

    return true;
  }

  Future<Result> moveObjects(
      List<AudioObject> srcObjList, FolderInfo folder) async {
    Result ret;
    for (final src in srcObjList) {
      final srcRepo = src.repo as Repository;
      final dstRepo = folder.repo as Repository;
      if (srcRepo == dstRepo) {
        ret = await moveObjectsRealOperation(src, folder);
      } else {
        log.debug("Move Object between Repo");
        if (dstRepo.isCloud) {
          final ok = await dstRepo.addToCloud(src);
          if (!ok) {
            final errMsg = "Add Object to ${dstRepo.name} failed!\n"
                "Object:$src";
            showSnackBar(Text(errMsg));
            log.error(errMsg);
            return Fail(ErrMsg(errMsg));
          }
        }
        if (srcRepo.isCloud) {
          final ok = await srcRepo.removeFromCloud(src);
          if (!ok) {
            final errMsg = "Remove Object from ${srcRepo.name} failed!\n"
                "Object:$src";
            showSnackBar(Text(errMsg));
            log.error(errMsg);
            return Fail(ErrMsg(errMsg));
          }
        }
        ret = await moveObjectsRealOperation(src, folder, updateCloud: false);
      }
      if (ret.failed) {
        showSnackBar(Text("Move Object failed!\nsrc:$src, dst:$folder"));
        log.error("Move Object failed! src:$src, dst:$folder");
        return ret;
      }
      removeObjectFromCache(src);
      addObjectIntoCache(src, dst: folder);
    }
    return Succeed();
  }

  Future<Result> newFolder(String path) async {
    final ret = await newFolderRealOperation(path);
    if (ret.failed) {
      log.error("New Folder($path) failed:${ret.error}");
      return ret;
    }
    final folder = ret.value as FolderInfo;
    folder.allAudioCount = 0;
    folder.bytes = 0;
    folder.timestamp = DateTime.now();

    return ret;
  }

  Future<Result> notifyNewAudio(String path) async {
    var ret = await getAudioInfoRealOperation(path);
    if (ret.failed) return ret;
    AudioInfo newAudio = ret.value;
    final addRet = addObjectIntoCache(newAudio);
    if (addRet == false) {
      return Fail(ErrMsg("Add audio info into cache failed!"));
    }

    return ret;
  }

  Future<Result> removeObject(AudioObject obj) async {
    final ret = await removeObjectRealOperation(obj);
    if (ret.succeed) {
      removeObjectFromCache(obj, destory: true);
    } else {
      log.error("Remove object(${obj.path}) failed");
      return ret;
    }
    return Succeed();
  }

  ///Move file/folder in storage
  ///do NOT change cache <br>
  ///Returned Result's value is null
  Future<Result> moveObjectsRealOperation(AudioObject src, FolderInfo dstFolder,
      {bool updateCloud = true});

  ///Create a new folder in storage and add new [FolderInfo] into cache. <br>
  ///Returned Result's value is the new [FolderInfo]
  Future<Result> newFolderRealOperation(String relativePath);

  ///Remove the file/folder from storage recursively <br>
  ///do NOT change cache <br>
  ///Returned Result's value is null
  Future<Result> removeObjectRealOperation(AudioObject obj);

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

enum RepoType {
  filesystem("Local Stroage", Icon(Icons.phone_android)),
  playlist("Playlist", Icon(Icons.playlist_play_outlined), browsable: false),
  trash("Trash", Icon(Icons.delete_outline), browsable: false),
  iCloud("iCloud", Icon(Icons.cloud_outlined)),
  googleDrive("Google Drive", Icon(Icons.cloud_outlined)),
  allStoreage("All Storages", Icon(Icons.storage),
      isTab: false, browsable: false);

  final String title;
  final Icon icon;
  final bool isTab;
  final bool browsable;
  const RepoType(this.title, this.icon,
      {this.isTab = true, this.browsable = true});

  @override
  String toString() => name;

  static RepoType fromString(String string) => RepoType.values.byName(string);
}

enum CloudState {
  isNotCloud,
  init,
  connecting,
  connected,
  error,
}

enum CloudSyncMethod {
  merge,
  syncToRemote,
  syncToLocal;

  @override
  String toString() => name;

  static CloudSyncMethod fromString(String string) =>
      CloudSyncMethod.values.byName(string);
}

enum CloudConflictResolveMethod {
  byUser,
  byTimestamp,
  useLocal,
  useRemote;

  @override
  String toString() => name;

  static CloudConflictResolveMethod fromString(String string) =>
      CloudConflictResolveMethod.values.byName(string);
}

class CloudSyncSetting {
  CloudSyncMethod syncMethod;
  CloudConflictResolveMethod conflictResolveMethod;

  CloudSyncSetting(
      {required this.conflictResolveMethod, required this.syncMethod});

  factory CloudSyncSetting.fromJson(Map<String, dynamic> json) {
    return CloudSyncSetting(
      syncMethod: CloudSyncMethod.fromString(json['syncMethod']!),
      conflictResolveMethod:
          CloudConflictResolveMethod.fromString(json['syncMethod']!),
    );
  }
  Map<String, dynamic> toJson() => {
        'syncMethod': syncMethod.toString(),
        'conflictResolveMethod': conflictResolveMethod.toString(),
      };
}

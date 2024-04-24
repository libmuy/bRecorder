import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

import '../core/logging.dart';
import '../core/result.dart';
import '../core/service_locator.dart';
import '../core/utils/task_queue.dart';
import '../domain/entities.dart';
import 'filesystem_repository.dart';
import 'repository.dart';

const _kRootFolderName = "bRecorder";
const _kFolderMimeType = 'application/vnd.google-apps.folder';
const _kAppTagKey = "appTag";
const _kAppTagValue = "bRecorder";
const _kSingleFileFieldsInternal =
    'id, name, parents, properties, size, modifiedTime, '
    'videoMediaMetadata(durationMillis), mimeType';
const _kSingleFileFields = 'files($_kSingleFileFieldsInternal)';
const _kQueryWithTag = "properties has { "
    "key='$_kAppTagKey' and value='$_kAppTagValue'} and $_kQueryNoTrash";
const _kQueryNoTrash = "trashed = false";
const _kContentType = 'audio/aac';
const _kCommonProperties = {
  _kAppTagKey: _kAppTagValue,
};

// not implemented
bool _existInCloud(AudioObject folder, {String? parentId}) {
  return false;
}

class GoogleDriveRepository extends FilesystemRepository {
  CloudState _state = CloudState.init;
  final _googleSignIn =
      GoogleSignIn.standard(scopes: [gdrive.DriveApi.driveScope]);
  GoogleSignInAccount? _account;
  gdrive.DriveApi? get _driveApi => sl.gDriveApi;
  set _driveApi(newApi) => sl.gDriveApi = newApi;
  String _cloudErrorMessage = "";
  String? _gDriveRootFolderId;
  String? _gDriveMyDriveId;
  final _taskQ = TaskQueue(maxConcurrentTasks: 20);

  GoogleDriveRepository(super.rootPathFuture) {
    log.name = "RepoGDrive";
    log.level = LogLevel.verbose3;
  }

  gdrive.File get _googleDriveRootFolder => gdrive.File(
      id: _gDriveRootFolderId,
      mimeType: _kFolderMimeType,
      name: _kRootFolderName);

  // GoogleDriveRepository() {
  //   _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
  //     _googleAcountNotifier.update(newValue: account, forceNotify: true);
  //     log.info("User account $account");
  //   });
  //   _googleSignIn.signInSilently();
  // }

  @override
  Future<bool> connectCloud({bool background = false}) async {
    _state = CloudState.connecting;
    try {
      if (background) {
        _account = await _googleSignIn.signInSilently();
      } else {
        _account = await _googleSignIn.signIn();
      }
      if (_account == null) return false;
      final authHeaders = await _account!.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders, log);
      _driveApi = gdrive.DriveApi(authenticateClient);
    } catch (e) {
      _account = null;
      _driveApi = null;
      _state = CloudState.error;
      _cloudErrorMessage = e.toString();
      return false;
    }
    _state = CloudState.connected;
    return true;
  }

  @override
  Future<bool> disconnectCloud() async {
    _account = null;
    _driveApi = null;
    await _googleSignIn.signOut();
    _state = CloudState.init;
    return true;
  }

  String? get account {
    if (_account == null) return null;
    return _account!.email;
  }

  @override
  String get cloudErrMessage => _cloudErrorMessage;

  @override
  final type = RepoType.googleDrive;

  @override
  CloudState get cloudState => _state;

  @override
  Future<bool> removeFromCloud(AudioObject obj) async => _removeFile(obj);
  @override
  // not implemented
  Future<bool> addToCloud(AudioObject obj) async {
    if (obj.isFolder) {}
    return true;
  }

  bool _existInFs(AudioObject obj) {
    if (obj.cloudData == null) return true;
    if (obj.cloudData!.state == CloudFileState.downloading) return false;
    return true;
  }

  @override
  Future<bool> fetchFolderInfoFs(FolderInfo request,
      {bool folderOnly = false, bool prefetch = false}) async {
    final ok = await super
        .fetchFolderInfoFs(request, folderOnly: folderOnly, prefetch: prefetch);
    if (!ok) return false;

    request.cloudData ??= CloudFileData(existInFs: true);
    for (var obj in request.subObjects) {
      obj.cloudData ??= CloudFileData(existInFs: true);
    }
    //this is more time consuming than fetch all items with property once
    // _taskQ.add(Task((_) async => await request.updateCloudData()));

    return true;
  }

  @override
  Future<Result> moveObjectsRealOperation(AudioObject src, FolderInfo dstFolder,
      {bool updateCloud = true}) async {
    final ret = await super.moveObjectsRealOperation(src, dstFolder);
    if (ret.failed || updateCloud == false) return ret;

    //Update Cloud: move cloud object
    assert(src.repo == this && src.repo == dstFolder.repo);
    try {
      final request = gdrive.File(parents: [dstFolder.cloudData!.id!]);
      await _driveApi!.files
          .update(request, src.cloudData!.id!, $fields: _kSingleFileFields);
    } catch (e) {
      return Fail(ErrMsg("Move Google Drive object failed!"
          " src:$src, dst:$dstFolder"));
    }

    return const Succeed();
  }

  @override
  Future<Result> newFolderRealOperation(String relativePath,
      {bool updateCloud = true}) async {
    final ret = await super.newFolderRealOperation(relativePath);
    if (ret.failed || updateCloud == false) return ret;

    FolderInfo folder = ret.value;
    final newFolder = await _createDirectory(folder);
    return ret;
  }

  @override
  Future<Result> removeObjectRealOperation(AudioObject obj,
      {bool updateCloud = true}) async {
    final ret = await super.removeObjectRealOperation(obj);
    if (ret.failed || updateCloud == false) return ret;

    final ok = await _removeFile(obj);
    if (!ok) {
      return Fail(ErrMsg("Create Google Drive folder failed"
          ": ${obj.path}"));
    }

    return ret;
  }

  @override
  Future<Result> notifyNewAudio(String path) async {
    var ret = await super.notifyNewAudio(path);
    if (ret.failed) return ret;

    final audio = ret.value as AudioInfo;
    final meta = await _getMetaData(audio);
    //Not exist in cloud, upload
    if (meta == null) {
      log.info("Audio($path) not exists in cloud, upload it");
      audio.cloudData = CloudFileData(existInCloud: false, existInFs: true);
      _uploadFile(audio);
    } else {
      log.info("Audio($path) already exists? not expected");
      audio.cloudData = CloudFileData(id: meta.id);
    }

    return ret;
  }

  Future<gdrive.File?> _getMetaDataFromId(String id) async {
    try {
      final file = await _driveApi!.files.get(id) as gdrive.File;
      return file;
    } catch (e) {
      log.error("Download Google Drive file(id:$id) failed, $e");
    }
    return null;
  }

  Future<gdrive.File?> _getMetaDataFromName(
      String parentId, String name) async {
    var query = "'$parentId' in parents and name = '$name' and $_kQueryNoTrash";
    try {
      final queryResult = await _driveApi!.files.list(
          q: query,
          $fields: 'nextPageToken, $_kSingleFileFields',
          spaces: 'drive');
      final files = queryResult.files;
      if (files == null || files.isEmpty) return null;
      return files.first;
    } catch (e) {
      log.error("Can not retrive files from Google Drive"
          ", query:$query, error: $e");
      return null;
    }
  }

  Future<gdrive.File?> _getMetaData(AudioObject audio) async {
    final cloudData = audio.cloudData;
    if (cloudData != null) return _getMetaDataFromId(cloudData.id!);
    final parent = audio.parent;
    assert(parent != null && parent.cloudData != null);
    return _getMetaDataFromName(parent!.cloudData!.id!, audio.name);
  }

  Future<bool> _updateCloudState(FolderInfo folder) async {
    int audioCount = 0;
    int bytes = 0;
    DateTime timestamp = DateTime(1970);
    bool syncing = false;
    bool downloading = false;
    bool uploading = false;
    bool conflict = false;

    void setFlags(CloudFileState state) {
      switch (state) {
        case CloudFileState.init:
          log.error("############# this should not happen ########");
          break;
        case CloudFileState.synced:
          break;
        case CloudFileState.downloading:
          downloading = true;
          break;
        case CloudFileState.uploading:
          uploading = true;
          break;
        case CloudFileState.syncing:
          syncing = true;
          break;
        case CloudFileState.conflict:
          conflict = true;
          break;
      }
    }

    log.debug("Get statics: ${folder.path}");
    for (final sub in folder.subObjects) {
      if (sub is FolderInfo) {
        await _updateCloudState(sub);
        audioCount += sub.allAudioCount!;
      } else if (sub is AudioInfo) {
        //UI requested audios have no detail info, gather info here
        if (sub.bytes == null) {
          final result = await getAudioInfoFromRepo(sub, prefetch: true);
          if (!result) {
            log.error("Get AudioInfo from repo failed: ${sub.path}");
            return false;
          }
        }
        audioCount++;
      }
      bytes += sub.bytes!;
      if (sub.timestamp!.compareTo(timestamp) > 1) timestamp = sub.timestamp!;

      setFlags(sub.cloudData!.state);
    }
    folder.allAudioCount = audioCount;
    folder.bytes = bytes;
    folder.timestamp = timestamp;
    // if (conflict) {
    //   folder.cloudData!.state = CloudFileState.conflict;
    // } else if (downloading && !uploading && !syncing) {
    //   folder.cloudData!.state = CloudFileState.downloading;
    // } else if (!downloading && uploading && !syncing) {
    //   folder.cloudData!.state = CloudFileState.uploading;
    // } else if (downloading || uploading || syncing) {
    //   folder.cloudData!.state = CloudFileState.syncing;
    // } else if (!downloading && !uploading && !syncing) {
    //   folder.cloudData!.state = CloudFileState.synced;
    // }
    folder.updateUI();
    return true;
  }

  @override
  Future<bool> preFetchInternal() async {
    bool networkUpdate;
    final fsPrefetchResult = super.preFetchInternal();

    // log.debug("============== Prefetch: Add Cloud Data to cache");
    // //Add Cloud Data
    // for (var obj in cache!.subObjects) {
    //   obj.cloudData = CloudFileData(CloudFileState.uploading);
    // }

    do {
      log.debug("============== Prefetch: Get Google Drive Files with tag");
      networkUpdate = await _updateFromCloudWithAppTag(fsPrefetchResult);
      if (!doingPrefetch) return false;
      await waitUiReqWhilePrefetch();
      if (!networkUpdate) {
        log.error("Get File info from Google Drive (with tag) failed"
            ", retry in 10 seconds");
        await Future.delayed(const Duration(seconds: 10));
      }
    } while (!networkUpdate);

    do {
      log.debug("============== Prefetch: Get Google Drive Files without tag");
      networkUpdate = await _updateFromCloudWithoutAppTag();
      if (!doingPrefetch) return false;
      await waitUiReqWhilePrefetch();
      if (!networkUpdate) {
        log.error("Get File info from Google Drive (without tag) failed"
            ", retry in 10 seconds");
        await Future.delayed(const Duration(seconds: 10));
      }
    } while (!networkUpdate);

    do {
      log.debug("============== Prefetch: Sync");
      networkUpdate = await _syncAudioObject(cache!);
      if (!doingPrefetch) return false;
      await waitUiReqWhilePrefetch();
      if (!networkUpdate) {
        log.error("Sync with Google Drive failed"
            ", retry in 10 seconds");
        await Future.delayed(const Duration(seconds: 10));
      }
    } while (!networkUpdate);

    log.debug("============== Prefetch: Update Cloud state");
    await _updateCloudState(cache!);

    log.debug("============== Prefetch: End");
    return true;
  }

  Future<List<gdrive.File>?> _getSubsFromCloud(String folderId,
      {bool withoutProperty = true}) async {
    String? nextToken;
    List<gdrive.File> ret = [];
    List<gdrive.File>? files;
    gdrive.FileList queryResult;
    var query = "'$folderId' in parents and $_kQueryNoTrash";
    if (withoutProperty) query += " and not $_kQueryWithTag";
    try {
      //Get All files with app tag
      do {
        queryResult = await _driveApi!.files.list(
            q: query,
            $fields: 'nextPageToken, $_kSingleFileFields',
            spaces: 'drive');
        files = queryResult.files;
        nextToken = queryResult.nextPageToken;
        if (files == null || files.isEmpty) break;
        for (var f in files) {
          ret.add(await _makeSureHasProperty(f));
        }
      } while (nextToken != null);
    } catch (e) {
      log.error("Can not retrive files from Google Drive"
          ", query:$query, error: $e");
      return null;
    }

    return ret;
  }

  Future<bool> _addCloudFileToCache(String path, gdrive.File file,
      {Map<String, List<gdrive.File>>? filesByParent}) async {
    final id = file.id!;
    final name = file.name!;
    FolderInfo? parent;
    log.debug("Add cloud file($path) to cache");

    if (path == "/") {
      parent = null;
    } else {
      final dirPath = dirname(path);
      parent = findObjectFromCache(dirPath) as FolderInfo?;
      if (parent == null) {
        log.error("Not found parent dir:$dirPath");
        return false;
      }
    }

    if (file.isDirectory) {
      FolderInfo thisFolder;
      if (parent == null) {
        thisFolder = cache!;
      } else {
        if (parent.hasSubfolder(name)) {
          //Add Folder if not exists
          thisFolder = parent.subfoldersMap![name]!;
        } else {
          //Create folder and add folder into cache
          final ret = await newFolderRealOperation(path, updateCloud: false);
          if (!doingPrefetch) return false;
          await waitUiReqWhilePrefetch();
          if (ret.failed) return false;

          thisFolder = ret.value;
        }
      }
      thisFolder.cloudData = CloudFileData(id:id);

      List<gdrive.File>? subs;
      //Get subs from cache
      if (filesByParent != null && filesByParent.containsKey(id)) {
        subs = filesByParent[id]!;
        //Get subs from Cloud
      } else {
        subs = await _getSubsFromCloud(id);
        if (!doingPrefetch) return false;
        await waitUiReqWhilePrefetch();
      }
      if (subs != null) {
        for (final sub in subs) {
          final ret = await _addCloudFileToCache(join(path, sub.name!), sub,
              filesByParent: filesByParent);
          if (!doingPrefetch) return false;
          await waitUiReqWhilePrefetch();
          if (ret == false) return false;
        }
      }
    } else {
      AudioInfo thisFile;
      // if (parent!.hasAudio(name)) {
      //   thisFile = parent.audiosMap![name]!;
      //   if (thisFile.bytes == int.parse(file.size!)) {
      //     thisFile.cloudData = CloudFileData(id:id, state: CloudFileState.synced);
      //   } else {
      //     thisFile.cloudData =
      //         CloudFileData(id, state: CloudFileState.conflict);
      //   }
      // } else {
      //   thisFile = AudioInfo(path,
      //       bytes: int.parse(file.size!),
      //       timestamp: file.modifiedTime!,
      //       repo: this);
      //   thisFile.cloudData =
      //       CloudFileData(id, state: CloudFileState.downloading);
      //   addObjectIntoCache(thisFile, dst: parent, onlyStruct: true);
      // }
    }

    return true;
  }

/*=======================================================================*\ 
  Sync Worker
\*=======================================================================*/
  ///Sync a [AudioObject] with Cloud using following identify local and cloud
  /// - local data: `obj.path`
  /// - cloud data: `obj.cloudData.id`
  ///
  /// Parameters:
  ///
  /// [obj] - the [AudioObject] will be sync
  ///
  /// [parentId] - `obj`'s parent id in Cloud side.
  /// Get the parent id from `obj.parent?.cloudData?.id` if omitted.
  ///
  /// [syncSetting] - the sync behavior. get it from global settings if omitted.
  Future<bool> _syncAudioObject(AudioObject obj,
      {String? parentId, CloudSyncSetting? syncSetting}) async {
    final setting = syncSetting ?? (await sl.settings).cloudSyncSetting;
    var parent = parentId ?? obj.parent?.cloudData?.id;
    parent ??= _gDriveRootFolderId;
    final existInCloud = _existInCloud(obj, parentId: parent);
    final existInFs = _existInFs(obj);
    if (obj.isAudio) {
      switch (setting!.syncMethod) {
        case CloudSyncMethod.merge:
          break;
        case CloudSyncMethod.syncToRemote:
          // TODO: Handle this case.
          break;
        case CloudSyncMethod.syncToLocal:
          // TODO: Handle this case.
          break;
      }
    } else if (obj.isFolder) {
    //Not exist in cloud, create it
    if (obj.cloudData == null) {
      final gFolder = await _createDirectory(obj as FolderInfo);
    }

    for (final sub in (obj as FolderInfo).subObjects) {
      if (sub is FolderInfo) {
        final ok = await _syncAudioObject(sub);
        if (!ok) return false;
      } else if (sub is AudioInfo) {
        //Not exist in cloud, upload it
        if (sub.cloudData == null) {
          final ok = await _uploadFile(sub);
          if (!ok) return false;
        } else {
          if (sub.cloudData!.state == CloudFileState.downloading) {
            final ok = await _downloadFile(sub);
            if (!ok) return false;
          }
        }
      }
    }

    }
    return true;
  }

  Future<gdrive.File> _makeSureHasProperty(gdrive.File file) async {
    final properties = file.properties;
    if (properties != null &&
        properties.containsKey(_kAppTagKey) &&
        properties[_kAppTagKey] == _kAppTagValue) return file;

    log.debug("Folder(${file.name}) has no tag, add tag");
    final request = gdrive.File(properties: {_kAppTagKey: _kAppTagValue});
    return _driveApi!.files
        .update(request, file.id!, $fields: _kSingleFileFields);
  }

  Future<gdrive.File?> _getRootFolder() async {
    gdrive.File? rootFolder;
    final file =
        await _driveApi!.files.get("root", $fields: "id") as gdrive.File;
    log.verbose("Got 'My Drive' folder id:${file.id}");
    final queryRootFolder = "name = '$_kRootFolderName'"
        " and mimeType = '$_kFolderMimeType' and $_kQueryNoTrash"
        " and '${file.id}' in parents";

    //Get Root Folder with tag
    var queryResult = await _driveApi!.files.list(
        q: "$queryRootFolder and $_kQueryWithTag",
        $fields: _kSingleFileFields,
        spaces: 'drive');
    if (!doingPrefetch) return null;
    await waitUiReqWhilePrefetch();
    var files = queryResult.files;

    //No 'bRecorder' folder exists, search without tag
    if (files == null || files.isEmpty) {
      log.verbose("Get root folder with tag failed, retry get it without tag");
      queryResult = await _driveApi!.files.list(
          q: queryRootFolder, $fields: _kSingleFileFields, spaces: 'drive');
      if (!doingPrefetch) return null;
      await waitUiReqWhilePrefetch();
      files = queryResult.files;
    } else {
      log.verbose("Get root folder with tag OK!");
    }

    //No 'bRecorder' folder exists, create it
    if (files == null || files.isEmpty) {
      log.verbose("Root folder not exists, create it");
      // rootFolder = await _createDirectory(cache!);
    } else {
      rootFolder = files.first;
      log.info("[Google Drive] Got root folder, id:${rootFolder.id}");
    }

    if (rootFolder == null) return null;

    //Got the 'bRecorder' Folder without app tag
    rootFolder = await _makeSureHasProperty(rootFolder);
    _gDriveRootFolderId = rootFolder.id!;
    return rootFolder;
  }

  Future<bool> _updateFromCloudWithAppTag(Future<bool> fsPrefetchResult) async {
    if (_account == null) return false;
    Map<String, List<gdrive.File>> filesByParent = {};
    String? nextToken;
    gdrive.File? rootFolder;

    const fields = 'nextPageToken, $_kSingleFileFields';
    List<gdrive.File>? files;
    gdrive.FileList queryResult;
    try {
      //Get root folder
      rootFolder = await _getRootFolder();
      if (rootFolder == null) return false;
      if (!doingPrefetch) return false;
      await waitUiReqWhilePrefetch();

      //Get All files with app tag
      do {
        queryResult = await _driveApi!.files
            .list(q: _kQueryWithTag, $fields: fields, spaces: 'drive');
        if (!doingPrefetch) return false;
        await waitUiReqWhilePrefetch();
        files = queryResult.files;
        nextToken = queryResult.nextPageToken;
        if (files == null || files.isEmpty) break;

        for (final f in files) {
          log.debug("got file with tag:${f.name}");
          final parentId = f.parents!.first;
          if (filesByParent.containsKey(parentId)) {
            filesByParent[parentId]!.add(f);
          } else {
            filesByParent[parentId] = [f];
          }
        }
      } while (nextToken != null);
    } catch (e) {
      log.error("Can not retrive files from Google Drive: $e");
      return false;
    }

    //Wait filesystem prefetch done
    final ok = await fsPrefetchResult;
    if (!ok) return false;

    return await _addCloudFileToCache("/", rootFolder,
        filesByParent: filesByParent);
  }

  Future<bool> _updateFromCloudWithoutAppTag() async {
    return await _addCloudFileToCache("/", _googleDriveRootFolder);
  }

  ///Delete Google Drive File/Folder recursively
  Future<bool> _removeFile(AudioObject file) async {
    log.debug("[Google Drive] Remove:${file.path}");
    try {
      await _driveApi!.files.delete(file.cloudData!.id!);
    } catch (e) {
      log.error("Delete Google Drive file(${file.path}) failed, $e");
      return false;
    }
    log.debug("Delete Google Drive file(${file.path}) OK");
    return true;
  }

  ///Create a
  Future<Result> _createDirectory(FolderInfo folder, {String? parentId}) async {
    log.debug("[Google Drive] Create Folder:${folder.path}");
    final exist = _existInCloud(folder, parentId: parentId);
    if (exist) {
      log.error("Already exist: $folder");
      return const Fail(AlreadExists());
    }

    final parent = parentId ?? folder.parent?.cloudData?.id;
    var file =
        gdrive.File(properties: _kCommonProperties, mimeType: _kFolderMimeType);
    if (parent == null) {
      //Root folder
      file.name = _kRootFolderName;
    } else {
      //Normal folder
      file.name = folder.name;
      file.parents = [
        folder.parent!.cloudData!.id!,
      ];
    }

    try {
      file = await _driveApi!.files
          .create(file, $fields: _kSingleFileFieldsInternal);
      folder.cloudData = CloudFileData(id: file.id);
    } catch (e) {
      final errMsg = "Create Google Drive folder failed, $e";
      log.error(errMsg);
      return Fail(ErrMsg(errMsg));
    }
    log.debug("Create Google Drive folder OK");
    return Succeed(file);
  }

  Future<bool> _uploadFile(AudioInfo audio, {bool overwrite = false}) async {
    log.debug("[Google Drive] Upload:${audio.path}");
    var media = gdrive.Media((await audio.file).openRead(), audio.bytes,
        contentType: _kContentType);
    var driveFile = gdrive.File(
        properties: _kCommonProperties,
        parents: [audio.parent!.cloudData!.id!],
        name: audio.name);

    try {
      gdrive.File result;
      //Overwrite upload
      if (audio.cloudData != null) {
        if (overwrite) {
          result = await _driveApi!.files
              .update(driveFile, audio.cloudData!.id!, uploadMedia: media);
        } else {
          log.error("Upload error: File Already exists."
              " use [overwrite] argument to overwrite");
          return false;
        }
        driveFile.id = audio.cloudData!.id;
      } else {
        result = await _driveApi!.files.create(driveFile, uploadMedia: media);
      }
      // audio.cloudData = CloudFileData(result.id, state: CloudFileState.synced);
      audio.updateUI();
      log.info("Upload audio to Google Drive OK: ${audio.path}");
    } catch (e) {
      log.error("Upload Google Drive file(${audio.path}) failed, $e");
      return false;
    }
    return true;
  }

  Future<bool> _downloadFile(AudioInfo audio, {bool overwrite = false}) async {
    log.debug("[Google Drive] Download:${audio.path}");
    try {
      if ((await audio.file).existsSync()) {
        if (!overwrite) {
          log.error("Download error: File Already exists."
              " use [overwrite] argument to overwrite");
          return false;
        }
      }
      final media = await _driveApi!.files.get(audio.cloudData!.id!,
          downloadOptions: gdrive.DownloadOptions.fullMedia) as gdrive.Media;
      final result = (await audio.file).openWrite().addStream(media.stream);
      log.info("Download file startted");
      result.then((_) async {
        final updateResult = await getAudioInfoFromRepo(audio);
        if (!updateResult) return false;
        // audio.cloudData!.state = CloudFileState.synced;
        audio.updateUI();
        log.info("Download from Google Drive DONE: ${audio.path}");
      }, onError: (e) {
        log.info("Download from Google Drive ERROR: ${audio.path} \n$e");
      });
    } catch (e) {
      log.error("Download Google Drive file(${audio.path}) failed, $e");
      return false;
    }
    return true;
  }

  void debugDumpCache() {
    cache!.dump();
  }

  void debugGetAllFiles() async {
    if (_account == null) return;

    log.debug("retriving file list");
    _driveApi!.files
        .list(
            q: "name = '$_kRootFolderName' and type",
            $fields: 'nextPageToken, files(id, name, parents)',
            spaces: 'drive')
        .then((list) {
      log.debug("got file list");
      list.files?.forEach((file) {
        // _driveApi!.files
        //     .get(file.id!, $fields: 'id, name, parents')
        //     .then((value) {
        //   final file = value as drive.File;
        //   log.debug("parent:${file.parents}");
        // });

        log.debug("ID:${file.id}, "
            "name:${file.name}, "
            "parents:${file.parents}, "
            "size:${file.size}");
      });
    });
  }
}

// final authHeaders = await account!.authHeaders;
// final authenticateClient = GoogleAuthClient(authHeaders);
// final driveApi = drive.DriveApi(authenticateClient);
// final Stream<List<int>> mediaStream =
//     Future.value([104, 105]).asStream().asBroadcastStream();
// var media = drive.Media(mediaStream, 2);
// var driveFile = drive.File();
// driveFile.name = "hello_world.txt";
// final result =
//     await driveApi.files.create(driveFile, uploadMedia: media);
// log.info("Upload result: $result");

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  Logger log;

  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers, this.log);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final ret = await _client.send(request..headers.addAll(_headers));
    // log.debug("Sent url: ${request.url}, bytes: ${request.contentLength} ");
    return ret;
  }
}

extension GoogleDriveRepoExt on gdrive.File {
  bool get isDirectory => mimeType == "application/vnd.google-apps.folder";
}

extension AudioObjectExt on AudioObject {
  Future<bool> existInFs({String? parentId}) async {
    if (cloudData != null && cloudData!.existInFs != null) {
      return cloudData!.existInCloud!;
    }

    final type = await FileSystemEntity.type(path);
    final file =
        type == FileSystemEntityType.file ? File(path) : Directory(path);
    cloudData!.existInFs = await file.exists();
    return cloudData!.existInCloud!;
  }

  Future<bool> existInCloud({String? parentId}) async {
    if (cloudData != null && cloudData!.existInCloud != null) {
      return cloudData!.existInCloud!;
    }

    final ok = await updateCloudData(parentId: parentId);
    if (!ok) return false;

    return cloudData!.existInCloud!;
  }

  Future<bool> updateCloudData({String? parentId}) async {
    //already updated
    if (cloudData != null) {
      if (cloudData!.existInCloud != null) return true;
      if (cloudData!.updating != null) return cloudData!.updating!.future;
    }
    cloudData ??= CloudFileData();
    cloudData!.updating = Completer();

    var parentCloudId = parentId ?? parent?.cloudData?.id;
    assert(parentCloudId != null);
    var query = "'$parentCloudId' in parents and "
        "name = '$name' and $_kQueryNoTrash";
    try {
      final queryResult = await sl.gDriveApi!.files
          .list(q: query, $fields: _kSingleFileFields, spaces: 'drive');
      final files = queryResult.files;

      if (files == null || files.isEmpty) {
        cloudData!.existInCloud = false;
      } else {
        final file = files.first;
        cloudData!.existInCloud = true;
        cloudData!.id = file.id;
        cloudData!.size = int.parse(file.size!);
      }

      //Dont know filesystem info, set size by cloud side
      if (cloudData!.existInFs == null) {}
      cloudData!.updating!.complete(true);
      cloudData!.updating = null;
      return true;
    } catch (e) {
      log.error("Can not retrive files from Google Drive"
          ", query:$query, error: $e");
      cloudData!.updating!.complete(false);
      cloudData!.updating = null;
      return false;
    }
  }
}

class CloudFileData {
  String? id;
  int? size;
  Completer<bool>? updating;
  CloudFileState get state {
    if (existInCloud == null || existInFs == null) return CloudFileState.init;
    assert(existInCloud! || !existInFs!);
    if (existInCloud! && !existInFs!) return CloudFileState.downloading;
    if (!existInCloud! && existInFs!) return CloudFileState.uploading;
    if (synced) return CloudFileState.synced;
    return CloudFileState.conflict;
  }

  bool? existInCloud;
  bool? existInFs;
  bool synced = false;

  CloudFileData({this.id, this.existInFs, this.existInCloud, this.size});
}

enum CloudFileState {
  init,
  downloading,
  uploading,
  syncing, // uploading or downloading
  synced,
  conflict,
}

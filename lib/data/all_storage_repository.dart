// ignore_for_file: unused_element

import 'package:path/path.dart';

import '../core/result.dart';
import '../core/service_locator.dart';
import '../domain/entities.dart';
import 'repository.dart';
import '../core/logging.dart';

final _log = Logger('RepoAll', level: LogLevel.debug);

class AllStorageRepository extends Repository {
  List<Repository>? _repoList;
  Map<String, Repository>? _nameToRepo;


  @override
  final type = RepoType.allStoreage;

  List<Repository> get repoList {
    if (_repoList != null) {
      return _repoList!;
    }

    _repoList = RepoType.values
        .map((e) => sl.getRepository(e))
        .toList()
        .where((e) => e.browsable)
        .toList();

    return _repoList!;
  }

  Repository? nameToRepo(String name) {
    _nameToRepo ??=
        repoList.asMap().map((key, repo) => MapEntry(repo.name, repo));
    if (_nameToRepo!.containsKey(name)) {
      return _nameToRepo![name]!;
    }

    return null;
  }

  void _addRepoNameToPath(String prefix, FolderInfo folder) {
    _log.debug("change path to:${folder.path}");
    folder.path = "/$prefix${folder.path}";

    folder.subfolders?.forEach((f) {
      _addRepoNameToPath(prefix, f);
    });

    folder.audios?.forEach((f) {
      f.path = "/$prefix${f.path}";
    });
  }

  Result parseRepoPath(String path) {
    final pathList = split(path);
    final repo = nameToRepo(pathList[1]);
    if (repo == null) return Fail(ErrMsg("Path($path) not exists"));
    // remove repo name
    var pathList2 = List<String>.from(pathList);
    pathList2.removeAt(1);
    final path2 = joinAll(pathList2);
    _log.debug("reomve repo name from path:$path");

    return Succeed(RepoPath(repo, path2));
  }

  @override
  Future<Result> getFolderInfoRealOperation(String relativePath,
      {bool folderOnly = false}) async {
    if (relativePath == "/") {
      var root = FolderInfo("/");
      _log.debug("get root folder info");
      var folders = await Future.wait(repoList.map((repo) async {
        final ret = await repo.getFolderInfo("/", folderOnly: folderOnly);
        if (ret.succeed) {
          final folder = ret.value as FolderInfo;
          final newFolder = folder.copyWith(parent: root, repo: this);
          _addRepoNameToPath(repo.name, newFolder);
          return newFolder;
        }
        return FolderInfo.empty;
      }).toList());

      root.subfoldersMap =
          Map.fromIterables(repoList.map((e) => e.name), folders);

      return Succeed(root);
    }

    final pathRet = parseRepoPath(relativePath);
    if (pathRet.failed) {
      return pathRet;
    }

    final repo = pathRet.value.repo;
    final repoPath = pathRet.value.audioPath;
    final ret = await repo.getFolderInfo(repoPath, folderOnly: folderOnly);
    if (ret.failed) return Fail(ErrMsg("Get Folder($relativePath) failed!"));

    _addRepoNameToPath(repo, ret.value);

    return ret;
  }

  @override
  Future<String> get rootPath async {
    return "";
  }

  @override
  Future<Result> moveObjectsRealOperation(AudioObject src, FolderInfo dstFolder,
      {bool updateCloud = true}) async {
    return const Fail(IOFailure());
  }

  @override
  Future<Result> removeObjectRealOperation(AudioObject obj) async {
    return const Fail(IOFailure());
  }

  @override
  Future<Result> newFolderRealOperation(String relativePath) async {
    final pathRet = parseRepoPath(relativePath);
    if (pathRet.failed) {
      return pathRet;
    }

    final repo = pathRet.value.repo;
    final repoPath = pathRet.value.audioPath;
    final ret = await repo.newFolder(repoPath);
    if (ret.failed) return Fail(ErrMsg("New Folder($relativePath) failed!"));

    return const Succeed();
  }

  @override
  Future<Result> getAudioInfoRealOperation(String relativePath) async {
    return const Fail(IOFailure());
  }
}

class RepoPath {
  Repository repo;
  String path;

  RepoPath(this.repo, this.path);
}

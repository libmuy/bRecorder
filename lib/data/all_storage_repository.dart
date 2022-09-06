import 'package:brecorder/core/result.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../core/logging.dart';
import '../core/service_locator.dart';
import '../domain/abstract_repository.dart';
import '../domain/entities.dart';
import 'repository_type.dart';

final log = Logger('FolderSelector');

class AllStorageRepository extends Repository {
  List<Repository>? _repoList;
  Map<String, Repository>? _nameToRepo;

  @override
  final String name = "All Storages";

  @override
  final Icon icon = const Icon(Icons.storage);

  @override
  final realStorage = false;

  List<Repository> get repoList {
    if (_repoList != null) {
      return _repoList!;
    }

    _repoList = RepoType.values
        .map((e) => sl.getRepository(e))
        .toList()
        .where((e) => e.realStorage)
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

  void _addRepoNameToPath(Repository repo, FolderInfo folder) {
    log.debug("change path to:${folder.path}");
    folder.path = "/${repo.name}${folder.path}";
    for (final f in folder.subfolders) {
      _addRepoNameToPath(repo, f);
    }
    for (final f in folder.audios) {
      f.path = "/${repo.name}${f.path}";
    }
  }

  Result parseRepoPath(String path) {
    final pathList = split(path);
    final repo = nameToRepo(pathList[1]);
    if (repo == null) return Fail(ErrMsg("Path($path) not exists"));
    // remove repo name
    var pathList2 = List<String>.from(pathList);
    pathList2.removeAt(1);
    final path2 = joinAll(pathList2);
    log.debug("reomve repo name from path:$path");

    return Succeed(RepoPath(repo, path2));
  }

  @override
  Future<Result> getFolderInfo(String path, {bool folderOnly = false}) async {
    if (path == "/") {
      log.debug("get root folder info");
      var folders = await Future.wait(repoList.map((repo) async {
        final ret = await repo.getFolderInfo("/", folderOnly: folderOnly);
        if (ret.succeed) {
          _addRepoNameToPath(repo, ret.value);
          return ret.value as FolderInfo;
        }
        return FolderInfo("/", 0, DateTime(1970), [], [], 0);
      }).toList());
      final value = FolderInfo("/", 0, DateTime(1970), folders, [], 0);
      return Succeed(value);
    }

    final pathRet = parseRepoPath(path);
    if (pathRet.failed) {
      return pathRet;
    }

    final repo = pathRet.value.repo;
    final repoPath = pathRet.value.path;
    final ret = await repo.getFolderInfo(repoPath, folderOnly: folderOnly);
    if (ret.failed) return Fail(ErrMsg("Get Folder($path) failed!"));

    _addRepoNameToPath(repo, ret.value);

    return ret;
  }

  @override
  Future<String> get rootPath async {
    return "";
  }

  @override
  Future<Result> moveObjects(List<String> srcPath, String dstPath) async {
    return Fail(IOFailure());
  }

  @override
  Future<Result> newFolder(String path) async {
    final pathRet = parseRepoPath(path);
    if (pathRet.failed) {
      return pathRet;
    }

    final repo = pathRet.value.repo;
    final repoPath = pathRet.value.path;
    final ret = await repo.newFolder(repoPath);
    if (ret.failed) return Fail(ErrMsg("New Folder($path) failed!"));

    return Succeed();
  }

  @override
  Future<Result> removeObject(AudioObject object) async {
    return Fail(IOFailure());
  }
}

class RepoPath {
  Repository repo;
  String path;

  RepoPath(this.repo, this.path);
}

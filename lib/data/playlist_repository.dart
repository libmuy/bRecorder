import 'package:brecorder/core/result.dart';
import 'package:flutter/material.dart';

import '../domain/entities.dart';
import 'abstract_repository.dart';

class PlaylistRepository extends Repository {
  @override
  Future<Result> getFolderInfoRealOperation(String relativePath,
      {bool folderOnly = false}) async {
    return Succeed(FolderInfo(relativePath, 0, DateTime(1907), 0));
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
  Future<Result> moveObjectsRealOperation(
      String srcRelativePath, String dstRelativePath) async {
    return Fail(IOFailure());
  }

  @override
  Future<Result> newFolderRealOperation(String relativePath) async {
    return Fail(IOFailure());
  }

  @override
  Future<Result> removeObjectRealOperation(String relativePath) async {
    return Fail(IOFailure());
  }

  @override
  Future<Result> getAudioInfoRealOperation(String relativePath) async {
    return Fail(IOFailure());
  }
}

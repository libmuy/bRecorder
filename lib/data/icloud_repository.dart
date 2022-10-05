import 'package:flutter/material.dart';

import '../core/result.dart';
import '../domain/entities.dart';
import 'repository.dart';

class ICloudRepository extends Repository {
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
  final String name = "iCloud";
  @override
  final Icon icon = const Icon(Icons.cloud_outlined);
  @override
  final realStorage = true;

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

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../core/result.dart';
import '../domain/entities.dart';
import 'repository.dart';

class GoogleDriveRepository extends Repository {
  final _googleSignIn =
      GoogleSignIn.standard(scopes: [drive.DriveApi.driveScope]);

  GoogleSignInAccount? _account;

  // GoogleDriveRepository() {
  //   _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
  //     _googleAcountNotifier.update(newValue: account, forceNotify: true);
  //     log.info("User account $account");
  //   });
  //   _googleSignIn.signInSilently();
  // }

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
  bool get enabled => _account != null;

  @override
  Future<bool> setEnabled(bool value) async {
    if (value) {
      _account = await _googleSignIn.signIn();
    } else {
      await _googleSignIn.signOut();
      _account = null;
    }
    return enabled;
  }

  String? get account {
    if (_account == null) return null;
    return _account!.email;
  }

  @override
  final type = RepoType.googleDrive;

  @override
  final isCloud = true;

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

  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

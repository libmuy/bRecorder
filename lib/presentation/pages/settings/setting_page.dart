import 'package:brecorder/core/utils/notifiers.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;

import '../../../core/logging.dart';
import '../../../core/service_locator.dart';

final log = Logger('SettingPage', level: LogLevel.debug);

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late final _googleSignIn = sl.get<GoogleSignIn>();
  final _googleAcountNotifier =
      ForcibleValueNotifier<GoogleSignInAccount?>(null);

  @override
  void initState() {
    super.initState();

    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _googleAcountNotifier.update(newValue: account, forceNotify: true);
      log.info("User account $account");
    });
    _googleSignIn.signInSilently();
  }

  Widget _buildGoogleAcountWidget() {
    Widget signedInWidget() {
      return Row(
        children: [
          Expanded(
            child: Text(
              _googleAcountNotifier.value!.email,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ElevatedButton(
              onPressed: () {
                _googleSignIn.signOut();
                // _googleSignIn.disconnect();
                // _googleAcountNotifier.update(newValue: null, forceNotify: true);
              },
              child: const Text("Sign Out"))
        ],
      );
    }

    Widget notSignedInWidget() {
      return Center(
        child: ElevatedButton(
            onPressed: () {
              try {
                _googleSignIn.signIn();
              } catch (e) {
                log.error("signin google failed:$e");
              }
            },
            child: const Text("Sign In")),
      );
    }

    return ValueListenableBuilder(
        valueListenable: _googleAcountNotifier,
        builder: (context, value, _) {
          late Widget internalWidget;
          if (value == null) {
            internalWidget = notSignedInWidget();
          } else {
            internalWidget = signedInWidget();
          }

          return Padding(
            padding: const EdgeInsets.only(left: 10.0, right: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Google Drive:"),
                const SizedBox(
                  width: 10,
                ),
                Expanded(child: internalWidget)
              ],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Column(children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 40.0, bottom: 20.0),
          child: Text("Cloud Setting"),
        ),
        const Divider(
          height: 1,
        ),
        _buildGoogleAcountWidget(),
        const Divider(
          height: 1,
        ),
        TextButton(
          onPressed: () async {
            final account = _googleAcountNotifier.value;
            if (account == null) {
              log.debug("not signed in");
              return;
            }
            final authHeaders = await account!.authHeaders;
            final authenticateClient = GoogleAuthClient(authHeaders);
            final driveApi = drive.DriveApi(authenticateClient);
            final Stream<List<int>> mediaStream =
                Future.value([104, 105]).asStream().asBroadcastStream();
            var media = drive.Media(mediaStream, 2);
            var driveFile = drive.File();
            driveFile.name = "hello_world.txt";
            final result =
                await driveApi.files.create(driveFile, uploadMedia: media);
            log.info("Upload result: $result");
          },
          child: const Text("Upload dummy file"),
        ),
        const Divider(
          height: 1,
        ),
      ]),
    );
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;

  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

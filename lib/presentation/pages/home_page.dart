import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:brecorder/presentation/pages/browser_view.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';

import '../../domain/entities.dart';
import '../ploc/home_page_state.dart';
import '../widgets/title_bar.dart';

final log = Logger('HomePage');

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final getIt = GetIt.instance;
  final stateManager = GetIt.instance.get<HomePageState>();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: TitleBar(
          leadingOnPressed: (() {
            log.debug("pressed");
          }),
          endingOnPressed: (() {
            log.debug("pressed");
          }),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.phone_android),
                iconMargin: EdgeInsets.all(0),
              ),
              Tab(
                  icon: Icon(Icons.cloud_outlined),
                  iconMargin: EdgeInsets.all(0)),
              Tab(
                  icon: Icon(Icons.delete_outline),
                  iconMargin: EdgeInsets.all(0)),
            ],
          ),
        ),
        body: const TabBarView(
          physics: BouncingScrollPhysics(),
          children: [
            BrowserView(
              repoType: RepoType.filesystem,
            ),
            BrowserView(
              repoType: RepoType.filesystem,
            ),
            BrowserView(
              repoType: RepoType.filesystem,
            ),
          ],
        ),

        // body: ValueListenableBuilder<FolderInfo>(
        //     valueListenable: stateManager.filesystemFolderNotifier,
        //     builder: (context, folderInfo, _) {
        //       return Column(
        //         children: [
        //           _positionBar(folderInfo.path),
        //           const Divider(
        //             height: 3,
        //             thickness: 2,
        //           ),
        //           ListView(
        //               shrinkWrap: true,
        //               physics: const NeverScrollableScrollPhysics(),
        //               children: folderInfo.subfolders
        //                       .map((f) => ListTile(
        //                             title: Text(basename(f.path)),
        //                             leading: const Icon(Icons.folder),
        //                             onTap: () {
        //                               stateManager.cd(f.path);
        //                             },
        //                           ))
        //                       .toList() +
        //                   folderInfo.audios
        //                       .map((a) => ListTile(
        //                           title: Text(basename(a.path)),
        //                           leading: const Icon(Icons.audio_file)))
        //                       .toList()),
        //         ],
        //       );
        //     }),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            final agent = getIt.get<AudioServiceAgent>();
            agent.test("").then(
              (result) {
                result.fold((s) {
                  log.debug("audio agent return: $s");
                }, (f) {
                  log.debug("audio agent return: fail");
                });
              },
            );
          },
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

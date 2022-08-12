import 'package:brecorder/core/audio_agent.dart';
import 'package:brecorder/core/logging.dart';
import 'package:brecorder/home/domain/entities.dart';
import 'package:brecorder/home/presentation/pages/listener_test_page.dart';
import 'package:brecorder/home/presentation/pages/test_page.dart';
import 'package:brecorder/home/presentation/ploc/home_page_state.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';

final log = Logger('HomePage');

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final getIt = GetIt.instance;
  final stateManager = GetIt.instance.get<HomePageState>();

  @override
  void initState() {
    stateManager.cd("/");
    super.initState();
  }

  Widget _positionBar(String fullPath) {
    List<Widget> buttons = List.empty(growable: true);
    String path = "/";
    bool addSeparator = false;

    log.debug("generating position bar: $fullPath");

    for (final d in split(fullPath)) {
      if (d.isEmpty) continue;
      path = join(path, d);
      final buttonPath = path;
      log.debug("sub dir:$path");

      if (addSeparator) {
        buttons.add(const Text("/"));
      }

      buttons.add(TextButton(
        style: ButtonStyle(
          // padding: MaterialStateProperty.all(EdgeInsets.zero),
          minimumSize: MaterialStateProperty.all(Size.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () {
          log.info("Path button:$buttonPath clicked");
          stateManager.cd(buttonPath);
        },
        child: Text(d),
      ));

      if (d != separator && addSeparator == false) {
        addSeparator = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 15, top: 15, right: 15, bottom: 0),
      child: Row(
        children: buttons,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const MyTestPage(title: "Rec Test Page")));
                },
                child: const Text("Test")),
            ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ListenerTestPage()));
                },
                child: const Text("ListenerTest")),
          ],
        ),
      ),
      body: ValueListenableBuilder<FolderInfo>(
          valueListenable: stateManager.filesystemFolderNotifier,
          builder: (context, folderInfo, _) {
            return Column(
              children: [
                _positionBar(folderInfo.path),
                const Divider(
                  height: 3,
                  thickness: 2,
                ),
                ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: folderInfo.subfolders
                            .map((f) => ListTile(
                                  title: Text(basename(f.path)),
                                  leading: const Icon(Icons.folder),
                                  onTap: () {
                                    stateManager.cd(f.path);
                                  },
                                ))
                            .toList() +
                        folderInfo.audios
                            .map((a) => ListTile(
                                title: Text(basename(a.path)),
                                leading: const Icon(Icons.audio_file)))
                            .toList()),
              ],
            );
          }),
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
    );
  }
}

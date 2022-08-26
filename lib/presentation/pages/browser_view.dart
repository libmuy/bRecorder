import 'package:brecorder/core/logging.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';

import '../../domain/entities.dart';
import '../ploc/browser_view_state.dart';

final log = Logger('BrowserView');

class BrowserView extends StatefulWidget {
  final RepoType repoType;

  const BrowserView({Key? key, required this.repoType}) : super(key: key);

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView> {
  late BrowserViewState state;
  final getIt = GetIt.instance;

  @override
  void initState() {
    super.initState();
    switch (widget.repoType) {
      case RepoType.filesystem:
        state = getIt.get<FilesystemBrowserViewState>();
        break;
      case RepoType.iCloud:
        state = getIt.get<ICloudBrowserViewState>();
        break;
      case RepoType.playlist:
        state = getIt.get<PlaylistBrowserViewState>();
        break;
      case RepoType.trash:
        state = getIt.get<TrashBrowserViewState>();
        break;
    }
    state.cd("/");
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
          state.cd(buttonPath);
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
    return ValueListenableBuilder<FolderInfo>(
        valueListenable: state.folderNotifier,
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
                                  state.cd(f.path);
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
        });
  }
}

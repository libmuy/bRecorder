import 'package:brecorder/core/logging.dart';
import 'package:brecorder/data/all_storage_repository.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:brecorder/domain/abstract_repository.dart';
import 'package:brecorder/presentation/pages/browser_view.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:brecorder/presentation/widgets/new_folder_dialog.dart';
import 'package:brecorder/presentation/widgets/title_bar.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../core/service_locator.dart';

final log = Logger('FolderSelector');

class FolderSelector extends StatefulWidget {
  final void Function(Repository repo, String path) folderNotify;

  const FolderSelector({
    Key? key,
    required this.folderNotify,
  }) : super(key: key);

  @override
  State<FolderSelector> createState() => _FolderSelectorState();
}

class _FolderSelectorState extends State<FolderSelector> {
  final titleNotifier = ValueNotifier("/");
  // final browser = BrowserViewState();
  final repo = sl.get<AllStorageRepository>();
  final browserViewState = sl.get<AllStoreageBrowserViewState>();
  String currentPath = "/";

  // @override
  // void initState() {
  //   super.initState();
  // }

  // @override
  // void dispose() {
  //   super.dispose();
  // }

  @override
  Widget build(context) {
    final titleBar = TitleBar(
      titleNotifier: titleNotifier,
      titleHeight: 40,
      leadingIcon: const Icon(Icons.arrow_back),
      leadingOnPressed: () {
        if (currentPath == "/") {
          Navigator.pop(context);
        } else {
          browserViewState.cdParent();
        }
      },
      endingIcon: ValueListenableBuilder<String>(
          valueListenable: titleNotifier,
          builder: (context, title, _) {
            if (currentPath == "/") {
              return Container();
            } else {
              return const Icon(Icons.create_new_folder_outlined);
            }
          }),
      endingOnPressed: () {
        showNewFolderDialog(context, (value) {
          repo
              .newFolder(join(currentPath, value))
              .then((_) => browserViewState.refresh());
        });
      },
      onTitleTapped: (path) {
        browserViewState.cd(path);
      },
    );
    return Column(
      children: [
        SizedBox(height: titleBar.preferredSize.height, child: titleBar),
        Expanded(
            child: BrowserView(
          repoType: RepoType.allStoreage,
          folderOnly: true,
          persistPath: false,
          titleNotifier: titleNotifier,
          onFolderChanged: (path) {
            currentPath = path;
          },
        )),
        Container(
          alignment: Alignment.center,
          child: ElevatedButton(
            child: const Text("Select Folder"),
            onPressed: () {
              final pathRet = repo.parseRepoPath(currentPath);
              if (pathRet.succeed) {
                widget.folderNotify(pathRet.value.repo, pathRet.value.path);
              }

              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}

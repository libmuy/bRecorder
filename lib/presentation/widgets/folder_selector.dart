import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../data/all_storage_repository.dart';
import '../../data/repository.dart';
import '../../domain/entities.dart';
import '../pages/browser_view.dart';
import '../ploc/browser_view_state.dart';
import 'dialogs.dart';
import 'title_bar.dart';

final log = Logger('FolderSelector');

class FolderSelector extends StatefulWidget {
  final void Function(FolderInfo folder) onFolderSelected;

  const FolderSelector({
    super.key,
    required this.onFolderSelected,
  });

  @override
  State<FolderSelector> createState() => _FolderSelectorState();
}

class _FolderSelectorState extends State<FolderSelector> {
  final titleNotifier = ValueNotifier("/");
  // final browser = BrowserViewState();
  final repo = sl.get<AllStorageRepository>();
  final browserViewState = sl.get<AllStoreageBrowserViewState>();
  var currentFolder = FolderInfo.empty;

  // @override
  // void initState() {
  //   super.initState();
  // }

  // @override
  // void dispose() {
  //   super.dispose();
  // }

  String get currentPath {
    return currentFolder.path;
  }

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
          editable: false,
          titleNotifier: titleNotifier,
          destoryRepoCache: true,
          onFolderChanged: (folder) {
            currentFolder = folder;
          },
        )),
        Container(
          alignment: Alignment.center,
          child: ElevatedButton(
            child: const Text("Select Folder"),
            onPressed: () {
              final copyFrom = currentFolder.copyFrom as FolderInfo?;
              widget.onFolderSelected(copyFrom ?? currentFolder);

              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}

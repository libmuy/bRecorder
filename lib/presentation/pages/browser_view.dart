import 'dart:async';

import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:brecorder/presentation/ploc/browser_view_delegate.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';

import '../../domain/entities.dart';
import '../ploc/browser_view_state.dart';

final log = Logger('BrowserView');

class BrowserView extends StatefulWidget {
  final RepoType repoType;
  final BrowserViewDelegate? delegate;

  const BrowserView({Key? key, required this.repoType, this.delegate})
      : super(key: key);

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView> {
  late BrowserViewState state;
  final getIt = GetIt.instance;

  @override
  void initState() {
    super.initState();
    if (widget.delegate != null) {
      widget.delegate!.setEditModeFunc = _setEditModeCallback;
    }
    state = sl.getBrowserViewState(widget.repoType);
    log.debug("initState");
    state.init();
  }

  void _setEditModeCallback(bool edit) {
    if (state.editMode == edit) {
      return;
    }

    setState(() {
      state.editMode = edit;
    });
  }

  // Widget _positionBar(String fullPath) {
  //   List<Widget> buttons = List.empty(growable: true);
  //   String path = "/";
  //   bool addSeparator = false;

  //   log.debug("generating position bar: $fullPath");

  //   for (final d in split(fullPath)) {
  //     if (d.isEmpty) continue;
  //     path = join(path, d);
  //     final buttonPath = path;
  //     log.debug("sub dir:$path");

  //     if (addSeparator) {
  //       buttons.add(const Text("/"));
  //     }

  //     buttons.add(TextButton(
  //       style: ButtonStyle(
  //         // padding: MaterialStateProperty.all(EdgeInsets.zero),
  //         minimumSize: MaterialStateProperty.all(Size.zero),
  //         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  //       ),
  //       onPressed: () {
  //         log.info("Path button:$buttonPath clicked");
  //         state.cd(buttonPath);
  //       },
  //       child: Text(d),
  //     ));

  //     if (d != separator && addSeparator == false) {
  //       addSeparator = true;
  //     }
  //   }

  //   return Padding(
  //     padding: const EdgeInsets.only(left: 15, top: 15, right: 15, bottom: 0),
  //     child: Row(
  //       children: buttons,
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FolderInfo>(
        valueListenable: state.folderNotifier,
        builder: (context, folderInfo, _) {
          return Column(
            children: [
              // _positionBar(folderInfo.path),
              // const Divider(
              //   height: 3,
              //   thickness: 2,
              // ),
              Expanded(
                child: ListView(
                    // shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
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
              ),
              state.editMode
                  ? SizedBox(
                      height: 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          MaterialButton(
                              child:
                                  const Icon(Icons.create_new_folder_outlined),
                              onPressed: () {}),
                          MaterialButton(
                              child:
                                  const Icon(Icons.create_new_folder_outlined),
                              onPressed: () {}),
                          MaterialButton(
                              child:
                                  const Icon(Icons.create_new_folder_outlined),
                              onPressed: () {}),
                          MaterialButton(
                              child:
                                  const Icon(Icons.create_new_folder_outlined),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) =>
                                      AlertDialog(
                                    title: const Text('New Folder'),
                                    content: TextField(
                                      onChanged: (value) {
                                        state.newFolderName = value;
                                      },
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          state.newFolder();
                                          Navigator.pop(context);
                                        },
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                        ],
                      ))
                  : Container()
            ],
          );
        });
  }
}

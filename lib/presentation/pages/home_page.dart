import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:brecorder/presentation/pages/browser_view.dart';
import 'package:brecorder/presentation/pages/record_page.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ploc/home_page_state.dart';
import '../widgets/title_bar.dart';

final log = Logger('HomePage');

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final state = sl.get<HomePageState>();
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    state.init(this);
  }

  @override
  void dispose() {
    super.dispose();
    state.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar(
        titleNotifier: state.titleNotifier,
        titleHeight: 50,
        bottomHeight: 50,
        leadingOnPressed: state.titleBarLeadingOnPressed,
        endingOnPressed: state.titleBarEndingOnPressed,
        onTitleTapped: (path) {
          state.currentBrowserState.cd(path);
        },
        leadingIcon: ValueListenableBuilder<String>(
            valueListenable: state.titleNotifier,
            builder: (context, title, _) {
              if (state.isRoot) {
                return const Icon(Icons.settings);
              }
              return const Icon(Icons.arrow_back);
            }),
        endingIcon: ValueListenableBuilder<BrowserViewMode>(
          valueListenable: state.modeNotifier,
          builder: (context, mode, child) {
            switch (mode) {
              case BrowserViewMode.normal:
              case BrowserViewMode.playback:
                return const Icon(Icons.edit);
              case BrowserViewMode.edit:
                return const Icon(Icons.done);
            }
          },
        ),
        bottom: TabBar(
          controller: state.tabController,
          tabs: state.tabsInfo
              .map((e) => Tab(
                    icon: sl.getRepository(e.repoType).icon,
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: state.tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: state.tabsInfo
            .map((tab) => BrowserView(
                  repoType: tab.repoType,
                  modeNotifier: state.modeNotifier,
                  titleNotifier: state.titleNotifier,
                  onFolderChanged: state.onFolderChanged,
                ))
            .toList(),
      ),
      floatingActionButton: ValueListenableBuilder<BrowserViewMode>(
        valueListenable: state.modeNotifier,
        builder: (context, mode, child) {
          switch (mode) {
            case BrowserViewMode.playback:
            case BrowserViewMode.edit:
              return Container();
            case BrowserViewMode.normal:
              return FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return RecordPage(
                          dirPath: state.currentPath,
                          repoType: state.currentRepoType,
                        );
                      },
                    ),
                  );
                },
                tooltip: 'Increment',
                child: const Icon(Icons.add),
              );
          }
        },
      ),
    );
  }
}

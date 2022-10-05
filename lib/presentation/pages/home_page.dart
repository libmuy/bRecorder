import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/utils/notifiers.dart';
import '../../core/utils/utils.dart';
import '../ploc/home_page_state.dart';
import '../widgets/bottom_panel.dart';
import '../widgets/title_bar.dart';
import 'browser_view.dart';
import 'record_page.dart';

final log = Logger('HomePage');

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final state = sl.get<HomePageState>();
  final _modeNotifier = sl.get<GlobalModeNotifier>();
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
    return Stack(
      children: [
        WillPopScope(
          onWillPop: () async {
            return state.onPop();
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: TitleBar(
              titleNotifier: state.titleNotifier,
              titleHeight: 50,
              bottomHeight: 50,
              leadingOnPressed: () => state.titleBarLeadingOnPressed(context),
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
              endingIcon: ValueListenableBuilder<GlobalMode>(
                valueListenable: _modeNotifier,
                builder: (context, mode, child) {
                  switch (mode) {
                    case GlobalMode.normal:
                    case GlobalMode.playback:
                      return const Icon(Icons.edit);
                    case GlobalMode.edit:
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
                        titleNotifier: state.titleNotifier,
                        onFolderChanged: state.onFolderChanged,
                      ))
                  .toList(),
            ),
            floatingActionButton: ValueListenableBuilder<GlobalMode>(
              valueListenable: _modeNotifier,
              builder: (context, mode, child) {
                switch (mode) {
                  case GlobalMode.playback:
                  case GlobalMode.edit:
                    return Container();
                  case GlobalMode.normal:
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
          ),
        ),
        // Bottom Panels
        Align(alignment: Alignment.bottomCenter, child: BottomPanel()),
      ],
    );
  }
}

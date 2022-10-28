import 'package:brecorder/data/repository.dart';
import 'package:flutter/material.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/setting.dart';
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final state = sl.get<HomePageState>();
  final settings = sl.get<Settings>();
  final _modeNotifier = sl.get<GlobalModeNotifier>();
  Map<RepoType, Widget> _browserViewCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    state.onAppStateChanged(appState);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WillPopScope(
          onWillPop: () async {
            return state.onPop();
          },
          child: ValueListenableBuilder<List<TabInfo>?>(
              valueListenable: settings.tabsNotifier,
              builder: (context, allTabs, _) {
                log.info("Tabs changed");
                assert(allTabs != null);
                final tabs = allTabs!.where((tab) => tab.enabled).toList();
                state.initTabController(this, tabs, settings.tabIndex ?? 0);
                state.currentBrowserState.setInitialPath(state.currentPath);
                return Scaffold(
                  resizeToAvoidBottomInset: false,
                  appBar: TitleBar(
                    titleNotifier: state.titleNotifier,
                    titleHeight: 50,
                    bottomHeight: 50,
                    leadingOnPressed: () =>
                        state.titleBarLeadingOnPressed(context),
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
                      tabs: tabs
                          .map((e) => Tab(
                                icon: sl.getRepository(e.repoType).icon,
                              ))
                          .toList(),
                    ),
                  ),
                  body: TabBarView(
                    //the key is IMPORTANT!
                    //When rebuild Tabs, the view will not be update without key
                    key: GlobalKey(),
                    controller: state.tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: tabs.map((tab) {
                      if (!_browserViewCache.containsKey(tab.repoType)) {
                        _browserViewCache[tab.repoType] = BrowserView(
                          repoType: tab.repoType,
                          titleNotifier: state.titleNotifier,
                          onFolderChanged: state.onFolderChanged,
                        );
                      }
                      return _browserViewCache[tab.repoType]!;
                    }).toList(),
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
                );
              }),
        ),
        // Bottom Panels
        const Align(alignment: Alignment.bottomCenter, child: BottomPanel()),
      ],
    );
  }
}

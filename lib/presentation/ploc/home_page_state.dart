import 'package:brecorder/presentation/pages/settings/setting_page.dart';
import 'package:flutter/material.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/utils/notifiers.dart';
import '../../core/utils/utils.dart';
import '../../data/repository.dart';
import '../../domain/entities.dart';
import 'browser_view_state.dart';

final _log = Logger('HomeState');

class HomePageState {
  TabController? tabController;
  final titleNotifier = ValueNotifier("/");
  final _modeNotifier = sl.get<GlobalModeNotifier>();
  List<TabInfo> tabsInfo = [
    TabInfo(repoType: RepoType.filesystem),
    TabInfo(repoType: RepoType.iCloud),
    TabInfo(repoType: RepoType.trash),
  ];
  int currentTabIndex = 0;
  final fabStateNotifier = ValueNotifier(FABState(0, GlobalMode.normal));

  HomePageState() {
    _modeNotifier.addListener(() {
      fabStateNotifier.value =
          fabStateNotifier.value.copyWith(m: _modeNotifier.value);
    });
  }

  bool get isRoot {
    if (currentTab.currentPath == "/") {
      return true;
    }

    return false;
  }

  TabInfo get currentTab {
    return tabsInfo[currentTabIndex];
  }

  String get currentPath {
    return currentTab.currentPath;
  }

  RepoType get currentRepoType {
    return currentTab.repoType;
  }

  BrowserViewState get currentBrowserState {
    return sl.getBrowserViewState(currentTab.repoType);
  }

  void _tabControllerListener() {
    //indexIsChanging: tab is animating, this is the first call when changing TAB
    if (!tabController!.indexIsChanging) {
      _setEditMode(false);
      currentTabIndex = tabController!.index;
      // currentBrowserState.refresh();
      _notifyTitle();
      _log.info("Tab switched, index:$currentTabIndex");
      fabStateNotifier.value =
          fabStateNotifier.value.copyWith(i: currentTabIndex);
    }
  }

  void initTabController(
      TickerProviderStateMixin vsync, List<TabInfo> tabs, int index) {
    if (tabController != null) {
      tabController!.removeListener(_tabControllerListener);
      tabController!.dispose();
    }
    tabController =
        TabController(length: tabs.length, vsync: vsync, initialIndex: index);
    tabsInfo = tabs;
    currentTabIndex = 0;

    tabController!.addListener(_tabControllerListener);
  }

  void _setEditMode(bool edit) {
    switch (_modeNotifier.value) {
      case GlobalMode.normal:
      case GlobalMode.playback:
        if (edit) {
          _modeNotifier.value = GlobalMode.edit;
        }
        break;

      case GlobalMode.edit:
        if (!edit) {
          _modeNotifier.value = GlobalMode.normal;
        }
        break;
    }
  }

  void titleBarLeadingOnPressed(BuildContext context) {
    if (isRoot) {
      _log.debug("setting page");
      // showBubbleDialog(
      //   context,
      //   position: const Offset(50, 300),
      //   dialog: SizedBox(
      //       child: Container(
      //     color: Colors.red,
      //     child: const Text("sample"),
      //   )),
      // );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            return const SettingPage();
          },
        ),
      );
    } else {
      currentBrowserState.cdParent();
    }
  }

  void titleBarEndingOnPressed() {
    switch (_modeNotifier.value) {
      case GlobalMode.normal:
      case GlobalMode.playback:
        _setEditMode(true);
        break;

      case GlobalMode.edit:
        _setEditMode(false);
        break;
    }
  }

  void recordDone() {
    currentBrowserState.refresh();
  }

  void onFolderChanged(FolderInfo folder) {
    currentTab.currentFolder = folder;
    _notifyTitle();
  }

  void _notifyTitle() {
    if (currentPath == "/") {
      titleNotifier.value = currentRepoType.title;
    } else {
      titleNotifier.value = currentRepoType.title + currentPath;
    }
  }

  bool onPop() {
    // allows the pop when Normal Mode
    if (_modeNotifier.value != GlobalMode.normal) {
      _modeNotifier.value = GlobalMode.normal;
      return false;
    }

    if (currentBrowserState.cdParent()) return false;

    return true;
  }

  Future<void> onAppStateChanged(AppLifecycleState state) async {
    _log.info("App State:$state");
    if (state == AppLifecycleState.inactive) {
      for (final listener in sl.appCloseListeners) {
        listener();
      }
    }
  }
}

class FABState {
  int tabIndex;
  GlobalMode mode;
  FABState(this.tabIndex, this.mode);

  FABState copyWith({int? i, GlobalMode? m}) {
    final newState = FABState(tabIndex, mode);
    if (i != null) newState.tabIndex = i;
    if (m != null) newState.mode = m;

    return newState;
  }

  // @override
  // bool operator == (covariant FABState other) {
  //   if (identical(this, other)) return true;
  //   return tabIndex == other.tabIndex && mode == other.mode;
  // }

  // @override
  // int get hashCode => Object.hash(tabIndex, mode);
}

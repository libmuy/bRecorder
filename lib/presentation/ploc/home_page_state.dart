import 'package:brecorder/presentation/pages/settings/setting_page.dart';
import 'package:flutter/material.dart';

import '../../core/logging.dart';
import '../../core/service_locator.dart';
import '../../core/utils/notifiers.dart';
import '../../core/utils/utils.dart';
import '../../data/repository_type.dart';
import '../../domain/entities.dart';
import '../widgets/bubble_dialog.dart';
import 'browser_view_state.dart';

final log = Logger('HomeState');

class HomePageState {
  late final TabController tabController;
  final titleNotifier = ValueNotifier("/");
  final _modeNotifier = sl.get<GlobalModeNotifier>();
  final List<TabInfo> tabsInfo = [
    TabInfo(repoType: RepoType.filesystem),
    TabInfo(repoType: RepoType.iCloud),
    TabInfo(repoType: RepoType.trash),
  ];
  int currentTabIndex = 0;

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

  void init(SingleTickerProviderStateMixin vsync) {
    tabController = TabController(length: 3, vsync: vsync);

    tabController.addListener(() {
      _setEditMode(false);
      currentTabIndex = tabController.index;
      currentBrowserState.refresh();
    });
  }

  void dispose() {
    tabController.dispose();
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
      log.debug("setting page");
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
    currentTab.currentPath = folder.path;
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
}

class TabInfo {
  String currentPath;
  RepoType repoType;

  TabInfo({
    this.currentPath = "/",
    required this.repoType,
  });
}

import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:flutter/material.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:brecorder/presentation/ploc/browser_view_delegate.dart';

import '../../data/repository_type.dart';

final log = Logger('HomeState');

class HomePageState {
  late final TabController tabController;
  final titleNotifier = ValueNotifier("");
  final editModeNotifier = ValueNotifier(false);
  final List<TabInfo> tabsInfo = [
    TabInfo(
        repoType: RepoType.filesystem,
        icon: const Icon(Icons.phone_android),
        rootTitle: "Local Storage"),
    TabInfo(
        repoType: RepoType.iCloud,
        icon: const Icon(Icons.cloud_outlined),
        rootTitle: "iCloud"),
    TabInfo(
        repoType: RepoType.trash,
        icon: const Icon(Icons.delete_outline),
        rootTitle: "Trash"),
  ];
  int currentTabIndex = 0;

  bool get isRoot {
    final tabInfo = tabsInfo[currentTabIndex];
    if (tabInfo.currentPath == "/") {
      return true;
    }

    return false;
  }

  TabInfo get currentTab {
    return tabsInfo[currentTabIndex];
  }

  String get currentPath {
    return tabsInfo[currentTabIndex].currentPath;
  }

  RepoType get currentRepoType {
    return tabsInfo[currentTabIndex].repoType;
  }

  BrowserViewState get currentBrowserState {
    return sl.getBrowserViewState(currentTab.repoType);
  }

  void init(SingleTickerProviderStateMixin vsync) {
    tabController = TabController(length: 3, vsync: vsync);

    currentBrowserState.folderNotifier.addListener(_folderChangeListener);

    tabController.addListener(() {
      _setEditMode(false);
      currentBrowserState.folderNotifier.removeListener(_folderChangeListener);
      currentTabIndex = tabController.index;
      currentBrowserState.folderNotifier.addListener(_folderChangeListener);
      _notifyTitle();
    });
    _notifyTitle();
  }

  void dispose() {
    tabController.dispose();
  }

  void _notifyTitle() {
    final path = currentTab.currentPath;
    if (path == "/" || path == "") {
      titleNotifier.value = currentTab.rootTitle;
    } else {
      titleNotifier.value = path.substring(1);
    }
  }

  void _setEditMode(bool edit) {
    if (editModeNotifier.value == edit) {
      return;
    }
    editModeNotifier.value = edit;
    currentTab.delegate.setEditMode(edit);
  }

  void titleBarLeadingOnPressed() {
    if (isRoot) {
      log.debug("setting page");
    } else {
      currentBrowserState.cdParent();
    }
  }

  void titleBarEndingOnPressed() {
    log.debug("pressed");
    _setEditMode(!editModeNotifier.value);
  }

  void _folderChangeListener() {
    final path = currentBrowserState.folderNotifier.value.path;
    currentTab.currentPath = path;
    _notifyTitle();
    _setEditMode(false);
    log.info("folder changed: $path");
  }

  void recordDone() {
    currentBrowserState.refresh();
  }
}

class TabInfo {
  String rootTitle;
  String currentPath;
  RepoType repoType;
  BrowserViewDelegate delegate = BrowserViewDelegate();
  Icon icon;

  TabInfo(
      {this.rootTitle = "",
      this.currentPath = "/",
      required this.repoType,
      required this.icon});
}

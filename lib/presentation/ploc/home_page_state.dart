import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:brecorder/domain/entities.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:flutter/material.dart';

import '../../data/repository_type.dart';

final log = Logger('HomeState');

class HomePageState {
  late final TabController tabController;
  final titleNotifier = ValueNotifier("/");
  final modeNotifier = ValueNotifier(BrowserViewMode.normal);
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
    switch (modeNotifier.value) {
      case BrowserViewMode.normal:
      case BrowserViewMode.playback:
        if (edit) {
          modeNotifier.value = BrowserViewMode.edit;
        }
        break;

      case BrowserViewMode.edit:
        if (!edit) {
          modeNotifier.value = BrowserViewMode.normal;
        }
        break;
    }
  }

  void titleBarLeadingOnPressed() {
    if (isRoot) {
      log.debug("setting page");
    } else {
      currentBrowserState.cdParent();
    }
  }

  void titleBarEndingOnPressed() {
    switch (modeNotifier.value) {
      case BrowserViewMode.normal:
      case BrowserViewMode.playback:
        _setEditMode(true);
        break;

      case BrowserViewMode.edit:
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
}

class TabInfo {
  String currentPath;
  RepoType repoType;

  TabInfo({
    this.currentPath = "/",
    required this.repoType,
  });
}

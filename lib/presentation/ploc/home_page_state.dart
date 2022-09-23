import 'package:brecorder/core/logging.dart';
import 'package:brecorder/core/service_locator.dart';
import 'package:brecorder/data/repository_type.dart';
import 'package:brecorder/domain/entities.dart';
import 'package:brecorder/presentation/ploc/browser_view_state.dart';
import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/repository_type.dart';
import '../pages/browser_view.dart';
import '../widgets/bubble_dialog.dart';

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
  int _testCnt = 0;

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

  void _routeTestPage(BuildContext context) {
    Navigator.push(
        context,
        PageRouteBuilder(
          barrierDismissible: true,
          fullscreenDialog: true,
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) => Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  color: Colors.red,
                  height: 200,
                  child: Text("sample"),
                ),
              ),
            ],
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return const FadeUpwardsPageTransitionsBuilder().buildTransitions(
                MaterialPageRoute(
                  builder: (context) => Container(
                    color: Colors.blue,
                    height: 200,
                  ),
                ),
                context,
                animation,
                secondaryAnimation,
                child);
          },
        ));
  }

  void _routeTestPage2(BuildContext context) {
    Navigator.push(
        context,
        RawDialogRoute(
            barrierDismissible: false,
            barrierColor: Colors.transparent,
            // fullscreenDialog: true,
            // opaque: false,
            pageBuilder: (context, animation, secondaryAnimation) => Stack(
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        color: Colors.red,
                        height: 200,
                        child: Text("sample"),
                      ),
                    ),
                  ],
                )));
  }

  void _routeTestPage3(BuildContext context) {
    Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          barrierDismissible: true,
          fullscreenDialog: true,
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) {
            return BubbleDialog(
              position: const Offset(50, 300),
              child: SizedBox(
                  child: Container(
                color: Colors.red,
                child: const Text("sample"),
              )),
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var tween = Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.ease));

            return FadeTransition(
              opacity: animation.drive(tween),
              child: child,
            );
          },
        ));
  }

  void titleBarLeadingOnPressed(BuildContext context) {
    if (isRoot) {
      log.debug("setting page");
      showBubbleDialog(
        context,
        position: const Offset(50, 300),
        dialog: SizedBox(
            child: Container(
          color: Colors.red,
          child: const Text("sample"),
        )),
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

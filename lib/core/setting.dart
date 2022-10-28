import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brecorder/core/utils/utils.dart';
import 'package:brecorder/data/repository.dart';
import 'package:flutter/cupertino.dart';

import 'logging.dart';
import 'service_locator.dart';

const _kPrefKeyTabs = "settingsTabs";
const _kPrefKeyTabIndex = "settingsTabIndex";
final log = Logger('Settings', level: LogLevel.debug);

class Settings {
  final tabsNotifier = ValueNotifier<List<TabInfo>?>(null);
  int? tabIndex;

  List<TabInfo>? get tabs => tabsNotifier.value;
  Settings() {
    sl.appCloseListeners.add(save);
  }

  Future<void> load() async {
    final pref = await sl.asyncPref;
    var jsonStr = pref.getStringList(_kPrefKeyTabs);
    List<TabInfo>? tabs;

    if (jsonStr != null) {
      try {
        tabs = jsonStr.map((str) => TabInfo.fromJson(jsonDecode(str))).toList();
      } catch (e) {
        log.error("convert shared preference value to RepoType Failed\n"
            "error:$e\n"
            "jsons str:$jsonStr");
        jsonStr = null;
      }
    }

    //Set repos to default value
    //If restore from share preference failed
    tabs ??= RepoType.values
        .where(
          (type) {
            if (!Platform.isIOS && type == RepoType.iCloud) return false;
            return sl.getRepository(type).isTab;
          },
        )
        .map((type) =>
            TabInfo(repoType: type, enabled: !sl.getRepository(type).isCloud))
        .toList();

    tabsNotifier.value = tabs;

    //Get Tab index
    tabIndex = pref.getInt(_kPrefKeyTabIndex) ?? 0;
    if (tabIndex! >= tabs.length || tabIndex! < 0) tabIndex = 0;

    //Wait folder information
    //while waiting, the lanuch screen will be displayed
    final tab = tabs[tabIndex!];
    final repo = sl.getRepository(tab.repoType);
    await repo.getFolderInfo(tab.currentPath);

    //Prefetch the folder and audio information
    for (var tab in tabs) {
      final repo = sl.getRepository(tab.repoType);
      if (repo.isCloud && tab.enabled) {
        Timer.run(() async {
          final result = await repo.connectCloud(background: true);
          if (result) repo.preFetch();
        });
      }
      if (!repo.isCloud) repo.preFetch();
    }
  }

  Future<bool> save() async {
    if (tabs == null) return true;
    final pref = await sl.asyncPref;
    final tabsStringList = tabs!.map((tab) => jsonEncode(tab)).toList();
    return pref.setStringList(_kPrefKeyTabs, tabsStringList);
  }
}

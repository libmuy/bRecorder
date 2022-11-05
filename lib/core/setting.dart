import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brecorder/core/utils/utils.dart';
import 'package:brecorder/data/repository.dart';
import 'package:flutter/cupertino.dart';

import 'logging.dart';
import 'service_locator.dart';

const _kPrefKeyTabs = "settingsTabs";
const _kPrefKeyCloudSync = "settingsCloudSync";
const _kPrefKeyTabIndex = "settingsTabIndex";
final log = Logger('Settings', level: LogLevel.debug);

class Settings {
  final tabsNotifier = ValueNotifier<List<TabInfo>?>(null);
  int? tabIndex;
  CloudSyncSetting? cloudSyncSetting;

  List<TabInfo>? get tabs => tabsNotifier.value;
  final Completer<Settings> _loadCompleter = Completer();
  final bool _loadDone = false;
  Settings() {
    sl.appCloseListeners.add(save);
  }

  Future<Settings> waitLoadDone() async {
    if (_loadDone) return this;
    return _loadCompleter.future;
  }

  Future<void> load() async {
    final pref = await sl.asyncPref;
    //============================= Load Tabs ============================
    final jsonStrList = pref.getStringList(_kPrefKeyTabs);
    List<TabInfo>? tabs;

    if (jsonStrList != null) {
      try {
        tabs = jsonStrList
            .map((str) => TabInfo.fromJson(jsonDecode(str)))
            .toList();
      } catch (e) {
        log.warning("convert shared preference value to RepoType Failed\n"
            "error:$e\n"
            "jsons str:$jsonStrList");
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
    for (var tab in tabs) {
      final folder = tab.currentFolder;
      if (folder != null) folder.repo!.addOrphanCache(folder);
    }

    //Get Tab index
    tabIndex = pref.getInt(_kPrefKeyTabIndex) ?? 0;
    if (tabIndex! >= tabs.length || tabIndex! < 0) tabIndex = 0;

    //========================== Load Cloud Sync ==========================
    final jsonStr = pref.getString(_kPrefKeyCloudSync);

    if (jsonStr != null) {
      try {
        cloudSyncSetting = CloudSyncSetting.fromJson(jsonDecode(jsonStr));
      } catch (e) {
        log.warning("convert shared preference value to RepoType Failed\n"
            "error:$e\n"
            "jsons str:$jsonStr");
        cloudSyncSetting = CloudSyncSetting(
            conflictResolveMethod: CloudConflictResolveMethod.byUser,
            syncMethod: CloudSyncMethod.merge);
      }
    }

    //========================== Prefetch Repos ==========================
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

    _loadCompleter.complete(this);
  }

  Future<bool> save() async {
    if (tabs == null) return true;
    final pref = await sl.asyncPref;
    final tabsStringList = tabs!.map((tab) => jsonEncode(tab)).toList();
    return pref.setStringList(_kPrefKeyTabs, tabsStringList);
  }
}

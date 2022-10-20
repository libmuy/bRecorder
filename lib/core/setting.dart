import 'dart:convert';
import 'dart:io';

import 'package:brecorder/core/utils/utils.dart';
import 'package:brecorder/data/repository.dart';
import 'package:flutter/cupertino.dart';

import 'logging.dart';
import 'service_locator.dart';

const _kPrefKeyTabs = "tabs";
final log = Logger('Settings', level: LogLevel.debug);

class Settings {
  final tabsNotifier = ValueNotifier<List<TabInfo>?>(null);

  List<TabInfo>? get tabs => tabsNotifier.value;
  Settings() {
    _load();
  }

  Future<void> _load() async {
    final pref = await sl.asyncPref;
    var reposString = pref.getStringList(_kPrefKeyTabs);

    if (reposString != null) {
      try {
        tabsNotifier.value = reposString
            .map((str) => TabInfo.fromJson(jsonDecode(str)))
            .toList();
      } catch (e) {
        log.error("convert shared preference value to RepoType Failed");
        reposString = null;
      }
    }

    // set repos to default value
    if (reposString == null) {
      tabsNotifier.value = RepoType.values
          .where(
            (type) {
              if (!Platform.isIOS && type == RepoType.iCloud) return false;
              return sl.getRepository(type).isTab;
            },
          )
          .map((type) =>
              TabInfo(repoType: type, enabled: !sl.getRepository(type).isCloud))
          .toList();
    }
  }

  Future<bool> save() async {
    if (tabs == null) return true;
    final pref = await sl.asyncPref;
    return pref.setStringList(_kPrefKeyTabs,
        tabsNotifier.value!.map((repo) => repo.toString()).toList());
  }
}

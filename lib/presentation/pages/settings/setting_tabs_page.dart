import 'package:brecorder/data/google_drive_repository.dart';
import 'package:flutter/material.dart';

import '../../../core/global_info.dart';
import '../../../core/service_locator.dart';
import '../../../core/setting.dart';
import '../../../core/utils/utils.dart';


class SettingTabsPage extends StatefulWidget {
  const SettingTabsPage({super.key});

  @override
  State<SettingTabsPage> createState() => _SettingTabsPageState();
}

class _SettingTabsPageState extends State<SettingTabsPage> {
  final settings = sl.get<Settings>();
  List<TabInfo>? _newTabs;

  @override
  void initState() {
    super.initState();
  }

  Widget _buildListItem(TabInfo tabInfo, int? draggableListIndex) {
    final repoType = tabInfo.repoType;
    final repo = sl.getRepository(repoType);
    return Container(
      height: 60,
      color: Theme.of(context).primaryColor,
      key: Key(repoType.title),
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Expanded(
            child: Row(children: [
              //Leading Icon
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 15),
                width: 50,
                child: repoType.icon,
              ),

              //Titles
              Expanded(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    repoType.title,
                    style: const TextStyle(fontSize: 16),
                  ),
                  repo is GoogleDriveRepository && repo.account != null
                      ? Text(
                          repo.account!,
                          style: TextStyle(
                              fontSize: 12, color: Theme.of(context).hintColor),
                        )
                      : Container(),
                ],
              )),

              //Drag handler
              tabInfo.enabled && draggableListIndex != null
                  ? ReorderableDragStartListener(
                      index: draggableListIndex,
                      child: const Icon(Icons.drag_handle_outlined),
                    )
                  : Container(),
            ]),
          ),
          Switch(
            value: tabInfo.enabled,
            onChanged: (enable) {
              if (repo.isCloud) {
                final Future<bool> ret;
                if (enable) {
                  ret = repo.connectCloud();
                } else {
                  ret = repo.disconnectCloud();
                }
                ret.then((succed) {
                  if (succed) {
                    setState(() {
                      tabInfo.enabled = !tabInfo.enabled;
                    });
                  } else {
                    showSnackBar(SnackBar(
                        content: Text("Enable ${repoType.title} Failed!"
                            "(${repo.cloudErrMessage})")));
                  }
                });
              } else {
                setState(() {
                  tabInfo.enabled = !tabInfo.enabled;
                });
              }
            },
          )
        ],
      ),
    );
  }

  List<Widget> _buildSubList(List<TabInfo> tabs) {
    List<Widget> ret = [];
    for (var i = 0; i < tabs.length; i++) {
      ret.add(_buildListItem(tabs[i], i));
    }
    return ret;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        settings.tabsNotifier.value = _newTabs;
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Settings - Tabs"),
        ),
        body: Padding(
          padding: GlobalInfo.kSettingPagePadding,
          child: ValueListenableBuilder<List<TabInfo>?>(
              valueListenable: settings.tabsNotifier,
              builder: (context, tabs, _) {
                if (tabs == null) {
                  return Container(
                    color: Colors.red,
                  );
                }
                _newTabs ??= List.of(tabs);
                final enabledTabs = _newTabs!
                    .where(
                      (tab) => tab.enabled,
                    )
                    .toList();
                final disabledTabs = _newTabs!
                    .where(
                      (tab) => !tab.enabled,
                    )
                    .toList();
                _newTabs = enabledTabs + disabledTabs;

                final enabledItems = _buildSubList(enabledTabs);
                final disabledItems = _buildSubList(disabledTabs);

                return Column(
                  children: [
                    ReorderableListView(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      children: enabledItems,
                      onReorder: (int oldIndex, int newIndex) {
                        setState(() {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final item = _newTabs!.removeAt(oldIndex);
                          _newTabs!.insert(newIndex, item);
                        });
                      },
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: disabledItems,
                    )
                  ],
                );
              }),
        ),
      ),
    );
  }
}

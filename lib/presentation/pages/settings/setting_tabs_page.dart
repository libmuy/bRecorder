import 'package:flutter/material.dart';

import '../../../core/global_info.dart';
import '../../../core/logging.dart';
import '../../../core/service_locator.dart';
import '../../../core/setting.dart';
import '../../../core/utils/utils.dart';

final log = Logger('SettingPage', level: LogLevel.debug);

class SettingTabsPage extends StatefulWidget {
  const SettingTabsPage({Key? key}) : super(key: key);

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
    return Container(
      color: Theme.of(context).primaryColor,
      key: Key(repoType.name),
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Expanded(
            child: ListTile(
              // tileColor: _items[index].isOdd ? oddItemColor : evenItemColor,
              title: Text(repoType.name),
              leading: repoType.icon,
              trailing: tabInfo.enabled && draggableListIndex != null
                  ? ReorderableDragStartListener(
                      index: draggableListIndex,
                      child: const Icon(Icons.drag_handle_outlined),
                    )
                  : null,
            ),
          ),
          Switch(
            value: tabInfo.enabled,
            onChanged: (value) {
              setState(() {
                tabInfo.enabled = !tabInfo.enabled;
              });
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

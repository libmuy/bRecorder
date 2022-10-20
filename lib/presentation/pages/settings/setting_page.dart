import 'package:brecorder/core/global_info.dart';
import 'package:brecorder/core/utils/notifiers.dart';
import 'package:brecorder/data/repository.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../../../core/logging.dart';
import '../../../core/service_locator.dart';
import 'setting_tabs_page.dart';

final log = Logger('SettingPage', level: LogLevel.debug);

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  Widget _buildTitle(String titleString) {
    return Padding(
      padding: const EdgeInsets.only(top: 50, bottom: 10),
      child: Text(titleString),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Padding(
        padding: GlobalInfo.kSettingPagePadding,
        child: ListView(children: <Widget>[
          _buildTitle("General"),
          const Divider(
            height: 1,
          ),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return const SettingTabsPage();
                  },
                ),
              );
            },
            child: const ListTile(
              leading: Icon(Icons.tab),
              title: Text("Tabs"),
            ),
          ),
          _buildTitle("Dummy"),
          const Divider(
            height: 1,
          ),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return const SettingTabsPage();
                  },
                ),
              );
            },
            child: const ListTile(
              leading: Icon(Icons.tab),
              title: Text("Dumy"),
            ),
          ),
          const Divider(
            height: 1,
          ),
        ]),
      ),
    );
  }
}

import 'package:brecorder/home/presentation/pages/home_page.dart';
import 'package:brecorder/home/presentation/pages/test_page.dart';
import 'package:flutter/material.dart';

import 'core/service_locator.dart';
import 'core/logging.dart';

final log = Logger('Main');

void main() {
  Logger.forceLevel = LogLevel.all;
  init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bRecorder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const MyHomePage(title: 'bRecorder Home'),
      // home: const MyTestPage(title: 'Test Page'),
    );
  }
}

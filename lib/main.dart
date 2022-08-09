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
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // home: const MyHomePage(title: 'Flutter Demo Home Page'),
      home: const MyTestPage(title: 'Test Page'),
    );
  }
}

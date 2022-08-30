import 'package:flutter/material.dart';

import 'core/service_locator.dart';
import 'core/logging.dart';
import 'presentation/pages/home_page.dart';

final log = Logger('Main');

void main() {
  Logger.forceLevel = LogLevel.all;
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
      home: const HomePage(),
      // home: const MyTestPage(title: 'Test Page'),
    );
  }
}

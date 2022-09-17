import 'package:flutter/material.dart';

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
    /*=======================================================================*\ 
    Theme Common Part
  \*=======================================================================*/
    const labelSmall = TextStyle(
      fontSize: 8,
    );

    /*=======================================================================*\ 
    Theme Dark
  \*=======================================================================*/
    final themeDark = ThemeData.dark().copyWith(
      dialogBackgroundColor: Colors.black,
      textTheme: ThemeData.dark().textTheme.copyWith(
            labelSmall: labelSmall,
          ),
    );

    /*=======================================================================*\ 
    Theme Light
  \*=======================================================================*/
    final themeLight = ThemeData.light().copyWith(
      textTheme: ThemeData.light().textTheme.copyWith(
            labelSmall: labelSmall,
          ),
    );

    return MaterialApp(
      title: 'bRecorder',
      debugShowCheckedModeBanner: false,
      theme: themeLight,
      darkTheme: themeDark,
      // themeMode: ThemeMode.dark,

      home: const HomePage(),
      // home: const MyTestPage(title: 'Test Page'),
    );
  }
}

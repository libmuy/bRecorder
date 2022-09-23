import 'package:flutter/material.dart';

import 'core/logging.dart';
import 'core/service_locator.dart';
import 'presentation/pages/home_page.dart';

final log = Logger('Main');

void main() {
  // Logger.forceLevel = LogLevel.all;
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
      // useMaterial3: true,
      dialogBackgroundColor: Colors.black,
      textTheme: ThemeData.dark().textTheme.copyWith(
            labelSmall: labelSmall,
          ),
    );

    /*=======================================================================*\ 
    Theme Light
  \*=======================================================================*/
    final themeLight = ThemeData.light().copyWith(
      // useMaterial3: true,
      textTheme: ThemeData.light().textTheme.copyWith(
            labelSmall: labelSmall,
          ),
    );

    return MaterialApp(
      title: 'bRecorder',
      scaffoldMessengerKey: sl.messageState,
      debugShowCheckedModeBanner: false,
      theme: themeLight,
      darkTheme: themeDark,
      // themeMode: ThemeMode.dark,

      home: const HomePage(),
      // home: const MyTestPage(title: 'Test Page'),
    );
  }
}

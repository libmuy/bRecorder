import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/logging.dart';
import 'core/service_locator.dart';
import 'presentation/pages/home_page.dart';

final log = Logger('Main');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const BRecorderApp());
}

class BRecorderApp extends StatelessWidget {
  const BRecorderApp({Key? key}) : super(key: key);

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

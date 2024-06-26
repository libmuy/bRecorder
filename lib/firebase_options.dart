// File generated by FlutterFire CLI.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDKRHgkXPqIzQqkf59zmg8jh3tG0ETbqDs',
    appId: '1:315810402236:android:a4b6120060a9fa316b65b9',
    messagingSenderId: '315810402236',
    projectId: 'brecorder-63acc',
    storageBucket: 'brecorder-63acc.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD8Q3ZVM-pC-2DiGJrSjiRuTMKldj-zCWg',
    appId: '1:315810402236:ios:07eaf8fc8149e86b6b65b9',
    messagingSenderId: '315810402236',
    projectId: 'brecorder-63acc',
    storageBucket: 'brecorder-63acc.appspot.com',
    androidClientId: '315810402236-pcf6jseu4eop301js04utmg47gbbqvhj.apps.googleusercontent.com',
    iosClientId: '315810402236-lkuhatu9057pfg1qb4o8j5ug1bb4h9rq.apps.googleusercontent.com',
    iosBundleId: 'cyou.libmuy.bRecorder',
  );
}

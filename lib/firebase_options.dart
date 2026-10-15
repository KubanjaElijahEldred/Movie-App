// PLACEHOLDER Firebase configuration.
//
// These values are intentionally fake so the project compiles before it is
// connected to a Firebase project. Replace this entire file by running:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// That command regenerates this file with your real project's keys and also
// drops `android/app/google-services.json` and
// `ios/Runner/GoogleService-Info.plist` into place.
//
// Authentication will not work until this file holds real credentials; the
// app detects the failure and shows a "not configured yet" message instead of
// crashing.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA5XXGBNt1ZA2BFAGTt2CVkVS2etQJhceM',
    appId: '1:478726185470:web:1a3c53bbbc501a168ee0af',
    messagingSenderId: '478726185470',
    projectId: 'play-it-movies',
    authDomain: 'play-it-movies.firebaseapp.com',
    storageBucket: 'play-it-movies.firebasestorage.app',
    measurementId: 'G-KJF8RBL23Y',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBH4dDwewl4iMaS_SMQbpaRXJREPwF7STI',
    appId: '1:478726185470:android:9cdf3712085b23728ee0af',
    messagingSenderId: '478726185470',
    projectId: 'play-it-movies',
    storageBucket: 'play-it-movies.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCe9YzmaaZqS8ngF6voRy2AOLGUC5QMauw',
    appId: '1:478726185470:ios:b8e2edcc26b5d7328ee0af',
    messagingSenderId: '478726185470',
    projectId: 'play-it-movies',
    storageBucket: 'play-it-movies.firebasestorage.app',
    iosBundleId: 'com.bimsina.movies',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_MACOS_API_KEY',
    appId: 'REPLACE_WITH_YOUR_MACOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_STORAGE_BUCKET',
    iosBundleId: 'com.bimsina.movies',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_WINDOWS_API_KEY',
    appId: 'REPLACE_WITH_YOUR_WINDOWS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    authDomain: 'REPLACE_WITH_YOUR_AUTH_DOMAIN',
    storageBucket: 'REPLACE_WITH_YOUR_STORAGE_BUCKET',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_LINUX_API_KEY',
    appId: 'REPLACE_WITH_YOUR_LINUX_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_STORAGE_BUCKET',
  );
}

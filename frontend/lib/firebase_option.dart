// File generated manually based on Firebase project configuration.
// Project: bin-authentication

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBFdkglS6xnbnKz28Rcwpm92uke55wH4u0',
    appId: '1:230542805431:android:09802518a1dc653122c032',
    messagingSenderId: '230542805431',
    projectId: 'bin-authentication',
    storageBucket: 'bin-authentication.firebasestorage.app',
  );

  // iOS: replace appId after downloading GoogleService-Info.plist
  // Firebase Console → Project Settings → iOS app
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBFdkglS6xnbnKz28Rcwpm92uke55wH4u0',
    appId: '1:230542805431:ios:1:230542805431:ios:b6a2a78d7268b90522c032',
    messagingSenderId: '230542805431',
    projectId: 'bin-authentication',
    storageBucket: 'bin-authentication.firebasestorage.app',
    iosBundleId: 'com.elvin.myapp',
  );

  // Web: replace appId after registering web app
  // Firebase Console → Project Settings → Web app
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBFdkglS6xnbnKz28Rcwpm92uke55wH4u0',
    appId: '1:230542805431:web:1:230542805431:web:8036e75acf50943a22c032',
    messagingSenderId: '230542805431',
    projectId: 'bin-authentication',
    storageBucket: 'bin-authentication.firebasestorage.app',
  );
}

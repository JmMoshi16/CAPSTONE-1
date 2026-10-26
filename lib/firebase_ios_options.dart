import 'package:firebase_core/firebase_core.dart';

/// Firebase settings for the iPhone app (registered 2026-10-27 in project ecoreward-bin, from its
/// GoogleService-Info.plist). Android reads android/app/google-services.json instead. These are public client
/// identifiers, like the Android file; access to the data is controlled by the Firestore rules.
const iosFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyB6j83XwH1E6JjxV6Da18RYsjfB8zEgKos',
  appId: '1:920769404414:ios:4e0a89f770e8e4a71534af',
  messagingSenderId: '920769404414',
  projectId: 'ecoreward-bin',
  storageBucket: 'ecoreward-bin.firebasestorage.app',
  iosBundleId: 'com.example.ecorewardBin',
);

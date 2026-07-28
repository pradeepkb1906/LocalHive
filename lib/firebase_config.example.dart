/// Template for the Firebase client configuration.
/// Copy this file to lib/firebase_config.dart and fill in the values from
/// Firebase console → Project settings → Your apps → SDK setup (Config).
/// lib/firebase_config.dart is gitignored so the values stay out of the repo
/// (they are public client identifiers, but the org secret scanner flags them).
library;

class FirebaseConfig {
  static const apiKey = 'YOUR_WEB_API_KEY';
  static const authDomain = 'YOUR_PROJECT.firebaseapp.com';
  static const projectId = 'YOUR_PROJECT_ID';
  static const storageBucket = 'YOUR_PROJECT.firebasestorage.app';
  static const messagingSenderId = 'YOUR_SENDER_ID';
  static const appId = 'YOUR_APP_ID';
}

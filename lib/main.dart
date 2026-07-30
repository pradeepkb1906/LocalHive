import 'package:flutter/material.dart';
import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'services/firebase_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.instance.init();
  AppState.instance.start();
  runApp(const LocalHiveApp());
}

class LocalHiveApp extends StatelessWidget {
  const LocalHiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LocalHive',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Sign-in is the front door: the demo accounts on it are how anyone —
      // Pradeep's friend included — picks a persona and gets in. Signing out
      // from anywhere lands back here, because the root listens to auth state
      // rather than navigating.
      home: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) => AppState.instance.signedIn
            ? const HomeShell()
            : const SignInScreen(),
      ),
    );
  }
}

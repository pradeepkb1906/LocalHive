import 'package:flutter/material.dart';
import 'app_state.dart';
import 'screens/home_screen.dart';
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
      home: const HomeShell(),
    );
  }
}

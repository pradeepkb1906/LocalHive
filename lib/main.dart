import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() => runApp(const LocalHiveApp());

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

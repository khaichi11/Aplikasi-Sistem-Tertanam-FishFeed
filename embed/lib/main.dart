import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_wrapper.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FishFeedApp());
}

/// Aplikasi pengendali alat pemberi pakan ikan otomatis berbasis ESP32.
class FishFeedApp extends StatelessWidget {
  const FishFeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FishFeed',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthWrapper(),
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/firebase_config.dart';
import 'data/demo_backend.dart';
import 'data/feeder_backend.dart';
import 'data/firebase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FishFeedApp(backend: await _createBackend()));
}

/// Memakai Firebase bila konfigurasinya diberikan saat build, dan mode demo
/// bila tidak. Dengan begitu aplikasi selalu bisa dijalankan.
Future<FeederBackend> _createBackend() async {
  if (FirebaseConfig.isConfigured && !FirebaseConfig.forceDemo) {
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      return FirebaseBackend();
    } catch (error) {
      debugPrint('Firebase gagal dimulai, beralih ke mode demo: $error');
    }
  }
  return DemoBackend();
}

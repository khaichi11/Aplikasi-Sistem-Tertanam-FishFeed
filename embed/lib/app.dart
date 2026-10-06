import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/feeder_backend.dart';
import 'state/device_controller.dart';
import 'ui/pages/home_shell.dart';
import 'ui/pages/login_page.dart';
import 'ui/theme/app_theme.dart';

class FishFeedApp extends StatelessWidget {
  const FishFeedApp({
    super.key,
    required this.backend,
    this.clock = DateTime.now,
  });

  final FeederBackend backend;

  /// Sumber waktu, bisa diganti di pengujian.
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [Provider.value(value: backend), Provider.value(value: clock)],
      child: MaterialApp(
        title: 'FishFeed',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AuthGate(),
      ),
    );
  }
}

/// Menampilkan halaman masuk atau aplikasi utama sesuai status akun.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = context.read<FeederBackend>();
    return StreamBuilder<AppUser?>(
      stream: backend.authChanges(),
      initialData: backend.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const LoginPage();
        return ChangeNotifierProvider(
          key: ValueKey(user.uid),
          create: (_) => DeviceController(backend: backend, user: user)..load(),
          child: const HomeShell(),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/feeder_backend.dart';
import 'state/device_controller.dart';
import 'ui/pages/home_shell.dart';
import 'ui/pages/login_page.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/feeding_loader.dart';
import 'ui/widgets/opening_intro.dart';

class FishFeedApp extends StatefulWidget {
  const FishFeedApp({
    super.key,
    required this.backend,
    this.clock = DateTime.now,
    this.intro = true,
  });

  final FeederBackend backend;

  /// Sumber waktu, bisa diganti di pengujian.
  final DateTime Function() clock;

  /// Tampilkan pembuka saat aplikasi dibuka (dimatikan di uji widget).
  final bool intro;

  @override
  State<FishFeedApp> createState() => _FishFeedAppState();
}

class _FishFeedAppState extends State<FishFeedApp> {
  late bool _introDone = !widget.intro;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.backend),
        Provider.value(value: widget.clock),
      ],
      child: MaterialApp(
        title: 'FishFeed',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child:
              _introDone
                  ? const AuthGate()
                  : OpeningIntro(
                    appName: 'FishFeed',
                    tagline: 'Pemberi pakan ikan otomatis',
                    mark: const FeedingLoader(),
                    hint: 'Ketuk akuarium untuk menabur pakan',
                    colors: const [AppColors.teal, AppColors.oceanDeep],
                    paper: AppColors.background,
                    accent: AppColors.ocean,
                    ink: AppColors.ink,
                    displayFont: 'Poppins',
                    bodyFont: 'Inter',
                    onDone: () => setState(() => _introDone = true),
                  ),
        ),
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

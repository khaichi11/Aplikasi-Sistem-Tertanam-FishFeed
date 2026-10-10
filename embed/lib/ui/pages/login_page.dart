import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/demo_backend.dart';
import '../../data/feeder_backend.dart';
import '../theme/app_theme.dart';
import '../widgets/logo.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn({String? email, String? password}) async {
    if (email == null && !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<FeederBackend>().signIn(
        email: email ?? _email.text,
        password: password ?? _password.text,
      );
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final demo = context.read<FeederBackend>().isDemo;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.xl,
                Gap.xl,
                Gap.xl,
                Gap.xl,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Masuk', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Pantau akuarium dan beri pakan ikan dari mana saja.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: Gap.xl),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: AuthValidators.email,
                    ),
                    const SizedBox(height: Gap.lg),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: 'Kata sandi',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip:
                              _hide
                                  ? 'Tampilkan kata sandi'
                                  : 'Sembunyikan kata sandi',
                          onPressed: () => setState(() => _hide = !_hide),
                          icon: Icon(
                            _hide
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: AuthValidators.password,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Gap.md),
                      Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.bad,
                        ),
                      ),
                    ],
                    const SizedBox(height: Gap.xl),
                    FilledButton(
                      onPressed: _busy ? null : _signIn,
                      child:
                          _busy
                              ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                              : const Text('Masuk'),
                    ),
                    if (demo) ...[
                      const SizedBox(height: Gap.md),
                      OutlinedButton.icon(
                        onPressed:
                            _busy
                                ? null
                                : () => _signIn(
                                  email: DemoBackend.demoEmail,
                                  password: 'demo123',
                                ),
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('Coba dengan akun demo'),
                      ),
                      const SizedBox(height: Gap.sm),
                      // keterangan singkat, bukan kotak peringatan: versi tanpa Firebase memang dimaksudkan untuk dicoba
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.science_outlined,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Mode demo',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              ' dengan perangkat simulasi',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Gap.lg),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Belum punya akun?',
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed:
                              _busy
                                  ? null
                                  : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SignUpPage(),
                                    ),
                                  ),
                          child: const Text('Daftar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kepala halaman bergradasi laut dengan logo dan gelombang.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipPath(
      clipper: const WaveClipper(),
      child: Container(
        width: double.infinity,
        color: AppColors.ocean,
        padding: EdgeInsets.fromLTRB(
          Gap.xl,
          MediaQuery.paddingOf(context).top + Gap.xl,
          Gap.xl,
          Gap.xxl + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const FishFeedLogo(size: 64),
            ),
            const SizedBox(height: Gap.lg),
            Text(
              'FishFeed',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            Text(
              'Pemberi pakan ikan otomatis berbasis ESP32',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Memotong bagian bawah kontainer menjadi gelombang lembut.
class WaveClipper extends CustomClipper<Path> {
  const WaveClipper();

  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;
    return Path()
      ..lineTo(0, h - 30)
      ..quadraticBezierTo(w * 0.25, h, w * 0.5, h - 22)
      ..quadraticBezierTo(w * 0.78, h - 44, w, h - 16)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(WaveClipper oldClipper) => false;
}

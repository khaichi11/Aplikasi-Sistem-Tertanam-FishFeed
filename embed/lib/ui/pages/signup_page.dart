import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/feeder_backend.dart';
import '../theme/app_theme.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await context.read<FeederBackend>().signUp(
        email: _email.text,
        password: _password.text,
      );
      navigator.popUntil((route) => route.isFirst);
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Buat akun', style: theme.textTheme.headlineSmall),
              const SizedBox(height: Gap.xs),
              Text(
                'Satu akun bisa memantau beberapa perangkat FishFeed.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: Gap.xl),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
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
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Kata sandi',
                  helperText: 'Minimal 6 karakter',
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
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _confirm,
                obscureText: _hide,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Ulangi kata sandi',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                validator:
                    (value) =>
                        value == _password.text
                            ? null
                            : 'Kata sandi tidak sama.',
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
                onPressed: _busy ? null : _submit,
                child: const Text('Daftar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

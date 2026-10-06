import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/feeder_backend.dart';
import '../../utils/formatting.dart';
import '../theme/app_theme.dart';

/// Menunggu perangkat menjalankan perintah pemberian pakan. Firmware menandai
/// perintah `done` setelah servo bergerak.
class FeedProgressPage extends StatefulWidget {
  const FeedProgressPage({
    super.key,
    required this.deviceId,
    this.timeout = const Duration(seconds: 45),
  });

  final String deviceId;

  /// Setelah ini halaman berhenti menunggu. Perangkat yang sedang tidur
  /// tetap menjalankan perintah saat bangun.
  final Duration timeout;

  @override
  State<FeedProgressPage> createState() => _FeedProgressPageState();
}

enum _Phase { waiting, done, timedOut }

class _FeedProgressPageState extends State<FeedProgressPage> {
  StreamSubscription<CommandStatus>? _subscription;
  Timer? _timer;
  _Phase _phase = _Phase.waiting;
  late final DateTime _sentAt;

  @override
  void initState() {
    super.initState();
    _sentAt = context.read<DateTime Function()>()();
    _subscription = context
        .read<FeederBackend>()
        .watchCommandStatus(widget.deviceId)
        .listen((status) {
          if (status == CommandStatus.done && _phase == _Phase.waiting) {
            _timer?.cancel();
            setState(() => _phase = _Phase.done);
          }
        });
    _timer = Timer(widget.timeout, () {
      if (mounted && _phase == _Phase.waiting) {
        setState(() => _phase = _Phase.timedOut);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, message) = switch (_phase) {
      _Phase.waiting => (
        'Mengirim pakan...',
        'Menunggu perangkat ${widget.deviceId} menjatuhkan pakan.',
      ),
      _Phase.done => (
        'Pakan sudah diberikan!',
        'Perangkat memberi pakan pukul ${formatClock(_sentAt)}. Ikanmu '
            'sudah kenyang.',
      ),
      _Phase.timedOut => (
        'Perintah terkirim',
        'Perangkat belum merespons, mungkin sedang mode hemat daya. Pakan '
            'akan diberikan begitu perangkat aktif kembali.',
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Beri makan')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            children: [
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder:
                    (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                child: switch (_phase) {
                  _Phase.waiting => const SizedBox(
                    key: ValueKey('waiting'),
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      strokeWidth: 8,
                      color: AppColors.coral,
                    ),
                  ),
                  _Phase.done => const _Badge(
                    key: ValueKey('done'),
                    icon: Icons.check_rounded,
                    color: AppColors.good,
                  ),
                  _Phase.timedOut => const _Badge(
                    key: ValueKey('timeout'),
                    icon: Icons.schedule_send_rounded,
                    color: AppColors.ocean,
                  ),
                },
              ),
              const SizedBox(height: Gap.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: Gap.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    _phase == _Phase.waiting ? 'Tutup' : 'Kembali ke beranda',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 48),
        ),
      ),
    );
  }
}

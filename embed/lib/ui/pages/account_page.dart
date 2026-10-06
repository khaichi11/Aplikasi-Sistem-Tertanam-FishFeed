import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/feeder_backend.dart';
import '../../state/device_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'about_page.dart';
import 'device_manager_page.dart';

const appVersion = '1.1.0';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final backend = context.read<FeederBackend>();
    final ok = await confirm(
      context,
      title: 'Keluar dari akun?',
      message: 'Perangkat tetap berjalan sesuai jadwal walaupun kamu keluar.',
      confirmLabel: 'Keluar',
    );
    if (ok) await backend.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<DeviceController>();
    final backend = context.read<FeederBackend>();
    final email = controller.user.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.sky,
                  child: Text(
                    email.isEmpty ? '?' : email[0].toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.ocean,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      backend.isDemo
                          ? const DemoBadge()
                          : const StatusPill(
                            label: 'Terhubung ke Firebase',
                            icon: Icons.cloud_done_outlined,
                            color: AppColors.good,
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xl),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const IconTile(
                    icon: Icons.devices_other_rounded,
                    size: 40,
                  ),
                  title: const Text('Kelola perangkat'),
                  subtitle: Text(
                    '${controller.devices.length} perangkat terpasang',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openDeviceManager(context),
                ),
                const Divider(indent: 72),
                ListTile(
                  leading: const IconTile(
                    icon: Icons.info_outline_rounded,
                    size: 40,
                    color: AppColors.tealSoft,
                    foreground: AppColors.teal,
                  ),
                  title: const Text('Tentang FishFeed'),
                  subtitle: const Text('Cara kerja, sensor, dan ambang batas'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AboutPage(),
                        ),
                      ),
                ),
                const Divider(indent: 72),
                ListTile(
                  leading: const IconTile(
                    icon: Icons.logout_rounded,
                    size: 40,
                    color: AppColors.badSoft,
                    foreground: AppColors.bad,
                  ),
                  title: Text(
                    'Keluar',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.bad,
                    ),
                  ),
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xl),
          Text(
            'FishFeed $appVersion',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

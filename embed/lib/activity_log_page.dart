import 'package:flutter/material.dart';

import 'models/activity_entry.dart';
import 'services/feeder_service.dart';
import 'theme/app_theme.dart';
import 'utils/formatting.dart';

/// Menampilkan riwayat aktivitas perangkat secara langsung dari Firebase,
/// mencakup pemberian pakan manual, terjadwal, dan perubahan jadwal.
class ActivityLogPage extends StatelessWidget {
  final String deviceId;
  final FeederService service;

  const ActivityLogPage({
    super.key,
    required this.deviceId,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Aktivitas')),
      body: StreamBuilder<List<ActivityEntry>>(
        stream: service.activityStream(deviceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data ?? const [];
          if (logs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada aktivitas tercatat.',
                style: TextStyle(color: AppColors.neutral),
              ),
            );
          }
          return ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final log = logs[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: log.isFeed
                      ? AppColors.good.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.15),
                  child: Icon(
                    log.isFeed ? Icons.restaurant : Icons.schedule,
                    color: log.isFeed ? AppColors.good : AppColors.primary,
                  ),
                ),
                title: Text(log.title),
                subtitle: Text(formatTimestamp(log.timestamp)),
                trailing: Text(
                  log.source == 'device' ? 'Perangkat' : 'Aplikasi',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.neutral,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

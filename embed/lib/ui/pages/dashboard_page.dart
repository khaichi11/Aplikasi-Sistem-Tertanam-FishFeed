import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/feeder_backend.dart';
import '../../logic/activity_stats.dart';
import '../../logic/device_alerts.dart';
import '../../logic/schedule_logic.dart';
import '../../logic/sensor_status.dart';
import '../../models/device_snapshot.dart';
import '../../state/device_controller.dart';
import '../../utils/formatting.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_tile.dart';
import '../widgets/common.dart';
import '../widgets/gauges.dart';
import '../widgets/live_data.dart';
import 'device_manager_page.dart';
import 'feed_progress_page.dart';
import 'home_shell.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceController>();
    final id = controller.selectedId;

    Widget body;
    if (controller.loading && controller.devices.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (controller.error != null && controller.devices.isEmpty) {
      body = _Message(
        child: EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Tidak dapat memuat data',
          message: controller.error!,
          action: FilledButton(
            onPressed: controller.load,
            child: const Text('Coba lagi'),
          ),
        ),
      );
    } else if (id == null) {
      body = _Message(
        child: EmptyState(
          icon: Icons.router_outlined,
          title: 'Belum ada perangkat',
          message:
              'Pasangkan alat FishFeed dengan ID yang tercetak di '
              'perangkat untuk mulai memantau akuarium.',
          action: FilledButton.icon(
            onPressed: () => openDeviceManager(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah perangkat'),
          ),
        ),
      );
    } else {
      body = DeviceBuilder(
        deviceId: id,
        builder:
            (context, device) =>
                _DashboardContent(device: device ?? DeviceSnapshot(id: id)),
      );
    }
    return Scaffold(body: body);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(device: null),
        Expanded(child: Center(child: SingleChildScrollView(child: child))),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.device});

  final DeviceSnapshot device;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<DeviceController>();
    final now = context.read<DateTime Function()>()();
    final alerts = deviceAlerts(device, now);
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(device: device),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final alert in alerts) ...[
                  _AlertCard(alert: alert),
                  const SizedBox(height: Gap.sm),
                ],
                if (alerts.isNotEmpty) const SizedBox(height: Gap.md),
                const SectionHeader('Kondisi akuarium'),
                _Gauges(device: device),
                const SizedBox(height: Gap.xl),
                const _NextFeedingCard(),
                const SizedBox(height: Gap.lg),
                _FeedButton(
                  enabled: device.id.isNotEmpty,
                  empty:
                      feedLevelStatus(device.distanceCm).severity ==
                      Severity.bad,
                ),
                const SizedBox(height: Gap.xl),
                _WeeklyCard(deviceId: device.id),
                const SizedBox(height: Gap.xl),
                SectionHeader(
                  'Aktivitas terbaru',
                  actionLabel: 'Lihat semua',
                  onAction: () => HomeShell.of(context)?.open(HomeTab.activity),
                ),
                _RecentActivity(deviceId: device.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.device});

  final DeviceSnapshot? device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<DeviceController>();
    final backend = context.read<FeederBackend>();
    final now = context.read<DateTime Function()>()();
    final name = controller.user.email.split('@').first;
    final device = this.device;
    final muted = Colors.white.withValues(alpha: 0.8);

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.lg),
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        MediaQuery.paddingOf(context).top + Gap.md,
        Gap.lg,
        Gap.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.ocean,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radii.lg)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, $name',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                    Text(
                      'Akuarium kamu',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (backend.isDemo) const DemoBadge(onDark: true),
            ],
          ),
          if (device != null) ...[
            const SizedBox(height: Gap.lg),
            Material(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(Radii.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.md),
                onTap: () => _pickDevice(context),
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.set_meal_rounded,
                          color: AppColors.ocean,
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${device.id} · ${timeAgo(device.updatedAt, now)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: isReachable(device, now) ? 'Online' : 'Offline',
                        color:
                            isReachable(device, now)
                                ? const Color(0xFFB5EAD0)
                                : Colors.white70,
                        background: Colors.white.withValues(alpha: 0.16),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDevice(BuildContext context) async {
    final controller = context.read<DeviceController>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final id in controller.devices)
                  ListTile(
                    leading: const IconTile(
                      icon: Icons.set_meal_rounded,
                      size: 40,
                    ),
                    title: Text(id),
                    trailing:
                        id == controller.selectedId
                            ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.teal,
                            )
                            : null,
                    onTap: () => Navigator.of(context).pop(id),
                  ),
                ListTile(
                  leading: const IconTile(
                    icon: Icons.tune_rounded,
                    size: 40,
                    color: AppColors.tealSoft,
                    foreground: AppColors.teal,
                  ),
                  title: const Text('Kelola perangkat'),
                  onTap: () => Navigator.of(context).pop('__manage__'),
                ),
                const SizedBox(height: Gap.sm),
              ],
            ),
          ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == '__manage__') {
      await openDeviceManager(context);
    } else {
      await controller.select(choice);
    }
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final DeviceAlert alert;

  @override
  Widget build(BuildContext context) {
    final critical = alert.level == AlertLevel.critical;
    return NoticeBox(
      icon:
          critical ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
      title: alert.title,
      text: alert.message,
      color: critical ? AppColors.badSoft : AppColors.warningSoft,
      iconColor: critical ? AppColors.bad : const Color(0xFFB7791F),
    );
  }
}

class _Gauges extends StatelessWidget {
  const _Gauges({required this.device});

  final DeviceSnapshot device;

  @override
  Widget build(BuildContext context) {
    final feed = feedLevelStatus(device.distanceCm);
    final water = turbidityStatus(device.turbidityNtu);
    final battery = batteryStatus(device.batteryPercent);
    final ntu = device.turbidityNtu;
    final clarity = ntu == null ? 0.0 : (1 - ntu / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: _GaugeCard(
            title: 'Pakan',
            status: feed,
            value: feedLevelFraction(device.distanceCm),
            center:
                device.distanceCm == null
                    ? '-'
                    : '${(feedLevelFraction(device.distanceCm) * 100).round()}%',
            detail:
                device.distanceCm == null
                    ? 'Belum ada data'
                    : 'Jarak ${device.distanceCm!.toStringAsFixed(1)} cm',
            icon: Icons.set_meal_outlined,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: _GaugeCard(
            title: 'Air',
            status: water,
            value: clarity,
            center: ntu == null ? '-' : ntu.toStringAsFixed(0),
            unit: 'NTU',
            detail: 'Kekeruhan',
            icon: Icons.water_drop_outlined,
          ),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: _GaugeCard(
            title: 'Baterai',
            status: battery,
            value: (device.batteryPercent ?? 0) / 100,
            center:
                device.batteryPercent == null
                    ? '-'
                    : '${device.batteryPercent}%',
            detail:
                device.batteryVoltage == null
                    ? 'Belum ada data'
                    : '${device.batteryVoltage!.toStringAsFixed(2)} V',
            icon: Icons.battery_charging_full_rounded,
          ),
        ),
      ],
    );
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({
    required this.title,
    required this.status,
    required this.value,
    required this.center,
    required this.detail,
    required this.icon,
    this.unit,
  });

  final String title;
  final StatusInfo status;
  final double value;
  final String center;
  final String? unit;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.forSeverity(status.severity);
    final label =
        title == 'Baterai' && status.severity != Severity.unknown
            ? switch (status.severity) {
              Severity.good => 'Baik',
              Severity.warning => 'Sedang',
              _ => 'Rendah',
            }
            : status.label;
    return Semantics(
      label: '$title: $label, $center ${unit ?? ''}',
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.sm,
          vertical: Gap.md,
        ),
        child: ExcludeSemantics(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              RingGauge(
                value: value,
                color: color,
                size: 78,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(center, style: theme.textTheme.titleMedium),
                    if (unit != null)
                      Text(unit!, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              const SizedBox(height: Gap.sm),
              StatusPill(label: label, color: color),
              const SizedBox(height: 4),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextFeedingCard extends StatelessWidget {
  const _NextFeedingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = context.watch<DeviceController>().schedule;
    final now = context.read<DateTime Function()>()();
    final next = nextFeeding(schedule, now);
    final times = schedule.enabledEntries.map((e) => e.time).toList();

    return AppCard(
      onTap: () => HomeShell.of(context)?.open(HomeTab.schedule),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.alarm_rounded,
                color: AppColors.tealSoft,
                foreground: AppColors.teal,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pemberian pakan berikutnya',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      next == null ? 'Tidak terjadwal' : formatClock(next),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          next == null
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: StatusPill(
                  label: schedule.active ? 'Otomatis aktif' : 'Otomatis mati',
                  color: schedule.active ? AppColors.good : AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            next == null
                ? 'Atur jadwal agar FishFeed memberi pakan sendiri.'
                : _sentence(timeUntil(next, now)) +
                    (next.day != now.day ? ' (besok)' : ''),
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          if (times.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final time in times)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sky,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      time,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.ocean,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _sentence(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

class _FeedButton extends StatelessWidget {
  const _FeedButton({required this.enabled, this.empty = false});

  final bool enabled;

  /// Wadah pakan terbaca kosong: perintah tetap boleh dikirim, tetapi
  /// pengguna diberi tahu bahwa mungkin tidak ada pakan yang jatuh.
  final bool empty;

  Future<void> _feed(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Beri makan sekarang?',
      message:
          empty
              ? 'Wadah pakan terbaca kosong, jadi mungkin tidak ada pakan yang '
                  'jatuh. Isi ulang wadah terlebih dahulu bila memungkinkan.'
              : 'Perintah dikirim ke perangkat. Satu porsi pakan akan '
                  'dijatuhkan saat perangkat menerimanya.',
      confirmLabel: 'Beri makan',
    );
    if (!ok || !context.mounted) return;
    final controller = context.read<DeviceController>();
    final deviceId = controller.selectedId!;
    try {
      await controller.feedNow();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FeedProgressPage(deviceId: deviceId),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        showMessage(
          context,
          'Perintah gagal dikirim. Periksa koneksi internet.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Beri makan sekarang',
      excludeSemantics: true,
      child: Material(
        borderRadius: BorderRadius.circular(Radii.md),
        clipBehavior: Clip.antiAlias,
        color: AppColors.coral,
        child: Ink(
          child: InkWell(
            onTap: enabled ? () => _feed(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.lg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Beri makan sekarang',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Kirim satu porsi pakan ke akuarium',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.ink.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: AppColors.ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = context.read<DateTime Function()>()();
    return ActivityBuilder(
      deviceId: deviceId,
      builder: (context, entries) {
        final list = entries ?? const [];
        final counts = feedsPerDay(list, now);
        final labels = [
          for (var i = 6; i >= 0; i--)
            i == 0 ? 'Hari ini' : weekdayShort(now.subtract(Duration(days: i))),
        ];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pemberian pakan 7 hari',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  StatusPill(
                    label: '${counts.last}x hari ini',
                    color: AppColors.teal,
                    icon: Icons.restaurant_rounded,
                  ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              WeeklyBars(values: counts, labels: labels),
            ],
          ),
        );
      },
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return ActivityBuilder(
      deviceId: deviceId,
      builder: (context, entries) {
        if (entries == null) {
          return const Padding(
            padding: EdgeInsets.all(Gap.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (entries.isEmpty) {
          return const AppCard(child: Text('Belum ada aktivitas tercatat.'));
        }
        return Card(
          child: Column(
            children: [
              for (var i = 0; i < entries.length && i < 3; i++) ...[
                if (i > 0) const Divider(indent: 72),
                ActivityTile(entry: entries[i], showDate: true),
              ],
            ],
          ),
        );
      },
    );
  }
}

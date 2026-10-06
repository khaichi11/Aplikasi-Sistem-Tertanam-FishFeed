import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/activity_stats.dart';
import '../../models/activity_entry.dart';
import '../../state/device_controller.dart';
import '../../utils/formatting.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_tile.dart';
import '../widgets/common.dart';
import '../widgets/live_data.dart';

enum _Filter {
  all('Semua'),
  manual('Manual'),
  auto('Otomatis'),
  schedule('Jadwal');

  const _Filter(this.label);
  final String label;

  bool matches(ActivityEntry entry) => switch (this) {
    _Filter.all => true,
    _Filter.manual => entry.isFeed && !entry.isAutomatic,
    _Filter.auto => entry.isAutomatic,
    _Filter.schedule => !entry.isFeed,
  };
}

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceController>();
    final id = controller.selectedId;
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat aktivitas')),
      body:
          id == null
              ? const Center(
                child: EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Belum ada perangkat',
                  message: 'Riwayat muncul setelah perangkat dipasangkan.',
                ),
              )
              : ActivityBuilder(
                deviceId: id,
                builder: (context, entries) {
                  if (entries == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _buildList(context, entries);
                },
              ),
    );
  }

  Widget _buildList(BuildContext context, List<ActivityEntry> entries) {
    final theme = Theme.of(context);
    final now = context.read<DateTime Function()>()();
    final filtered = entries.where(_filter.matches).toList();
    final groups = <String, List<ActivityEntry>>{};
    for (final entry in filtered) {
      final time = entry.time;
      final key = time == null ? 'Waktu tidak diketahui' : dayLabel(time, now);
      groups.putIfAbsent(key, () => []).add(entry);
    }
    final week = feedsPerDay(entries, now).fold<int>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Pakan hari ini',
                value: '${feedsToday(entries, now)}x',
                color: AppColors.amberInk,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: _Stat(
                label: '7 hari terakhir',
                value: '${week}x',
                color: AppColors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: Gap.sm),
                  child: ChoiceChip(
                    label: Text(filter.label),
                    selected: _filter == filter,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        if (filtered.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Tidak ada aktivitas',
            message: 'Belum ada aktivitas untuk pilihan ini.',
          )
        else
          for (final MapEntry(key: day, value: items) in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm, top: Gap.sm),
              child: Text(
                day,
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 12),
              ),
            ),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const Divider(indent: 72),
                    ActivityTile(entry: items[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Gap.md),
          ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/schedule_logic.dart';
import '../../models/feed_schedule.dart';
import '../../state/device_controller.dart';
import '../../utils/formatting.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Jadwal pemberian pakan otomatis. Perubahan disimpan sekaligus dengan
/// tombol Simpan, lalu dijalankan firmware berdasarkan jam RTC-nya sendiri.
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  FeedSchedule? _draft;
  FeedSchedule? _source;
  bool _saving = false;

  static const _presets = [
    ('Pagi', '07:00'),
    ('Siang', '12:00'),
    ('Sore', '17:00'),
  ];

  bool get _dirty =>
      _draft != null &&
      _source != null &&
      _draft!.toMap().toString() != _source!.toMap().toString();

  void _syncWith(FeedSchedule schedule) {
    if (!identical(schedule, _source)) {
      _source = schedule;
      _draft = schedule;
    }
  }

  void _update(FeedSchedule schedule) => setState(() => _draft = schedule);

  void _addTime(String time) {
    final draft = _draft!;
    if (draft.entries.any((entry) => entry.time == time)) {
      showMessage(context, 'Waktu $time sudah ada di jadwal.');
      return;
    }
    final now = context.read<DateTime Function()>()();
    _update(
      FeedSchedule(
        active: draft.entries.isEmpty ? true : draft.active,
        entries: [
          ...draft.entries,
          ScheduleEntry(id: 't${now.microsecondsSinceEpoch}', time: time),
        ]..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay)),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Pilih waktu pemberian pakan',
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
    );
    if (picked != null) _addTime(formatHourMinute(picked.hour, picked.minute));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<DeviceController>().saveSchedule(_draft!);
      if (mounted) {
        showMessage(context, 'Jadwal tersimpan dan dikirim ke perangkat.');
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Jadwal gagal disimpan. Periksa koneksi internet.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<DeviceController>();
    if (!controller.hasDevice) {
      return Scaffold(
        appBar: AppBar(title: const Text('Jadwal pakan')),
        body: const Center(
          child: EmptyState(
            icon: Icons.schedule_rounded,
            title: 'Belum ada perangkat',
            message: 'Pasangkan perangkat FishFeed dulu untuk mengatur jadwal.',
          ),
        ),
      );
    }
    _syncWith(controller.schedule);
    final draft = _draft!;
    final now = context.read<DateTime Function()>()();
    final next = nextFeeding(draft, now);
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal pakan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickTime,
        backgroundColor: AppColors.ocean,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Tambah waktu'),
      ),
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child:
            _dirty
                ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      Gap.sm,
                      Gap.lg,
                      Gap.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _saving
                                    ? null
                                    : () => setState(() => _draft = _source),
                            child: const Text('Batalkan'),
                          ),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Simpan jadwal'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                : const SizedBox.shrink(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, 120),
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.sm, Gap.sm),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: draft.active,
              onChanged:
                  (value) => _update(
                    FeedSchedule(active: value, entries: draft.entries),
                  ),
              title: Text(
                'Pemberian pakan otomatis',
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                next == null
                    ? 'Tidak ada pemberian pakan terjadwal.'
                    : 'Berikutnya pukul ${formatClock(next)}, ${timeUntil(next, now)}.',
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final (label, time) in _presets)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text('$label $time'),
                  onPressed: () => _addTime(time),
                ),
            ],
          ),
          const SizedBox(height: Gap.xl),
          SectionHeader('Waktu pemberian pakan (${draft.entries.length})'),
          if (draft.entries.isEmpty)
            const AppCard(
              child: Text('Belum ada waktu. Tambahkan dengan tombol di bawah.'),
            )
          else
            for (final entry in draft.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: _TimeCard(
                  entry: entry,
                  scheduleActive: draft.active,
                  ranToday: entry.lastRun == today,
                  onToggle:
                      (value) => _update(
                        FeedSchedule(
                          active: draft.active,
                          entries: [
                            for (final e in draft.entries)
                              e.id == entry.id ? e.copyWith(enabled: value) : e,
                          ],
                        ),
                      ),
                  onDelete:
                      () => _update(
                        FeedSchedule(
                          active: draft.active,
                          entries:
                              draft.entries
                                  .where((e) => e.id != entry.id)
                                  .toList(),
                        ),
                      ),
                ),
              ),
          const SizedBox(height: Gap.md),
          const NoticeBox(
            icon: Icons.memory_rounded,
            text:
                'Jadwal disimpan di perangkat dan dijalankan berdasarkan jam '
                'RTC, jadi tetap berjalan walaupun ponsel mati.',
          ),
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.entry,
    required this.scheduleActive,
    required this.ranToday,
    required this.onToggle,
    required this.onDelete,
  });

  final ScheduleEntry entry;
  final bool scheduleActive;
  final bool ranToday;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = entry.enabled && scheduleActive;
    final lastRun = DateTime.tryParse(entry.lastRun);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.xs, Gap.md),
      child: Row(
        children: [
          Text(
            entry.time,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: active ? AppColors.ink : AppColors.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: Gap.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(entry.minutesOfDay),
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  ranToday
                      ? 'Sudah diberikan hari ini'
                      : lastRun == null
                      ? 'Belum pernah dijalankan'
                      : 'Terakhir ${dayLabel(lastRun, context.read<DateTime Function()>()()).toLowerCase()}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(value: entry.enabled, onChanged: onToggle),
          IconButton(
            tooltip: 'Hapus ${entry.time}',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  static String _label(int minutes) {
    final hour = minutes ~/ 60;
    if (hour < 11) return 'Pagi';
    if (hour < 15) return 'Siang';
    if (hour < 19) return 'Sore';
    return 'Malam';
  }
}

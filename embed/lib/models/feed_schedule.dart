/// Satu waktu pemberian pakan otomatis.
class ScheduleEntry {
  const ScheduleEntry({
    required this.id,
    required this.time,
    this.enabled = true,
    this.lastRun = '',
  });

  /// Kunci entri di Realtime Database.
  final String id;

  /// Waktu format 24 jam `HH:mm`.
  final String time;
  final bool enabled;

  /// Tanggal `YYYY-MM-DD` terakhir entri ini dijalankan firmware.
  final String lastRun;

  int get minutesOfDay {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  ScheduleEntry copyWith({bool? enabled}) => ScheduleEntry(
    id: id,
    time: time,
    enabled: enabled ?? this.enabled,
    lastRun: lastRun,
  );

  Map<String, dynamic> toMap() => {
    'time': time,
    'enabled': enabled,
    'last_run': lastRun,
  };
}

/// Jadwal pemberian pakan di `schedules/{id}`. Formatnya dibaca langsung oleh
/// firmware ESP32, jadi jangan diubah tanpa menyesuaikan firmware.
class FeedSchedule {
  const FeedSchedule({this.active = false, this.entries = const []});

  factory FeedSchedule.fromMap(Map<dynamic, dynamic>? data) {
    if (data == null) return const FeedSchedule();
    final raw = data['entries'] is Map ? data['entries'] as Map : const {};
    final entries = <ScheduleEntry>[
      for (final MapEntry(:key, :value) in raw.entries)
        if (value is Map)
          ScheduleEntry(
            id: key.toString(),
            time: value['time']?.toString() ?? '00:00',
            enabled: value['enabled'] == true,
            lastRun: value['last_run']?.toString() ?? '',
          ),
    ]..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    return FeedSchedule(active: data['active'] == true, entries: entries);
  }

  final bool active;

  /// Urut dari pagi ke malam.
  final List<ScheduleEntry> entries;

  List<ScheduleEntry> get enabledEntries =>
      entries.where((entry) => entry.enabled).toList();

  Map<String, dynamic> toMap() => {
    'active': active,
    'entries': {for (final entry in entries) entry.id: entry.toMap()},
  };
}

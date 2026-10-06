/// Satu baris riwayat aktivitas perangkat di `activity/{id}`.
///
/// Aktivitas berasal dari aplikasi (pemberian pakan manual, perubahan jadwal)
/// maupun dari firmware ESP32 (pemberian pakan terjadwal).
class ActivityEntry {
  const ActivityEntry({
    required this.type,
    required this.timestamp,
    required this.source,
    this.mode,
  });

  factory ActivityEntry.fromMap(Map<dynamic, dynamic> map) {
    return ActivityEntry(
      type: (map['type'] ?? 'feed').toString(),
      mode: map['mode']?.toString(),
      timestamp: (map['timestamp'] ?? '').toString(),
      source: (map['source'] ?? 'app').toString(),
    );
  }

  /// `feed` atau `schedule_update`.
  final String type;

  /// `manual` atau `auto` untuk pemberian pakan.
  final String? mode;

  /// Waktu kejadian, ISO 8601.
  final String timestamp;

  /// `app` atau `device`.
  final String source;

  Map<String, dynamic> toMap() => {
    'type': type,
    if (mode != null) 'mode': mode,
    'timestamp': timestamp,
    'source': source,
  };

  bool get isFeed => type == 'feed';
  bool get isAutomatic => isFeed && mode == 'auto';
  bool get fromDevice => source == 'device';
  DateTime? get time => DateTime.tryParse(timestamp);

  String get title {
    if (!isFeed) return 'Jadwal diperbarui';
    return isAutomatic ? 'Pakan otomatis' : 'Pakan manual';
  }

  String get subtitle {
    if (!isFeed) return 'Jadwal pemberian pakan diubah dari aplikasi';
    return isAutomatic
        ? 'Diberikan perangkat sesuai jadwal'
        : 'Diminta dari aplikasi';
  }
}

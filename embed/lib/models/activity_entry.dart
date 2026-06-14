/// Satu baris riwayat aktivitas perangkat.
///
/// Aktivitas dapat berasal dari aplikasi (pemberian pakan manual, perubahan
/// jadwal) maupun dari firmware ESP32 (pemberian pakan terjadwal).
class ActivityEntry {
  /// Jenis aktivitas: `feed` atau `schedule_update`.
  final String type;

  /// Mode pemberian pakan: `manual` atau `auto`. Kosong untuk jenis lain.
  final String? mode;

  /// Waktu kejadian dalam format ISO 8601.
  final String timestamp;

  /// Asal aktivitas: `app` atau `device`.
  final String source;

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

  Map<String, dynamic> toMap() => {
        'type': type,
        if (mode != null) 'mode': mode,
        'timestamp': timestamp,
        'source': source,
      };

  bool get isFeed => type == 'feed';

  /// Judul siap tampil dalam bahasa Indonesia.
  String get title {
    if (isFeed) {
      final label = mode == 'auto' ? 'Otomatis' : 'Manual';
      return 'Pemberian Pakan ($label)';
    }
    return 'Jadwal Diperbarui';
  }
}

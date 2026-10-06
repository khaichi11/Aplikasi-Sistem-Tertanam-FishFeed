/// Kondisi terbaru satu perangkat FishFeed seperti yang ditulis firmware ke
/// `devices/{id}` di Realtime Database.
class DeviceSnapshot {
  const DeviceSnapshot({
    required this.id,
    this.name,
    this.online = false,
    this.turbidityNtu,
    this.distanceCm,
    this.batteryPercent,
    this.batteryVoltage,
    this.updatedAt,
    this.lastSeen,
  });

  factory DeviceSnapshot.fromMap(String id, Map<dynamic, dynamic> data) {
    final info = data['info'] is Map ? data['info'] as Map : const {};
    final status = data['status'] is Map ? data['status'] as Map : const {};
    final sensors = data['sensors'] is Map ? data['sensors'] as Map : const {};
    return DeviceSnapshot(
      id: id,
      name: info['name']?.toString(),
      online: status['online'] == true,
      turbidityNtu: _number(sensors['turbidity']),
      // Firmware lama mengirim -1 saat pembacaan gagal.
      distanceCm: _nonNegative(_number(sensors['distance_cm'])),
      batteryPercent: _number(sensors['battery_percent'])?.round(),
      batteryVoltage: _number(sensors['battery_voltage']),
      updatedAt: sensors['timestamp']?.toString(),
      lastSeen: status['last_seen']?.toString(),
    );
  }

  final String id;
  final String? name;
  final bool online;
  final double? turbidityNtu;

  /// Jarak sensor ultrasonik ke permukaan pakan. Makin besar, makin kosong.
  final double? distanceCm;
  final int? batteryPercent;
  final double? batteryVoltage;

  /// Waktu pembacaan sensor terakhir (ISO 8601).
  final String? updatedAt;

  /// Waktu perangkat terakhir bangun (ISO 8601).
  final String? lastSeen;

  /// Kabar terbaru dari perangkat, dari sensor atau status.
  DateTime? get lastContact {
    final times =
        [updatedAt, lastSeen]
            .map((value) => DateTime.tryParse(value ?? ''))
            .whereType<DateTime>()
            .toList();
    if (times.isEmpty) return null;
    return times.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  String get displayName => (name == null || name!.isEmpty) ? id : name!;

  bool get hasSensorData =>
      turbidityNtu != null || distanceCm != null || batteryPercent != null;

  static double? _nonNegative(double? value) =>
      value == null || value < 0 ? null : value;

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

// Logika interpretasi data sensor.
//
// Berkas ini sengaja tidak bergantung pada Flutter agar dapat diuji secara
// terpisah. Pemetaan tingkat keparahan ke warna ditangani di lapisan tema.

/// Tingkat keparahan sebuah pembacaan sensor, dipakai untuk menentukan warna
/// indikator pada antarmuka.
enum Severity { good, warning, bad, unknown }

/// Hasil interpretasi satu pembacaan sensor: label siap tampil beserta
/// tingkat keparahannya.
class StatusInfo {
  final String label;
  final Severity severity;

  const StatusInfo(this.label, this.severity);
}

/// Ambang batas yang dipakai bersama oleh aplikasi.
///
/// Nilai-nilai ini mencerminkan kalibrasi sensor pada firmware ESP32 dan
/// dikumpulkan di satu tempat agar mudah disesuaikan.
class SensorThresholds {
  SensorThresholds._();

  /// Jarak (cm) dari sensor ultrasonik ke permukaan pakan.
  /// Jarak yang lebih besar berarti wadah lebih kosong.
  static const double feedEmptyCm = 5.0;
  static const double feedHalfCm = 3.0;

  /// Kekeruhan air dalam NTU; di atas nilai ini air dianggap keruh.
  static const double turbidityCloudyNtu = 50.0;

  /// Persentase baterai untuk batas peringatan dan kritis.
  static const int batteryLowPercent = 20;
  static const int batteryMediumPercent = 50;
}

/// Menentukan status persediaan pakan dari jarak sensor ultrasonik.
StatusInfo feedLevelStatus(num? distanceCm) {
  if (distanceCm == null) return const StatusInfo('Tidak diketahui', Severity.unknown);
  if (distanceCm > SensorThresholds.feedEmptyCm) {
    return const StatusInfo('Kosong', Severity.bad);
  }
  if (distanceCm > SensorThresholds.feedHalfCm) {
    return const StatusInfo('Setengah', Severity.warning);
  }
  return const StatusInfo('Penuh', Severity.good);
}

/// Menentukan status kekeruhan air dari pembacaan NTU.
StatusInfo turbidityStatus(num? ntu) {
  if (ntu == null) return const StatusInfo('Tidak diketahui', Severity.unknown);
  if (ntu > SensorThresholds.turbidityCloudyNtu) {
    return const StatusInfo('Keruh', Severity.bad);
  }
  return const StatusInfo('Jernih', Severity.good);
}

/// Menentukan status baterai dari persentase daya.
StatusInfo batteryStatus(int? percent) {
  if (percent == null) return const StatusInfo('Tidak diketahui', Severity.unknown);
  if (percent <= SensorThresholds.batteryLowPercent) {
    return StatusInfo('$percent%', Severity.bad);
  }
  if (percent <= SensorThresholds.batteryMediumPercent) {
    return StatusInfo('$percent%', Severity.warning);
  }
  return StatusInfo('$percent%', Severity.good);
}

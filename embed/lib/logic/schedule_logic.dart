import '../models/feed_schedule.dart';
import 'sensor_status.dart';

/// Waktu pemberian pakan otomatis berikutnya, atau null bila penjadwalan
/// nonaktif atau tidak ada waktu yang diaktifkan.
DateTime? nextFeeding(FeedSchedule schedule, DateTime now) {
  if (!schedule.active) return null;
  final enabled = schedule.enabledEntries;
  if (enabled.isEmpty) return null;
  final nowMinutes = now.hour * 60 + now.minute;
  final today = DateTime(now.year, now.month, now.day);
  for (final entry in enabled) {
    if (entry.minutesOfDay > nowMinutes) {
      return today.add(Duration(minutes: entry.minutesOfDay));
    }
  }
  return today.add(Duration(days: 1, minutes: enabled.first.minutesOfDay));
}

/// Teks singkat seperti "2 jam 15 menit lagi" atau "5 menit lagi".
String timeUntil(DateTime target, DateTime now) {
  final minutes = (target.difference(now).inSeconds / 60).ceil();
  if (minutes <= 1) return 'sebentar lagi';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest menit lagi';
  if (rest == 0) return '$hours jam lagi';
  return '$hours jam $rest menit lagi';
}

/// Mengubah jam dan menit menjadi teks `HH:mm`.
String formatHourMinute(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Persentase isi wadah pakan dari jarak sensor ultrasonik, memakai ambang
/// yang sama dengan [feedLevelStatus]: jarak penuh atau kurang dianggap 100%,
/// dan jarak kosong atau lebih dianggap 0%.
double feedLevelFraction(
  double? distanceCm, {
  double emptyCm = SensorThresholds.feedEmptyCm,
  double fullCm = SensorThresholds.feedFullCm,
}) {
  if (distanceCm == null) return 0;
  final fraction = (emptyCm - distanceCm) / (emptyCm - fullCm);
  return fraction.clamp(0.0, 1.0);
}

import '../models/activity_entry.dart';

/// Jumlah pemberian pakan per hari untuk [days] hari terakhir, dari yang
/// paling lama ke hari ini.
List<int> feedsPerDay(
  List<ActivityEntry> entries,
  DateTime now, {
  int days = 7,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final counts = List<int>.filled(days, 0);
  for (final entry in entries) {
    if (!entry.isFeed) continue;
    final time = DateTime.tryParse(entry.timestamp);
    if (time == null) continue;
    final day = DateTime(time.year, time.month, time.day);
    final age = today.difference(day).inDays;
    if (age >= 0 && age < days) counts[days - 1 - age]++;
  }
  return counts;
}

/// Pemberian pakan hari ini.
int feedsToday(List<ActivityEntry> entries, DateTime now) =>
    feedsPerDay(entries, now, days: 1).single;

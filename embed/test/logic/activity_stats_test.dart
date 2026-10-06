import 'package:fishfeed/logic/activity_stats.dart';
import 'package:fishfeed/models/activity_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 10, 15);

  ActivityEntry feed(DateTime at) => ActivityEntry(
    type: 'feed',
    mode: 'auto',
    timestamp: at.toIso8601String(),
    source: 'device',
  );

  test('counts feeds per day, oldest first, ignoring other activity', () {
    final entries = [
      feed(DateTime(2026, 6, 10, 7)),
      feed(DateTime(2026, 6, 10, 12)),
      feed(DateTime(2026, 6, 9, 7)),
      feed(DateTime(2026, 6, 4, 7)),
      feed(DateTime(2026, 6, 1, 7)), // older than 7 days
      ActivityEntry(
        type: 'schedule_update',
        timestamp: DateTime(2026, 6, 10, 8).toIso8601String(),
        source: 'app',
      ),
      const ActivityEntry(type: 'feed', timestamp: 'not a date', source: 'app'),
    ];
    expect(feedsPerDay(entries, now), [1, 0, 0, 0, 0, 1, 2]);
    expect(feedsToday(entries, now), 2);
  });
}

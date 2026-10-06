import 'package:fishfeed/logic/schedule_logic.dart';
import 'package:fishfeed/models/feed_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const schedule = FeedSchedule(
    active: true,
    entries: [
      ScheduleEntry(id: 'a', time: '07:00'),
      ScheduleEntry(id: 'b', time: '12:00', enabled: false),
      ScheduleEntry(id: 'c', time: '17:30'),
    ],
  );

  group('nextFeeding', () {
    test('picks the next enabled time today', () {
      expect(
        nextFeeding(schedule, DateTime(2026, 6, 1, 9, 15)),
        DateTime(2026, 6, 1, 17, 30),
      );
    });

    test('skips disabled times', () {
      expect(
        nextFeeding(schedule, DateTime(2026, 6, 1, 11, 0)),
        DateTime(2026, 6, 1, 17, 30),
      );
    });

    test('rolls over to tomorrow after the last time', () {
      expect(
        nextFeeding(schedule, DateTime(2026, 6, 1, 20, 0)),
        DateTime(2026, 6, 2, 7, 0),
      );
    });

    test('a time equal to now is already past', () {
      expect(
        nextFeeding(schedule, DateTime(2026, 6, 1, 7, 0)),
        DateTime(2026, 6, 1, 17, 30),
      );
    });

    test('is null when inactive or empty', () {
      expect(
        nextFeeding(
          const FeedSchedule(entries: [ScheduleEntry(id: 'a', time: '07:00')]),
          DateTime(2026, 6, 1),
        ),
        isNull,
      );
      expect(
        nextFeeding(const FeedSchedule(active: true), DateTime(2026)),
        isNull,
      );
    });
  });

  test('timeUntil is short and friendly', () {
    final now = DateTime(2026, 6, 1, 9, 0);
    expect(
      timeUntil(now.add(const Duration(seconds: 30)), now),
      'sebentar lagi',
    );
    expect(timeUntil(now.add(const Duration(minutes: 5)), now), '5 menit lagi');
    expect(timeUntil(now.add(const Duration(hours: 2)), now), '2 jam lagi');
    expect(
      timeUntil(now.add(const Duration(hours: 2, minutes: 15)), now),
      '2 jam 15 menit lagi',
    );
  });

  test('feedLevelFraction maps distance to fill level', () {
    expect(feedLevelFraction(1), 1);
    expect(feedLevelFraction(3), 0.5);
    expect(feedLevelFraction(5), 0);
    expect(feedLevelFraction(8), 0);
    expect(feedLevelFraction(null), 0);
  });

  test('formatHourMinute pads with zeros', () {
    expect(formatHourMinute(7, 5), '07:05');
  });
}

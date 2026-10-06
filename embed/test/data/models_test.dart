import 'package:fishfeed/models/activity_entry.dart';
import 'package:fishfeed/models/device_snapshot.dart';
import 'package:fishfeed/models/feed_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schedule round-trips in the format the firmware reads', () {
    final raw = {
      'active': true,
      'entries': {
        'x': {'time': '17:00', 'enabled': true, 'last_run': '2026-06-01'},
        'y': {'time': '07:00', 'enabled': false},
      },
    };
    final schedule = FeedSchedule.fromMap(raw);
    expect(schedule.active, isTrue);
    expect(schedule.entries.map((e) => e.time), ['07:00', '17:00']);
    expect(schedule.enabledEntries.single.lastRun, '2026-06-01');
    expect(schedule.toMap(), {
      'active': true,
      'entries': {
        'y': {'time': '07:00', 'enabled': false, 'last_run': ''},
        'x': {'time': '17:00', 'enabled': true, 'last_run': '2026-06-01'},
      },
    });
    expect(FeedSchedule.fromMap(null).entries, isEmpty);
  });

  test('device snapshot reads firmware telemetry', () {
    final device = DeviceSnapshot.fromMap('FF-1', {
      'info': {'name': 'Akuarium'},
      'status': {'online': true},
      'sensors': {
        'turbidity': 12,
        'distance_cm': '2.5',
        'battery_percent': 77.6,
        'battery_voltage': 3.9,
        'timestamp': '2026-06-01T10:00:00',
      },
    });
    expect(device.displayName, 'Akuarium');
    expect(device.online, isTrue);
    expect(device.distanceCm, 2.5);
    expect(device.batteryPercent, 78);
    expect(device.hasSensorData, isTrue);
    expect(DeviceSnapshot.fromMap('FF-2', {}).displayName, 'FF-2');
  });

  test('a failed distance reading is unknown, last contact is the newest', () {
    final device = DeviceSnapshot.fromMap('FF-1', {
      'status': {'online': true, 'last_seen': '2026-06-01T10:05:00'},
      'sensors': {'distance_cm': -1, 'timestamp': '2026-06-01T10:00:00'},
    });
    expect(device.distanceCm, isNull);
    expect(device.lastContact, DateTime(2026, 6, 1, 10, 5));
  });

  test('activity entries describe themselves', () {
    final auto = ActivityEntry.fromMap({
      'type': 'feed',
      'mode': 'auto',
      'timestamp': '2026-06-01T07:00:00',
      'source': 'device',
    });
    expect(auto.title, 'Pakan otomatis');
    expect(auto.fromDevice, isTrue);
    expect(auto.toMap()['mode'], 'auto');
    const update = ActivityEntry(
      type: 'schedule_update',
      timestamp: '',
      source: 'app',
    );
    expect(update.title, 'Jadwal diperbarui');
    expect(update.toMap().containsKey('mode'), isFalse);
  });
}

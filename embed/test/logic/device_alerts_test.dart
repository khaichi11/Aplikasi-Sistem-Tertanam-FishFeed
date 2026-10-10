import 'package:fishfeed/logic/device_alerts.dart';
import 'package:fishfeed/models/device_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 1, 12);

  DeviceSnapshot device({
    bool online = true,
    double distance = 2,
    double ntu = 10,
    int battery = 80,
    DateTime? updated,
  }) => DeviceSnapshot(
    id: 'FF-1',
    online: online,
    distanceCm: distance,
    turbidityNtu: ntu,
    batteryPercent: battery,
    updatedAt: (updated ?? now).toIso8601String(),
  );

  test('a healthy device has no alerts', () {
    expect(deviceAlerts(device(), now), isEmpty);
  });

  test('offline, empty feed and low battery are critical', () {
    final alerts = deviceAlerts(
      device(online: false, distance: 6, battery: 10),
      now,
    );
    expect(alerts.map((a) => a.title), [
      'Perangkat offline',
      'Pakan habis',
      'Baterai hampir habis',
    ]);
    expect(alerts.every((a) => a.level == AlertLevel.critical), isTrue);
  });

  test('half feed and cloudy water are warnings, after criticals', () {
    final alerts = deviceAlerts(device(distance: 4, ntu: 80, battery: 15), now);
    expect(alerts.first.title, 'Baterai hampir habis');
    expect(alerts.skip(1).map((a) => a.title).toSet(), {
      'Pakan menipis',
      'Air keruh',
    });
  });

  test('a device that stopped reporting counts as offline', () {
    final quiet = device(updated: now.subtract(const Duration(minutes: 6)));
    expect(isReachable(quiet, now), isFalse);
    expect(deviceAlerts(quiet, now).first.title, 'Perangkat offline');
    final recent = device(updated: now.subtract(const Duration(minutes: 2)));
    expect(isReachable(recent, now), isTrue);
  });
}

// Pengujian unit untuk logika interpretasi sensor.
//
// Logika ini murni (tanpa Firebase/Flutter) sehingga dapat diuji cepat tanpa
// inisialisasi perangkat.

import 'package:embed/sensor_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('feedLevelStatus', () {
    test('jarak besar berarti wadah kosong', () {
      expect(feedLevelStatus(6).severity, Severity.bad);
    });
    test('jarak menengah berarti setengah', () {
      expect(feedLevelStatus(4).severity, Severity.warning);
    });
    test('jarak kecil berarti penuh', () {
      expect(feedLevelStatus(1).severity, Severity.good);
    });
    test('null tidak diketahui', () {
      expect(feedLevelStatus(null).severity, Severity.unknown);
    });
  });

  group('turbidityStatus', () {
    test('di atas ambang berarti keruh', () {
      expect(turbidityStatus(120).severity, Severity.bad);
    });
    test('di bawah ambang berarti jernih', () {
      expect(turbidityStatus(10).severity, Severity.good);
    });
  });

  group('batteryStatus', () {
    test('baterai rendah kritis', () {
      expect(batteryStatus(10).severity, Severity.bad);
    });
    test('baterai sedang peringatan', () {
      expect(batteryStatus(40).severity, Severity.warning);
    });
    test('baterai penuh baik', () {
      expect(batteryStatus(90).severity, Severity.good);
    });
  });
}

import '../models/device_snapshot.dart';
import 'sensor_status.dart';

enum AlertLevel { warning, critical }

class DeviceAlert {
  const DeviceAlert(this.level, this.title, this.message);
  final AlertLevel level;
  final String title;
  final String message;
}

/// Perangkat dianggap offline bila tidak ada kabar selama ini. Firmware
/// bangun kira-kira setiap 20 detik, dan tidak bisa menandai dirinya offline
/// saat listrik padam.
const offlineAfter = Duration(minutes: 5);

/// Apakah perangkat masih mengirim kabar.
bool isReachable(DeviceSnapshot device, DateTime now) {
  if (!device.online) return false;
  final contact = device.lastContact;
  return contact == null || now.difference(contact) <= offlineAfter;
}

/// Peringatan yang perlu diperhatikan pemilik akuarium, dari yang paling
/// mendesak.
List<DeviceAlert> deviceAlerts(DeviceSnapshot device, DateTime now) {
  final alerts = <DeviceAlert>[];
  if (!isReachable(device, now)) {
    alerts.add(
      const DeviceAlert(
        AlertLevel.critical,
        'Perangkat offline',
        'Belum ada kabar dari alat FishFeed. Periksa daya dan koneksi WiFi.',
      ),
    );
  }

  final feed = feedLevelStatus(device.distanceCm);
  if (feed.severity == Severity.bad) {
    alerts.add(
      const DeviceAlert(
        AlertLevel.critical,
        'Pakan habis',
        'Isi ulang wadah pakan agar jadwal tetap berjalan.',
      ),
    );
  } else if (feed.severity == Severity.warning) {
    alerts.add(
      const DeviceAlert(
        AlertLevel.warning,
        'Pakan tinggal setengah',
        'Siapkan pakan untuk isi ulang dalam beberapa hari.',
      ),
    );
  }

  if (turbidityStatus(device.turbidityNtu).severity == Severity.bad) {
    alerts.add(
      const DeviceAlert(
        AlertLevel.warning,
        'Air keruh',
        'Kekeruhan di atas 50 NTU. Pertimbangkan mengganti sebagian air.',
      ),
    );
  }

  final battery = batteryStatus(device.batteryPercent);
  if (battery.severity == Severity.bad) {
    alerts.add(
      const DeviceAlert(
        AlertLevel.critical,
        'Baterai hampir habis',
        'Isi daya baterai perangkat secepatnya.',
      ),
    );
  }

  alerts.sort((a, b) => b.level.index.compareTo(a.level.index));
  return alerts;
}

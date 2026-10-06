import '../models/activity_entry.dart';
import '../models/device_snapshot.dart';
import '../models/feed_schedule.dart';

class AppUser {
  const AppUser({required this.uid, required this.email});
  final String uid;
  final String email;
}

/// Kesalahan dengan pesan yang siap ditampilkan ke pengguna.
class BackendException implements Exception {
  const BackendException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Status perintah pemberian pakan di `commands/{id}/current_command`.
enum CommandStatus { pending, done, unknown }

/// Semua akses data aplikasi. Ada dua implementasi:
///
/// * [FirebaseBackend] memakai Firebase dan berbicara dengan ESP32 asli.
/// * [DemoBackend] mensimulasikan perangkat di memori, tanpa Firebase.
abstract interface class FeederBackend {
  /// True bila memakai data simulasi.
  bool get isDemo;

  AppUser? get currentUser;
  Stream<AppUser?> authChanges();
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> signOut();

  /// ID perangkat milik pengguna, terurut.
  Future<List<String>> loadDevices(String uid);
  Future<bool> deviceExists(String deviceId);
  Future<void> pairDevice(String uid, String deviceId);
  Future<void> unpairDevice(String uid, String deviceId);

  /// Mengganti nama tampilan perangkat di `devices/{id}/info/name`.
  Future<void> renameDevice(String deviceId, String name);

  Stream<DeviceSnapshot> watchDevice(String deviceId);
  Future<FeedSchedule> loadSchedule(String deviceId);

  /// Menyimpan jadwal dan mencatatnya di riwayat aktivitas.
  Future<void> saveSchedule(String deviceId, FeedSchedule schedule);

  /// Mengirim perintah pemberian pakan dan mencatatnya di riwayat.
  Future<void> sendFeedCommand({required String deviceId, required String uid});
  Stream<CommandStatus> watchCommandStatus(String deviceId);

  /// Riwayat terbaru, dari yang paling baru.
  Stream<List<ActivityEntry>> watchActivity(String deviceId, {int limit = 50});
}

/// Validasi bersama untuk formulir masuk dan daftar.
abstract final class AuthValidators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    if (value == null || !_email.hasMatch(value.trim())) {
      return 'Masukkan alamat email yang valid.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 6) {
      return 'Kata sandi minimal 6 karakter.';
    }
    return null;
  }
}

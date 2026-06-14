import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/activity_entry.dart';

/// Lapisan tunggal akses data ke Firebase.
///
/// Seluruh jalur Realtime Database dan koleksi Firestore didefinisikan di sini
/// agar kontrak data dengan firmware ESP32 tetap konsisten dan tidak tersebar
/// sebagai string di banyak berkas.
///
/// Struktur Realtime Database:
///   devices/{id}/status/online      bool   (ditulis firmware)
///   devices/{id}/sensors            map    (ditulis firmware)
///   devices/{id}/info/name          string
///   commands/{id}/current_command   map    (ditulis aplikasi, dibaca firmware)
///   schedules/{id}                  map    (ditulis aplikasi, dibaca firmware)
///   activity/{id}/{pushId}          map    (ditulis aplikasi & firmware)
class FeederService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseFirestore _store = FirebaseFirestore.instance;

  String _devicePath(String id) => 'devices/$id';
  String _commandPath(String id) => 'commands/$id/current_command';
  String _schedulePath(String id) => 'schedules/$id';
  String _activityPath(String id) => 'activity/$id';

  // ---------------------------------------------------------------------------
  // Perangkat milik pengguna (Firestore).
  // ---------------------------------------------------------------------------

  /// Membaca daftar perangkat yang dimiliki pengguna.
  Future<Map<String, dynamic>> loadUserDevices(String userId) async {
    final doc = await _store.collection('users').doc(userId).get();
    if (!doc.exists) return {};
    return Map<String, dynamic>.from(doc.data()?['devices'] ?? {});
  }

  Future<void> saveUserDevices(
    String userId,
    Map<String, dynamic> devices,
  ) async {
    await _store
        .collection('users')
        .doc(userId)
        .update({'devices': devices});
  }

  /// Memastikan perangkat terdaftar di sistem sebelum dipasangkan.
  Future<bool> deviceExists(String deviceId) async {
    final snap = await _db.ref('${_devicePath(deviceId)}/info').get();
    return snap.exists;
  }

  // ---------------------------------------------------------------------------
  // Telemetri perangkat (Realtime Database).
  // ---------------------------------------------------------------------------

  /// Aliran data perangkat secara langsung (status, sensor, info).
  Stream<Map<String, dynamic>> deviceStream(String deviceId) {
    return _db.ref(_devicePath(deviceId)).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    });
  }

  // ---------------------------------------------------------------------------
  // Jadwal pemberian pakan.
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> loadSchedule(String deviceId) async {
    final snap = await _db.ref(_schedulePath(deviceId)).get();
    if (!snap.exists || snap.value is! Map) return {};
    return Map<String, dynamic>.from(snap.value as Map);
  }

  Future<void> saveSchedule(
    String deviceId,
    Map<String, dynamic> schedule,
  ) async {
    await _db.ref(_schedulePath(deviceId)).update(schedule);
  }

  // ---------------------------------------------------------------------------
  // Perintah dan riwayat aktivitas.
  // ---------------------------------------------------------------------------

  /// Mengirim perintah pemberian pakan ke perangkat dan mencatat aktivitas.
  Future<void> sendFeedCommand({
    required String deviceId,
    required String userId,
    bool auto = false,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    await _db.ref(_commandPath(deviceId)).set({
      'type': 'feed',
      'created_at': timestamp,
      'status': 'pending',
      'initiated_by': userId,
    });
    await logActivity(
      deviceId,
      ActivityEntry(
        type: 'feed',
        mode: auto ? 'auto' : 'manual',
        timestamp: timestamp,
        source: 'app',
      ),
    );
  }

  Future<void> logActivity(String deviceId, ActivityEntry entry) async {
    await _db.ref(_activityPath(deviceId)).push().set(entry.toMap());
  }

  /// Aliran riwayat aktivitas terbaru, terurut dari yang paling baru.
  Stream<List<ActivityEntry>> activityStream(String deviceId, {int limit = 50}) {
    return _db
        .ref(_activityPath(deviceId))
        .orderByChild('timestamp')
        .limitToLast(limit)
        .onValue
        .map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <ActivityEntry>[];
      final entries = value.values
          .whereType<Map>()
          .map(ActivityEntry.fromMap)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    });
  }
}

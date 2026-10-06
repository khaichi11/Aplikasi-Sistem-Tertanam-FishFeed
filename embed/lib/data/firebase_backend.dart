import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/activity_entry.dart';
import '../models/device_snapshot.dart';
import '../models/feed_schedule.dart';
import 'feeder_backend.dart';

/// Akses data lewat Firebase. Jalur Realtime Database mengikuti kontrak dengan
/// firmware ESP32:
///
///   devices/{id}/status/online      bool   (ditulis firmware)
///   devices/{id}/sensors            map    (ditulis firmware)
///   devices/{id}/info/name          string
///   commands/{id}/current_command   map    (ditulis aplikasi, dibaca firmware)
///   schedules/{id}                  map    (ditulis aplikasi, dibaca firmware)
///   activity/{id}/{pushId}          map    (ditulis aplikasi & firmware)
///
/// Daftar perangkat milik pengguna disimpan di Firestore `users/{uid}`.
class FirebaseBackend implements FeederBackend {
  FirebaseBackend({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = database ?? FirebaseDatabase.instance,
       _store = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseDatabase _db;
  final FirebaseFirestore _store;

  @override
  bool get isDemo => false;

  static AppUser? _toAppUser(User? user) =>
      user == null ? null : AppUser(uid: user.uid, email: user.email ?? '');

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Stream<AppUser?> authChanges() => _auth.authStateChanges().map(_toAppUser);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw BackendException(_authMessage(e.code));
    }
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _userDoc(credential.user!.uid).set({
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'devices': <String, dynamic>{},
      });
    } on FirebaseAuthException catch (e) {
      throw BackendException(_authMessage(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _store.collection('users').doc(uid);

  @override
  Future<List<String>> loadDevices(String uid) async {
    final doc = await _userDoc(uid).get();
    final devices = doc.data()?['devices'];
    if (devices is! Map) return [];
    return devices.keys.map((key) => key.toString()).toList()..sort();
  }

  @override
  Future<bool> deviceExists(String deviceId) async {
    final snap = await _db.ref('devices/$deviceId/info').get();
    return snap.exists;
  }

  @override
  Future<void> pairDevice(String uid, String deviceId) async {
    await _userDoc(uid).set({
      'devices': {
        deviceId: {
          'paired_at': DateTime.now().toIso8601String(),
          'role': 'owner',
        },
      },
    }, SetOptions(merge: true));
  }

  @override
  Future<void> unpairDevice(String uid, String deviceId) async {
    await _userDoc(uid).update({
      FieldPath(['devices', deviceId]): FieldValue.delete(),
    });
  }

  @override
  Future<void> renameDevice(String deviceId, String name) =>
      _db.ref('devices/$deviceId/info/name').set(name.trim());

  @override
  Stream<DeviceSnapshot> watchDevice(String deviceId) {
    return _db.ref('devices/$deviceId').onValue.map((event) {
      final value = event.snapshot.value;
      return DeviceSnapshot.fromMap(deviceId, value is Map ? value : const {});
    });
  }

  @override
  Future<FeedSchedule> loadSchedule(String deviceId) async {
    final snap = await _db.ref('schedules/$deviceId').get();
    final value = snap.value;
    return FeedSchedule.fromMap(value is Map ? value : null);
  }

  @override
  Future<void> saveSchedule(String deviceId, FeedSchedule schedule) async {
    // set() menggantikan seluruh jadwal, sehingga waktu yang dihapus ikut
    // hilang dari perangkat.
    await _db.ref('schedules/$deviceId').set(schedule.toMap());
    await _log(
      deviceId,
      ActivityEntry(
        type: 'schedule_update',
        timestamp: DateTime.now().toIso8601String(),
        source: 'app',
      ),
    );
  }

  @override
  Future<void> sendFeedCommand({
    required String deviceId,
    required String uid,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    await _db.ref('commands/$deviceId/current_command').set({
      'type': 'feed',
      'created_at': timestamp,
      'status': 'pending',
      'initiated_by': uid,
    });
    await _log(
      deviceId,
      ActivityEntry(
        type: 'feed',
        mode: 'manual',
        timestamp: timestamp,
        source: 'app',
      ),
    );
  }

  @override
  Stream<CommandStatus> watchCommandStatus(String deviceId) {
    return _db
        .ref('commands/$deviceId/current_command/status')
        .onValue
        .map(
          (event) => switch (event.snapshot.value) {
            'pending' => CommandStatus.pending,
            'done' => CommandStatus.done,
            _ => CommandStatus.unknown,
          },
        );
  }

  Future<void> _log(String deviceId, ActivityEntry entry) =>
      _db.ref('activity/$deviceId').push().set(entry.toMap());

  @override
  Stream<List<ActivityEntry>> watchActivity(String deviceId, {int limit = 50}) {
    return _db
        .ref('activity/$deviceId')
        .orderByChild('timestamp')
        .limitToLast(limit)
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value is! Map) return <ActivityEntry>[];
          return value.values
              .whereType<Map>()
              .map(ActivityEntry.fromMap)
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        });
  }

  static String _authMessage(String code) => switch (code) {
    'invalid-email' => 'Format email tidak valid.',
    'user-disabled' => 'Akun ini dinonaktifkan.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Email atau kata sandi salah.',
    'email-already-in-use' => 'Email ini sudah terdaftar.',
    'weak-password' => 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.',
    'network-request-failed' => 'Tidak ada koneksi internet.',
    'too-many-requests' => 'Terlalu banyak percobaan. Coba lagi nanti.',
    _ => 'Terjadi kesalahan ($code). Coba lagi.',
  };
}

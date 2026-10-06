import 'package:flutter/foundation.dart';

import '../data/feeder_backend.dart';
import '../models/feed_schedule.dart';

/// Perangkat milik pengguna, perangkat yang sedang dipilih, dan jadwalnya.
class DeviceController extends ChangeNotifier {
  DeviceController({required this.backend, required this.user});

  final FeederBackend backend;
  final AppUser user;

  List<String> _devices = const [];
  String? _selectedId;
  FeedSchedule _schedule = const FeedSchedule();
  bool _loading = true;
  String? _error;

  List<String> get devices => _devices;
  String? get selectedId => _selectedId;
  FeedSchedule get schedule => _schedule;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasDevice => _selectedId != null;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _devices = await backend.loadDevices(user.uid);
      if (_selectedId == null || !_devices.contains(_selectedId)) {
        _selectedId = _devices.isEmpty ? null : _devices.first;
      }
      await _loadSchedule();
    } catch (_) {
      _error = 'Gagal memuat perangkat. Periksa koneksi internet.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> select(String deviceId) async {
    if (!_devices.contains(deviceId) || deviceId == _selectedId) return;
    _selectedId = deviceId;
    _schedule = const FeedSchedule();
    notifyListeners();
    await _loadSchedule();
    notifyListeners();
  }

  Future<void> _loadSchedule() async {
    final id = _selectedId;
    _schedule =
        id == null ? const FeedSchedule() : await backend.loadSchedule(id);
  }

  /// Memasangkan perangkat dengan ID yang tercetak di alat.
  Future<void> pair(String rawId) async {
    final id = rawId.trim().toUpperCase();
    if (id.isEmpty) throw const BackendException('Masukkan ID perangkat.');
    if (_devices.contains(id)) {
      throw BackendException('Perangkat "$id" sudah terpasang.');
    }
    if (!await backend.deviceExists(id)) {
      throw BackendException(
        'Perangkat "$id" tidak ditemukan. Pastikan alat sudah menyala '
        'dan terhubung ke internet.',
      );
    }
    await backend.pairDevice(user.uid, id);
    _devices = [..._devices, id]..sort();
    _selectedId ??= id;
    await _loadSchedule();
    notifyListeners();
  }

  Future<void> unpair(String deviceId) async {
    await backend.unpairDevice(user.uid, deviceId);
    _devices = _devices.where((id) => id != deviceId).toList();
    if (_selectedId == deviceId) {
      _selectedId = _devices.isEmpty ? null : _devices.first;
      await _loadSchedule();
    }
    notifyListeners();
  }

  Future<void> rename(String deviceId, String name) async {
    if (name.trim().isEmpty) {
      throw const BackendException('Nama perangkat tidak boleh kosong.');
    }
    await backend.renameDevice(deviceId, name);
  }

  Future<void> saveSchedule(FeedSchedule schedule) async {
    final id = _selectedId;
    if (id == null) return;
    await backend.saveSchedule(id, schedule);
    _schedule = schedule;
    notifyListeners();
  }

  Future<void> feedNow() async {
    final id = _selectedId;
    if (id == null) return;
    await backend.sendFeedCommand(deviceId: id, uid: user.uid);
  }
}

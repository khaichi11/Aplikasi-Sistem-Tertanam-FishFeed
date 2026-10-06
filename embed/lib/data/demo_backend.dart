import 'dart:async';
import 'dart:math';

import '../models/activity_entry.dart';
import '../models/device_snapshot.dart';
import '../models/feed_schedule.dart';
import 'feeder_backend.dart';

/// Perangkat FishFeed simulasi di memori. Dipakai saat Firebase belum
/// dikonfigurasi, sehingga aplikasi bisa dicoba tanpa alat dan tanpa kunci
/// API. Data hilang saat aplikasi ditutup.
class DemoBackend implements FeederBackend {
  DemoBackend({
    DateTime Function()? clock,
    Duration? tickInterval = const Duration(seconds: 3),
    this.commandDelay = const Duration(seconds: 2),
    int seed = 7,
  }) : _clock = clock ?? DateTime.now,
       _random = Random(seed) {
    final now = _clock();
    _devices[pairedDemoDevice] = _SimulatedDevice(
      name: 'Akuarium Ruang Tamu',
      distanceCm: 2.2,
      turbidityNtu: 18,
      batteryPercent: 82,
      updatedAt: now,
    );
    _devices[spareDemoDevice] = _SimulatedDevice(
      name: 'Kolam Teras',
      distanceCm: 4.1,
      turbidityNtu: 64,
      batteryPercent: 37,
      updatedAt: now,
    );
    _schedules[pairedDemoDevice] = FeedSchedule(
      active: true,
      entries: [
        ScheduleEntry(id: 'pagi', time: '07:00', lastRun: _date(now)),
        const ScheduleEntry(id: 'siang', time: '12:00', enabled: false),
        ScheduleEntry(
          id: 'sore',
          time: '17:00',
          lastRun: _date(now.subtract(const Duration(days: 1))),
        ),
      ],
    );
    _activity[pairedDemoDevice] = _seedActivity(now);
    if (tickInterval != null) {
      _ticker = Timer.periodic(tickInterval, (_) => _tick());
    }
  }

  /// Perangkat yang sudah terpasang di akun demo.
  static const pairedDemoDevice = 'FF-2024';

  /// Perangkat yang bisa dicoba dipasangkan dari halaman Kelola Perangkat.
  static const spareDemoDevice = 'FF-2025';
  static const demoEmail = 'demo@fishfeed.id';

  final DateTime Function() _clock;
  final Random _random;
  final Duration commandDelay;
  Timer? _ticker;

  final _authController = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  final _accounts = <String, String>{demoEmail: 'demo123'};
  final _paired = <String>{pairedDemoDevice};
  final _devices = <String, _SimulatedDevice>{};
  final _schedules = <String, FeedSchedule>{};
  final _activity = <String, List<ActivityEntry>>{};
  final _commandStatus = <String, CommandStatus>{};
  final _changes = StreamController<String>.broadcast();

  @override
  bool get isDemo => true;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authChanges() async* {
    yield _user;
    yield* _authController.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final key = email.trim().toLowerCase();
    final stored = _accounts[key];
    if (stored != null && stored != password) {
      throw const BackendException('Email atau kata sandi salah.');
    }
    // Dalam mode demo, email baru langsung dibuatkan akun.
    _accounts[key] = password;
    _setUser(AppUser(uid: 'demo-$key', email: key));
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw const BackendException('Email ini sudah terdaftar.');
    }
    _accounts[key] = password;
    _setUser(AppUser(uid: 'demo-$key', email: key));
  }

  @override
  Future<void> signOut() async => _setUser(null);

  void _setUser(AppUser? user) {
    _user = user;
    _authController.add(user);
  }

  @override
  Future<List<String>> loadDevices(String uid) async =>
      _paired.toList()..sort();

  @override
  Future<bool> deviceExists(String deviceId) async =>
      _devices.containsKey(deviceId);

  @override
  Future<void> pairDevice(String uid, String deviceId) async {
    if (!_devices.containsKey(deviceId)) {
      throw BackendException('Perangkat "$deviceId" tidak ditemukan.');
    }
    _paired.add(deviceId);
  }

  @override
  Future<void> unpairDevice(String uid, String deviceId) async {
    _paired.remove(deviceId);
  }

  @override
  Future<void> renameDevice(String deviceId, String name) async {
    _devices[deviceId]?.name = name.trim();
    _changes.add(deviceId);
  }

  @override
  Stream<DeviceSnapshot> watchDevice(String deviceId) async* {
    yield _snapshot(deviceId);
    yield* _changes.stream
        .where((id) => id == deviceId)
        .map((id) => _snapshot(id));
  }

  DeviceSnapshot _snapshot(String id) {
    final device = _devices[id];
    if (device == null) return DeviceSnapshot(id: id);
    return DeviceSnapshot(
      id: id,
      name: device.name,
      online: true,
      turbidityNtu: device.turbidityNtu,
      distanceCm: device.distanceCm,
      batteryPercent: device.batteryPercent,
      batteryVoltage: 3.3 + device.batteryPercent / 100 * 0.9,
      updatedAt: device.updatedAt.toIso8601String(),
    );
  }

  @override
  Future<FeedSchedule> loadSchedule(String deviceId) async =>
      _schedules[deviceId] ?? const FeedSchedule();

  @override
  Future<void> saveSchedule(String deviceId, FeedSchedule schedule) async {
    _schedules[deviceId] = schedule;
    _addActivity(
      deviceId,
      ActivityEntry(
        type: 'schedule_update',
        timestamp: _clock().toIso8601String(),
        source: 'app',
      ),
    );
  }

  @override
  Future<void> sendFeedCommand({
    required String deviceId,
    required String uid,
  }) async {
    _setCommand(deviceId, CommandStatus.pending);
    _addActivity(
      deviceId,
      ActivityEntry(
        type: 'feed',
        mode: 'manual',
        timestamp: _clock().toIso8601String(),
        source: 'app',
      ),
    );
    // Seperti ESP32: perintah diproses beberapa saat kemudian.
    Timer(commandDelay, () {
      final device = _devices[deviceId];
      if (device != null) {
        device.distanceCm = min(6, device.distanceCm + 0.3);
        device.updatedAt = _clock();
      }
      _setCommand(deviceId, CommandStatus.done);
      _changes.add(deviceId);
    });
  }

  final _commandControllers = <String, StreamController<CommandStatus>>{};

  void _setCommand(String deviceId, CommandStatus status) {
    _commandStatus[deviceId] = status;
    _commandControllers[deviceId]?.add(status);
  }

  @override
  Stream<CommandStatus> watchCommandStatus(String deviceId) async* {
    final controller = _commandControllers.putIfAbsent(
      deviceId,
      StreamController<CommandStatus>.broadcast,
    );
    yield _commandStatus[deviceId] ?? CommandStatus.unknown;
    yield* controller.stream;
  }

  final _activityControllers =
      <String, StreamController<List<ActivityEntry>>>{};

  void _addActivity(String deviceId, ActivityEntry entry) {
    final list = _activity.putIfAbsent(deviceId, () => [])..insert(0, entry);
    _activityControllers[deviceId]?.add(List.unmodifiable(list));
  }

  @override
  Stream<List<ActivityEntry>> watchActivity(
    String deviceId, {
    int limit = 50,
  }) async* {
    final controller = _activityControllers.putIfAbsent(
      deviceId,
      StreamController<List<ActivityEntry>>.broadcast,
    );
    yield List.unmodifiable((_activity[deviceId] ?? const []).take(limit));
    yield* controller.stream.map((list) => list.take(limit).toList());
  }

  /// Pembacaan sensor bergeser sedikit, seperti perangkat sungguhan.
  void _tick() {
    final now = _clock();
    for (final MapEntry(key: id, value: device) in _devices.entries) {
      device.turbidityNtu = (device.turbidityNtu + _random.nextDouble() * 4 - 2)
          .clamp(5, 120);
      device.distanceCm = (device.distanceCm + _random.nextDouble() * 0.04)
          .clamp(0.5, 6);
      if (_random.nextInt(20) == 0 && device.batteryPercent > 5) {
        device.batteryPercent -= 1;
      }
      device.updatedAt = now;
      _changes.add(id);
    }
  }

  List<ActivityEntry> _seedActivity(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    ActivityEntry feed(DateTime at, String mode, String source) =>
        ActivityEntry(
          type: 'feed',
          mode: mode,
          timestamp: at.toIso8601String(),
          source: source,
        );
    final entries = <ActivityEntry>[
      feed(today.add(const Duration(hours: 7)), 'auto', 'device'),
      feed(today.subtract(const Duration(hours: 7)), 'auto', 'device'),
      feed(
        today.subtract(const Duration(hours: 9, minutes: 40)),
        'manual',
        'app',
      ),
      ActivityEntry(
        type: 'schedule_update',
        timestamp:
            today
                .subtract(const Duration(hours: 10, minutes: 5))
                .toIso8601String(),
        source: 'app',
      ),
      feed(today.subtract(const Duration(hours: 17)), 'auto', 'device'),
      feed(today.subtract(const Duration(days: 1, hours: 7)), 'auto', 'device'),
      feed(
        today.subtract(const Duration(days: 1, hours: 17)),
        'auto',
        'device',
      ),
    ];
    return entries
        .where((entry) => DateTime.parse(entry.timestamp).isBefore(now))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static String _date(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';

  /// Menghentikan simulasi. Dipanggil saat aplikasi ditutup dan di pengujian.
  void dispose() {
    _ticker?.cancel();
    _authController.close();
    _changes.close();
    for (final controller in _commandControllers.values) {
      controller.close();
    }
    for (final controller in _activityControllers.values) {
      controller.close();
    }
  }
}

class _SimulatedDevice {
  _SimulatedDevice({
    required this.name,
    required this.distanceCm,
    required this.turbidityNtu,
    required this.batteryPercent,
    required this.updatedAt,
  });

  String name;
  double distanceCm;
  double turbidityNtu;
  int batteryPercent;
  DateTime updatedAt;
}

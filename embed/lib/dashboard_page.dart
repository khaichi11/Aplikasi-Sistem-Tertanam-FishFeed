import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'activity_log_page.dart';
import 'device_manager_page.dart';
import 'feed_success_page.dart';
import 'models/activity_entry.dart';
import 'schedule_page.dart';
import 'sensor_status.dart';
import 'services/feeder_service.dart';
import 'theme/app_theme.dart';
import 'utils/formatting.dart';
import 'widgets/info_widgets.dart';

/// Layar utama: menampilkan telemetri perangkat secara langsung dan menyediakan
/// kendali pemberian pakan, penjadwalan, serta pengelolaan perangkat.
class DashboardPage extends StatefulWidget {
  final String userId;
  const DashboardPage({super.key, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FeederService _service = FeederService();

  List<String> _devices = [];
  String? _selectedId;
  Stream<Map<String, dynamic>>? _deviceStream;
  Map<String, dynamic> _schedule = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final devices = await _service.loadUserDevices(widget.userId);
    if (!mounted) return;
    setState(() {
      _devices = devices.keys.toList();
      _loading = false;
    });
    if (_devices.isNotEmpty) _selectDevice(_devices.first);
  }

  void _selectDevice(String id) {
    setState(() {
      _selectedId = id;
      _deviceStream = _service.deviceStream(id);
    });
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    if (_selectedId == null) return;
    final schedule = await _service.loadSchedule(_selectedId!);
    if (mounted) setState(() => _schedule = schedule);
  }

  Future<void> _refresh() async {
    final devices = await _service.loadUserDevices(widget.userId);
    if (!mounted) return;
    setState(() => _devices = devices.keys.toList());
    if (_selectedId != null && _devices.contains(_selectedId)) {
      await _loadSchedule();
    } else if (_devices.isNotEmpty) {
      _selectDevice(_devices.first);
    } else {
      setState(() {
        _selectedId = null;
        _deviceStream = null;
      });
    }
  }

  Future<void> _confirmAndFeed() async {
    if (_selectedId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Beri Makan Sekarang'),
        content: const Text(
          'Perintah pemberian pakan akan dikirim ke perangkat. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.good,
              foregroundColor: Colors.white,
              minimumSize: const Size(88, 40),
            ),
            child: const Text('Beri Makan'),
          ),
        ],
      ),
    );
    if (confirmed != true || _selectedId == null) return;

    await _service.sendFeedCommand(
      deviceId: _selectedId!,
      userId: widget.userId,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedSuccessPage(time: TimeOfDay.now().format(context)),
      ),
    );
  }

  Future<void> _openSchedule() async {
    if (_selectedId == null) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SchedulePage(initialSchedule: _schedule),
      ),
    );
    if (result == null || _selectedId == null || !mounted) return;
    setState(() => _schedule = result);
    await _service.saveSchedule(_selectedId!, result);
    await _service.logActivity(
      _selectedId!,
      ActivityEntry(
        type: 'schedule_update',
        timestamp: DateTime.now().toIso8601String(),
        source: 'app',
      ),
    );
  }

  void _openActivityLog() {
    if (_selectedId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityLogPage(
          deviceId: _selectedId!,
          service: _service,
        ),
      ),
    );
  }

  Future<void> _openDeviceManager() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceManagerPage(
          userId: widget.userId,
          connectedDevices: _devices,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _devices = result.keys.toList());
    if (_devices.isEmpty) {
      setState(() {
        _selectedId = null;
        _deviceStream = null;
      });
    } else if (!_devices.contains(_selectedId)) {
      _selectDevice(_devices.first);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed == true) FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FishFeed'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _devices.isEmpty ? _buildEmptyState() : _buildContent(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.router_outlined, size: 72, color: AppColors.neutral),
        const SizedBox(height: 16),
        const Text(
          'Belum ada perangkat terpasang',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tambahkan perangkat FishFeed menggunakan ID perangkat untuk mulai '
          'memantau dan memberi pakan.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.neutral),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _openDeviceManager,
          icon: const Icon(Icons.add),
          label: const Text('Tambah Perangkat'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _deviceStream,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const {};
        final info = (data['info'] as Map?) ?? const {};
        final status = (data['status'] as Map?) ?? const {};
        final sensors = (data['sensors'] as Map?) ?? const {};

        final online = status['online'] == true;
        final deviceName = (info['name'] as String?) ?? _selectedId;

        final distance = _asNum(sensors['distance_cm']);
        final ntu = _asNum(sensors['turbidity']);
        final batteryPct = _asInt(sensors['battery_percent']);
        final batteryVolt = _asNum(sensors['battery_voltage']);
        final lastUpdate = formatTimestamp(sensors['timestamp']?.toString());

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_devices.length > 1) _buildDeviceSelector(),
              _buildDeviceHeader(deviceName, online, lastUpdate),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SensorTile(
                      icon: Icons.set_meal_outlined,
                      title: 'Persediaan Pakan',
                      status: feedLevelStatus(distance),
                      detail: distance != null
                          ? 'Jarak ${distance.toStringAsFixed(1)} cm'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SensorTile(
                      icon: Icons.battery_charging_full,
                      title: 'Baterai',
                      status: batteryStatus(batteryPct),
                      detail: batteryVolt != null
                          ? '${batteryVolt.toStringAsFixed(2)} V'
                          : null,
                    ),
                  ),
                ],
              ),
              SensorTile(
                icon: Icons.water_drop_outlined,
                title: 'Kekeruhan Air',
                status: turbidityStatus(ntu),
                detail: ntu != null
                    ? '${ntu.toStringAsFixed(0)} NTU'
                    : null,
              ),
              _buildScheduleCard(),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _selectedId != null ? _confirmAndFeed : null,
                icon: const Icon(Icons.restaurant),
                label: const Text('Beri Makan Sekarang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.good,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _selectedId != null ? _openSchedule : null,
                icon: const Icon(Icons.schedule),
                label: const Text('Atur Jadwal'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _selectedId != null ? _openActivityLog : null,
                icon: const Icon(Icons.history),
                label: const Text('Riwayat Aktivitas'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openDeviceManager,
                icon: const Icon(Icons.devices_other),
                label: const Text('Kelola Perangkat'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceSelector() {
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedId,
          items: _devices
              .map((id) => DropdownMenuItem(value: id, child: Text(id)))
              .toList(),
          onChanged: (id) {
            if (id != null) _selectDevice(id);
          },
        ),
      ),
    );
  }

  Widget _buildDeviceHeader(String? name, bool online, String lastUpdate) {
    return SectionCard(
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Icon(Icons.phishing, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? '-',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pembaruan terakhir: $lastUpdate',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.neutral,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              OnlineDot(online: online),
              const SizedBox(width: 6),
              Text(
                online ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: online ? AppColors.good : AppColors.neutral,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    final active = _schedule['active'] == true;
    final entries = (_schedule['entries'] as Map?) ?? const {};
    final times = entries.values
        .whereType<Map>()
        .where((e) => e['enabled'] == true)
        .map((e) => e['time']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toList()
      ..sort();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Jadwal Pemberian Pakan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.good.withValues(alpha: 0.12)
                      : AppColors.neutral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  active ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.good : AppColors.neutral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            times.isEmpty
                ? 'Belum ada jadwal yang diatur.'
                : 'Waktu: ${times.join(', ')}',
            style: const TextStyle(color: AppColors.neutral),
          ),
        ],
      ),
    );
  }

  static num? _asNum(dynamic v) => v is num ? v : null;

  static int? _asInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

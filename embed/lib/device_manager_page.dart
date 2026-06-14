import 'package:flutter/material.dart';

import 'services/feeder_service.dart';
import 'theme/app_theme.dart';

/// Mengelola daftar perangkat yang terpasang pada akun pengguna. Perangkat
/// dipasangkan menggunakan ID yang tercetak pada alat dan harus sudah
/// terdaftar di sistem oleh firmware.
class DeviceManagerPage extends StatefulWidget {
  final String userId;
  final List<String> connectedDevices;

  const DeviceManagerPage({
    super.key,
    required this.userId,
    required this.connectedDevices,
  });

  @override
  State<DeviceManagerPage> createState() => _DeviceManagerPageState();
}

class _DeviceManagerPageState extends State<DeviceManagerPage> {
  final FeederService _service = FeederService();
  final TextEditingController _deviceIdC = TextEditingController();
  late Map<String, dynamic> _devices;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _devices = {for (final id in widget.connectedDevices) id: true};
  }

  Future<void> _addDevice() async {
    final id = _deviceIdC.text.trim();
    if (id.isEmpty || _devices.containsKey(id)) return;

    setState(() => _busy = true);
    final exists = await _service.deviceExists(id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!exists) {
      _showMessage('Perangkat dengan ID "$id" tidak ditemukan.');
      return;
    }
    setState(() {
      _devices[id] = {
        'paired_at': DateTime.now().toIso8601String(),
        'role': 'owner',
      };
      _deviceIdC.clear();
    });
    await _service.saveUserDevices(widget.userId, _devices);
    if (mounted) _showMessage('Perangkat "$id" berhasil ditambahkan.');
  }

  Future<void> _removeDevice(String id) async {
    setState(() => _devices.remove(id));
    await _service.saveUserDevices(widget.userId, _devices);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _deviceIdC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Perangkat')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _deviceIdC,
                    decoration: const InputDecoration(
                      labelText: 'ID Perangkat',
                      prefixIcon: Icon(Icons.qr_code_2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _busy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton.filled(
                        icon: const Icon(Icons.add),
                        onPressed: _addDevice,
                      ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _devices.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada perangkat.',
                        style: TextStyle(color: AppColors.neutral),
                      ),
                    )
                  : ListView(
                      children: _devices.keys.map((id) {
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.memory),
                            title: Text(id),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: AppColors.bad,
                              onPressed: () => _removeDevice(id),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _devices),
              child: const Text('Selesai'),
            ),
          ],
        ),
      ),
    );
  }
}

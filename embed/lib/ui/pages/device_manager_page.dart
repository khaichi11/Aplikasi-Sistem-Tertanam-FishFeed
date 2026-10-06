import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/demo_backend.dart';
import '../../data/feeder_backend.dart';
import '../../logic/device_alerts.dart';
import '../../logic/sensor_status.dart';
import '../../state/device_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/live_data.dart';

Future<void> openDeviceManager(BuildContext context) {
  final controller = context.read<DeviceController>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder:
          (_) => ChangeNotifierProvider.value(
            value: controller,
            child: const DeviceManagerPage(),
          ),
    ),
  );
}

class DeviceManagerPage extends StatefulWidget {
  const DeviceManagerPage({super.key});

  @override
  State<DeviceManagerPage> createState() => _DeviceManagerPageState();
}

class _DeviceManagerPageState extends State<DeviceManagerPage> {
  final _id = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = _id.text.trim().toUpperCase();
      await context.read<DeviceController>().pair(id);
      _id.clear();
      if (mounted) showMessage(context, 'Perangkat $id berhasil dipasangkan.');
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gagal memasangkan. Periksa koneksi internet.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(String id, String current) async {
    final controller = context.read<DeviceController>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initial: current),
    );
    if (name == null) return;
    try {
      await controller.rename(id, name);
    } on BackendException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _unpair(String id) async {
    final controller = context.read<DeviceController>();
    final ok = await confirm(
      context,
      title: 'Lepas perangkat $id?',
      message:
          'Perangkat tidak lagi muncul di akunmu. Jadwal di perangkat '
          'tetap berjalan.',
      confirmLabel: 'Lepas',
      destructive: true,
    );
    if (ok) await controller.unpair(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<DeviceController>();
    final demo = context.read<FeederBackend>().isDemo;
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola perangkat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pasangkan perangkat baru',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  'Masukkan ID yang tercetak di alat FishFeed, misalnya FF-2024. '
                  'Pastikan alat sudah menyala dan terhubung ke WiFi.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: Gap.lg),
                TextField(
                  controller: _id,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _pair(),
                  decoration: InputDecoration(
                    labelText: 'ID perangkat',
                    prefixIcon: const Icon(Icons.qr_code_2_rounded),
                    errorText: _error,
                    errorMaxLines: 3,
                  ),
                ),
                const SizedBox(height: Gap.md),
                FilledButton.icon(
                  onPressed: _busy ? null : _pair,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Pasangkan'),
                ),
                if (demo) ...[
                  const SizedBox(height: Gap.md),
                  NoticeBox(
                    icon: Icons.science_outlined,
                    text:
                        'Mode demo: coba pasangkan ${DemoBackend.spareDemoDevice}.',
                    color: AppColors.coralSoft,
                    iconColor: AppColors.coral,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Gap.xl),
          SectionHeader('Perangkat terpasang (${controller.devices.length})'),
          if (controller.devices.isEmpty)
            const AppCard(child: Text('Belum ada perangkat terpasang.'))
          else
            for (final id in controller.devices)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.md),
                child: DeviceBuilder(
                  deviceId: id,
                  builder: (context, device) {
                    final name = device?.displayName ?? id;
                    final battery = batteryStatus(device?.batteryPercent);
                    final selected = id == controller.selectedId;
                    final online =
                        device != null &&
                        isReachable(
                          device,
                          context.read<DateTime Function()>()(),
                        );
                    return AppCard(
                      onTap: () => controller.select(id),
                      color: selected ? AppColors.sky : null,
                      child: Row(
                        children: [
                          const IconTile(icon: Icons.set_meal_rounded),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: theme.textTheme.titleSmall),
                                const SizedBox(height: 2),
                                Wrap(
                                  spacing: Gap.sm,
                                  runSpacing: 4,
                                  children: [
                                    Text(id, style: theme.textTheme.bodySmall),
                                    StatusPill(
                                      label: online ? 'Online' : 'Offline',
                                      color:
                                          online
                                              ? AppColors.good
                                              : AppColors.muted,
                                    ),
                                    if (device?.batteryPercent != null)
                                      StatusPill(
                                        label: battery.label,
                                        icon: Icons.battery_std_rounded,
                                        color: AppColors.forSeverity(
                                          battery.severity,
                                        ),
                                      ),
                                    if (selected)
                                      const StatusPill(
                                        label: 'Dipilih',
                                        icon: Icons.check_rounded,
                                        color: AppColors.ocean,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Pilihan untuk $id',
                            onSelected:
                                (action) =>
                                    action == 'rename'
                                        ? _rename(id, name)
                                        : _unpair(id),
                            itemBuilder:
                                (context) => const [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Ganti nama'),
                                  ),
                                  PopupMenuItem(
                                    value: 'unpair',
                                    child: Text('Lepas perangkat'),
                                  ),
                                ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}

/// Owns its text controller, so the field stays valid while the dialog
/// animates closed.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ganti nama perangkat'),
      content: TextField(
        controller: _text,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nama'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

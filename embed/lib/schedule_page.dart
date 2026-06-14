import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

/// Pengaturan jadwal pemberian pakan otomatis. Jadwal disimpan dalam format
/// 24 jam dan dieksekusi oleh firmware perangkat berdasarkan RTC-nya sendiri.
class SchedulePage extends StatefulWidget {
  final Map<String, dynamic> initialSchedule;
  const SchedulePage({super.key, required this.initialSchedule});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late bool _active;
  late Map<String, Map<String, dynamic>> _entries;

  @override
  void initState() {
    super.initState();
    _active = widget.initialSchedule['active'] == true;
    final raw =
        (widget.initialSchedule['entries'] as Map?)?.cast<String, dynamic>() ??
            {};
    _entries = raw.map((key, value) {
      final m = Map<String, dynamic>.from(value as Map);
      return MapEntry(key, {
        'time': m['time'],
        'enabled': m['enabled'] == true,
        'last_run': m['last_run'] ?? '',
      });
    });
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;

    final timeStr =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _entries[id] = {'time': timeStr, 'enabled': true, 'last_run': ''};
    });
  }

  void _remove(String id) => setState(() => _entries.remove(id));

  void _toggle(String id, bool value) =>
      setState(() => _entries[id]!['enabled'] = value);

  void _save() {
    Navigator.pop(context, {'active': _active, 'entries': _entries});
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _entries.entries.toList()
      ..sort((a, b) =>
          (a.value['time'] ?? '').compareTo(b.value['time'] ?? ''));

    return Scaffold(
      appBar: AppBar(title: const Text('Atur Jadwal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: SwitchListTile(
                title: const Text('Aktifkan Penjadwalan'),
                subtitle: const Text(
                  'Perangkat memberi pakan otomatis pada waktu yang diaktifkan.',
                ),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _addTime,
              icon: const Icon(Icons.add_alarm),
              label: const Text('Tambah Waktu'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: sorted.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada waktu yang ditambahkan.',
                        style: TextStyle(color: AppColors.neutral),
                      ),
                    )
                  : ListView.builder(
                      itemCount: sorted.length,
                      itemBuilder: (_, i) {
                        final id = sorted[i].key;
                        final data = sorted[i].value;
                        final lastRun = (data['last_run'] as String?) ?? '';
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: Checkbox(
                              value: data['enabled'] as bool,
                              onChanged: (v) => _toggle(id, v ?? false),
                            ),
                            title: Text(
                              data['time'] ?? '-',
                              style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: lastRun.isEmpty
                                ? null
                                : Text('Terakhir dijalankan: $lastRun'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: AppColors.bad,
                              onPressed: () => _remove(id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Simpan Jadwal'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../logic/sensor_status.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/logo.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang FishFeed')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
        children: [
          const Center(child: FishFeedLogo(size: 88)),
          const SizedBox(height: Gap.lg),
          Text(
            'FishFeed',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          Text(
            'Pemberi pakan ikan otomatis berbasis ESP32',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: Gap.xl),
          const SectionHeader('Cara kerja'),
          const _Step(
            number: 1,
            title: 'Perangkat membaca sensor',
            body:
                'ESP32 mengukur sisa pakan dengan sensor ultrasonik, '
                'kekeruhan air, dan tegangan baterai.',
          ),
          const _Step(
            number: 2,
            title: 'Data dikirim ke Firebase',
            body:
                'Telemetri dikirim ke Realtime Database, lalu tampil langsung '
                'di aplikasi.',
          ),
          const _Step(
            number: 3,
            title: 'Aplikasi mengirim perintah',
            body:
                'Tombol beri makan dan jadwal disimpan di Firebase dan dibaca '
                'perangkat. Servo membuka katup untuk menjatuhkan pakan.',
          ),
          const _Step(
            number: 4,
            title: 'Jadwal tetap jalan sendiri',
            body:
                'Jadwal dijalankan perangkat dengan jam RTC DS3231, jadi '
                'tidak bergantung pada ponsel.',
          ),
          const SizedBox(height: Gap.lg),
          const SectionHeader('Ambang batas sensor'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.set_meal_outlined),
                  title: const Text('Pakan'),
                  subtitle: Text(
                    'Jarak sensor ke pakan: cukup sampai '
                    '${_number(SensorThresholds.feedHalfCm)} cm, menipis di bawah '
                    '${_number(SensorThresholds.feedEmptyCm)} cm, dan kosong mulai '
                    '${_number(SensorThresholds.feedEmptyCm)} cm.',
                  ),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.water_drop_outlined),
                  title: const Text('Kekeruhan air'),
                  subtitle: Text(
                    'Keruh bila di atas '
                    '${_number(SensorThresholds.turbidityCloudyNtu)} NTU.',
                  ),
                ),
                const Divider(indent: 56),
                const ListTile(
                  leading: Icon(Icons.battery_std_rounded),
                  title: Text('Baterai'),
                  subtitle: Text(
                    'Rendah di ${SensorThresholds.batteryLowPercent}% ke bawah, '
                    'sedang sampai ${SensorThresholds.batteryMediumPercent}%.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 3.0 menjadi "3", 2.5 tetap "2.5".
String _number(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body});

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.ocean,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

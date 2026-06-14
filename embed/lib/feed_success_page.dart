import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

/// Halaman konfirmasi setelah perintah pemberian pakan berhasil dikirim.
class FeedSuccessPage extends StatelessWidget {
  final String time;
  const FeedSuccessPage({super.key, required this.time});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pemberian Pakan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.good, size: 96),
              const SizedBox(height: 20),
              Text(
                'Perintah pemberian pakan terkirim pukul $time.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Perangkat akan memproses perintah dalam beberapa saat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.neutral),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali ke Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

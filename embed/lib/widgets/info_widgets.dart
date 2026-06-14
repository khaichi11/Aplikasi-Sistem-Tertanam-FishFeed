import 'package:flutter/material.dart';

import '../sensor_status.dart';
import '../theme/app_theme.dart';

/// Kartu sederhana dengan padding seragam untuk membungkus konten dashboard.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Indikator titik berwarna untuk menandai status daring perangkat.
class OnlineDot extends StatelessWidget {
  final bool online;
  const OnlineDot({super.key, required this.online});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: online ? AppColors.good : AppColors.neutral,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Kartu sensor: ikon, judul, status berwarna, dan nilai mentah pendukung.
class SensorTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final StatusInfo status;
  final String? detail;

  const SensorTile({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorForSeverity(status.severity);
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              style: const TextStyle(fontSize: 12, color: AppColors.neutral),
            ),
          ],
        ],
      ),
    );
  }
}

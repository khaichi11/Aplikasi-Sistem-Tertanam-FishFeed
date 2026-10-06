import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../models/activity_entry.dart';
import '../../utils/formatting.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.entry, this.showDate = false});

  final ActivityEntry entry;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, background) =
        !entry.isFeed
            ? (Icons.edit_calendar_rounded, AppColors.ocean, AppColors.sky)
            : entry.isAutomatic
            ? (Icons.alarm_on_rounded, AppColors.teal, AppColors.tealSoft)
            : (Icons.restaurant_rounded, AppColors.coral, AppColors.coralSoft);
    final time = entry.time;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: 2,
      ),
      leading: IconTile(
        icon: icon,
        color: background,
        foreground: color,
        size: 42,
      ),
      title: Text(entry.title),
      subtitle: Text(entry.subtitle),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time == null ? '-' : formatClock(time),
            style: theme.textTheme.titleSmall,
          ),
          Text(
            showDate && time != null
                ? dayLabel(time, context.read<DateTime Function()>()())
                : entry.fromDevice
                ? 'Perangkat'
                : 'Aplikasi',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

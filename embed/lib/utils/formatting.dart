const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

String _two(int n) => n.toString().padLeft(2, '0');

/// Mengubah timestamp ISO 8601 menjadi teks seperti `01 Mei 2024 13:45`.
/// Mengembalikan tanda hubung bila kosong, dan teks asli bila tidak valid.
String formatTimestamp(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return '${_two(dt.day)} ${_months[dt.month - 1]} ${dt.year} '
      '${_two(dt.hour)}:${_two(dt.minute)}';
}

/// Jam saja, misalnya `13:45`.
String formatClock(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

/// Judul kelompok riwayat: "Hari ini", "Kemarin" atau tanggal.
String dayLabel(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(day.year, day.month, day.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  return '${_weekdays[target.weekday - 1]}, ${target.day} '
      '${_months[target.month - 1]} ${target.year}';
}

/// Singkatan hari untuk grafik, misalnya `Sen`.
String weekdayShort(DateTime day) => _weekdays[day.weekday - 1];

/// Waktu relatif singkat: "baru saja", "5 menit lalu", "2 jam lalu".
String timeAgo(String? iso, DateTime now) {
  final time = DateTime.tryParse(iso ?? '');
  if (time == null) return 'belum ada data';
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
  if (diff.inDays < 1) return '${diff.inHours} jam lalu';
  return formatTimestamp(iso);
}

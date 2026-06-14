/// Mengubah timestamp ISO 8601 menjadi teks tanggal-waktu yang mudah dibaca,
/// misalnya `2024-05-01T13:45:00` menjadi `01-05-2024 13:45`.
///
/// Mengembalikan tanda hubung bila masukan kosong atau tidak valid.
String formatTimestamp(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}-${two(dt.month)}-${dt.year} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

# FishFeed (Aplikasi Flutter)

Aplikasi seluler pengendali alat pemberi pakan ikan otomatis berbasis ESP32.
Dokumentasi lengkap proyek (perangkat keras, firmware, dan struktur data
Firebase) berada di [README utama](../README.md).

## Struktur kode

```
lib/
├── main.dart                 Titik masuk dan inisialisasi tema
├── auth_wrapper.dart         Pengalih halaman berdasarkan status login
├── login_page.dart           Halaman masuk
├── signup_page.dart          Halaman pendaftaran
├── dashboard_page.dart       Layar utama: telemetri dan kendali
├── schedule_page.dart        Pengaturan jadwal pemberian pakan
├── activity_log_page.dart    Riwayat aktivitas perangkat
├── device_manager_page.dart  Pemasangan dan penghapusan perangkat
├── feed_success_page.dart    Konfirmasi pemberian pakan
├── models/                   Model data (riwayat aktivitas)
├── services/                 Lapisan akses Firebase
├── widgets/                  Komponen UI yang dapat dipakai ulang
├── theme/                    Tema dan palet warna
└── utils/                    Fungsi bantu
```

## Menjalankan

```
flutter pub get
flutter run
```

Konfigurasi Firebase (`google-services.json` untuk Android) tidak disertakan di
repositori dan harus ditambahkan sendiri.

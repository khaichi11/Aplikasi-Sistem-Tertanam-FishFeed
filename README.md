# FishFeed

Sistem pemberi pakan ikan otomatis berbasis ESP32 yang dikendalikan melalui
aplikasi seluler. Perangkat membaca kondisi air dan persediaan pakan, mengirim
data ke Firebase secara langsung, serta menjalankan pemberian pakan baik secara
manual maupun terjadwal.

Proyek terdiri dari dua bagian:

- **Firmware ESP32** (`Final_Embed/`) yang membaca sensor, menggerakkan servo
  pakan, dan menyinkronkan data dengan Firebase.
- **Aplikasi Flutter** (`embed/`) untuk memantau perangkat dan mengirim perintah.

## Fitur

- Pemantauan langsung kekeruhan air, persediaan pakan, dan baterai.
- Pemberian pakan manual dari aplikasi dengan konfirmasi.
- Penjadwalan pemberian pakan otomatis berbasis RTC pada perangkat.
- Riwayat aktivitas yang mencatat pemberian pakan manual, terjadwal, dan
  perubahan jadwal.
- Dukungan banyak perangkat per akun melalui pemasangan ID perangkat.
- Autentikasi pengguna dengan email dan kata sandi.

## Arsitektur

```
+-----------------+        perintah & jadwal        +-------------------+
|                 |  ----------------------------->  |                   |
|  Aplikasi       |                                  |   Firebase        |
|  Flutter        |  <-----------------------------  |   (RTDB +         |
|                 |        telemetri & riwayat       |   Firestore)      |
+-----------------+                                  +-------------------+
                                                              ^
                                              telemetri |     | perintah & jadwal
                                                         v     |
                                                   +-------------------+
                                                   |   ESP32           |
                                                   |   sensor + servo  |
                                                   +-------------------+
```

Aplikasi tidak berkomunikasi langsung dengan perangkat. Seluruh pertukaran data
melewati Firebase, sehingga perangkat dan aplikasi tidak perlu berada pada
jaringan yang sama.

## Tangkapan Layar

Gambar disimpan pada `docs/images/`. Ganti berkas di folder tersebut untuk
memperbarui tampilan di bawah.

| Masuk | Dashboard | Jadwal |
|-------|-----------|--------|
| ![Masuk](docs/images/login.png) | ![Dashboard](docs/images/dashboard.png) | ![Jadwal](docs/images/schedule.png) |

| Riwayat | Kelola Perangkat | Rangkaian |
|---------|------------------|-----------|
| ![Riwayat](docs/images/activity.png) | ![Kelola Perangkat](docs/images/device-manager.png) | ![Rangkaian](docs/images/wiring.png) |

## Perangkat Keras

| Komponen                | Fungsi                                  |
|-------------------------|-----------------------------------------|
| ESP32                   | Pengendali utama                        |
| RTC DS3231              | Sumber waktu untuk jadwal               |
| Sensor ultrasonik HC-SR04 | Mengukur jarak permukaan pakan        |
| Sensor kekeruhan        | Mengukur kekeruhan air (NTU)            |
| Servo                   | Membuka katup penjatuh pakan            |
| Baterai + pembagi tegangan | Sumber daya dan pembacaan persentase |

### Pemetaan pin

| Pin ESP32 | Sambungan                          |
|-----------|------------------------------------|
| GPIO 21   | SDA (RTC DS3231)                   |
| GPIO 22   | SCL (RTC DS3231)                   |
| GPIO 5    | Trigger sensor ultrasonik          |
| GPIO 18   | Echo sensor ultrasonik             |
| GPIO 34   | Keluaran analog sensor kekeruhan   |
| GPIO 32   | Pembagi tegangan baterai           |
| GPIO 13   | Sinyal servo                       |

## Struktur Data Firebase

### Realtime Database

```
devices/{id}/status/online        bool      status daring (ditulis perangkat)
devices/{id}/sensors              objek     telemetri terbaru (ditulis perangkat)
devices/{id}/info/name            string    nama perangkat
commands/{id}/current_command     objek     perintah dari aplikasi
schedules/{id}                    objek     jadwal pemberian pakan
activity/{id}/{pushId}            objek     riwayat aktivitas
```

Objek `sensors` berisi `turbidity` (NTU), `distance_cm`, `battery_percent`,
`battery_voltage`, dan `timestamp`.

Objek `schedules/{id}` berisi `active` (bool) dan `entries`, yaitu kumpulan
jadwal dengan `time` (format 24 jam `HH:mm`), `enabled` (bool), dan `last_run`
(tanggal eksekusi terakhir).

### Firestore

```
users/{uid}
  email       string
  createdAt   timestamp
  devices     map   daftar perangkat milik pengguna
```

## Struktur Repositori

```
.
├── embed/          Aplikasi Flutter
├── Final_Embed/    Firmware ESP32 (Arduino)
├── docs/images/    Gambar dokumentasi
└── README.md
```

## Menjalankan Aplikasi

Diperlukan Flutter SDK 3.7 atau lebih baru.

```
cd embed
flutter pub get
flutter run
```

Aplikasi memerlukan konfigurasi Firebase milik Anda. Tambahkan
`google-services.json` (Android) ke `embed/android/app/` dan aktifkan
Authentication (email/kata sandi), Realtime Database, serta Firestore pada
proyek Firebase. Berkas konfigurasi tidak disertakan di repositori.

## Mengunggah Firmware

Diperlukan Arduino IDE dengan dukungan papan ESP32 dan pustaka berikut:
`Firebase ESP Client`, `ESP32Servo`, dan `RTClib`.

1. Salin `Final_Embed/config.example.h` menjadi `Final_Embed/config.h`.
2. Isi kredensial WiFi dan Firebase pada `config.h`.
3. Buka `Final_Embed/Final_Embed.ino`, pilih papan ESP32, lalu unggah.

Berkas `config.h` berisi kredensial dan tidak diunggah ke repositori.

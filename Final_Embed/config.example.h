// Template konfigurasi rahasia untuk firmware FishFeed.
//
// Salin berkas ini menjadi "config.h" pada folder yang sama, lalu isi sesuai
// jaringan dan proyek Firebase Anda. Berkas "config.h" sengaja diabaikan oleh
// Git agar kredensial tidak ikut terunggah.

#ifndef CONFIG_H
#define CONFIG_H

// Jaringan WiFi.
#define WIFI_SSID       "NAMA_WIFI"
#define WIFI_PASSWORD   "KATA_SANDI_WIFI"

// Kredensial proyek Firebase (Realtime Database + Authentication).
#define API_KEY         "FIREBASE_WEB_API_KEY"
#define DATABASE_URL    "https://nama-proyek-default-rtdb.firebaseio.com/"
#define USER_EMAIL      "akun@contoh.com"
#define USER_PASSWORD   "KATA_SANDI_AKUN"

// Identitas perangkat. Nilai ini juga dipakai sebagai kunci di Realtime
// Database dan dimasukkan saat memasangkan perangkat di aplikasi.
#define DEVICE_ID       "FF-2024"

#endif  // CONFIG_H

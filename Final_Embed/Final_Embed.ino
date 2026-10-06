/*
 * FishFeed - Firmware ESP32 untuk pemberi pakan ikan otomatis.
 *
 * Tanggung jawab firmware:
 *   - Membaca sensor: kekeruhan air, jarak permukaan pakan (ultrasonik), dan
 *     tegangan baterai.
 *   - Mengirim telemetri ke Firebase Realtime Database secara berkala.
 *   - Menjalankan pemberian pakan saat menerima perintah manual dari aplikasi.
 *   - Menjalankan pemberian pakan terjadwal berdasarkan RTC DS3231.
 *   - Mencatat pemberian pakan terjadwal ke riwayat aktivitas.
 *
 * Tugas dijalankan sebagai task FreeRTOS yang terpisah. Setiap siklus, ESP32
 * aktif selama beberapa detik lalu masuk deep sleep untuk menghemat daya
 * (lihat AWAKE_DURATION_MS dan DEEP_SLEEP_US).
 *
 * Semua panggilan Firebase dilindungi satu mutex, karena objek FirebaseData
 * tidak aman dipakai beberapa task sekaligus.
 *
 * Kredensial WiFi dan Firebase berada di config.h (tidak diunggah ke Git).
 * Salin config.example.h menjadi config.h sebelum melakukan kompilasi.
 *
 * Struktur data Realtime Database:
 *   devices/{id}/status/online     bool
 *   devices/{id}/status/last_seen  waktu bangun terakhir (ISO 8601)
 *   devices/{id}/sensors           objek telemetri
 *   commands/{id}/current_command  perintah dari aplikasi
 *   schedules/{id}                 jadwal pemberian pakan
 *   activity/{id}                  riwayat aktivitas
 */

#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <Wire.h>
#include <ESP32Servo.h>
#include "RTClib.h"
#include "esp_sleep.h"
#include <time.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/semphr.h>

#include "config.h"

// --- Pin perangkat keras ---------------------------------------------------
#define RTC_SDA_PIN     21   // SDA RTC DS3231
#define RTC_SCL_PIN     22   // SCL RTC DS3231
#define BATT_DIV_PIN    32   // Pembagi tegangan baterai
#define TURBIDITY_PIN   34   // Sensor kekeruhan (analog)
#define TRIG_PIN        5    // Trigger sensor ultrasonik
#define ECHO_PIN        18   // Echo sensor ultrasonik (pakai pembagi tegangan 5 V -> 3,3 V)
#define SERVO_PIN       13   // Servo penggerak katup pakan

// --- Kalibrasi sensor kekeruhan -------------------------------------------
#define V0              3.0f    // Tegangan keluaran pada 0 NTU
#define V100            1.5f    // Tegangan keluaran pada 100 NTU
#define NTU100          100.0f

// --- Kalibrasi baterai -----------------------------------------------------
#define BATT_DIVIDER_RATIO  2.0f   // Pembagi tegangan 1:1 (dua resistor sama besar)
#define BATT_EMPTY_MV       3300   // Tegangan baterai dianggap 0%
#define BATT_FULL_MV        4200   // Tegangan baterai dianggap 100%

// --- Posisi servo ----------------------------------------------------------
// Sudut dalam derajat (0-180). Sesuaikan bila mekanisme katup berbeda.
#define SERVO_REST_POSITION    0     // Posisi tertutup (diam)
#define SERVO_FEED_POSITION    180   // Posisi membuka katup untuk menjatuhkan pakan
#define SERVO_FEED_DURATION_MS 1000  // Lama katup terbuka per pemberian pakan

// --- Pengaturan waktu ------------------------------------------------------
#define AWAKE_DURATION_MS          5000ULL          // Durasi aktif sebelum deep sleep
#define DEEP_SLEEP_US              (5000ULL * 1000) // Durasi deep sleep (mikrodetik)
#define OFFLINE_SLEEP_US           (30000ULL * 1000) // Tidur lebih lama bila tidak ada WiFi
#define SENSOR_READ_INTERVAL       5000
#define COMMAND_CHECK_INTERVAL     10000
#define SCHEDULE_CHECK_INTERVAL    10000
#define WIFI_TIMEOUT_MS            15000
#define NTP_TIMEOUT_MS             10000
#define FIREBASE_READY_TIMEOUT_MS  15000
// Sinkronisasi RTC dengan NTP sekali setiap sekian kali bangun (sekitar 2 jam).
#define NTP_RESYNC_EVERY_BOOTS     360

const char* ntpServer = "pool.ntp.org";
const long gmtOffset = 7 * 3600;  // WIB (UTC+7)
const int daylightOffset = 0;

// Bertahan saat deep sleep, hilang saat listrik padam.
RTC_DATA_ATTR uint32_t bootCount = 0;

RTC_DS3231 rtc;
FirebaseAuth auth;
FirebaseConfig config;
FirebaseData fbdo;
Servo feederServo;

TaskHandle_t turbidityTaskHandle = NULL;
TaskHandle_t ultrasonicTaskHandle = NULL;
TaskHandle_t batteryTaskHandle = NULL;
TaskHandle_t sendTaskHandle = NULL;
TaskHandle_t scheduleTaskHandle = NULL;
TaskHandle_t commandTaskHandle = NULL;

SemaphoreHandle_t dataMutex;
SemaphoreHandle_t firebaseMutex;

typedef struct {
  float turbidity_raw;
  float turbidity_volt;
  float turbidity_ntu;
  long distance_cm;       // -1 bila pembacaan gagal
  float battery_voltage;
  int battery_percent;
} SensorData;

SensorData sensorData = {0, 0, 0, -1, 0, 0};

// ---------------------------------------------------------------------------
// Firebase: setiap panggilan memegang firebaseMutex selama memakai fbdo.
// ---------------------------------------------------------------------------

bool fbSetJSON(const String& path, FirebaseJson* json) {
  xSemaphoreTake(firebaseMutex, portMAX_DELAY);
  bool ok = Firebase.RTDB.setJSON(&fbdo, path.c_str(), json);
  xSemaphoreGive(firebaseMutex);
  return ok;
}

bool fbPushJSON(const String& path, FirebaseJson* json) {
  xSemaphoreTake(firebaseMutex, portMAX_DELAY);
  bool ok = Firebase.RTDB.pushJSON(&fbdo, path.c_str(), json);
  xSemaphoreGive(firebaseMutex);
  return ok;
}

bool fbSetString(const String& path, const String& value) {
  xSemaphoreTake(firebaseMutex, portMAX_DELAY);
  bool ok = Firebase.RTDB.setString(&fbdo, path.c_str(), value);
  xSemaphoreGive(firebaseMutex);
  return ok;
}

bool fbSetBool(const String& path, bool value) {
  xSemaphoreTake(firebaseMutex, portMAX_DELAY);
  bool ok = Firebase.RTDB.setBool(&fbdo, path.c_str(), value);
  xSemaphoreGive(firebaseMutex);
  return ok;
}

// Membaca string. pathMissing bernilai true bila jalur belum ada.
bool fbGetString(const String& path, String& out, bool& pathMissing) {
  xSemaphoreTake(firebaseMutex, portMAX_DELAY);
  bool ok = Firebase.RTDB.getString(&fbdo, path.c_str());
  pathMissing = !ok && fbdo.errorReason() == "path not exist";
  if (ok) out = fbdo.stringData();
  xSemaphoreGive(firebaseMutex);
  return ok;
}

// Membaca objek JSON dan menyalin isinya, supaya bisa diproses tanpa mutex.
bool fbGetJSON(const String& path, FirebaseJson& out) {
  xSemaphoreTake(firebaseMutex, portMAX_DELAY);
  bool ok = Firebase.RTDB.getJSON(&fbdo, path.c_str());
  String payload = ok ? fbdo.payload() : String();
  if (!ok) {
    Serial.printf("Gagal membaca %s: %s\n", path.c_str(), fbdo.errorReason().c_str());
  }
  xSemaphoreGive(firebaseMutex);
  if (ok) out.setJsonData(payload);
  return ok;
}

String devicePath(const char* child) {
  return "/devices/" + String(DEVICE_ID) + "/" + child;
}

// ---------------------------------------------------------------------------
// Waktu
// ---------------------------------------------------------------------------

// Membuat timestamp ISO 8601 dari waktu RTC saat ini.
void buildIsoTimestamp(const DateTime& now, char* buffer, size_t size) {
  snprintf(buffer, size, "%04d-%02d-%02dT%02d:%02d:%02d",
           now.year(), now.month(), now.day(),
           now.hour(), now.minute(), now.second());
}

// Menyetel RTC dari NTP. Mengembalikan false bila waktu tidak didapat sebelum
// batas waktu, tanpa membuat perangkat macet.
bool syncRtcFromNtp() {
  configTime(gmtOffset, daylightOffset, ntpServer);
  struct tm tm;
  if (!getLocalTime(&tm, NTP_TIMEOUT_MS)) {
    Serial.println("Gagal mengambil waktu NTP, RTC tidak diubah");
    return false;
  }
  rtc.adjust(DateTime(tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
                      tm.tm_hour, tm.tm_min, tm.tm_sec));
  Serial.printf("RTC disetel dari NTP: %04d-%02d-%02d %02d:%02d:%02d\n",
                tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
                tm.tm_hour, tm.tm_min, tm.tm_sec);
  return true;
}

bool rtcNeedsSync() {
  return rtc.lostPower()
      || rtc.now().year() < 2024
      || bootCount % NTP_RESYNC_EVERY_BOOTS == 1;
}

// ---------------------------------------------------------------------------
// Sensor dan aktuator
// ---------------------------------------------------------------------------

// Menjalankan servo satu siklus untuk menjatuhkan pakan.
void dispenseFeed() {
  feederServo.write(SERVO_FEED_POSITION);
  vTaskDelay(SERVO_FEED_DURATION_MS / portTICK_PERIOD_MS);
  feederServo.write(SERVO_REST_POSITION);
}

long readUltrasonicCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(5);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long dur = pulseIn(ECHO_PIN, HIGH, 30000);
  return (dur > 0) ? (long)((dur / 58.2f) + 0.5f) : -1;
}

void readTurbidity() {
  int raw = analogRead(TURBIDITY_PIN);
  float volt = raw * (3.3f / 4095.0f);
  float ntu = max(0.0f, NTU100 / (V0 - V100) * (V0 - volt));

  xSemaphoreTake(dataMutex, portMAX_DELAY);
  sensorData.turbidity_raw = raw;
  sensorData.turbidity_volt = volt;
  sensorData.turbidity_ntu = ntu;
  xSemaphoreGive(dataMutex);
}

void readDistance() {
  long dist = readUltrasonicCm();
  xSemaphoreTake(dataMutex, portMAX_DELAY);
  sensorData.distance_cm = dist;
  xSemaphoreGive(dataMutex);
}

void readBattery() {
  // analogReadMilliVolts memakai kalibrasi ADC bawaan ESP32.
  uint32_t mv = analogReadMilliVolts(BATT_DIV_PIN) * BATT_DIVIDER_RATIO;
  int pct = constrain(map((long)mv, BATT_EMPTY_MV, BATT_FULL_MV, 0, 100), 0, 100);

  xSemaphoreTake(dataMutex, portMAX_DELAY);
  sensorData.battery_voltage = mv / 1000.0f;
  sensorData.battery_percent = pct;
  xSemaphoreGive(dataMutex);
}

// Mencatat satu aktivitas pemberian pakan ke riwayat di Realtime Database.
void logFeedActivity(const char* mode) {
  char ts[25];
  buildIsoTimestamp(rtc.now(), ts, sizeof(ts));

  FirebaseJson activity;
  activity.set("type", "feed");
  activity.set("mode", mode);
  activity.set("timestamp", ts);
  activity.set("source", "device");
  fbPushJSON("/activity/" + String(DEVICE_ID), &activity);
}

// ---------------------------------------------------------------------------
// Task FreeRTOS
// ---------------------------------------------------------------------------

void turbidityTask(void* pvParameters) {
  for (;;) {
    readTurbidity();
    vTaskDelay(SENSOR_READ_INTERVAL / portTICK_PERIOD_MS);
  }
}

void ultrasonicTask(void* pvParameters) {
  for (;;) {
    readDistance();
    vTaskDelay(SENSOR_READ_INTERVAL / portTICK_PERIOD_MS);
  }
}

void batteryTask(void* pvParameters) {
  for (;;) {
    readBattery();
    vTaskDelay(SENSOR_READ_INTERVAL / portTICK_PERIOD_MS);
  }
}

void sendSensorDataTask(void* pvParameters) {
  for (;;) {
    char ts[25];
    buildIsoTimestamp(rtc.now(), ts, sizeof(ts));

    xSemaphoreTake(dataMutex, portMAX_DELAY);
    SensorData snapshot = sensorData;
    xSemaphoreGive(dataMutex);

    FirebaseJson j;
    j.set("turbidity_raw", snapshot.turbidity_raw);
    j.set("turbidity_volt", snapshot.turbidity_volt);
    j.set("turbidity", snapshot.turbidity_ntu);
    // Pembacaan gagal tidak dikirim, supaya aplikasi tidak salah membaca
    // wadah sebagai penuh.
    if (snapshot.distance_cm >= 0) j.set("distance_cm", snapshot.distance_cm);
    j.set("battery_voltage", snapshot.battery_voltage);
    j.set("battery_percent", snapshot.battery_percent);
    j.set("timestamp", ts);

    String path = devicePath("sensors");
    if (!fbSetJSON(path, &j)) {
      vTaskDelay(100 / portTICK_PERIOD_MS);
      fbSetJSON(path, &j);
    }
    Serial.printf("Terkirim: ntu=%.1f jarak=%ld baterai=%.2fV %d%% @%s\n",
                  snapshot.turbidity_ntu, snapshot.distance_cm,
                  snapshot.battery_voltage, snapshot.battery_percent, ts);

    vTaskDelay(SENSOR_READ_INTERVAL / portTICK_PERIOD_MS);
  }
}

void checkForCommandsTask(void* pvParameters) {
  const String base = "/commands/" + String(DEVICE_ID) + "/current_command";
  for (;;) {
    String status, type;
    bool missing = false;
    if (fbGetString(base + "/status", status, missing)) {
      bool unused = false;
      if (status == "pending" && fbGetString(base + "/type", type, unused)
          && type == "feed") {
        dispenseFeed();
        fbSetString(base + "/status", "done");
        Serial.println("Pemberian pakan manual selesai");
      }
    } else if (missing) {
      FirebaseJson init;
      init.set("type", "none");
      init.set("status", "done");
      fbSetJSON(base, &init);
    }
    vTaskDelay(COMMAND_CHECK_INTERVAL / portTICK_PERIOD_MS);
  }
}

// Mengubah "HH:mm", "HH:mm:ss" atau "h:mm AM/PM" menjadi jam dan menit.
bool parseScheduleTime(String t, int& hh, int& mm) {
  t.trim();
  bool pm = t.endsWith("PM"), am = t.endsWith("AM");
  if (pm || am) {
    t = t.substring(0, t.length() - 2);
    t.trim();
  }
  int c1 = t.indexOf(':');
  if (c1 <= 0) return false;
  int c2 = t.indexOf(':', c1 + 1);
  hh = t.substring(0, c1).toInt();
  mm = (c2 > 0) ? t.substring(c1 + 1, c2).toInt() : t.substring(c1 + 1).toInt();
  if (pm && hh != 12) hh += 12;
  if (am && hh == 12) hh = 0;
  return hh >= 0 && hh < 24 && mm >= 0 && mm < 60;
}

void checkScheduleTask(void* pvParameters) {
  const String schedPath = "/schedules/" + String(DEVICE_ID);
  for (;;) {
    FirebaseJson root;
    FirebaseJsonData jd;
    if (!fbGetJSON(schedPath, root)
        || !root.get(jd, "active") || !jd.boolValue
        || !root.get(jd, "entries")) {
      vTaskDelay(SCHEDULE_CHECK_INTERVAL / portTICK_PERIOD_MS);
      continue;
    }
    FirebaseJson entries;
    jd.getJSON(entries);

    DateTime now = rtc.now();
    char todayBuf[16];
    snprintf(todayBuf, sizeof(todayBuf), "%04d-%02d-%02d",
             now.year(), now.month(), now.day());
    String today(todayBuf);

    String dueKey;
    size_t count = entries.iteratorBegin();
    for (size_t i = 0; i < count; i++) {
      FirebaseJson::IteratorValue iv = entries.valueAt(i);
      // Iterator juga menelusuri isi tiap entri (time, enabled, ...).
      // Hanya objek entri yang diproses.
      if (!iv.value.startsWith("{")) continue;
      FirebaseJson entry(iv.value);
      FirebaseJsonData field;

      if (!entry.get(field, "enabled") || !field.boolValue) continue;
      if (!entry.get(field, "time")) continue;
      int hh = 0, mm = 0;
      if (!parseScheduleTime(field.stringValue, hh, mm)) continue;
      String lastRun = entry.get(field, "last_run") ? field.stringValue : String();

      if (hh == now.hour() && mm == now.minute() && lastRun != today) {
        dueKey = iv.key;
        break;
      }
    }
    entries.iteratorEnd();

    if (dueKey.length() > 0) {
      Serial.printf("Pemberian pakan terjadwal (entri %s)\n", dueKey.c_str());
      // Tandai dulu, supaya tidak diulang bila perangkat tertidur di tengah.
      fbSetString(schedPath + "/entries/" + dueKey + "/last_run", today);
      dispenseFeed();
      logFeedActivity("auto");
    }
    vTaskDelay(SCHEDULE_CHECK_INTERVAL / portTICK_PERIOD_MS);
  }
}

// ---------------------------------------------------------------------------
// Siklus bangun
// ---------------------------------------------------------------------------

void goToSleep(uint64_t sleepUs) {
  Serial.printf("Deep sleep %llu ms\n", sleepUs / 1000);
  Serial.flush();
  esp_sleep_enable_timer_wakeup(sleepUs);
  esp_deep_sleep_start();
}

bool connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - start > WIFI_TIMEOUT_MS) return false;
    delay(250);
  }
  Serial.printf("WiFi terhubung, IP %s\n", WiFi.localIP().toString().c_str());
  return true;
}

bool startFirebase() {
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  unsigned long start = millis();
  while (!Firebase.ready()) {
    if (millis() - start > FIREBASE_READY_TIMEOUT_MS) return false;
    delay(100);
  }
  return true;
}

void stopTask(TaskHandle_t& handle) {
  if (handle != NULL) {
    vTaskDelete(handle);
    handle = NULL;
  }
}

void setup() {
  Serial.begin(115200);
  bootCount++;
  Serial.printf("\nFishFeed %s, bangun ke-%lu\n", DEVICE_ID, (unsigned long)bootCount);

  dataMutex = xSemaphoreCreateMutex();
  firebaseMutex = xSemaphoreCreateMutex();

  feederServo.attach(SERVO_PIN);
  feederServo.write(SERVO_REST_POSITION);
  analogReadResolution(12);
  analogSetPinAttenuation(TURBIDITY_PIN, ADC_11db);
  analogSetPinAttenuation(BATT_DIV_PIN, ADC_11db);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT_PULLDOWN);

  Wire.begin(RTC_SDA_PIN, RTC_SCL_PIN);
  if (!rtc.begin()) {
    Serial.println("RTC tidak terdeteksi, coba lagi nanti");
    goToSleep(OFFLINE_SLEEP_US);
  }

  // Baca sensor sekali sebelum mengirim, agar data pertama tidak kosong.
  readTurbidity();
  readDistance();
  readBattery();

  if (!connectWiFi()) {
    Serial.println("WiFi tidak tersedia");
    goToSleep(OFFLINE_SLEEP_US);
  }
  if (rtcNeedsSync()) syncRtcFromNtp();
  if (!startFirebase()) {
    Serial.println("Firebase belum siap");
    goToSleep(OFFLINE_SLEEP_US);
  }

  char ts[25];
  buildIsoTimestamp(rtc.now(), ts, sizeof(ts));
  fbSetBool(devicePath("status/online"), true);
  fbSetString(devicePath("status/last_seen"), ts);

  xTaskCreatePinnedToCore(turbidityTask, "Turbidity Task", 4096, NULL, 2, &turbidityTaskHandle, 0);
  xTaskCreatePinnedToCore(ultrasonicTask, "Ultrasonic Task", 4096, NULL, 2, &ultrasonicTaskHandle, 0);
  xTaskCreatePinnedToCore(batteryTask, "Battery Task", 4096, NULL, 2, &batteryTaskHandle, 0);
  xTaskCreatePinnedToCore(sendSensorDataTask, "Send Sensor Data Task", 8192, NULL, 3, &sendTaskHandle, 1);
  xTaskCreatePinnedToCore(checkForCommandsTask, "Command Task", 8192, NULL, 2, &commandTaskHandle, 1);
  xTaskCreatePinnedToCore(checkScheduleTask, "Schedule Task", 8192, NULL, 2, &scheduleTaskHandle, 1);

  // Biarkan tugas berjalan beberapa saat, lalu hentikan dan masuk deep sleep.
  vTaskDelay(AWAKE_DURATION_MS / portTICK_PERIOD_MS);

  // Tunggu panggilan Firebase yang sedang berjalan selesai sebelum berhenti.
  xSemaphoreTake(firebaseMutex, portMAX_DELAY);
  stopTask(turbidityTaskHandle);
  stopTask(ultrasonicTaskHandle);
  stopTask(batteryTaskHandle);
  stopTask(sendTaskHandle);
  stopTask(commandTaskHandle);
  stopTask(scheduleTaskHandle);
  feederServo.write(SERVO_REST_POSITION);

  goToSleep(DEEP_SLEEP_US);
}

void loop() {
  // Kosong: seluruh pekerjaan ditangani oleh task FreeRTOS di setup().
}

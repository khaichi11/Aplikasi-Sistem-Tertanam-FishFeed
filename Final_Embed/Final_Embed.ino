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
 * Kredensial WiFi dan Firebase berada di config.h (tidak diunggah ke Git).
 * Salin config.example.h menjadi config.h sebelum melakukan kompilasi.
 *
 * Struktur data Realtime Database:
 *   devices/{id}/status/online    bool
 *   devices/{id}/sensors          objek telemetri
 *   commands/{id}/current_command perintah dari aplikasi
 *   schedules/{id}                jadwal pemberian pakan
 *   activity/{id}                 riwayat aktivitas
 */

#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <Wire.h>
#include <ESP32Servo.h>
#include "RTClib.h"
#include <driver/adc.h>
#include "esp_sleep.h"
#include <time.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include "config.h"

// --- Pin perangkat keras ---------------------------------------------------
#define BATT_DIV_PIN    32   // Pembagi tegangan baterai
#define TURBIDITY_PIN   34   // Sensor kekeruhan (analog)
#define TRIG_PIN        5    // Trigger sensor ultrasonik
#define ECHO_PIN        18   // Echo sensor ultrasonik
#define SERVO_PIN       13   // Servo penggerak katup pakan

// --- Kalibrasi sensor kekeruhan -------------------------------------------
#define V0              3.0f    // Tegangan keluaran pada 0 NTU
#define V100            1.5f    // Tegangan keluaran pada 100 NTU
#define NTU100          100.0f

// --- Posisi servo ----------------------------------------------------------
// Sudut dalam derajat (0-180). Sesuaikan bila mekanisme katup berbeda.
#define SERVO_REST_POSITION    0     // Posisi tertutup (diam)
#define SERVO_FEED_POSITION    180   // Posisi membuka katup untuk menjatuhkan pakan
#define SERVO_FEED_DURATION_MS 1000  // Lama katup terbuka per pemberian pakan

// --- Pengaturan waktu ------------------------------------------------------
#define AWAKE_DURATION_MS       5000ULL          // Durasi aktif sebelum deep sleep
#define DEEP_SLEEP_US           (5000ULL * 1000) // Durasi deep sleep (mikrodetik)
#define SENSOR_READ_INTERVAL    5000
#define RTC_SYNC_INTERVAL       60000
#define COMMAND_CHECK_INTERVAL  10000
#define SCHEDULE_CHECK_INTERVAL 10000

const char* ntpServer = "pool.ntp.org";
const long gmtOffset = 7 * 3600;  // WIB (UTC+7)
const int daylightOffset = 0;

RTC_DS3231 rtc;
FirebaseAuth auth;
FirebaseConfig config;
FirebaseData fbdo;
Servo feederServo;

TaskHandle_t turbidityTaskHandle = NULL;
TaskHandle_t ultrasonicTaskHandle = NULL;
TaskHandle_t rtcSyncTaskHandle = NULL;
TaskHandle_t scheduleTaskHandle = NULL;
TaskHandle_t commandTaskHandle = NULL;

SemaphoreHandle_t dataMutex;

typedef struct {
  float turbidity_raw;
  float turbidity_volt;
  float turbidity_ntu;
  long distance_cm;
  float battery_voltage;
  int battery_percent;
  char timestamp[25];
} SensorData;

SensorData sensorData;

// Menjalankan servo satu siklus untuk menjatuhkan pakan.
void dispenseFeed() {
  feederServo.write(SERVO_FEED_POSITION);
  vTaskDelay(SERVO_FEED_DURATION_MS / portTICK_PERIOD_MS);
  feederServo.write(SERVO_REST_POSITION);
}

// Membuat timestamp ISO 8601 dari waktu RTC saat ini.
void buildIsoTimestamp(const DateTime& now, char* buffer, size_t size) {
  snprintf(buffer, size, "%04d-%02d-%02dT%02d:%02d:%02d",
           now.year(), now.month(), now.day(),
           now.hour(), now.minute(), now.second());
}

// Mencatat satu aktivitas pemberian pakan ke riwayat di Realtime Database.
void logFeedActivity(const char* mode) {
  DateTime now = rtc.now();
  char ts[25];
  buildIsoTimestamp(now, ts, sizeof(ts));

  FirebaseJson activity;
  activity.set("type", "feed");
  activity.set("mode", mode);
  activity.set("timestamp", ts);
  activity.set("source", "device");

  String path = "/activity/" + String(DEVICE_ID);
  Firebase.RTDB.pushJSON(&fbdo, path.c_str(), &activity);
}

void clearOscFlag() {
  Wire.beginTransmission(0x68);
  Wire.write(0x0F);
  Wire.write(0x00);
  Wire.endTransmission();
}

void syncDS3231toNTP() {
  configTime(gmtOffset, daylightOffset, ntpServer);
  Serial.print("Menunggu NTP");
  while (time(nullptr) < 1609459200) {
    delay(500);
    Serial.print('.');
  }
  Serial.println();

  struct tm tm;
  if (!getLocalTime(&tm)) {
    Serial.println("Gagal mengambil waktu NTP");
    return;
  }
  Serial.printf("Waktu NTP: %04d-%02d-%02d %02d:%02d:%02d\n",
                tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
                tm.tm_hour, tm.tm_min, tm.tm_sec);

  rtc.adjust(DateTime(
    tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
    tm.tm_hour, tm.tm_min, tm.tm_sec
  ));

  DateTime t2 = rtc.now();
  Serial.printf("RTC setelah disetel: %04d-%02d-%02d %02d:%02d:%02d\n",
                t2.year(), t2.month(), t2.day(),
                t2.hour(), t2.minute(), t2.second());

  clearOscFlag();
}

void ensureRtcValid() {
  DateTime t = rtc.now();
  if (t.year() < 2023 || abs(t.second() - (int)time(nullptr) % 60) > 5) {
    Serial.println("Waktu RTC tidak wajar, sinkronisasi ulang NTP");
    syncDS3231toNTP();
  }
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

void turbidityTask(void *pvParameters) {
  for (;;) {
    int raw = analogRead(TURBIDITY_PIN);
    float volt = raw * (3.3f / 4095.0f);
    float ntu = NTU100 / (V0 - V100) * (V0 - volt);
    ntu = max(0.0f, ntu);

    xSemaphoreTake(dataMutex, portMAX_DELAY);
    sensorData.turbidity_raw = raw;
    sensorData.turbidity_volt = volt;
    sensorData.turbidity_ntu = ntu;
    xSemaphoreGive(dataMutex);

    vTaskDelay(SENSOR_READ_INTERVAL / portTICK_PERIOD_MS);
  }
}

void ultrasonicTask(void *pvParameters) {
  for (;;) {
    long dist = readUltrasonicCm();

    xSemaphoreTake(dataMutex, portMAX_DELAY);
    sensorData.distance_cm = dist;
    xSemaphoreGive(dataMutex);

    vTaskDelay(SENSOR_READ_INTERVAL / portTICK_PERIOD_MS);
  }
}

void batteryTask(void *pvParameters) {
  for (;;) {
    int rawB = analogRead(BATT_DIV_PIN);
    float Vbat = rawB * (3.3f / 4095.0f) * 2.0f;
    int pctBatt = map((int)(Vbat * 1000), 3300, 4200, 0, 100);
    pctBatt = constrain(pctBatt, 0, 100);

    xSemaphoreTake(dataMutex, portMAX_DELAY);
    sensorData.battery_voltage = Vbat;
    sensorData.battery_percent = pctBatt;
    xSemaphoreGive(dataMutex);

    vTaskDelay(SENSOR_READ_INTERVAL / portTICK_PERIOD_MS);
  }
}

void sendSensorDataTask(void *pvParameters) {
  for (;;) {
    DateTime now = rtc.now();
    char ts[25];
    buildIsoTimestamp(now, ts, sizeof(ts));

    xSemaphoreTake(dataMutex, portMAX_DELAY);
    sensorData.timestamp[0] = '\0';
    strncat(sensorData.timestamp, ts, sizeof(sensorData.timestamp) - 1);
    FirebaseJson j;
    j.set("turbidity_raw", sensorData.turbidity_raw);
    j.set("turbidity_volt", sensorData.turbidity_volt);
    j.set("turbidity", sensorData.turbidity_ntu);
    j.set("distance_cm", sensorData.distance_cm);
    j.set("battery_voltage", sensorData.battery_voltage);
    j.set("battery_percent", sensorData.battery_percent);
    j.set("timestamp", sensorData.timestamp);
    xSemaphoreGive(dataMutex);

    String path = "/devices/" + String(DEVICE_ID) + "/sensors";
    if (!Firebase.RTDB.setJSON(&fbdo, path.c_str(), &j)) {
      vTaskDelay(100 / portTICK_PERIOD_MS);
      Firebase.RTDB.setJSON(&fbdo, path.c_str(), &j);
    }
    Serial.printf("Terkirim: ntu=%.1f jarak=%ld baterai=%.2fV %d%% @%s\n",
                  sensorData.turbidity_ntu, sensorData.distance_cm,
                  sensorData.battery_voltage, sensorData.battery_percent, ts);

    vTaskDelay(SENSOR_READ_INTERVAL / portTICK_PERIOD_MS);
  }
}

void checkForCommandsTask(void *pvParameters) {
  for (;;) {
    String base = "/commands/" + String(DEVICE_ID) + "/current_command";
    String statusPath = base + "/status";

    if (!Firebase.RTDB.getString(&fbdo, statusPath)) {
      if (fbdo.errorReason() == "path not exist") {
        FirebaseJson init;
        init.set("type", "none");
        init.set("status", "done");
        Firebase.RTDB.setJSON(&fbdo, base.c_str(), &init);
      }
      vTaskDelay(COMMAND_CHECK_INTERVAL / portTICK_PERIOD_MS);
      continue;
    }

    if (fbdo.stringData() == "pending") {
      if (Firebase.RTDB.getString(&fbdo, (base + "/type").c_str())
          && fbdo.stringData() == "feed") {
        dispenseFeed();
        Firebase.RTDB.setString(&fbdo, statusPath.c_str(), "done");
        Serial.println("Pemberian pakan manual selesai");
      }
    }
    vTaskDelay(COMMAND_CHECK_INTERVAL / portTICK_PERIOD_MS);
  }
}

void checkScheduleTask(void *pvParameters) {
  for (;;) {
    String schedPath = "/schedules/" + String(DEVICE_ID);

    if (!Firebase.RTDB.getJSON(&fbdo, schedPath.c_str())) {
      Serial.printf("Gagal membaca jadwal: %s\n", fbdo.errorReason().c_str());
      vTaskDelay(SCHEDULE_CHECK_INTERVAL / portTICK_PERIOD_MS);
      continue;
    }

    FirebaseJson &root = fbdo.jsonObject();
    FirebaseJsonData jd;

    if (!root.get(jd, "active") || !jd.boolValue) {
      vTaskDelay(SCHEDULE_CHECK_INTERVAL / portTICK_PERIOD_MS);
      continue;
    }

    if (!root.get(jd, "entries")) {
      Serial.println("Tidak ada child 'entries' pada jadwal");
      vTaskDelay(SCHEDULE_CHECK_INTERVAL / portTICK_PERIOD_MS);
      continue;
    }
    FirebaseJson entries;
    jd.getJSON(entries);

    DateTime now = rtc.now();
    int nowH = now.hour(), nowM = now.minute();
    char todayBuf[11];
    sprintf(todayBuf, "%04d-%02d-%02d", now.year(), now.month(), now.day());
    String today(todayBuf);

    size_t count = entries.iteratorBegin();
    for (size_t i = 0; i < count; i++) {
      FirebaseJson::IteratorValue iv = entries.valueAt(i);
      String key = iv.key;
      FirebaseJson entry(iv.value);

      entry.get(jd, "enabled");
      if (!jd.boolValue) continue;

      entry.get(jd, "time");
      String t = jd.stringValue; t.trim();
      int hh = 0, mm = 0;
      bool pm = t.endsWith("PM"), am = t.endsWith("AM");
      if (pm || am) {
        String tm = t.substring(0, t.length() - 2); tm.trim();
        int c = tm.indexOf(':');
        hh = tm.substring(0, c).toInt();
        mm = tm.substring(c + 1).toInt();
        if (pm && hh != 12) hh += 12;
        if (am && hh == 12) hh = 0;
      } else {
        int c1 = t.indexOf(':'), c2 = t.indexOf(':', c1 + 1);
        hh = t.substring(0, c1).toInt();
        mm = (c2 > 0) ? t.substring(c1 + 1, c2).toInt() : t.substring(c1 + 1).toInt();
      }

      entry.get(jd, "last_run");
      String lastRun = jd.stringValue;

      if (hh == nowH && mm == nowM && lastRun != today) {
        Serial.printf("Pemberian pakan terjadwal @ %02d:%02d (entry %s)\n",
                      hh, mm, key.c_str());
        dispenseFeed();
        logFeedActivity("auto");

        String lrPath = schedPath + "/entries/" + key + "/last_run";
        Firebase.RTDB.setString(&fbdo, lrPath.c_str(), today);

        entries.iteratorEnd();
        break;
      }
    }
    entries.iteratorEnd();
    vTaskDelay(SCHEDULE_CHECK_INTERVAL / portTICK_PERIOD_MS);
  }
}

void rtcSyncTask(void *pvParameters) {
  for (;;) {
    ensureRtcValid();
    vTaskDelay(RTC_SYNC_INTERVAL / portTICK_PERIOD_MS);
  }
}

void setup() {
  Serial.begin(115200);

  Wire.begin(21, 22);
  if (!rtc.begin()) {
    Serial.println("RTC tidak terdeteksi");
    while (1);
  }
  clearOscFlag();

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print('.');
    delay(500);
  }
  Serial.println("\nWiFi terhubung");

  syncDS3231toNTP();

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  feederServo.attach(SERVO_PIN);
  feederServo.write(SERVO_REST_POSITION);
  analogSetWidth(12);
  analogSetPinAttenuation(TURBIDITY_PIN, ADC_11db);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT_PULLDOWN);

  String statPath = "/devices/" + String(DEVICE_ID) + "/status/online";
  Firebase.RTDB.setBool(&fbdo, statPath.c_str(), true);

  dataMutex = xSemaphoreCreateMutex();

  xTaskCreatePinnedToCore(turbidityTask, "Turbidity Task", 4096, NULL, 2, &turbidityTaskHandle, 0);
  xTaskCreatePinnedToCore(ultrasonicTask, "Ultrasonic Task", 4096, NULL, 2, &ultrasonicTaskHandle, 0);
  xTaskCreatePinnedToCore(batteryTask, "Battery Task", 4096, NULL, 2, NULL, 0);
  xTaskCreatePinnedToCore(sendSensorDataTask, "Send Sensor Data Task", 8192, NULL, 3, NULL, 1);
  xTaskCreatePinnedToCore(checkForCommandsTask, "Command Task", 8192, NULL, 2, &commandTaskHandle, 1);
  xTaskCreatePinnedToCore(checkScheduleTask, "Schedule Task", 8192, NULL, 2, &scheduleTaskHandle, 1);
  xTaskCreatePinnedToCore(rtcSyncTask, "RTC Sync Task", 4096, NULL, 1, &rtcSyncTaskHandle, 0);

  // Biarkan tugas berjalan beberapa saat, lalu hentikan dan masuk deep sleep.
  vTaskDelay(AWAKE_DURATION_MS / portTICK_PERIOD_MS);

  vTaskDelete(turbidityTaskHandle);
  vTaskDelete(ultrasonicTaskHandle);
  vTaskDelete(rtcSyncTaskHandle);
  vTaskDelete(scheduleTaskHandle);
  vTaskDelete(commandTaskHandle);

  Serial.printf("Deep sleep %llu ms\n", DEEP_SLEEP_US / 1000);
  esp_sleep_enable_timer_wakeup(DEEP_SLEEP_US);
  esp_deep_sleep_start();
}

void loop() {
  // Kosong: seluruh pekerjaan ditangani oleh task FreeRTOS di setup().
}

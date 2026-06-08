/*
 * mqttHandler.ino - MQTT & WiFi Handler
 * HydroMate Monitor v3.4
 *
 * Broker  : ThingsBoard Cloud Free (mqtt.thingsboard.cloud:1883)
 * Auth    : Access Token sebagai MQTT username, password kosong
 * Library : PubSubClient, WiFiManager, ArduinoJson
 *
 * Publish:
 *   v1/devices/me/telemetry             → data sensor realtime
 *   v1/devices/me/attributes            → nilai kalibrasi aktif (client attributes)
 *   v1/devices/me/rpc/response/<id>     → respons RPC ke ThingsBoard
 *
 * Subscribe:
 *   v1/devices/me/rpc/request/+         → perintah dari ThingsBoard / Flutter
 *   v1/devices/me/attributes            → push shared attributes (kalibrasi dari app)
 *   v1/devices/me/attributes/response/+ → respons request attributes saat boot
 *
 * RPC Methods (dikirim Flutter → ThingsBoard → ESP32):
 *   setPump       params: true/false = force ON/OFF, "AUTO" = mode otomatis
 *   setPumpMode   params: 0/1/2 = 15min/jam | 30min/jam | Always ON
 *   calibrate     params: "CAL7" | "CAL4" | "RESETPH" | "RESETTDS" | "TDSK:<ppm>"
 *
 * Shared Attributes (Flutter app set di ThingsBoard → push ke ESP32):
 *   ph_neutral_voltage  → tegangan kalibrasi pH 7.0 (EEPROM addr 0)
 *   ph_acid_voltage     → tegangan kalibrasi pH 4.0 (EEPROM addr 4)
 *   k_value             → TDS K-value              (EEPROM addr 16)
 *   ph_min              → batas bawah pH (dari preset tanaman Flutter)
 *   ph_max              → batas atas pH  (dari preset tanaman Flutter)
 *   tds_min             → batas bawah TDS/PPM
 *   tds_max             → batas atas TDS/PPM
 *   preset_name         → nama preset aktif (info saja)
 *
 * Catatan v3.4:
 *   - Tidak pakai WiFiClientSecure / TLS (plain MQTT port 1883)
 *   - Alert/alarm ditangani ThingsBoard Rule Engine, tidak publish dari ESP32
 *   - History otomatis tersimpan di ThingsBoard telemetry (30 hari)
 *   - NTP tidak diperlukan, ThingsBoard timestamp server-side
 */

#include <WiFi.h>
#include <WiFiManager.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <EEPROM.h>

// ====== KONFIGURASI THINGSBOARD ======
#define TB_HOST      "mqtt.thingsboard.cloud"
#define TB_PORT      1883
#define TB_TOKEN     "jGPyvH3KA37Zkr0d0Kuf"   // Access Token device
#define TB_CLIENT_ID "esp32-hydromate"

#define AP_NAME      "HydroMate-Setup"
#define AP_PASSWORD  "hydromate123"

// ====== THINGSBOARD TOPICS ======
#define TOPIC_TELEMETRY      "v1/devices/me/telemetry"
#define TOPIC_ATTRIBUTES     "v1/devices/me/attributes"
#define TOPIC_ATTR_REQ       "v1/devices/me/attributes/request/1"
#define TOPIC_ATTR_RES       "v1/devices/me/attributes/response/+"
#define TOPIC_RPC_REQ        "v1/devices/me/rpc/request/+"
#define TOPIC_RPC_RES_PREFIX "v1/devices/me/rpc/response/"

// ====== MQTT CLIENT ======
// Plain WiFiClient (tidak perlu TLS ke ThingsBoard Cloud port 1883)
WiFiClient   wifiClient;
PubSubClient mqttClient(wifiClient);

// ====== GLOBAL STATE ======
bool wifiConnected = false;
bool mqttConnected = false;

// Reconnect tracking
unsigned long lastMqttRetry    = 0;
unsigned long lastWiFiRetry    = 0;
int           wifiRetryCounter = 0;

// Pending calibration command (diproses di loopMQTT, bukan di callback)
String pendingCalCommand = "";

// ====== EXTERN - dari file lain ======
extern float   ph, tds, temp;
extern bool    flowStatus, pompaUtamaOn;
extern uint8_t mainPumpMode;
extern unsigned long cycleStartTime;
extern bool    pumpForceOverride, pumpForceState;
extern float   phNeutralVoltage, phAcidVoltage;
extern bool    phCalibrated;
extern float   kValue;
extern float   targetMinPH, targetMaxPH;
extern float   targetMinPPM, targetMaxPPM;

extern void calibratePH_Neutral();
extern void calibratePH_Acid();
extern void resetPH();
extern void calibrateTDS_Auto_WithPPM(float ppm);
extern void resetTDS();

// ========================================
// PUBLISH CLIENT ATTRIBUTES
// Dipanggil setelah connect dan setelah kalibrasi
// Menyimpan nilai kalibrasi aktif ke ThingsBoard
// ========================================
void publishClientAttributes() {
  if (!mqttClient.connected()) return;

  StaticJsonDocument<128> doc;
  doc["ph_neutral_voltage"] = phNeutralVoltage;
  doc["ph_acid_voltage"]    = phAcidVoltage;
  doc["k_value"]            = kValue;
  doc["ph_calibrated"]      = phCalibrated;

  char out[128];
  serializeJson(doc, out);
  mqttClient.publish(TOPIC_ATTRIBUTES, out);
  Serial.println("[TB] Client attributes published");
}

// ========================================
// PROSES PENDING CALIBRATION COMMAND
// Dipanggil dari loopMQTT(), TIDAK dari callback
// (hindari blocking di MQTT callback)
// ========================================
void processPendingCalCommand() {
  if (pendingCalCommand.isEmpty()) return;
  String cmd        = pendingCalCommand;
  pendingCalCommand = "";

  Serial.printf("[CAL] Memproses: %s\n", cmd.c_str());

  if (cmd == "CAL7") {
    delay(2000);
    calibratePH_Neutral();
    Serial.println("[CAL] pH 7.0 kalibrasi selesai");

  } else if (cmd == "CAL4") {
    delay(2000);
    calibratePH_Acid();
    Serial.println("[CAL] pH 4.0 kalibrasi selesai");

  } else if (cmd == "RESETPH") {
    resetPH();
    Serial.println("[CAL] pH direset ke default");

  } else if (cmd.startsWith("TDSK:")) {
    float ppm = cmd.substring(5).toFloat();
    if (ppm > 0) {
      calibrateTDS_Auto_WithPPM(ppm);
      Serial.printf("[CAL] TDS kalibrasi selesai (ref: %.1f ppm)\n", ppm);
    }

  } else if (cmd == "RESETTDS") {
    resetTDS();
    Serial.println("[CAL] TDS K-value direset ke 1.0");

  } else {
    Serial.printf("[CAL] Command tidak dikenal: %s\n", cmd.c_str());
    return;
  }

  // Publish nilai kalibrasi terbaru ke ThingsBoard sebagai client attributes
  publishClientAttributes();
}

// ========================================
// HANDLE RPC REQUEST
// Dipanggil dari mqttCallback ketika ada
// pesan di topic rpc/request/+
// ========================================
void handleRPC(const String& requestId, const String& body) {
  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, body) != DeserializationError::Ok) {
    Serial.println("[RPC] Gagal parse JSON");
    return;
  }

  String method   = doc["method"] | "";
  String response = "{\"result\":\"ok\"}";

  Serial.printf("[RPC] method=%s\n", method.c_str());

  // ---- Kontrol pompa force ----
  if (method == "setPump") {
    JsonVariant params = doc["params"];
    if (params.is<bool>()) {
      pumpForceOverride = true;
      pumpForceState    = params.as<bool>();
      Serial.printf("[RPC] Pump force: %s\n", pumpForceState ? "ON" : "OFF");
    } else {
      // params = "AUTO" → kembalikan ke mode otomatis
      pumpForceOverride = false;
      Serial.println("[RPC] Pump mode: AUTO");
    }

  // ---- Set mode jadwal pompa ----
  } else if (method == "setPumpMode") {
    int m = doc["params"] | -1;
    if (m >= 0 && m <= 2) {
      mainPumpMode   = (uint8_t)m;
      EEPROM.write(20, mainPumpMode);
      EEPROM.commit();
      cycleStartTime = millis();
      const char* names[] = {"15min/jam", "30min/jam", "Always ON"};
      Serial.printf("[RPC] Pump mode → %d (%s)\n", mainPumpMode, names[mainPumpMode]);
    } else {
      response = "{\"result\":\"invalid mode\"}";
    }

  // ---- Kalibrasi sensor ----
  } else if (method == "calibrate") {
    String cmd = doc["params"] | "";
    cmd.toUpperCase();
    if (cmd.length() > 0) {
      pendingCalCommand = cmd;  // diproses di loopMQTT()
      Serial.printf("[RPC] Kalibrasi queued: %s\n", cmd.c_str());
    } else {
      response = "{\"result\":\"empty params\"}";
    }

  } else {
    response = "{\"result\":\"unknown method\"}";
    Serial.printf("[RPC] Method tidak dikenal: %s\n", method.c_str());
  }

  // Kirim respons RPC ke ThingsBoard (wajib untuk two-way RPC)
  String resTopic = TOPIC_RPC_RES_PREFIX + requestId;
  mqttClient.publish(resTopic.c_str(), response.c_str());
}

// ========================================
// HANDLE SHARED ATTRIBUTES
// Menerima update kalibrasi dari Flutter app
// via ThingsBoard shared attributes
//
// Format PUSH update:
//   {"ph_neutral_voltage":2.7}
//
// Format RESPONSE request saat boot:
//   {"shared":{"ph_neutral_voltage":2.7,"ph_acid_voltage":3.3,"k_value":1.0}}
// ========================================
void handleSharedAttributes(const String& body) {
  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, body) != DeserializationError::Ok) return;

  // Tentukan sumber JSON: response dari request (ada key "shared")
  // atau push update langsung
  JsonObject attrs = doc.containsKey("shared")
                     ? doc["shared"].as<JsonObject>()
                     : doc.as<JsonObject>();

  bool changed = false;

  if (attrs.containsKey("ph_neutral_voltage")) {
    float val = attrs["ph_neutral_voltage"];
    if (val > 0.5 && val < 3.5) {
      phNeutralVoltage = val;
      phCalibrated     = true;
      changed          = true;
      EEPROM.put(0, phNeutralVoltage);
      Serial.printf("[TB] ph_neutral_voltage ← %.4f\n", phNeutralVoltage);
    }
  }

  if (attrs.containsKey("ph_acid_voltage")) {
    float val = attrs["ph_acid_voltage"];
    if (val > 0.5 && val < 3.5) {
      phAcidVoltage = val;
      changed       = true;
      EEPROM.put(4, phAcidVoltage);
      Serial.printf("[TB] ph_acid_voltage ← %.4f\n", phAcidVoltage);
    }
  }

  if (attrs.containsKey("k_value")) {
    float val = attrs["k_value"];
    if (val >= 0.25 && val <= 4.0) {
      kValue  = val;
      changed = true;
      EEPROM.put(16, kValue);
      Serial.printf("[TB] k_value ← %.5f\n", kValue);
    }
  }

  if (changed) {
    EEPROM.put(8, phCalibrated);
    EEPROM.commit();
    Serial.println("[TB] Kalibrasi dari app diterapkan & disimpan ke EEPROM");
  }

  // ── Threshold preset tanaman ──────────────────────────
  // Tidak disimpan ke EEPROM — selalu baca dari ThingsBoard
  bool thresholdChanged = false;

  if (attrs.containsKey("ph_min")) {
    float val = attrs["ph_min"];
    if (val > 0 && val < 14) {
      targetMinPH      = val;
      thresholdChanged = true;
      Serial.printf("[TB] ph_min ← %.2f\n", targetMinPH);
    }
  }
  if (attrs.containsKey("ph_max")) {
    float val = attrs["ph_max"];
    if (val > 0 && val < 14) {
      targetMaxPH      = val;
      thresholdChanged = true;
      Serial.printf("[TB] ph_max ← %.2f\n", targetMaxPH);
    }
  }
  if (attrs.containsKey("tds_min")) {
    float val = attrs["tds_min"];
    if (val >= 0) {
      targetMinPPM     = val;
      thresholdChanged = true;
      Serial.printf("[TB] tds_min ← %.0f\n", targetMinPPM);
    }
  }
  if (attrs.containsKey("tds_max")) {
    float val = attrs["tds_max"];
    if (val >= 0) {
      targetMaxPPM     = val;
      thresholdChanged = true;
      Serial.printf("[TB] tds_max ← %.0f\n", targetMaxPPM);
    }
  }
  if (attrs.containsKey("preset_name")) {
    String name = attrs["preset_name"] | "";
    if (name.length() > 0)
      Serial.printf("[TB] preset ← %s\n", name.c_str());
  }

  if (thresholdChanged) {
    Serial.printf("[TB] Threshold → pH:[%.1f–%.1f] TDS:[%.0f–%.0f]\n",
      targetMinPH, targetMaxPH, targetMinPPM, targetMaxPPM);
  }
}

// ========================================
// MQTT CALLBACK
// ========================================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String topicStr = String(topic);
  String msg      = "";
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];

  Serial.printf("[MQTT IN] %s → %s\n", topicStr.c_str(), msg.c_str());

  // RPC request dari ThingsBoard
  if (topicStr.startsWith("v1/devices/me/rpc/request/")) {
    String requestId = topicStr.substring(strlen("v1/devices/me/rpc/request/"));
    handleRPC(requestId, msg);
    return;
  }

  // Shared attributes: push update ATAU response dari request boot
  if (topicStr == "v1/devices/me/attributes" ||
      topicStr.startsWith("v1/devices/me/attributes/response/")) {
    handleSharedAttributes(msg);
    return;
  }
}

// ========================================
// MQTT CONNECT + SUBSCRIBE
// ========================================
bool mqttConnect() {
  if (WiFi.status() != WL_CONNECTED) return false;

  // ThingsBoard: token = username, password = null/kosong
  bool ok = mqttClient.connect(TB_CLIENT_ID, TB_TOKEN, nullptr);

  if (ok) {
    // Subscribe semua topic yang diperlukan
    mqttClient.subscribe(TOPIC_RPC_REQ);    // perintah pompa & kalibrasi dari app
    mqttClient.subscribe(TOPIC_ATTRIBUTES); // push update shared attributes dari TB
    mqttClient.subscribe(TOPIC_ATTR_RES);   // response attributes request saat boot

    Serial.println("✅ ThingsBoard connected!");
    Serial.printf("   Host  : %s:%d\n", TB_HOST, TB_PORT);
    Serial.printf("   Token : %s\n", TB_TOKEN);

    // Request shared attributes (nilai kalibrasi) dari ThingsBoard saat boot
    // ESP32 akan terima balasan di topic TOPIC_ATTR_RES
    mqttClient.publish(
      TOPIC_ATTR_REQ,
      "{\"sharedKeys\":\"ph_neutral_voltage,ph_acid_voltage,k_value,ph_min,ph_max,tds_min,tds_max,preset_name\"}"
    );
    Serial.println("[TB] Requesting shared attributes (kalibrasi)...");

    // Publish nilai kalibrasi aktif sebagai client attributes
    publishClientAttributes();

  } else {
    Serial.printf("❌ ThingsBoard MQTT gagal (rc=%d)\n", mqttClient.state());
    Serial.println("   Cek: token valid? WiFi OK? Host reachable?");
  }

  return ok;
}

// ========================================
// SETUP MQTT
// ========================================
void setupMQTT() {
  WiFiManager wm;
  wm.setConfigPortalTimeout(300);

  Serial.printf("\n📶 WiFiManager - AP: %s / %s\n", AP_NAME, AP_PASSWORD);
  Serial.println("   Hubungkan ke AP lalu setting WiFi, atau tunggu auto-connect...");

  if (!wm.autoConnect(AP_NAME, AP_PASSWORD)) {
    Serial.println("❌ WiFi gagal konek, restart...");
    delay(3000);
    ESP.restart();
  }

  wifiConnected = true;
  Serial.printf("✅ WiFi: %s | IP: %s | RSSI: %d dBm\n",
    WiFi.SSID().c_str(),
    WiFi.localIP().toString().c_str(),
    WiFi.RSSI());

  WiFi.setSleep(WIFI_PS_MIN_MODEM);

  // Setup MQTT client — plain (tidak TLS)
  mqttClient.setServer(TB_HOST, TB_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setBufferSize(512);

  mqttConnect();
}

// ========================================
// KIRIM DATA TELEMETRY KE THINGSBOARD
// Dipanggil dari main loop saat ada perubahan sensor
// ========================================
void kirimDataMQTT(float suhu, float phVal, float tdsVal, bool flow) {
  if (!mqttClient.connected()) return;

  StaticJsonDocument<256> doc;
  doc["ph"]          = round(phVal  * 100.0) / 100.0;
  doc["tds"]         = round(tdsVal * 10.0)  / 10.0;
  doc["temperature"] = round(suhu   * 10.0)  / 10.0;
  doc["flow"]        = flow;
  doc["pump"]        = pompaUtamaOn;
  doc["pump_mode"]   = mainPumpMode;

  char payload[256];
  serializeJson(doc, payload);

  if (mqttClient.publish(TOPIC_TELEMETRY, payload)) {
    Serial.printf("[TB] Telemetry: %s\n", payload);
  } else {
    Serial.println("[TB] ❌ Publish gagal!");
  }
}

// ========================================
// checkAndSendAlerts
// v3.4: tidak diperlukan — ThingsBoard Rule Engine
// yang generate alarm dan trigger notifikasi OneSignal
// ========================================
void checkAndSendAlerts(float suhu, float phVal, float tdsVal) {
  // No-op: alarm ditangani di ThingsBoard Rule Engine (Step 3)
  (void)suhu; (void)phVal; (void)tdsVal;
}

// ========================================
// LOOP MQTT
// Dipanggil setiap iterasi main loop
// ========================================
void loopMQTT() {
  wifiConnected = (WiFi.status() == WL_CONNECTED);

  // WiFi self-healing
  if (!wifiConnected) {
    mqttConnected = false;
    if (millis() - lastWiFiRetry > 30000) {
      lastWiFiRetry = millis();
      if (++wifiRetryCounter > 5) {
        Serial.println("⚠️ WiFi gagal 5x, restart...");
        delay(3000);
        ESP.restart();
      }
      Serial.printf("[WiFi] Reconnect attempt %d...\n", wifiRetryCounter);
      WiFi.reconnect();
    }
    return;
  }
  wifiRetryCounter = 0;

  // MQTT reconnect
  if (!mqttClient.connected()) {
    mqttConnected = false;
    if (millis() - lastMqttRetry > 5000) {
      lastMqttRetry = millis();
      Serial.println("[TB] Reconnecting...");
      mqttConnected = mqttConnect();
    }
  } else {
    mqttConnected = true;
  }

  // Proses pesan masuk (RPC, attributes)
  mqttClient.loop();

  // Proses calibration command (diluar callback untuk hindari blocking)
  processPendingCalCommand();
}

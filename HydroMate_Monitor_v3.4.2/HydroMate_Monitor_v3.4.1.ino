/*
 * HydroMate Monitor v3.4
 * HYVIBE - Universitas Syiah Kuala
 *
 * Mode: Monitoring + Pompa Utama + MQTT (ThingsBoard Cloud)
 *
 * Pin Assignment:
 *   pH sensor    → GPIO 34
 *   TDS/PPM      → GPIO 32
 *   Water Flow   → GPIO 27
 *   DS18B20      → GPIO 5
 *   Pompa Utama  → GPIO 19
 *
 * Changelog v3.4:
 *   - Migrasi MQTT broker: EMQX Cloud → ThingsBoard Cloud Free
 *   - Protokol: plain MQTT port 1883 (tidak pakai TLS/WiFiClientSecure)
 *   - Auth: Access Token sebagai MQTT username
 *   - Telemetry dikirim ke ThingsBoard standard topic
 *   - Kontrol pompa via ThingsBoard RPC (setPump, setPumpMode)
 *   - Kalibrasi sensor via ThingsBoard RPC (calibrate)
 *   - Nilai kalibrasi disimpan sebagai ThingsBoard shared attributes
 *   - Alert/alarm ditangani ThingsBoard Rule Engine (tidak publish dari ESP32)
 *   - History otomatis tersimpan di ThingsBoard telemetry (30 hari)
 */

#include <Wire.h>
#include <EEPROM.h>

// ====== PIN DEFINITIONS ======
const int   PH_PIN          = 34;
const int   TDS_PIN         = 32;
const int   FLOW_SENSOR_PIN = 27;
#define POMPA_UTAMA 19

// ====== SENSOR CONSTANTS ======
const float aref     = 3.3;
const float adcRange = 4095.0;

// ====== CALIBRATION VARIABLES ======
float kValue           = 1.0;
float temperature      = 25.0;
float phNeutralVoltage = 2.7;
float phAcidVoltage    = 3.3;
bool  phCalibrated     = false;

// ====== ALERT THRESHOLDS ======
float targetMinPPM  = 800;
float targetMaxPPM  = 1200;
float targetMinPH   = 6.0;
float targetMaxPH   = 7.0;
float targetMinSuhu = 24.0;
float targetMaxSuhu = 28.0;

// ====== LCD GLOBAL READINGS ======
float ph           = 0.0;
float tds          = 0.0;
float temp         = 25.0;
bool  flowStatus   = false;
bool  pompaUtamaOn = false;

// ====== MAIN PUMP CYCLE ======
uint8_t       mainPumpMode      = 0;
unsigned long cycleStartTime    = 0;
bool          pumpForceOverride = false;
bool          pumpForceState    = false;

// ====== SENSOR CACHE ======
float suhuTerakhir  = -999;
float phTerakhir    = -999;
float tdsTerakhir   = -999;
bool  flowTerakhir  = false;

// ====== FUNCTION PROTOTYPES ======
void  checkCalibrationCommand();
void  setupLCD();
void  updateLCD();
void  setupDS18B20();
void  setupPH();
void  setupTDS();
void  setupFlow();
float bacaSuhu();
float bacaPH();
float bacaTDS(float suhu);
bool  bacaStatusFlow();
void  setupMQTT();
void  loopMQTT();
void  kirimDataMQTT(float suhu, float ph, float tds, bool flow);
void  checkAndSendAlerts(float suhu, float ph, float tds);

extern bool wifiConnected;
extern bool mqttConnected;

// ========================================
// PUMP HELPERS
// ========================================
bool shouldMainPumpBeOn() {
  if (mainPumpMode == 2) return true;
  const unsigned long cycleDuration = 60UL * 60000;
  unsigned long onDuration = (mainPumpMode == 0) ? 15UL * 60000 : 30UL * 60000;
  return ((millis() - cycleStartTime) % cycleDuration) < onDuration;
}

void setPompaUtama(bool on) {
  digitalWrite(POMPA_UTAMA, on ? HIGH : LOW);
  pompaUtamaOn = on;
}

void updateMainPump() {
  bool isOn = (digitalRead(POMPA_UTAMA) == HIGH);
  if (pumpForceOverride) {
    if ( pumpForceState && !isOn) setPompaUtama(true);
    if (!pumpForceState &&  isOn) setPompaUtama(false);
    return;
  }
  bool shouldBeOn = shouldMainPumpBeOn();
  if ( shouldBeOn && !isOn) setPompaUtama(true);
  if (!shouldBeOn &&  isOn) setPompaUtama(false);
}

// ========================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  EEPROM.begin(512);

  uint8_t savedMode = EEPROM.read(20);
  if (savedMode <= 2) mainPumpMode = savedMode;
  cycleStartTime = millis();

  Serial.println("\n\n╔════════════════════════════════════════╗");
  Serial.println("║    HydroMate Monitor v3.4              ║");
  Serial.println("║    HYVIBE - Universitas Syiah Kuala    ║");
  Serial.println("║    Broker: ThingsBoard Cloud           ║");
  Serial.println("╚════════════════════════════════════════╝\n");

  setupLCD();

  pinMode(POMPA_UTAMA, OUTPUT);
  digitalWrite(POMPA_UTAMA, LOW);

  setupMQTT();
  setupDS18B20();
  setupPH();
  setupTDS();
  setupFlow();
}

// ========================================
void loop() {
  loopMQTT();
  checkCalibrationCommand();

  float suhu = bacaSuhu();
  float ph   = bacaPH();
  float tds  = bacaTDS(suhu);
  bool  flow = bacaStatusFlow();

  updateMainPump();

  // Kirim ke ThingsBoard jika ada perubahan signifikan
  static unsigned long lastMqttUpdate = 0;
  if (millis() - lastMqttUpdate > 2000) {
    if (abs(tds  - tdsTerakhir)  > 5    ||
        abs(ph   - phTerakhir)   > 0.05 ||
        abs(suhu - suhuTerakhir) > 0.5  ||
        flow != flowTerakhir) {
      kirimDataMQTT(suhu, ph, tds, flow);
      tdsTerakhir  = tds;
      phTerakhir   = ph;
      suhuTerakhir = suhu;
      flowTerakhir = flow;
    }
    lastMqttUpdate = millis();
  }

  // checkAndSendAlerts tidak diperlukan di v3.4
  // ThingsBoard Rule Engine yang tangani alarm & notifikasi
  static unsigned long lastAlertCheck = 0;
  if (millis() - lastAlertCheck > 5000) {
    checkAndSendAlerts(suhu, ph, tds);
    lastAlertCheck = millis();
  }

  // Serial log
  static unsigned long lastPrint = 0;
  if (millis() - lastPrint > 2000) {
    const char* forceStr = pumpForceOverride
                           ? (pumpForceState ? " (FORCE ON)" : " (FORCE OFF)")
                           : "";
    Serial.printf("[v3.4] pH:%.2f | PPM:%.1f | Suhu:%.1f°C | Flow:%s | Pompa:%s%s | WiFi:%s | TB:%s\n",
      ph, tds, suhu,
      flow         ? "ON"  : "OFF",
      pompaUtamaOn ? "ON"  : "OFF",
      forceStr,
      wifiConnected ? "OK" : "OFF",
      mqttConnected ? "OK" : "OFF");
    lastPrint = millis();
  }

  updateLCD();

  ::ph         = ph;
  ::tds        = tds;
  ::temp       = suhu;
  ::flowStatus = flow;

  delay(100);
}

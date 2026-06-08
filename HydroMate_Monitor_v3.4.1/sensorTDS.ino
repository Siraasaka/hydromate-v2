/*
 * TDS Sensor - HydroMate Monitor v3.3
 * Pin: GPIO 32 (extern dari main)
 */

#include <EEPROM.h>

extern const int TDS_PIN;
extern float kValue, temperature;
extern const float aref, adcRange;

int ADDR_K_VALUE = 16;

int tds_buffer[10], tds_temp;

// ========== SETUP TDS ==========
void setupTDS() {
  pinMode(TDS_PIN, INPUT);
  EEPROM.get(ADDR_K_VALUE, kValue);
  if (isnan(kValue) || kValue < 0.25 || kValue > 4.0) kValue = 1.0;
}

// ========== FILTER ADC ==========
float readFilteredTdsVoltage() {
  for (int i = 0; i < 10; i++) {
    tds_buffer[i] = analogRead(TDS_PIN);
    delay(30);
  }
  for (int i = 0; i < 9; i++)
    for (int j = i + 1; j < 10; j++)
      if (tds_buffer[i] > tds_buffer[j]) {
        tds_temp = tds_buffer[i];
        tds_buffer[i] = tds_buffer[j];
        tds_buffer[j] = tds_temp;
      }
  unsigned long sum = 0;
  for (int i = 2; i < 8; i++) sum += tds_buffer[i];
  return (sum / 6.0) * aref / adcRange;
}

// ========== BACA TDS RAW (tanpa K) ==========
float readRawTDS(float suhu) {
  float voltage = readFilteredTdsVoltage();
  float ecValue = 133.42 * pow(voltage, 3) - 255.86 * pow(voltage, 2) + 857.39 * voltage;
  float ecValue25 = ecValue / (1.0 + 0.02 * (suhu - 25.0));
  return ecValue25 * 0.5;
}

// ========== BACA TDS FINAL (dengan K) ==========
float bacaTDS(float suhu) {
  temperature = (suhu < -55 || suhu > 125 || isnan(suhu)) ? 25.0 : suhu;
  return readRawTDS(temperature) * kValue;
}

// ========== KALIBRASI TDS OTOMATIS ==========
void calibrateTDS_Auto_WithPPM(float realPPM) {
  if (realPPM == 0) {
    Serial.println("Masukkan nilai PPM referensi:");
    while (!Serial.available()) delay(10);
    String input = Serial.readStringUntil('\n');
    input.trim();
    realPPM = input.toFloat();
  }

  if (realPPM < 50 || realPPM > 5000) return;

  delay(3000);
  float tdsBase = readRawTDS(temperature);
  float newK    = realPPM / tdsBase;

  if (newK < 0.5 || newK > 2.0) return;

  kValue = newK;
  EEPROM.put(ADDR_K_VALUE, kValue);
  EEPROM.commit();
  Serial.printf("TDS cal OK: K=%.5f\n", kValue);
}

// ========== KALIBRASI TDS MANUAL (K langsung) ==========
void calibrateTDS_Manual() {
  Serial.println("Masukkan K-value (0.5 - 2.0):");
  while (!Serial.available()) delay(10);
  String input = Serial.readStringUntil('\n');
  input.trim();
  float newK = input.toFloat();

  if (newK >= 0.5 && newK <= 2.0) {
    kValue = newK;
    EEPROM.put(ADDR_K_VALUE, kValue);
    EEPROM.commit();
    Serial.printf("K-value set: %.5f\n", kValue);
  }
}

// ========== RESET TDS ==========
void resetTDS() {
  kValue = 1.0;
  EEPROM.put(ADDR_K_VALUE, kValue);
  EEPROM.commit();
  Serial.println("TDS K-value reset ke 1.0");
}

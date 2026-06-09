/*
 * Unified Calibration & Control System - HydroMate Monitor v3.3
 *
 * Serial Commands:
 *   CAL7        → Kalibrasi pH 7.0
 *   CAL4        → Kalibrasi pH 4.0
 *   RESETPH     → Reset kalibrasi pH
 *   TDSK        → Kalibrasi TDS otomatis (input PPM via Serial)
 *   TDSKM       → Kalibrasi TDS manual (input K langsung)
 *   RESETTDS    → Reset TDS K-value
 *   PUMP 0      → Set mode 15 menit ON per jam
 *   PUMP 1      → Set mode 30 menit ON per jam
 *   PUMP 2      → Always ON
 *   PUMP STATUS → Lihat status pompa saat ini
 */

void calibratePH_Neutral();
void calibratePH_Acid();
void resetPH();
void calibrateTDS_Auto_WithPPM(float ppm);
void calibrateTDS_Manual();
void resetTDS();
void setPompaUtama(bool on);

extern float   phNeutralVoltage, phAcidVoltage;
extern bool    phCalibrated;
extern float   kValue;
extern float   temperature;
extern uint8_t mainPumpMode;
extern unsigned long cycleStartTime;
extern bool    pompaUtamaOn;

void checkCalibrationCommand() {
  if (!Serial.available()) return;

  String command = Serial.readStringUntil('\n');
  command.trim();
  command.toUpperCase();
  if (command.length() == 0) return;

  // ---- KALIBRASI pH ----
  if (command == "CAL7") {
    delay(2000);
    calibratePH_Neutral();

  } else if (command == "CAL4") {
    delay(2000);
    calibratePH_Acid();

  } else if (command == "RESETPH") {
    resetPH();

  // ---- KALIBRASI TDS ----
  } else if (command == "TDSK") {
    calibrateTDS_Auto_WithPPM(0);

  } else if (command == "TDSKM") {
    calibrateTDS_Manual();

  } else if (command == "RESETTDS") {
    resetTDS();

  // ---- KONTROL POMPA UTAMA ----
  } else if (command == "PUMP 0") {
    mainPumpMode = 0;
    EEPROM.write(20, mainPumpMode);
    EEPROM.commit();
    cycleStartTime = millis();
    Serial.println("Pump mode: 15 menit ON per jam");

  } else if (command == "PUMP 1") {
    mainPumpMode = 1;
    EEPROM.write(20, mainPumpMode);
    EEPROM.commit();
    cycleStartTime = millis();
    Serial.println("Pump mode: 30 menit ON per jam");

  } else if (command == "PUMP 2") {
    mainPumpMode = 2;
    EEPROM.write(20, mainPumpMode);
    EEPROM.commit();
    cycleStartTime = millis();
    Serial.println("Pump mode: Always ON");

  } else if (command == "PUMP STATUS") {
    const char* modeNames[] = {"15min/jam", "30min/jam", "Always ON"};
    Serial.printf("Pompa: %s | Mode: %d (%s)\n",
                  pompaUtamaOn ? "ON" : "OFF",
                  mainPumpMode,
                  modeNames[mainPumpMode]);

  } else {
    Serial.println("Command tidak dikenal.");
    Serial.println("Gunakan: CAL7|CAL4|RESETPH|TDSK|TDSKM|RESETTDS|PUMP 0|PUMP 1|PUMP 2|PUMP STATUS");
  }
}

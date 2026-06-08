/*
 * displayLCD.ino - LCD I2C Display Handler
 * HydroMate Monitor v3.4
 *
 * Mode 0: pH | PPM / Suhu | Flow
 * Mode 1: Pompa status | MQTT status
 */

#include <LiquidCrystal_I2C.h>
#include <Wire.h>

LiquidCrystal_I2C lcd(0x27, 16, 2);
bool lcdAvailable = false;

int           displayMode       = 0;
unsigned long lastDisplayUpdate = 0;
const long    displayInterval   = 3000;

extern float   ph, tds, temp;
extern bool    flowStatus;
extern bool    pompaUtamaOn;
extern uint8_t mainPumpMode;
extern bool    wifiConnected;
extern bool    mqttConnected;

// ========================================
void setupLCD() {
  Wire.begin();
  Wire.beginTransmission(0x27);
  byte error = Wire.endTransmission();

  if (error == 0) {
    lcdAvailable = true;
    lcd.init();
    lcd.backlight();
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print("  HydroMate v3.4");
    lcd.setCursor(0, 1); lcd.print("  Initializing..");
    delay(2000);
    lcd.clear();
  } else {
    lcdAvailable = false;
  }
}

// ========================================
void updateLCD() {
  if (!lcdAvailable) return;
  unsigned long now = millis();
  if (now - lastDisplayUpdate >= displayInterval) {
    lastDisplayUpdate = now;
    displayMode = (displayMode + 1) % 2;
    lcd.clear();
    if (displayMode == 0) displaySensorData();
    else                  displaySystemStatus();
  }
}

// ========================================
// MODE 0: SENSOR DATA
// "pH:X.X  P:XXXX "
// "T:XX.XC Flow:ON"
// ========================================
void displaySensorData() {
  if (!lcdAvailable) return;

  lcd.setCursor(0, 0);
  lcd.print("pH:");
  lcd.print(ph, 1);
  lcd.setCursor(8, 0);
  lcd.print("P:");
  lcd.print((int)tds);

  lcd.setCursor(0, 1);
  lcd.print("T:");
  lcd.print(temp, 1);
  lcd.print("C");
  lcd.setCursor(9, 1);
  lcd.print(flowStatus ? "Flow:ON " : "Flow:OFF");
}

// ========================================
// MODE 1: SYSTEM STATUS
// "Pompa:ON  Md:X  "
// "WiFi:OK MQTT:OK "
// ========================================
void displaySystemStatus() {
  if (!lcdAvailable) return;

  lcd.setCursor(0, 0);
  lcd.print("Pompa:");
  lcd.print(pompaUtamaOn ? "ON " : "OFF");
  lcd.setCursor(10, 0);
  lcd.print("Md:");
  lcd.print(mainPumpMode);

  lcd.setCursor(0, 1);
  lcd.print(wifiConnected ? "WiFi:OK " : "WiFi:OFF");
  lcd.setCursor(8, 1);
  lcd.print(mqttConnected ? "MQTT:OK " : "MQTT:OFF");
}

/*
 * pH Sensor - HydroMate Monitor v3.3
 * Pin: GPIO 34 (extern dari main)
 * - 2-point calibration (pH 7.0 & pH 4.0)
 * - ADC filtering (10 samples, buang 2 atas + 2 bawah)
 */

extern const int PH_PIN;
extern float phNeutralVoltage, phAcidVoltage;
extern bool  phCalibrated;
extern const float aref, adcRange;

int buffer_arr[10], tempValue;
unsigned long int avgval;

// ========== SETUP pH ==========
void setupPH() {
  pinMode(PH_PIN, INPUT);
  EEPROM.get(0, phNeutralVoltage);
  EEPROM.get(4, phAcidVoltage);
  EEPROM.get(8, phCalibrated);

  if (isnan(phNeutralVoltage) || phNeutralVoltage < 0.5 || phNeutralVoltage > 3.5)
    phNeutralVoltage = 2.7;
  if (isnan(phAcidVoltage) || phAcidVoltage < 0.5 || phAcidVoltage > 3.5)
    phAcidVoltage = 3.3;
}

// ========== FILTER ADC ==========
float readFilteredVoltage() {
  for (int i = 0; i < 10; i++) {
    buffer_arr[i] = analogRead(PH_PIN);
    delay(30);
  }
  for (int i = 0; i < 9; i++)
    for (int j = i + 1; j < 10; j++)
      if (buffer_arr[i] > buffer_arr[j]) {
        tempValue = buffer_arr[i];
        buffer_arr[i] = buffer_arr[j];
        buffer_arr[j] = tempValue;
      }
  avgval = 0;
  for (int i = 2; i < 8; i++) avgval += buffer_arr[i];
  return (avgval / 6.0) * aref / adcRange;
}

// ========== BACA pH ==========
float bacaPH() {
  float volt = readFilteredVoltage();
  float phValue;

  if (phCalibrated) {
    float slope     = 3.0 / (phNeutralVoltage - phAcidVoltage);
    float intercept = 7.0 - slope * phNeutralVoltage;
    phValue = slope * volt + intercept;
  } else {
    phValue = -5.70 * volt + 21.34;
  }

  if (phValue < 0)  phValue = 0;
  if (phValue > 14) phValue = 14;
  return phValue;
}

// ========== KALIBRASI pH 7.0 ==========
void calibratePH_Neutral() {
  phNeutralVoltage = readFilteredVoltage();
  phCalibrated = true;
  EEPROM.put(0, phNeutralVoltage);
  EEPROM.commit();
  Serial.printf("CAL7 OK: %.4fV\n", phNeutralVoltage);
}

// ========== KALIBRASI pH 4.0 ==========
void calibratePH_Acid() {
  phAcidVoltage = readFilteredVoltage();
  phCalibrated  = true;
  EEPROM.put(4, phAcidVoltage);
  EEPROM.put(8, phCalibrated);
  EEPROM.commit();
  Serial.printf("CAL4 OK: %.4fV\n", phAcidVoltage);
}

// ========== RESET KALIBRASI pH ==========
void resetPH() {
  phCalibrated     = false;
  phNeutralVoltage = 2.7;
  phAcidVoltage    = 3.3;
  EEPROM.put(0, phNeutralVoltage);
  EEPROM.put(4, phAcidVoltage);
  EEPROM.put(8, phCalibrated);
  EEPROM.commit();
  Serial.println("pH reset ke default");
}

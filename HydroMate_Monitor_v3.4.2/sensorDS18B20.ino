/*
 * DS18B20 Temperature Sensor - HydroMate Monitor v3.3
 * Pin: GPIO 5
 */

#include <OneWire.h>
#include <DallasTemperature.h>

#define ONE_WIRE_BUS 5

OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature ds18b20(&oneWire);

void setupDS18B20() {
  ds18b20.begin();
}

float bacaSuhu() {
  ds18b20.requestTemperatures();
  delay(100);

  float temp = ds18b20.getTempCByIndex(0);

  // 1x retry jika invalid
  if (temp < -55 || temp > 125 || isnan(temp)) {
    delay(50);
    ds18b20.requestTemperatures();
    delay(100);
    temp = ds18b20.getTempCByIndex(0);
  }

  // Failsafe
  if (temp < -55 || temp > 125 || isnan(temp)) return 25.0;

  return temp;
}

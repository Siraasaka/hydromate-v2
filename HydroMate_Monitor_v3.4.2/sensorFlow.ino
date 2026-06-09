/*
 * Water Flow Sensor - HydroMate Monitor v3.3
 * Pin: GPIO 27 (defined di main)
 * - Debounce 100ms di ISR untuk filter noise PCB
 */

extern const int FLOW_SENSOR_PIN;

volatile int           flowPulseCount = 0;
volatile unsigned long lastPulseTime  = 0;
unsigned long          lastFlowCheck  = 0;

const unsigned long FLOW_CHECK_INTERVAL = 1000;
const unsigned long DEBOUNCE_US         = 100000; // 100ms
const int           FLOW_PULSE_THRESHOLD = 5;

void IRAM_ATTR flowPulseCounter() {
  unsigned long now = micros();
  if (now - lastPulseTime > DEBOUNCE_US) {
    flowPulseCount++;
    lastPulseTime = now;
  }
}

void setupFlow() {
  pinMode(FLOW_SENSOR_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(FLOW_SENSOR_PIN), flowPulseCounter, FALLING);
}

bool bacaStatusFlow() {
  unsigned long currentTime = millis();

  if (currentTime - lastFlowCheck >= FLOW_CHECK_INTERVAL) {
    bool isFlowing = (flowPulseCount >= FLOW_PULSE_THRESHOLD);
    flowPulseCount = 0;
    lastFlowCheck  = currentTime;
    return isFlowing;
  }

  return false;
}

// ========================================
// KIRIM DATA TELEMETRY + CLIENT ATTRIBUTES
// FIX: Publish JUGA ke TOPIC_ATTRIBUTES agar
//      Flutter bisa baca via CLIENT_SCOPE subscription
//      (ThingsBoard Free tier blokir tsSubCmds/historyCmds)
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

  // 1. Publish ke telemetry (time-series) — untuk history & alarm rules TB
  if (mqttClient.publish(TOPIC_TELEMETRY, payload)) {
    Serial.printf("[TB] Telemetry: %s\n", payload);
  } else {
    Serial.println("[TB] ❌ Publish telemetry gagal!");
  }

  // 2. JUGA publish ke client attributes — untuk realtime display di Flutter
  //    attrSubCmds CLIENT_SCOPE bekerja di semua tier ThingsBoard
  if (mqttClient.publish(TOPIC_ATTRIBUTES, payload)) {
    Serial.println("[TB] Client attrs updated");
  }
}

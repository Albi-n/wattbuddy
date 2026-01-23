#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <LittleFS.h>

/* ============ CONFIGURATION ============ */
const char* ssid = "OPPO F15";
const char* pass = "UmbikkoMyre";

#define ACS_PIN 34
#define ZMPT_PIN 35
#define RELAY1_PIN 23
#define RELAY2_PIN 19

float Vrms = 220.0, Irms = 0.0, Power = 0.0;
float energy_kWh = 0;
float cost_per_unit = 7.0; 
float power_factor = 0.95;
unsigned long lastReadingTime = 0;
unsigned long lastEnergyUpdate = 0;

WebServer server(80);

/* ============ ADC INITIALIZATION ============ */
void initializeADC() {
  pinMode(ACS_PIN, INPUT);
  pinMode(ZMPT_PIN, INPUT);
  analogReadResolution(12);
  Serial.println("✅ ADC pins initialized");
}

/* ============ PERMANENT STORAGE ============ */
void saveData() {
  File f = LittleFS.open("/energy.txt", "w");
  if (f) {
    f.print(energy_kWh, 4);
    f.close();
    Serial.println("💾 Energy data saved: " + String(energy_kWh, 4) + " kWh");
  }
}

void loadData() {
  if (LittleFS.exists("/energy.txt")) {
    File f = LittleFS.open("/energy.txt", "r");
    if (f) {
      energy_kWh = f.readString().toFloat();
      f.close();
      Serial.println("📂 Energy data loaded: " + String(energy_kWh, 4) + " kWh");
    }
  }
}

/* ============ API ENDPOINTS ============ */
void sendCORS() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "POST,GET,OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

void handleReadings() {
  String json = "{";
  json += "\"voltage\":" + String(Vrms, 1);
  json += ",\"current\":" + String(Irms, 3);
  json += ",\"power\":" + String(Power, 2);
  json += ",\"energy\":" + String(energy_kWh, 4);
  json += ",\"relay1\":" + String(digitalRead(RELAY1_PIN) == HIGH ? "true" : "false");
  json += ",\"relay2\":" + String(digitalRead(RELAY2_PIN) == HIGH ? "true" : "false");
  json += "}";
  sendCORS();
  server.send(200, "application/json", json);
  Serial.println("📤 /api/readings sent: " + json);
}

void handleRelay1On() {
  digitalWrite(RELAY1_PIN, HIGH); // Turn relay ON (power connected)
  sendCORS();
  server.send(200, "application/json", "{\"success\":true,\"state\":\"on\"}");
  Serial.println("🔌 Relay 1: ON (GPIO HIGH)");
}

void handleRelay1Off() {
  digitalWrite(RELAY1_PIN, LOW); // Turn relay OFF (power disconnected)
  sendCORS();
  server.send(200, "application/json", "{\"success\":true,\"state\":\"off\"}");
  Serial.println("🔌 Relay 1: OFF (GPIO LOW)");
}

void handleRelay2On() {
  digitalWrite(RELAY2_PIN, HIGH);
  sendCORS();
  server.send(200, "application/json", "{\"success\":true,\"state\":\"on\"}");
  Serial.println("🔌 Relay 2: ON (GPIO HIGH)");
}

void handleRelay2Off() {
  digitalWrite(RELAY2_PIN, LOW);
  sendCORS();
  server.send(200, "application/json", "{\"success\":true,\"state\":\"off\"}");
  Serial.println("🔌 Relay 2: OFF (GPIO LOW)");
}

void handleStatus() {
  String json = "{";
  json += "\"relay1\":\"" + String(digitalRead(RELAY1_PIN) == HIGH ? "on" : "off") + "\"";
  json += ",\"relay2\":\"" + String(digitalRead(RELAY2_PIN) == HIGH ? "on" : "off") + "\"";
  json += ",\"voltage\":" + String(Vrms, 1);
  json += ",\"current\":" + String(Irms, 3);
  json += ",\"power\":" + String(Power, 2);
  json += ",\"energy\":" + String(energy_kWh, 4);
  json += "}";
  sendCORS();
  server.send(200, "application/json", json);
}

/* ============ SETUP ============ */
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n\n========== ESP32 WATT BUDDY ==========");
  Serial.println("Starting initialization...");
  
  // RELAY INITIALIZATION - Crucial Order
  // Set pins to OUTPUT FIRST before setting values
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);
  digitalWrite(RELAY1_PIN, LOW);   // Set default state to LOW (OFF)
  digitalWrite(RELAY2_PIN, LOW);
  Serial.println("✅ Relay pins initialized (both OFF - GPIO LOW)");
  
  initializeADC();

  // Initialize LittleFS and load energy data
  if(LittleFS.begin(true)) {
    Serial.println("✅ LittleFS initialized");
    loadData();
  } else {
    Serial.println("❌ LittleFS failed to initialize");
  }

  // Connect to WiFi
  Serial.print("📡 Connecting to WiFi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, pass);
  
  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 20) { 
    delay(500); 
    Serial.print("."); 
    wifiAttempts++;
  }
  
  Serial.println();
  Serial.print("WiFi Status: ");
  Serial.println(WiFi.status());
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("✅ WiFi Connected!");
    Serial.println("✅ IP Address: " + WiFi.localIP().toString());
    Serial.println("✅ SSID: " + String(ssid));
    Serial.println("✅ Signal Strength (RSSI): " + String(WiFi.RSSI()) + " dBm");
  } else {
    Serial.println("❌ WiFi Connection Failed!");
  }

  // Setup mDNS
  if (MDNS.begin("wattbuddy")) {
    Serial.println("✅ mDNS started: http://wattbuddy.local");
  } else {
    Serial.println("❌ mDNS failed to start");
  }

  // Setup Web Server routes
  server.on("/api/readings", HTTP_GET, handleReadings);
  server.on("/api/relay1/on", HTTP_GET, handleRelay1On);
  server.on("/api/relay1/off", HTTP_GET, handleRelay1Off);
  server.on("/api/relay2/on", HTTP_GET, handleRelay2On);
  server.on("/api/relay2/off", HTTP_GET, handleRelay2Off);
  server.on("/api/status", HTTP_GET, handleStatus);
  
  server.begin();
  Serial.println("✅ Web Server started on port 80");
  Serial.println("========================================\n");
}

/* ============ MAIN LOOP ============ */
void loop() {
  server.handleClient();
  
  // Read sensors every 1 second
  if (millis() - lastReadingTime > 1000) {
    calculateEnergy();
    lastReadingTime = millis();
  }
  
  // Update energy accumulation every 1 second
  // Energy (kWh) = Power (W) / 1000 / 3600 (to convert to kWh per second)
  if (millis() - lastEnergyUpdate > 1000) {
    energy_kWh += (Power / 1000.0) / 3600.0;
    saveData();  // Save energy to persistent storage
    lastEnergyUpdate = millis();
  }
}

/* ============ SENSOR CALCULATIONS ============ */
void calculateEnergy() {
  long sumI2 = 0, sumV2 = 0;
  long avgI = 0, avgV = 0;
  int samples = 400; 

  // Calculate baseline (DC offset)
  for (int i = 0; i < samples; i++) {
    avgI += analogRead(ACS_PIN);
    avgV += analogRead(ZMPT_PIN);
    delayMicroseconds(50);
  }
  avgI /= samples;
  avgV /= samples;

  // Calculate RMS values
  for (int i = 0; i < samples; i++) {
    float rawI = analogRead(ACS_PIN) - avgI;
    float rawV = analogRead(ZMPT_PIN) - avgV;
    sumI2 += (rawI * rawI);
    sumV2 += (rawV * rawV);
  }

  // Calibration multipliers (adjust based on your sensor specs)
  // For ACS712-5A: typically 0.185 V/A, for -5 to 5A range
  // For ZMPT101B: typically 0.0495V/V or adjust as needed
  Irms = sqrt(sumI2 / samples) * 0.088;  // Current multiplier
  Vrms = sqrt(sumV2 / samples) * 0.58;   // Voltage multiplier

  // Noise gates - prevent low readings from noise
  if (Irms < 0.42) Irms = 0.0;  // Ignore currents below 0.42A
  if (Vrms < 40.0) Vrms = 0.0;  // Ignore voltages below 40V

  // Calculate power with power factor
  Power = Vrms * Irms * power_factor;
  if (Power < 0.5) Power = 0.0;  // Ignore power below 0.5W (noise)

  Serial.printf("V: %.1fV | I: %.3fA | P: %.2fW | E: %.4f kWh\n", Vrms, Irms, Power, energy_kWh);
}

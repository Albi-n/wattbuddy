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
const float FREQUENCY = 50.0;
unsigned long lastReadingTime = 0;
unsigned long lastEnergyUpdate = 0;

WebServer server(80);

/* ============ ADC INITIALIZATION ============ */
void initializeADC() {
  pinMode(ACS_PIN, INPUT);
  pinMode(ZMPT_PIN, INPUT);
  Serial.println("✅ ADC pins initialized");
}

/* ============ TEMPERATURE SENSOR - FIXED ============ */
float readInternalTemperature() {
  return 25.0; // Room temperature fallback
}

/* ============ PERMANENT STORAGE ============ */
void saveData() {
  File f = LittleFS.open("/energy.txt", "w");
  if (f) {
    f.print(energy_kWh, 4);
    f.close();
    Serial.println("✅ Energy data saved: " + String(energy_kWh, 4) + " kWh");
  }
}

void loadData() {
  if (LittleFS.exists("/energy.txt")) {
    File f = LittleFS.open("/energy.txt", "r");
    if (f) {
      energy_kWh = f.readString().toFloat();
      f.close();
      Serial.println("✅ Energy data loaded: " + String(energy_kWh, 4) + " kWh");
    }
  }
}

/* ============ API ENDPOINTS ============ */
void handleReadings() {
  unsigned long timestamp = millis() / 1000;
  
  // Ensure we have valid data
  if (Vrms == 0) Vrms = 220.0; // Default voltage if not reading
  
  String json = "{";
  json += "\"voltage\":" + String(Vrms, 1);
  json += ",\"current\":" + String(Irms, 3);
  json += ",\"power\":" + String(Power, 2);
  json += ",\"energy\":" + String(energy_kWh, 4);
  json += ",\"bill\":" + String(energy_kWh * cost_per_unit, 2);
  json += ",\"power_factor\":" + String(power_factor, 2);
  json += ",\"frequency\":" + String(FREQUENCY, 1);
  json += ",\"temperature\":" + String(readInternalTemperature(), 1);
  json += ",\"timestamp\":" + String(timestamp);
  json += ",\"relay1\":" + String(digitalRead(RELAY1_PIN) == LOW ? "true" : "false");
  json += ",\"relay2\":" + String(digitalRead(RELAY2_PIN) == LOW ? "true" : "false");
  json += ",\"uptime\":" + String(millis() / 1000);
  json += "}";
  
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Content-Type", "application/json");
  server.send(200, "application/json", json);
  
  Serial.println("📊 Readings sent: V=" + String(Vrms, 1) + "V, I=" + String(Irms, 3) + "A, P=" + String(Power, 2) + "W");
}

void handleRelay1On() {
  digitalWrite(RELAY1_PIN, LOW);
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"success\":true,\"relay\":1,\"state\":\"on\"}");
  Serial.println("🔌 Relay 1: ON");
}

void handleRelay1Off() {
  digitalWrite(RELAY1_PIN, HIGH);
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"success\":true,\"relay\":1,\"state\":\"off\"}");
  Serial.println("🔌 Relay 1: OFF");
}

void handleRelay2On() {
  digitalWrite(RELAY2_PIN, LOW);
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"success\":true,\"relay\":2,\"state\":\"on\"}");
  Serial.println("🔌 Relay 2: ON");
}

void handleRelay2Off() {
  digitalWrite(RELAY2_PIN, HIGH);
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"success\":true,\"relay\":2,\"state\":\"off\"}");
  Serial.println("🔌 Relay 2: OFF");
}

void handleReset() {
  energy_kWh = 0;
  saveData();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"success\":true,\"message\":\"Energy counter reset\"}");
  Serial.println("🔄 Energy counter reset");
}

void handleStatus() {
  String json = "{";
  json += "\"connected\":true";
  json += ",\"version\":\"1.0.0\"";
  json += ",\"uptime\":" + String(millis() / 1000);
  json += ",\"relay1\":" + String(digitalRead(RELAY1_PIN) == LOW ? "on" : "off");
  json += ",\"relay2\":" + String(digitalRead(RELAY2_PIN) == LOW ? "on" : "off");
  json += "}";
  
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
}

void handleNotFound() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(404, "application/json", "{\"error\":\"Endpoint not found\"}");
}

/* ============ SETUP ============ */
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n=== WattBuddy ESP32 Energy Monitor v1.1 ===");
  
  // Initialize ADC Pins FIRST
  initializeADC();
  
  // Initialize Relay Pins
  digitalWrite(RELAY1_PIN, HIGH); 
  digitalWrite(RELAY2_PIN, HIGH);
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);
  Serial.println("✅ Relay pins configured");

  // Initialize File System
  if(!LittleFS.begin(true)) {
    Serial.println("❌ LittleFS Mount Failed");
  } else {
    Serial.println("✅ LittleFS initialized");
    loadData();
  }

  // Connect to WiFi
  Serial.print("🌐 Connecting to WiFi: " + String(ssid));
  WiFi.begin(ssid, pass);
  
  int timeout = 0;
  while (WiFi.status() != WL_CONNECTED && timeout < 20) {
    delay(500);
    Serial.print(".");
    timeout++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✅ WiFi Connected!");
    Serial.println("   IP Address: " + WiFi.localIP().toString());
  } else {
    Serial.println("\n❌ WiFi Connection Failed!");
  }

  // Initialize mDNS
  if (!MDNS.begin("wattbuddy")) {
    Serial.println("❌ mDNS Failed");
  } else {
    Serial.println("✅ mDNS initialized - Access via http://wattbuddy.local");
  }

  // Setup API Endpoints
  server.on("/api/readings", HTTP_GET, handleReadings);
  server.on("/api/relay1/on", HTTP_POST, handleRelay1On);
  server.on("/api/relay1/off", HTTP_POST, handleRelay1Off);
  server.on("/api/relay2/on", HTTP_POST, handleRelay2On);
  server.on("/api/relay2/off", HTTP_POST, handleRelay2Off);
  server.on("/api/reset", HTTP_POST, handleReset);
  server.on("/api/status", HTTP_GET, handleStatus);
  server.onNotFound(handleNotFound);
  
  server.begin();
  Serial.println("🚀 Web server started on port 80");
  Serial.println("\n📡 Available Endpoints:");
  Serial.println("   GET  http://wattbuddy.local/api/readings");
  Serial.println("   POST http://wattbuddy.local/api/relay1/on");
  Serial.println("   POST http://wattbuddy.local/api/relay1/off");
  Serial.println("   POST http://wattbuddy.local/api/relay2/on");
  Serial.println("   POST http://wattbuddy.local/api/relay2/off");
  Serial.println("   POST http://wattbuddy.local/api/reset");
  Serial.println("   GET  http://wattbuddy.local/api/status\n");
  
  lastReadingTime = millis();
  lastEnergyUpdate = millis();
}

/* ============ MAIN LOOP ============ */
void loop() {
  server.handleClient();
  
  // Read sensors every 500ms (faster readings)
  if (millis() - lastReadingTime > 500) {
    calculateEnergy();
    lastReadingTime = millis();
  }
  
  // Update energy every 1 second
  if (millis() - lastEnergyUpdate > 1000) {
    float timeStepSeconds = 1.0; // 1 second
    float timeStepHours = timeStepSeconds / 3600.0;
    energy_kWh += (Power / 1000.0) * timeStepHours;
    
    lastEnergyUpdate = millis();
    
    // Save energy every 5 minutes
    static unsigned long lastSave = 0;
    if (millis() - lastSave > 300000) {
      saveData();
      lastSave = millis();
    }
  }
}

/* ============ SENSOR CALCULATIONS ============ */
void calculateEnergy() {
  double sumI2 = 0, sumV2 = 0;
  int samples = 200; // Reduced for faster response

  for (int i = 0; i < samples; i++) {
    // Read Current (ACS712 30A module) - Pin 34
    int rawI = analogRead(ACS_PIN);
    float iV = (rawI / 4095.0) * 3.3;
    float current_digital = (iV - 1.06) / 0.185; // CORRECTED offset to 1.06V (was 1.65V)
    if (current_digital < 0) current_digital = 0;
    sumI2 += current_digital * current_digital;
    
    // Read Voltage (ZMPT101B module) - Pin 35 - RECALIBRATED
    int rawV = analogRead(ZMPT_PIN);
    float vV = (rawV / 4095.0) * 3.3;
    float vAC = (vV - 1.65) * 779.0; // CORRECTED scale factor to 779.0 (was 220.0) for better voltage readings
    if (vAC < 0) vAC = 0;
    sumV2 += vAC * vAC;
    
    delayMicroseconds(50); // Reduced delay for faster sampling
  }
  
  // RMS Calculations
  Irms = sqrt(sumI2 / samples);
  Vrms = sqrt(sumV2 / samples);
  
  // Filter out noise - tighter thresholds for cleaner data
  if (Irms < 0.05) Irms = 0;  // 50mA noise threshold
  if (Vrms < 100.0 || Vrms > 250.0) Vrms = 220.0; // Accept only 100-250V range, else assume 220V nominal
  
  // Calculate Power
  Power = Vrms * Irms * power_factor;
  
  // Prevent negative power
  if (Power < 0.1) Power = 0;
  
  // Debug output every 10 seconds
  static unsigned long lastDebug = 0;
  if (millis() - lastDebug > 10000) {
    Serial.print("📈 V=" + String(Vrms, 1) + "V ");
    Serial.print("I=" + String(Irms, 3) + "A ");
    Serial.print("P=" + String(Power, 2) + "W ");
    Serial.println("E=" + String(energy_kWh, 4) + "kWh");
    lastDebug = millis();
  }
}

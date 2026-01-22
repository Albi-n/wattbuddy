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

WebServer server(80);

/* ============ ADC INITIALIZATION ============ */
void initializeADC() {
  pinMode(ACS_PIN, INPUT);
  pinMode(ZMPT_PIN, INPUT);
  Serial.println("✅ ADC pins initialized");
}

/* ============ SETUP ============ */
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n=== WattBuddy ESP32 CALIBRATION MODE ===");
  Serial.println("This mode prints raw sensor values for calibration");
  
  initializeADC();
  
  // Initialize Relay Pins
  digitalWrite(RELAY1_PIN, HIGH); 
  digitalWrite(RELAY2_PIN, HIGH);
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);
  Serial.println("✅ Relay pins configured");

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
    Serial.println("✅ mDNS initialized");
  }

  Serial.println("\n📊 RAW SENSOR CALIBRATION DATA");
  Serial.println("================================");
  Serial.println("Format: rawI | iV(V) | current_offset | rawV | vV(V) | voltage_offset");
  Serial.println("(Connect/disconnect loads to see values change)");
  Serial.println("================================\n");
}

/* ============ MAIN LOOP ============ */
void loop() {
  // Read 10 samples and print
  static unsigned long lastPrint = 0;
  
  if (millis() - lastPrint > 2000) { // Print every 2 seconds
    lastPrint = millis();
    
    int rawI_sum = 0, rawV_sum = 0;
    
    for (int i = 0; i < 10; i++) {
      rawI_sum += analogRead(ACS_PIN);
      rawV_sum += analogRead(ZMPT_PIN);
    }
    
    int rawI = rawI_sum / 10;
    int rawV = rawV_sum / 10;
    
    // Convert to voltage
    float iV = (rawI / 4095.0) * 3.3;
    float vV = (rawV / 4095.0) * 3.3;
    
    // Current calculation with different offsets to test
    float current_test = (iV - 1.06) / 0.185;  // CORRECTED offset to 1.06V
    if (current_test < 0) current_test = 0;
    
    // Voltage calculation
    float voltage_test = (vV - 1.65) * 779.0;  // CORRECTED scale factor to 779.0
    if (voltage_test < 0) voltage_test = 0;
    
    Serial.print("🔍 rawI=" + String(rawI) + " | iV=" + String(iV, 3) + "V");
    Serial.print(" | I=" + String(current_test, 3) + "A");
    Serial.print(" || rawV=" + String(rawV) + " | vV=" + String(vV, 3) + "V");
    Serial.println(" | V=" + String(voltage_test, 1) + "V");
    
    // Extra diagnostics
    if (current_test < 0.01 && rawI > 1000) {
      Serial.println("   ⚠️  WARNING: Current sensor offset might be wrong!");
      Serial.println("   💡 TIP: Try adjusting offset from 1.65 to " + String(iV, 2));
    }
    
    if (voltage_test < 50) {
      Serial.println("   ⚠️  WARNING: Voltage reading too low!");
      Serial.println("   💡 TIP: Try adjusting offset or scale factor");
    }
  }
}

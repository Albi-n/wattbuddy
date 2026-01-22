# WattBuddy Integration Troubleshooting Guide

## Symptom: App shows "Connecting to ESP32..." forever

### Possible Causes & Solutions

#### 1. **Wrong IP Address**
```dart
// ❌ Wrong
static const String esp32Url = 'http://192.168.0.100';

// ✅ Correct (check Serial Monitor on ESP32)
static const String esp32Url = 'http://192.168.1.100';
```
**How to Fix:**
- Open Arduino Serial Monitor
- Set baud to 115200
- Look for "✅ WiFi Connected!"
- Find your IP address
- Update `esp32_service.dart` line 8

#### 2. **Phone Not on Same WiFi**
- Phone must be on same WiFi as ESP32
- Check WiFi in Settings (not mobile data)
- Both devices should show same network name

#### 3. **ESP32 WiFi Connection Failed**
Look in Serial Monitor:
```
❌ WiFi Connection Failed. Check credentials or Signal.
```
**Solutions:**
- Verify WiFi name: `gecIi`
- Verify WiFi password: `66666666`
- Move ESP32 closer to router
- Check if WiFi is 2.4GHz (5GHz not supported on most ESP32)
- Restart ESP32 (power cycle)

#### 4. **Firewall Blocking Port 80**
**Windows:**
- Run `allow-firewall.ps1` (included in repo)
- Or manually add exception for your WiFi network

---

## Symptom: API endpoints return 404

### Possible Causes & Solutions

#### 1. **Wrong ESP32 Code Uploaded**
Check if you uploaded `esp32_final_with_api.ino` and not an older version
```cpp
// ✅ Should have these endpoints
server.on("/api/latest", HTTP_GET, handleGetLatestData);
server.on("/api/relay1/on", HTTP_GET, handleRelay1On);
server.on("/api/relay2/on", HTTP_GET, handleRelay2On);
```

**How to Fix:**
1. Double-check filename: `esp32_final_with_api.ino`
2. Recompile and re-upload
3. Monitor Serial output to confirm upload

#### 2. **ArduinoJSON Library Not Installed**
Check Serial Monitor for errors mentioning `ArduinoJson`

**Install Library:**
1. Arduino IDE → Sketch → Include Library → Manage Libraries
2. Search: `ArduinoJSON`
3. Install by Benoit Blanchon (v6.x or v7.x)
4. Re-upload code

#### 3. **Wrong URL Format**
```javascript
// ❌ Wrong (URL incomplete)
http://192.168.1.100/api

// ✅ Correct (include /api/latest or specific endpoint)
http://192.168.1.100/api/latest
http://192.168.1.100/api/relay1/on
```

---

## Symptom: Sensor readings show 0 or garbage values

### Voltage Reading = 0

**Check These:**
1. **ZMPT101B Connections**
   ```
   ZMPT101B → GPIO 35 (ADC pin)
   GND      → GND
   VCC      → 3.3V
   ```

2. **Calibration Values** (in ESP32 code)
   ```cpp
   // Current code values
   float vVolts = (analogRead(ZMPT_PIN) / ADC_MAX) * VREF;
   float vAC = (vVolts - 1.65) * 682.0;  // Check this multiplier
   ```

3. **Test with Multimeter**
   - Measure voltage at GPIO 35
   - Should be ~1.65V (midpoint) when no AC power
   - Should vary 0-3.3V with AC signal

### Current Reading = 0

**Check These:**
1. **ACS712 Connections**
   ```
   ACS712 → GPIO 34 (ADC pin)
   GND    → GND
   VCC    → 5V (IMPORTANT: must be 5V!)
   IP     → Measures AC current
   ```

2. **Calibration Values**
   ```cpp
   float currentMidpointV = 1.068;  // Check with multimeter
   float sensitivity = 0.0925;       // For ACS712-5A
   ```

3. **Hardware Check**
   - Is AC current flowing through ACS712?
   - Check with clamp meter on AC wire

---

## Symptom: Relay control buttons don't work

### Solution 1: Check GPIO Connections
```cpp
#define RELAY1_PIN 23      // Check GPIO 23
#define RELAY2_PIN 19      // Check GPIO 19
```

Verify physical connections:
```
ESP32 GPIO 23 → Relay Module IN1
ESP32 GPIO 19 → Relay Module IN2
ESP32 GND     → Relay Module GND
5V Supply     → Relay Module VCC
```

### Solution 2: Relay Module Power
- Relay module needs 5V supply
- Use separate power supply if possible
- Current draw: ~70mA per relay

### Solution 3: Check Logic Levels
```cpp
// LOW = ON, HIGH = OFF (inverted logic!)
digitalWrite(RELAY1_PIN, LOW);   // Turns relay ON
digitalWrite(RELAY1_PIN, HIGH);  // Turns relay OFF
```

### Solution 4: Test Endpoint Manually
Open in browser:
```
http://192.168.1.100/api/relay1/on
```

Should return:
```json
{"success":true,"relay":1,"state":true}
```

If error, check Serial Monitor

---

## Symptom: Flutter app crashes on startup

### Error: "http: http not found"
```bash
# Run in Flutter project directory
flutter pub get
```

### Error: "fl_chart not found"
Already in `pubspec.yaml`, run:
```bash
flutter pub get
flutter clean
flutter pub get
```

### Error: "import file not found"
Make sure all new files exist:
- ✅ `lib/widgets/realtime_power_chart.dart`
- ✅ `lib/widgets/relay_control_widget.dart`
- ✅ `lib/widgets/sensor_data_widget.dart`

If missing, download them from the repository

---

## Symptom: Chart shows no data

### Check 1: Data Actually Updating?
Add a print statement to see:
```bash
# Look at console output while app running
[  +100 ms] ✅ Direct ESP32 Data: {"voltage":230.5,...}
```

### Check 2: Correct Data Type?
Flutter expects:
```dart
'voltage': double or int
'current': double or int
'power': double or int
```

### Check 3: Chart Update Frequency
If WiFi is slow, increase timer:
```dart
// Change from 2 seconds to 5 seconds
_refreshTimer = Timer.periodic(
  const Duration(seconds: 5),  // ← Changed from 2
  (_) => _loadRealTimeData(),
);
```

---

## Symptom: "Permission denied" when running ESP32 code

### Windows Users
1. Run `allow-firewall.ps1` as Administrator
2. Or disable Windows Defender temporarily
3. Or add exception for Arduino IDE

### Mac Users
```bash
# Grant permission
chmod +x /Applications/Arduino.app/Contents/Java/tools/esptool.py
```

---

## Symptom: Serial Monitor shows garbage text

### Problem: Wrong Baud Rate
```
Serial.begin(115200);  // ESP32 code uses THIS
```

**Fix:** Arduino Serial Monitor → Set to **115200**

### Problem: Wrong Board Selected
- Tools → Board → **ESP32 Dev Module**
- Tools → Port → Select correct COM port

---

## Symptom: Relay clicking but device doesn't turn on/off

### Check 1: Relay Module Contacts
- Inspect relay for burnt contacts
- Test continuity with multimeter
- Swap relay module to different GPIO

### Check 2: Device Wiring
```
AC Live → Relay NO contact
Device  → Relay COM contact
AC Neutral → Device
```
Verify correct wiring

### Check 3: Relay Activation Level
If relay activates opposite:
```cpp
// If relay turns ON when should turn OFF
digitalWrite(RELAY1_PIN, HIGH);   // Try HIGH instead of LOW
digitalWrite(RELAY1_PIN, LOW);    // And LOW instead of HIGH
```

---

## Symptom: Energy reading doesn't increase

### Check Calculation Logic
```cpp
void loop() {
  if (millis() - lastReadingTime > 2000) {
    calculateEnergy();
    float timeStepHours = (millis() - lastReadingTime) / 3600000.0;
    energy_kWh += (Power / 1000.0) * timeStepHours;
    // Energy should increase every 2 seconds
  }
}
```

**Verify:**
1. Power reading is not zero
2. Time calculation is correct
3. Energy being saved to storage

---

## Symptom: WiFi disconnects frequently

### Solution 1: Power Supply
- Use high-quality USB power supply (2A minimum)
- Avoid cheap phone chargers
- Add capacitor (100µF) across ESP32 power pins

### Solution 2: WiFi Settings
```cpp
// Increase timeout
int timeout = 0;
while (WiFi.status() != WL_CONNECTED && timeout < 60) {  // Increased from 40
  delay(500);
  Serial.print(".");
  timeout++;
}
```

### Solution 3: Use Static IP
```cpp
// Instead of DHCP
IPAddress staticIP(192, 168, 1, 100);
IPAddress gateway(192, 168, 1, 1);
IPAddress subnet(255, 255, 255, 0);
WiFi.config(staticIP, gateway, subnet);
WiFi.begin(ssid, pass);
```

---

## Performance Issues

### Chart Updates Too Slow
```dart
// Reduce update frequency
Timer.periodic(Duration(seconds: 5), ...)  // Instead of 2 seconds
```

### Memory Issues
```cpp
// Clear buffer if needed
esp32Data = null;  // Release old data
```

---

## Complete Debug Checklist

- [ ] ESP32 board selected in Arduino IDE
- [ ] Baud rate 115200 in Serial Monitor
- [ ] ArduinoJSON library installed
- [ ] Correct ESP32 code uploaded
- [ ] WiFi connected (check Serial Monitor)
- [ ] IP address matches Flutter code
- [ ] Phone on same WiFi network
- [ ] Sensors connected to correct pins
- [ ] Relay module has 5V power
- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] All new widget files created
- [ ] API endpoints tested in browser first
- [ ] No firewall blocking port 80

---

## Getting Help

1. **Check Serial Monitor Output** - Most issues visible here
2. **Test API Manually** - Use browser before Flutter
3. **Verify Connections** - Double-check all pin connections
4. **Try Restart** - Power cycle ESP32 and restart app
5. **Check Voltage** - Use multimeter on sensor inputs
6. **Ask with Details** - Share:
   - Serial Monitor output
   - API response (from browser)
   - Flutter console error
   - Hardware connections diagram

---

**Last Updated**: January 22, 2026
**Keep this handy while testing!**

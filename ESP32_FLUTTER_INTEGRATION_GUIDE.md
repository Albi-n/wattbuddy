# WattBuddy - ESP32 to Flutter Integration Setup Guide

## 🎯 Overview
This guide explains how to connect your ESP32 energy monitor to the Flutter WattBuddy app and display live power usage charts.

## 📋 Components

### 1. **ESP32 Firmware** (`esp32_corrected_FINAL.ino`)
- Reads voltage and current sensors
- Exposes JSON API on port 80
- Logs data to Serial Monitor
- Endpoints:
  - `GET /api/latest` - Latest sensor reading
  - `GET /history` - Last 60 readings

### 2. **Flutter App Updates**
- **ESP32 Service** - Handles API communication
- **Live Power Chart** - Real-time visualization widget
- **Dashboard Integration** - Displays chart and metrics

### 3. **Backend Server** (`wattbuddy-server`)
- Stores readings in memory (last 60 per user)
- Provides endpoints for Flutter app
- Logs to console for monitoring

---

## 🔧 Step 1: Configure ESP32

### Prerequisites
- Arduino IDE with ESP32 board support
- ArduinoJson library (for JSON support)
- WiFi credentials

### Setup Instructions

1. **Update WiFi Credentials**
   ```cpp
   const char* ssid = "YOUR_SSID";
   const char* pass = "YOUR_PASSWORD";
   ```

2. **Find ESP32 IP Address**
   - Upload the sketch
   - Open Serial Monitor (115200 baud)
   - Look for: `📱 IP Address: 192.168.x.x`

3. **Test the Endpoints**
   ```bash
   # Get latest data
   curl http://192.168.x.x/api/latest
   
   # Get history
   curl http://192.168.x.x/history
   ```

### Serial Output Format
```
⚡ V: 230.1V | I: 1.234A | P: 283.5W | E: 0.0125 kWh | Cost: ₹0.09
```

---

## 🚀 Step 2: Configure Flutter App

### Update ESP32 Service

Edit `lib/services/esp32_service.dart`:

```dart
// Option 1: Direct ESP32 IP (for local testing)
static const String esp32Url = 'http://192.168.x.x:80';

// Option 2: Backend Server (for production)
static const String serverUrl = 'http://192.168.x.x:5000';
```

### Run Flutter App
```bash
flutter pub get
flutter run
```

### Dashboard Features
- ✅ Live Power Chart (last 60 readings)
- ✅ Real-time metrics (V, I, P)
- ✅ Peak/Avg/Min power display
- ✅ Energy tracking
- ✅ Cost calculation

---

## 📡 Step 3: Backend Server Setup

### Start Node.js Server
```bash
cd wattbuddy-server
npm install
npm start
```

Expected output:
```
🚀 WattBuddy Server Running with All 4 Features!
```

### API Endpoints

#### Post Reading (from ESP32 or Flutter)
```bash
POST /api/esp32/reading
Body: {
  "userId": "user123",
  "voltage": 230.1,
  "current": 1.234,
  "power": 283.5,
  "energy_kWh": 0.0125,
  "cost_INR": 0.09,
  "timestamp": 1609459200000
}
```

#### Get Latest Data
```bash
GET /api/esp32/latest/:userId
Response: { "voltage": 230.1, "current": 1.234, "power": 283.5, ... }
```

#### Get History
```bash
GET /api/esp32/history/:userId
Response: { "data": [ {...}, {...} ], "count": 60 }
```

---

## 🔄 Data Flow

```
ESP32 (Sensors)
    ↓
    ├─→ Serial Monitor (Debug)
    ├─→ JSON API (/api/latest, /history)
    │
    └─→ Flutter App
        ├─ Direct Connection (LAN only)
        └─ Via Backend Server (over internet)
            │
            └─→ Live Chart Display
                ├─ Current Power
                ├─ Peak/Avg/Min
                └─ Energy Counter
```

---

## 📊 Live Chart Features

The `LivePowerChart` widget shows:

1. **Line Chart**
   - Last 60 power readings
   - Auto-scaling Y-axis
   - Smooth curves
   - Hover data points

2. **Statistics Box**
   - Peak power
   - Average power
   - Minimum power

3. **Real-time Updates**
   - Refreshes every 2 seconds
   - Smooth animations
   - Loading indicator

---

## 🛠️ Troubleshooting

### ESP32 Not Connecting to WiFi
```
Check:
- WiFi SSID and password are correct
- WiFi is 2.4GHz (ESP32 doesn't support 5GHz)
- Router is not blocking ESP32 MAC address
```

### Flutter App Not Connecting to ESP32
```
Check:
- ESP32 IP address in esp32_service.dart
- ESP32 and phone are on same WiFi network
- No firewall blocking port 80
- Serial monitor shows "✅ WiFi Connected!"
```

### Chart Not Updating
```
Check:
- Server logs show readings being received
- "/api/esp32/history/{userId}" returns data
- Dashboard refresh interval is set correctly (2 seconds)
```

### Serial Monitor Shows Noise
```
Solution:
- Calibrate sensors during power-up (no load connected)
- Check sensor wiring
- Add capacitors to sensor power lines
```

---

## 📝 Important Notes

1. **Change ESP32 IP Address**: Update both ESP32 code and Flutter service
2. **Change WiFi Credentials**: Don't commit to git!
3. **userId**: Set from logged-in user in Flutter
4. **Data Retention**: Keeps last 60 readings in memory
5. **No Database**: Use in-memory storage (for testing)

---

## 📱 Dashboard Preview

```
Dashboard
├─ User Info Card
├─ Metrics Cards (V, I, P, E)
├─ Live Power Chart ⭐ (NEW)
├─ Monthly Usage Chart
└─ Recent Bills
```

---

## 🎓 Example: Complete Data Flow

1. **ESP32 Reads Sensors**
   ```cpp
   Vrms = 230.1V, Irms = 1.234A, Power = 283.5W
   ```

2. **Print to Serial**
   ```
   ⚡ V: 230.1V | I: 1.234A | P: 283.5W | E: 0.0125 kWh | Cost: ₹0.09
   ```

3. **App Polls Every 2 Seconds**
   ```
   GET /api/esp32/latest/user123
   ```

4. **Chart Updates**
   ```
   Add (283.5W) to chart
   Shift old data left
   Animate transition
   ```

---

## 🔒 Security Notes

- ⚠️ Change WiFi password before deployment
- ⚠️ Use HTTPS in production
- ⚠️ Add authentication to API endpoints
- ⚠️ Validate user IDs

---

## 📞 Support

For issues:
1. Check Serial Monitor on ESP32
2. Check Flutter console (`flutter logs`)
3. Check Node.js server output
4. Enable debugging in esp32_service.dart

---

**Last Updated**: January 22, 2026
**Status**: ✅ Ready for Testing

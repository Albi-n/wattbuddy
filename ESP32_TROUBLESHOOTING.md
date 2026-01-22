# ESP32 Timeout Troubleshooting Guide

## Current Issue
Flutter app shows: `❌ Live ESP32 fetch error: TimeoutException after 0:00:10.000000`

## Root Cause Analysis
Backend is trying to reach ESP32 at `wattbuddy.local/api/readings` but **ESP32 is not responding**.

Possible reasons:
1. ✅ **ESP32 is powered OFF** - Most likely!
2. ✅ **Old firmware is still running** - Need to upload esp32_energy_monitor_FIXED.ino
3. ✅ **WiFi connection lost** - Check serial monitor
4. ✅ **ESP32 on wrong network** - Connected to wrong WiFi SSID
5. ✅ **Firewall blocking mDNS** - Windows might block .local hostname resolution

## Solution Steps

### Step 1: Upload Fixed Firmware to ESP32
```
1. Open Arduino IDE
2. File → Open → esp32_energy_monitor_FIXED.ino
3. Select Board: ESP32 Dev Module
4. Select Port: COM# (your ESP32 port)
5. Click Upload
6. Wait for "✅ Done Uploading"
```

### Step 2: Verify ESP32 is Running
Open Serial Monitor (Tools → Serial Monitor, 115200 baud) and look for:
```
=== WattBuddy ESP32 Energy Monitor v1.1 ===
✅ ADC pins initialized
✅ Relay pins configured
✅ LittleFS initialized
🌐 Connecting to WiFi: OPPO F15.......
✅ WiFi Connected!
   IP Address: 192.168.xxx.xxx
✅ mDNS initialized - Access via http://wattbuddy.local
🚀 Web server started on port 80

📡 Available Endpoints:
   GET  http://wattbuddy.local/api/readings
   ...

📈 V=220.0V I=0.000A P=0.00W E=0.0080kWh  ← Should show ~220V
```

**Key Signs it's Working:**
- ✅ WiFi shows "Connected"
- ✅ IP Address is displayed (192.168.233.xxx)
- ✅ Voltage reads ~220V (or whatever your nominal is)
- ✅ You see periodic "📈 V=..." debug output

### Step 3: Test ESP32 Connectivity from PC
```powershell
# Option 1: Ping using mDNS
ping wattbuddy.local

# Option 2: Test API directly in browser
# Go to: http://wattbuddy.local/api/readings
# (May not work on Windows - use Option 3 instead)

# Option 3: Curl from PowerShell
curl "http://wattbuddy.local/api/readings" -Headers @{"Accept"="application/json"}
```

Expected response (if working):
```json
{
  "voltage": 220.1,
  "current": 0.00,
  "power": 0.00,
  "energy": 0.0080,
  "bill": 0.056,
  "relay1": "false",
  "relay2": "false"
}
```

### Step 4: Check Backend Logs
If ESP32 is running but still timing out, check backend logs:

```powershell
# The backend should show messages like:
# ✅ Live ESP32 Data: V=220V, P=0W, I=0A
# OR
# ❌ ESP32 Fetch Error: ENOTFOUND (if mDNS hostname not resolving)
```

## If Still Timing Out...

### Option A: Use ESP32 IP Address Instead
If mDNS (.local) doesn't work on your Windows setup:

1. **Find ESP32 IP address** from serial monitor (shown during WiFi connect)
2. **Edit server.js line 174:**
```javascript
// OLD (not working):
const esp32URL = 'http://wattbuddy.local/api/readings';

// NEW (use actual IP from serial monitor, e.g., 192.168.233.214):
const esp32URL = 'http://192.168.233.214/api/readings';
```
3. Restart backend: `taskkill /F /IM node.exe` then `node server.js`

### Option B: Windows mDNS Fix
If Windows doesn't resolve `.local` hostnames:

1. **Install Bonjour Print Services** (enables mDNS on Windows)
   - Download from Apple: https://support.apple.com/downloads/bonjour
   - Or use: `winget install Apple.Bonjour`

2. Restart your PC and try again

### Option C: Quick Verification
Test if backend can reach ESP32:
```powershell
# From PowerShell, check if port 80 is open on ESP32
Test-NetConnection -ComputerName wattbuddy.local -Port 80

# If successful: TcpTestSucceeded should be True
# If failed: TcpTestSucceeded will be False
```

## Expected Timeline

- **After upload**: 5-10 seconds for ESP32 to boot
- **After WiFi connect**: 2-3 seconds for mDNS to register
- **First API call**: Should return data within 1 second

## Still Not Working?

**Check these in order:**
1. ✅ Is ESP32 powered on? (Check USB power, LED blinking?)
2. ✅ Did firmware upload succeed? (Watch for "✅ Done Uploading" and no errors)
3. ✅ Does serial monitor show WiFi Connected?
4. ✅ Is PC on same WiFi network as ESP32? (OPPO F15)
5. ✅ Are firewall/antivirus blocking mDNS?
6. ✅ Does `ping wattbuddy.local` work from PC?

## Calibration Notes
Recent firmware update changed sensor calibration:
- **Voltage (ZMPT101B)**: Now reads ~220V nominal (previously showed 39-55V unstable)
- **Current (ACS712)**: Improved offset for better idle readings (should be ~0A when nothing running)
- **Noise filter**: Tighter thresholds for cleaner data

Serial output every 10 seconds should show:
```
📈 V=220.0V I=0.000A P=0.00W E=0.0080kWh
```

If you're seeing different values, calibration may need adjustment.

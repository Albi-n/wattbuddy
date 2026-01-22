# WattBuddy Debugging Guide

## ✅ Fixed: Type Mismatch Error

The error `type 'int' is not a subtype of type 'FutureOr<String>'` has been fixed in `esp32_service.dart`. The userId is now properly converted from int to String.

---

## ❌ ESP32 Timeout Issue - Diagnosis

You're getting `TimeoutException after 0:00:10.000000` which means the app can't reach the backend.

### Step 1: Verify Backend is Running

```bash
# Terminal 1: Start the backend
cd wattbuddy-server
npm start

# Should output:
# ✅ Server running on port 4000
# ✅ Database connection successful
```

**Check**: Does it show these messages?

### Step 2: Verify Backend IP Address

Your Flutter app is trying to reach: `http://192.168.233.214:5000`

But the backend runs on **port 4000**, not 5000!

**FIX**: Update the URL in `esp32_service.dart`:

Change:
```dart
static const String serverUrl = 'http://192.168.233.214:5000';
```

To:
```dart
static const String serverUrl = 'http://192.168.233.214:4000';
```

### Step 3: Test Connection from Browser

Open in your browser:
```
http://192.168.233.214:4000/api/esp32/live
```

**Expected**: Should return JSON with sensor data or error (not timeout)

### Step 4: Verify Network

```bash
# In PowerShell, test if backend is reachable
ping 192.168.233.214
# Should show responses, not "Request timed out"

# Test if port 4000 is open
Test-NetConnection -ComputerName 192.168.233.214 -Port 4000
# Should show: TcpTestSucceeded : True
```

### Step 5: Check Firewall

If Test-NetConnection shows `False`, your firewall is blocking it.

**Solution**: Allow Node.js through Windows Firewall
```bash
# Run as Administrator
New-NetFirewallRule -DisplayName "Node.js" -Direction Inbound -Program "C:\Program Files\nodejs\node.exe" -Action Allow
```

---

## 🚀 Quick Fix Checklist

- [ ] Update port from 5000 to **4000** in esp32_service.dart
- [ ] Verify backend is running with `npm start`
- [ ] Test URL in browser: `http://192.168.233.214:4000/api/esp32/live`
- [ ] Verify firewall allows port 4000
- [ ] Restart Flutter app: Press `r` for hot reload in flutter run terminal

---

## 📋 What Gets Fixed

After these changes:
- ✅ Type error (`int` → `String`) fixed
- ✅ Backend will respond to API calls
- ✅ ESP32 sensor data will display
- ✅ Relay control will work
- ✅ Multi-user data isolation will work

---

## 🔧 If Still Not Working

1. **Check backend logs** - Look for error messages
2. **Verify database connection** - Backend should show "✅ Database connection successful"
3. **Check ESP32 is connected** - Backend should show readings being received
4. **Check API endpoints** - Test manually: `curl http://192.168.233.214:4000/api/esp32/live`

---

## 📝 Architecture Reminder

```
Flutter App (Chrome)
  ↓
  Backend (Node.js on 192.168.233.214:4000)
    ↓
    Database (PostgreSQL)
    ↓
    ESP32 Proxy → http://192.168.233.214/api/readings
```

The port is crucial!

# WattBuddy Implementation Steps - Database & App Consolidation

## Overview
This document outlines the steps to implement:
1. **User-specific database storage** for ESP32 sensor data
2. **Unique constraints** for consumer_number and username
3. **User login-based data routing** (data goes to logged-in user only)
4. **Consolidate duplicate features** (Device Control in both Dashboard and Devices Screen)

---

## PHASE 1: DATABASE SCHEMA UPDATES ⚙️

### Step 1.1: Update Schema with New Columns
**File**: `wattbuddy-server/init.sql`

Add missing columns to `energy_readings` table:
- `voltage FLOAT`
- `current FLOAT`
- `energy FLOAT`
- `power_factor FLOAT`
- `frequency FLOAT`
- `temperature FLOAT`

### Step 1.2: Add Device Configuration Table
Create table for storing device names and relay assignments per user:
```sql
CREATE TABLE device_configs (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  relay1_name VARCHAR(255) DEFAULT 'Device 1',
  relay2_name VARCHAR(255) DEFAULT 'Device 2',
  updated_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
)
```

### Step 1.3: Add Relay Status Table
```sql
CREATE TABLE relay_status (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL,
  relay_number INT NOT NULL,
  is_on BOOLEAN DEFAULT FALSE,
  last_toggled_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, relay_number)
)
```

---

## PHASE 2: BACKEND SERVER UPDATES 🔧

### Step 2.1: Update Auth Controller
**File**: `wattbuddy-server/controllers/authController.js`

**Changes needed:**
- Add unique constraint validation for `consumer_number` and `username`
- On successful registration:
  - Create entry in `device_configs` table
  - Initialize `relay_status` entries for both relays
  - Set up `power_limit` entry
- Return user ID in response for client storage

### Step 2.2: Create Device Config Service
**File**: `wattbuddy-server/services/deviceConfigService.js`

**Methods:**
```javascript
class DeviceConfigService {
  static async getDeviceConfig(userId)
  static async updateDeviceNames(userId, relay1Name, relay2Name)
  static async saveDeviceToDb(userId, deviceName, relayNumber)
  static async getRelayStatus(userId, relayNumber)
  static async updateRelayStatus(userId, relayNumber, status)
}
```

### Step 2.3: Update ESP32 Storage Service
**File**: `wattbuddy-server/services/esp32StorageService.js`

**Changes:**
- Accept `userId` from request header or body
- Validate user is authenticated
- Store data only for that specific user
- Fetch previous readings only for that user

### Step 2.4: Create Device Control Route
**File**: `wattbuddy-server/routes/deviceRoutes.js` (NEW FILE)

**Endpoints:**
```
POST   /api/devices/config            - Get device config
PUT    /api/devices/config            - Update device names
POST   /api/devices/relay/status      - Get relay status
PUT    /api/devices/relay/toggle      - Toggle relay
POST   /api/devices/relay/on          - Turn relay ON
POST   /api/devices/relay/off         - Turn relay OFF
```

### Step 2.5: Update Server.js
**File**: `wattbuddy-server/server.js`

**Changes:**
- Register device routes
- Update ESP32 data endpoint to validate userId
- Add authentication middleware for protected routes

### Step 2.6: Update ESP32 API Endpoint
**File**: `wattbuddy-server/server.js`

**Current**: `/api/esp32/data`
**Changes:**
- REQUIRE `userId` in request body or header
- Validate user exists in database
- Store with timestamp
- Broadcast only to that user's socket room

---

## PHASE 3: FLUTTER APP UPDATES 📱

### Step 3.1: Update Login/Register Screen
**File**: `lib/screens/login_register.dart`

**Changes:**
- On successful login:
  - Store user ID, consumer_number, username to SharedPreferences
  - Validate consumer_number uniqueness
  - Validate username uniqueness on registration
- Emit socket event with userId for room subscription
- Join user-specific socket room

### Step 3.2: Consolidate Device Control
**Decision**: Keep it in **Devices Screen** (primary location)

**Remove from Dashboard**:
- Delete `RelayControlWidget` import from `dashboard_screen.dart`
- Remove `const RelayControlWidget()` widget
- Keep only live data display on dashboard

### Step 3.3: Update Devices Screen
**File**: `lib/screens/devices_screen.dart`

**Changes:**
- Load device configs from backend database
- Save device names to backend (not just SharedPreferences)
- Add relay status toggle buttons
- Show real-time relay status
- Add ability to add/remove/rename devices
- Improve UI for better organization

### Step 3.4: Create Device Control Widget
**File**: `lib/widgets/device_control_widget.dart`

**Features:**
- Display all configured devices
- Toggle relay status with visual feedback
- Show last toggled time
- Confirm before toggle

### Step 3.5: Update Dashboard Screen
**File**: `lib/screens/dashboard_screen.dart`

**Changes:**
- Remove relay control widget
- Keep only live data display (voltage, current, power)
- Add "Go to Devices" button if user needs device control
- Show device status summary (which devices are ON/OFF)

### Step 3.6: Create ESP32 Service Updates
**File**: `lib/services/esp32_service.dart`

**Changes:**
- Add userId parameter to all API calls
- Send userId in request header or body
- Store userId locally from login
- Filter data by current user only

### Step 3.7: Update API Service
**File**: `lib/services/api_service.dart`

**Changes:**
- Store userId globally
- Add userId to all device-related endpoints
- Add user-specific data filtering

---

## PHASE 4: SOCKET.IO REAL-TIME UPDATES 🔌

### Step 4.1: Update Socket Connection
**File**: `lib/services/socket_service.dart` or similar

**Changes:**
```javascript
// On login, connect socket with userId
socket.emit('user_login', {
  userId: userId,
  username: username
});

// Server joins user to room
socket.join(`user_${userId}`);

// Broadcast data only to user room
io.to(`user_${userId}`).emit('live_data_update', data);
```

### Step 4.2: Update Server Socket Events
**File**: `wattbuddy-server/server.js`

```javascript
io.on('connection', (socket) => {
  socket.on('user_login', (data) => {
    socket.join(`user_${data.userId}`);
    console.log(`User ${data.userId} joined room`);
  });

  socket.on('disconnect', (data) => {
    console.log(`User ${data.userId} disconnected`);
  });
});
```

---

## PHASE 5: DATA MIGRATION & TESTING 🧪

### Step 5.1: Database Migration Script
**File**: `wattbuddy-server/migrations/001_add_device_tables.sql`

```sql
-- Run manually with: psql -U postgres -d wattbuddy -f migrations/001_add_device_tables.sql
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS voltage FLOAT;
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS current FLOAT;
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS energy FLOAT;
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS power_factor FLOAT;
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS frequency FLOAT;
ALTER TABLE energy_readings ADD COLUMN IF NOT EXISTS temperature FLOAT;

CREATE TABLE IF NOT EXISTS device_configs (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  relay1_name VARCHAR(255) DEFAULT 'Device 1',
  relay2_name VARCHAR(255) DEFAULT 'Device 2',
  updated_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS relay_status (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL,
  relay_number INT NOT NULL,
  is_on BOOLEAN DEFAULT FALSE,
  last_toggled_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, relay_number)
);
```

### Step 5.2: Test Flows
1. **User Registration**
   - Create new user with unique consumer_number and username
   - Verify database entries created for all tables
   - Check device_configs initialized

2. **User Login**
   - Login with user credentials
   - Verify userId stored locally
   - Check socket room subscription

3. **ESP32 Data Flow**
   - Send data from ESP32 with userId
   - Verify data stored in correct user's records
   - Check live chart updates for current user only
   - Verify other users' data not visible

4. **Device Control**
   - Toggle relay from Devices Screen
   - Verify status updated in database
   - Check real-time status in app
   - Verify relay command sent to correct relay on ESP32

5. **Multi-user Isolation**
   - Login User A → verify sees only User A data
   - Login User B → verify sees only User B data
   - Verify User A data not visible to User B

---

## IMPLEMENTATION ORDER 📋

1. **Database Updates** (Step 1.1 - 1.3)
2. **Backend Services** (Step 2.1 - 2.6)
3. **Socket Configuration** (Step 4.1 - 4.2)
4. **Flutter Authentication** (Step 3.1)
5. **UI Consolidation** (Step 3.2 - 3.5)
6. **Service Updates** (Step 3.6 - 3.7)
7. **Testing** (Step 5.2)

---

## SUMMARY OF CHANGES

| Component | Current | New |
|-----------|---------|-----|
| Data Storage | No user isolation | User-specific storage |
| Device Control | Dashboard + Devices | Devices Screen ONLY |
| Consumer# | Non-unique | UNIQUE constraint |
| Username | Non-unique | UNIQUE constraint |
| Real-time Data | Broadcast to all | User-specific rooms |
| Device Config | LocalStorage only | Database + LocalCache |
| Relay Status | Manual tracking | Database-backed |

---

## NOTES
- All timestamps should use ISO 8601 format
- Implement proper error handling and validation
- Add rate limiting for device control (prevent relay spam)
- Log all data access for audit trail
- Test with multiple devices simultaneously

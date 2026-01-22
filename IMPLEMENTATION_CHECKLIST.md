# WattBuddy Multi-User Implementation - Checklist

## Status: BACKEND IMPLEMENTATION COMPLETE ✅

All backend services, routes, and database migrations have been created and are ready for deployment.

---

## BACKEND COMPLETED ITEMS

### ✅ Database Schema (migrations/001_add_device_tables.sql)
- [x] Added missing columns to `energy_readings` (voltage, current, energy, pf, frequency, temperature)
- [x] Created `device_configs` table
- [x] Created `relay_status` table
- [x] Created `device_control_logs` table (audit trail)
- [x] Created `user_sessions` table
- [x] Added proper indexes for performance
- [x] Added UNIQUE constraint to username

### ✅ Services
- [x] `DeviceConfigService` - Complete device management
  - getDeviceConfig()
  - initializeDeviceConfig() - Called on registration
  - updateDeviceNames()
  - getRelayStatus()
  - getAllRelayStatus()
  - toggleRelay()
  - setRelayState()
  - logDeviceControl() - Audit trail
  - getDeviceControlHistory()
  - initializeAllRelays() - Called on registration

- [x] `ESP32StorageService` - Enhanced with user isolation
  - validateUser() - Check user exists
  - storeReading() - User-specific storage
  - getLatestReadings() - User-specific queries
  - getReadingsByTimeRange()
  - getHourlyStats()
  - getDailySummary()
  - getLatestReading()
  - getReadingCount()

### ✅ Routes
- [x] `authController.js` - Updated
  - validateUser in register() with unique fields
  - Initialize device configs on successful registration
  - Return userId in login/register response

- [x] `deviceRoutes.js` - New file
  - GET /api/devices/config/:userId
  - PUT /api/devices/config
  - GET /api/devices/relay/status/:userId
  - GET /api/devices/relay/status/:userId/:relayNumber
  - POST /api/devices/relay/toggle
  - POST /api/devices/relay/on
  - POST /api/devices/relay/off
  - GET /api/devices/history/:userId

### ✅ Server Configuration
- [x] Register device routes
- [x] Add DeviceConfigService import
- [x] Update ESP32 data endpoint with userId validation
- [x] Add user-specific endpoints:
  - GET /api/esp32/readings/:userId
  - GET /api/esp32/latest/:userId
- [x] Enhanced Socket.io configuration:
  - user_login event for room subscription
  - relay_control event
  - User-specific data broadcasting

---

## FLUTTER IMPLEMENTATION - IN PROGRESS 🚀

### ✅ API Service Updates (COMPLETE)
- [x] Add global userId storage
- [x] setUserId() method for storing user ID after login
- [x] Update post() and get() methods to include userId
- [x] Update login() to store userId globally
- [x] Add device control endpoints:
  - getDeviceConfig()
  - updateDeviceNames()
  - getAllRelayStatus()
  - getRelayStatusForRelay()
  - toggleRelay()
  - turnRelayOn()
  - turnRelayOff()
  - getDeviceControlHistory()

### ⏳ Login/Register Screen (NEXT)
**File**: lib/screens/login_register.dart

**Changes needed**:
1. Store userId from registration response
2. Store userId from login response
3. Call ApiService.setUserId() after successful login
4. Add validation for unique username and consumer_number
5. Show appropriate error messages for duplicate fields

### ⏳ Device Control UI Consolidation (NEXT)
**Dashboard Screen**: lib/screens/dashboard_screen.dart
- [x] Remove RelayControlWidget import
- [x] Remove `const RelayControlWidget()` widget
- [x] Keep only live data display

**Devices Screen**: lib/screens/devices_screen.dart
- [ ] Update to use new backend device APIs
- [ ] Load device configs from database
- [ ] Save device names to backend
- [ ] Add relay status toggle functionality
- [ ] Improve UI layout for device management

**Create**: lib/widgets/device_control_widget.dart
- [ ] Unified device control widget
- [ ] Display all configured devices
- [ ] Toggle relay with visual feedback
- [ ] Show last toggled time
- [ ] Confirmation dialog before toggle

### ⏳ ESP32 Service Updates (NEXT)
**File**: lib/services/esp32_service.dart
- [ ] Add userId to all API calls
- [ ] Update data fetching methods
- [ ] Filter data by current user

### ⏳ Socket.io Integration (NEXT)
**File**: lib/services/socket_service.dart (if exists) or in relevant service
- [ ] Implement user_login event on app startup
- [ ] Subscribe to user-specific data updates
- [ ] Implement relay_control event for real-time relay updates

### ⏳ Main/App Widget (NEXT)
**File**: lib/main.dart
- [ ] Call ApiService.setUserId() on app startup if user logged in
- [ ] Store userId from SharedPreferences and set globally

---

## IMPLEMENTATION SEQUENCE

### Phase 1: Backend (✅ COMPLETE)
1. Create database migration
2. Create DeviceConfigService
3. Create deviceRoutes
4. Update authController
5. Update ESP32StorageService
6. Update server.js

### Phase 2: Flutter API Layer (✅ COMPLETE)
1. Update ApiService with device endpoints

### Phase 3: Flutter UI/Logic (⏳ IN PROGRESS)
1. Update Login/Register screen
2. Update main.dart for userId initialization
3. Update Dashboard screen
4. Update Devices screen
5. Create Device Control Widget
6. Update ESP32 service
7. Implement Socket.io integration

### Phase 4: Testing
1. Test user registration with unique validation
2. Test user login with userId storage
3. Test data isolation (User A sees only User A data)
4. Test relay control (works only for logged-in user)
5. Test multiple concurrent users
6. Test socket.io real-time updates

---

## KEY FEATURES IMPLEMENTED

### ✅ User Isolation
- Database queries filter by `user_id`
- API endpoints validate userId
- Socket.io broadcasts only to user-specific rooms

### ✅ Data Storage
- ESP32 readings stored with timestamp
- Device configurations per user
- Relay status tracking in database
- Audit trail of device control actions

### ✅ Unique Constraints
- Email UNIQUE
- consumer_number UNIQUE
- username UNIQUE (added)

### ✅ Device Management
- Store device names per user
- Track relay status per user
- Log all device control actions
- Device history/audit trail

---

## DATABASE TABLES REFERENCE

```sql
-- Users table (updated)
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(100) NOT NULL UNIQUE,
  email VARCHAR(255) UNIQUE NOT NULL,
  consumer_number VARCHAR(100) UNIQUE NOT NULL,
  password TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Device configuration per user
CREATE TABLE device_configs (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  relay1_name VARCHAR(255) DEFAULT 'Device 1',
  relay2_name VARCHAR(255) DEFAULT 'Device 2',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Relay status per user
CREATE TABLE relay_status (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL,
  relay_number INT NOT NULL CHECK (relay_number IN (1, 2)),
  is_on BOOLEAN DEFAULT FALSE,
  last_toggled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(user_id, relay_number)
);

-- Energy readings per user (updated)
CREATE TABLE energy_readings (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL,
  power_consumption FLOAT,
  voltage FLOAT DEFAULT 0,
  current FLOAT DEFAULT 0,
  energy FLOAT DEFAULT 0,
  power_factor FLOAT DEFAULT 0,
  frequency FLOAT DEFAULT 0,
  temperature FLOAT DEFAULT 0,
  recorded_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Audit trail
CREATE TABLE device_control_logs (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL,
  relay_number INT NOT NULL,
  action VARCHAR(50) NOT NULL,
  previous_state BOOLEAN,
  new_state BOOLEAN,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

---

## API ENDPOINTS READY

### Authentication
- POST /api/auth/register
- POST /api/auth/login

### Device Control
- GET /api/devices/config/:userId
- PUT /api/devices/config
- GET /api/devices/relay/status/:userId
- GET /api/devices/relay/status/:userId/:relayNumber
- POST /api/devices/relay/toggle
- POST /api/devices/relay/on
- POST /api/devices/relay/off
- GET /api/devices/history/:userId

### ESP32 Data
- POST /api/esp32/data
- GET /api/esp32/readings/:userId
- GET /api/esp32/latest/:userId

---

## DEPLOYMENT STEPS

### 1. Database Migration
```bash
# Connect to PostgreSQL
psql -U postgres -d wattbuddy -f wattbuddy-server/migrations/001_add_device_tables.sql
```

### 2. Restart Server
```bash
# Stop current server
# Install any missing dependencies
npm install
# Start server
npm start
```

### 3. Deploy Flutter App
```bash
# Hot reload should work fine
flutter hot reload
```

---

## NEXT IMMEDIATE STEPS

1. Update `lib/screens/login_register.dart` to call ApiService.setUserId()
2. Update `lib/main.dart` to restore userId from SharedPreferences on app startup
3. Remove RelayControlWidget from Dashboard
4. Update Devices Screen to use new API endpoints
5. Create Device Control Widget
6. Test the complete flow

---

## NOTES

- All timestamps use ISO 8601 format
- userId is stored as String in Flutter (converted from int in backend)
- Socket.io rooms follow pattern: `user_{userId}`
- Device names are stored per user (not global)
- Relay status is tracked in database for persistence
- All API calls include userId for security and isolation

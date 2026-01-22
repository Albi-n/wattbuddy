# Flutter Implementation Quick Guide

## 1. Update Login/Register Screen

### File: lib/screens/login_register.dart

After successful login/registration, store userId globally:

```dart
// In loginUserFun() method, after successful login:
if (success) {
  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString('wattBuddyUser');
  if (userJson != null) {
    final user = jsonDecode(userJson);
    if (user['id'] != null) {
      // Store userId globally in API service
      ApiService.setUserId(user['id'].toString());
    }
  }
  
  if (!mounted) return;
  Navigator.pushReplacementNamed(context, '/dashboard');
}

// In registerUser() method, after successful registration:
if (res['message'] == 'Registration successful') {
  // User data with id is returned from backend
  if (res['user'] != null && res['user']['id'] != null) {
    ApiService.setUserId(res['user']['id'].toString());
  }
  showForm(0); // go to login
}
```

---

## 2. Update Main Widget

### File: lib/main.dart

Initialize userId on app startup:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize userId from SharedPreferences if already logged in
  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString('wattBuddyUser');
  if (userJson != null) {
    final user = jsonDecode(userJson);
    if (user['id'] != null) {
      ApiService.setUserId(user['id'].toString());
      debugPrint('✅ User ID restored from storage: ${user['id']}');
    }
  }
  
  runApp(const MyApp());
}
```

---

## 3. Remove Relay Control from Dashboard

### File: lib/screens/dashboard_screen.dart

**Remove these lines**:
```dart
import '../widgets/relay_control_widget.dart';  // DELETE THIS
...
// RELAY CONTROL WIDGET - DELETE THIS ENTIRE SECTION
const RelayControlWidget(),
```

**Keep only**:
- Live sensor data display (voltage, current, power)
- Power usage chart
- Recent bills
- User info

---

## 4. Update Devices Screen

### File: lib/screens/devices_screen.dart

Replace device management with API calls:

```dart
// Add at top
import '../services/api_service.dart';

class _DevicesScreenState extends State<DevicesScreen> {
  List<Map<String, dynamic>> relayStatus = [];
  String relay1Name = "Device 1";
  String relay2Name = "Device 2";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceConfig();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (_) {
      _loadDeviceConfig();
    });
  }

  Future<void> _loadDeviceConfig() async {
    setState(() => isLoading = true);
    
    try {
      final config = await ApiService.getDeviceConfig();
      final statusList = await ApiService.getAllRelayStatus();
      
      if (mounted) {
        setState(() {
          if (config['config'] != null) {
            relay1Name = config['config']['relay1_name'] ?? 'Device 1';
            relay2Name = config['config']['relay2_name'] ?? 'Device 2';
          }
          relayStatus = statusList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showError('Failed to load device config: $e');
      }
    }
  }

  Future<void> _toggleRelay(int relayNumber) async {
    final success = await ApiService.toggleRelay(relayNumber);
    
    if (success) {
      _showSuccess('Relay $relayNumber toggled successfully');
      _loadDeviceConfig(); // Refresh status
    } else {
      _showError('Failed to toggle relay');
    }
  }

  Future<void> _updateDeviceNames(String name1, String name2) async {
    final success = await ApiService.updateDeviceNames(name1, name2);
    
    if (success) {
      _showSuccess('Device names updated');
      _loadDeviceConfig();
    } else {
      _showError('Failed to update device names');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
```

---

## 5. Create Device Control Widget

### File: lib/widgets/device_control_widget.dart

```dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DeviceControlWidget extends StatefulWidget {
  const DeviceControlWidget({super.key});

  @override
  State<DeviceControlWidget> createState() => _DeviceControlWidgetState();
}

class _DeviceControlWidgetState extends State<DeviceControlWidget> {
  List<Map<String, dynamic>> relayStatus = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRelayStatus();
  }

  Future<void> _loadRelayStatus() async {
    setState(() => isLoading = true);
    
    try {
      final statusList = await ApiService.getAllRelayStatus();
      if (mounted) {
        setState(() {
          relayStatus = statusList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _toggleRelay(int relayNumber, bool currentState) async {
    final action = currentState ? 'off' : 'on';
    final success = currentState 
      ? await ApiService.turnRelayOff(relayNumber)
      : await ApiService.turnRelayOn(relayNumber);
    
    if (success) {
      _loadRelayStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Text('Device Control', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ...relayStatus.map((relay) {
          return Card(
            child: ListTile(
              title: Text('Relay ${relay['relay_number']}'),
              subtitle: Text(relay['is_on'] ? 'ON' : 'OFF'),
              trailing: Switch(
                value: relay['is_on'] ?? false,
                onChanged: (value) {
                  _toggleRelay(relay['relay_number'], relay['is_on']);
                },
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}
```

---

## 6. Update ESP32 Service

### File: lib/services/esp32_service.dart

Make sure userId is included in all API calls:

```dart
static Future<Map<String, dynamic>?> fetchLatestData() async {
  try {
    if (ApiService.userId == null) {
      debugPrint('❌ User not authenticated');
      return null;
    }

    final response = await ApiService.get('/esp32/latest/${ApiService.userId}');
    
    if (response['success'] == true && response['reading'] != null) {
      return response['reading'];
    }
    return null;
  } catch (e) {
    debugPrint('❌ Error fetching ESP32 data: $e');
    return null;
  }
}

static Future<List<Map<String, dynamic>>> fetchReadings({int limit = 100}) async {
  try {
    if (ApiService.userId == null) {
      debugPrint('❌ User not authenticated');
      return [];
    }

    final response = await ApiService.get('/esp32/readings/${ApiService.userId}?limit=$limit');
    
    if (response['success'] == true && response['readings'] is List) {
      return List<Map<String, dynamic>>.from(response['readings']);
    }
    return [];
  } catch (e) {
    debugPrint('❌ Error fetching readings: $e');
    return [];
  }
}
```

---

## 7. Socket.io Integration (Optional but Recommended)

### In your socket service or dashboard screen:

```dart
// On app startup or after login
socket.emit('user_login', {
  'userId': ApiService.userId,
  'username': username,
});

// Listen to relay status updates
socket.on('relay_status_updated', (data) {
  setState(() {
    // Update relay status UI
  });
});

// Listen to live data
socket.on('live_data_update', (data) {
  setState(() {
    // Update sensor data UI
  });
});
```

---

## KEY CHANGES SUMMARY

| Screen | Change | Impact |
|--------|--------|--------|
| Dashboard | Remove RelayControlWidget | Cleaner UI, focuses on data display |
| Devices | Add relay control | Single source for device management |
| Login/Register | Store userId | Enable user data isolation |
| Main | Initialize userId | Auto-login functionality |
| API Service | Include userId in all calls | User data isolation |

---

## TESTING CHECKLIST

- [ ] Register with unique username, email, consumer_number
- [ ] Login and verify userId is stored
- [ ] Navigate to dashboard and see live data
- [ ] Go to devices screen and control relays
- [ ] Update device names
- [ ] Logout and login as different user
- [ ] Verify different user sees different data
- [ ] Check relay toggles work correctly
- [ ] Verify no other user's data is visible

---

## COMMON ISSUES & FIXES

### Issue: "User not authenticated" error
**Solution**: Make sure ApiService.setUserId() is called after login

### Issue: Device control endpoints return 400
**Solution**: Check that userId is being sent in request body or x-user-id header

### Issue: Multiple users seeing same data
**Solution**: Verify API queries include `WHERE user_id = $1`

### Issue: Relay status not updating
**Solution**: Make sure to refresh status after toggle action

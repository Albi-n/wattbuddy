# Exact Code Changes Needed - Copy & Paste Ready

## 1. lib/screens/login_register.dart

### Change 1: Update loginUserFun() method

Find this line:
```dart
if (success) {
  Navigator.pushReplacementNamed(context, '/dashboard');
}
```

Replace with:
```dart
if (success) {
  // Store userId globally for all API calls
  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString('wattBuddyUser');
  if (userJson != null) {
    try {
      final user = jsonDecode(userJson);
      if (user['id'] != null) {
        ApiService.setUserId(user['id'].toString());
        debugPrint('✅ Global userId set: ${user['id']}');
      }
    } catch (e) {
      debugPrint('❌ Error parsing user data: $e');
    }
  }
  
  if (!mounted) return;
  Navigator.pushReplacementNamed(context, '/dashboard');
}
```

### Change 2: Update registerUser() method

Find this section:
```dart
_showSnack(res['message']);

if (res['message'] == 'Registration successful') {
  showForm(0); // go to login
}
```

Replace with:
```dart
_showSnack(res['message']);

if (res['message'] == 'Registration successful') {
  // Store userId if available in response
  if (res['user'] != null && res['user']['id'] != null) {
    try {
      ApiService.setUserId(res['user']['id'].toString());
      debugPrint('✅ Global userId set: ${res['user']['id']}');
    } catch (e) {
      debugPrint('❌ Error setting userId: $e');
    }
  }
  showForm(0); // go to login
}
```

---

## 2. lib/main.dart

### Change: Add userId restoration in main()

Find:
```dart
void main() {
  runApp(const MyApp());
}
```

Replace with:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Restore userId from SharedPreferences if user was previously logged in
  try {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('wattBuddyUser');
    if (userJson != null) {
      final user = jsonDecode(userJson);
      if (user['id'] != null) {
        ApiService.setUserId(user['id'].toString());
        debugPrint('✅ User ID restored from storage: ${user['id']}');
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error restoring userId: $e');
  }
  
  runApp(const MyApp());
}
```

**Important**: Make sure to import at the top:
```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
```

---

## 3. lib/screens/dashboard_screen.dart

### Change: Remove RelayControlWidget

**Find and DELETE these lines**:
```dart
import '../widgets/relay_control_widget.dart';
```

**Find this section** (around line 250):
```dart
            // RELAY CONTROL WIDGET
            const RelayControlWidget(),
```

**Replace with nothing** (delete both lines)

---

## 4. lib/screens/devices_screen.dart

### Complete Replacement of Device Management Logic

Replace the entire `_loadRelayStatus()` method:

**OLD CODE (delete)**:
```dart
  Future<void> _loadRelayStatus() async {
    try {
      final status = await ApiService.getRelayStatus();
      // ... old code
    } catch (e) {
      debugPrint('Error: $e');
    }
  }
```

**NEW CODE (replace with)**:
```dart
  Future<void> _loadDeviceConfig() async {
    setState(() => isLoading = true);
    
    try {
      final config = await ApiService.getDeviceConfig();
      final statusList = await ApiService.getAllRelayStatus();
      
      if (mounted) {
        setState(() {
          if (config['success'] == true && config['config'] != null) {
            relay1Name = config['config']['relay1_name'] ?? 'Device 1';
            relay2Name = config['config']['relay2_name'] ?? 'Device 2';
          }
          if (statusList.isNotEmpty) {
            relay1Status = statusList.firstWhere(
              (r) => r['relay_number'] == 1,
              orElse: () => {'relay_number': 1, 'is_on': false}
            )['is_on'] ?? false;
            
            relay2Status = statusList.firstWhere(
              (r) => r['relay_number'] == 2,
              orElse: () => {'relay_number': 2, 'is_on': false}
            )['is_on'] ?? false;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Failed to load device config: $e');
      }
      debugPrint('❌ Error loading device config: $e');
    }
  }
```

### Replace initState()

**OLD CODE**:
```dart
  @override
  void initState() {
    super.initState();
    _loadDeviceNames();
    _loadRelayStatus();
    // Auto-refresh every 15 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 15), (_) {
      _loadRelayStatus();
    });
  }
```

**NEW CODE**:
```dart
  @override
  void initState() {
    super.initState();
    _loadDeviceConfig();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 10), (_) {
      _loadDeviceConfig();
    });
  }
```

### Add New Toggle Method

Add this new method for relay control:

```dart
  Future<void> _toggleRelayWithConfirmation(int relayNumber) async {
    final relayName = relayNumber == 1 ? relay1Name : relay2Name;
    final currentState = relayNumber == 1 ? relay1Status : relay2Status;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Toggle $relayName'),
        content: Text('Turn $relayName ${currentState ? 'OFF' : 'ON'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isControlling = true);
      
      final success = await ApiService.toggleRelay(relayNumber);
      
      setState(() => isControlling = false);
      
      if (success) {
        _showSuccessSnackBar('$relayName toggled successfully');
        _loadDeviceConfig(); // Refresh status
      } else {
        _showErrorSnackBar('Failed to toggle $relayName');
      }
    }
  }
```

### Update UI Build Methods

In your build method where you have relay toggle buttons, change:
```dart
onPressed: () async {
  // old code
}
```

To:
```dart
onPressed: isControlling ? null : () => _toggleRelayWithConfirmation(1),
```

---

## 5. lib/widgets/device_control_widget.dart (NEW FILE)

**Create this NEW file** with this content:

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
  Map<String, dynamic>? deviceConfig;
  bool isLoading = false;
  bool isControlling = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceConfig();
  }

  Future<void> _loadDeviceConfig() async {
    setState(() => isLoading = true);
    
    try {
      final config = await ApiService.getDeviceConfig();
      final statusList = await ApiService.getAllRelayStatus();
      
      if (mounted) {
        setState(() {
          if (config['success'] == true) {
            deviceConfig = config['config'];
          }
          relayStatus = statusList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        debugPrint('❌ Error loading device config: $e');
      }
    }
  }

  Future<void> _toggleRelay(int relayNumber) async {
    setState(() => isControlling = true);
    
    try {
      final success = await ApiService.toggleRelay(relayNumber);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Relay $relayNumber toggled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadDeviceConfig();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to toggle relay'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isControlling = false);
    }
  }

  String _getRelayName(int relayNumber) {
    if (deviceConfig == null) return 'Device $relayNumber';
    if (relayNumber == 1) {
      return deviceConfig!['relay1_name'] ?? 'Device 1';
    } else {
      return deviceConfig!['relay2_name'] ?? 'Device 2';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Device Control',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (relayStatus.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No devices configured'),
          )
        else
          ...relayStatus.map((relay) {
            final relayNum = relay['relay_number'] ?? 0;
            final isOn = relay['is_on'] ?? false;
            final lastToggled = relay['last_toggled_at'] ?? '';
            final name = _getRelayName(relayNum);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(name),
                subtitle: Text(isOn ? 'ON' : 'OFF'),
                trailing: Switch(
                  value: isOn,
                  onChanged: isControlling
                    ? null
                    : (_) => _toggleRelay(relayNum),
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

## 6. lib/services/esp32_service.dart

### Update fetchLatestData() method

Find:
```dart
static Future<Map<String, dynamic>?> fetchLatestData() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/esp32/live'),
      // ...
    );
```

Replace with:
```dart
static Future<Map<String, dynamic>?> fetchLatestData() async {
  try {
    if (ApiService.userId == null) {
      debugPrint('❌ User not authenticated');
      return null;
    }

    final response = await http.get(
      Uri.parse('$baseUrl/esp32/latest/${ApiService.userId}'),
      headers: {'Content-Type': 'application/json'},
    );
```

### Update getReadingHistory() method (if exists)

Replace endpoint with:
```dart
Uri.parse('$baseUrl/esp32/readings/${ApiService.userId}?limit=$limit'),
```

---

## 7. lib/main.dart - Add Required Imports

Make sure these imports are at the top:
```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart'; // If not already imported
```

---

## SUMMARY OF FILES TO MODIFY

| File | Action | Lines |
|------|--------|-------|
| lib/screens/login_register.dart | Update 2 methods | ~20 |
| lib/main.dart | Update main() function | ~15 |
| lib/screens/dashboard_screen.dart | Remove 2 lines | 2 |
| lib/screens/devices_screen.dart | Update methods & build | ~50 |
| lib/widgets/device_control_widget.dart | CREATE NEW | ~150 |
| lib/services/esp32_service.dart | Update 2 methods | ~10 |

**Total Changes**: ~250 lines of code  
**Estimated Time**: 1-2 hours

---

## VERIFICATION CHECKLIST

After making all changes:

- [ ] Code compiles without errors
- [ ] No import errors
- [ ] App starts successfully
- [ ] Login works and userId is stored
- [ ] Dashboard loads without RelayControlWidget
- [ ] Devices screen shows relay controls
- [ ] Toggling relay shows confirmation dialog
- [ ] Relay status updates after toggle
- [ ] Multiple users can login and see different data
- [ ] No console errors

---

## TESTING THE COMPLETE FLOW

1. **Build & Run**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Test Registration**:
   - Register new user with unique username
   - Verify success message

3. **Test Login**:
   - Login with created account
   - Verify userId is stored globally
   - Check debug output for "✅ Global userId set"

4. **Test Data Isolation**:
   - Go to Dashboard → see live data
   - Go to Devices → toggle relay
   - Logout and login as different user
   - Verify different user sees different data

5. **Test Device Control**:
   - Toggle relay 1 → should show confirmation dialog
   - Confirm toggle → relay status should update
   - Check database to verify correct user_id in relay_status

---

## DEBUG COMMANDS

Monitor console for these success messages:

```
✅ User ID set: 123
✅ User ID restored from storage: 123
✅ Global userId set: 123
📱 Fetching device config for user 123
🔌 Toggling relay 1 for user 123
✅ Relay 1 toggled successfully
```

If you see errors instead, check:
- Is userId being passed? (`ApiService.userId` should not be null)
- Are API responses successful? (Check response body)
- Is user authenticated? (Should have token in SharedPreferences)

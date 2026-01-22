import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Store userId globally for all API calls
  static String? _userId;

  static String? get userId => _userId;

  static void setUserId(String id) {
    _userId = id;
    debugPrint('✅ User ID set: $id');
  }

  // Use emulator host so Android emulator can reach the local server
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:4000/api';
    }

    if (Platform.isAndroid) {
      // REAL ANDROID PHONE (CPH2001)
      return 'http://172.17.4.170:4000/api';
    }

    // Windows / macOS / Linux
    return 'http://localhost:4000/api';
  }

  // For a real phone on the same Wi-Fi use: http://YOUR_PC_IP:4000/api

  // Connection timeout - increase from 10 to 30 seconds to allow for database operations
  static const Duration connectionTimeout = Duration(seconds: 30);

  // Generic POST request with userId
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      // Add userId if not already in body
      if (_userId != null && !body.containsKey('userId')) {
        body['userId'] = _userId;
      }

      debugPrint('📤 POST $endpoint: $body');
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              if (_userId != null) 'x-user-id': _userId!,
            },
            body: jsonEncode(body),
          )
          .timeout(connectionTimeout);

      debugPrint('📥 Response: ${response.statusCode}');
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('❌ POST Error: $e');
      throw Exception('POST $endpoint failed: $e');
    }
  }

  /// Generic GET request with userId
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      debugPrint('📤 GET $endpoint');
      final response = await http
          .get(
            Uri.parse('$baseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              if (_userId != null) 'x-user-id': _userId!,
            },
          )
          .timeout(connectionTimeout);
      debugPrint('📥 Response: ${response.statusCode}');
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('❌ GET Error: $e');
      throw Exception('GET $endpoint failed: $e');
    }
  }

  // ---------------- REGISTER ----------------
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String consumerNumber,
    required String password,
  }) async {
    try {
      debugPrint('📤 Registering user: $email');
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'email': email,
              'consumer_number': consumerNumber,
              'password': password,
            }),
          )
          .timeout(
            connectionTimeout,
            onTimeout: () {
              throw Exception('Registration request timed out. Make sure the server is running and the database is accessible.');
            },
          );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'message': errorData['message'] ?? 'Registration failed',
          'success': false,
        };
      }
    } on SocketException catch (e) {
      debugPrint('❌ Network error: $e');
      return {
        'message': 'Cannot reach server. Is the backend running on http://10.0.2.2:4000?',
        'success': false,
      };
    }
  }

  // ---------------- LOGIN ----------------
  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📤 Logging in: $email');
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(
            connectionTimeout,
            onTimeout: () {
              throw Exception('Login request timed out. Make sure the server is running and the database is accessible.');
            },
          );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('wattBuddyUser', jsonEncode(data['user']));
        
        // Store userId globally for all subsequent API calls
        if (data['user'] != null && data['user']['id'] != null) {
          setUserId(data['user']['id'].toString());
          debugPrint('✅ Login successful, userId stored');
        }
        return true;
      }

      debugPrint('❌ Login failed: ${data['message']}');
      return false;
    } on SocketException catch (e) {
      debugPrint('❌ Network error: $e');
      return false;
    }
  }

  // ============ RELAY CONTROL ============
  static Future<bool> controlRelay1(bool turnOn) async {
    try {
      final endpoint = turnOn ? '/relay1/on' : '/relay1/off';
      debugPrint('📤 Sending relay 1 command: ${turnOn ? 'ON' : 'OFF'}');
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Relay 1 ${turnOn ? 'ON' : 'OFF'} successful');
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Relay 1 control error: $e');
      return false;
    }
  }

  static Future<bool> controlRelay2(bool turnOn) async {
    try {
      final endpoint = turnOn ? '/relay2/on' : '/relay2/off';
      debugPrint('📤 Sending relay 2 command: ${turnOn ? 'ON' : 'OFF'}');
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Relay 2 ${turnOn ? 'ON' : 'OFF'} successful');
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Relay 2 control error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getRelayStatus() async {
    try {
      debugPrint('📤 Getting relay status');
      final response = await http
          .get(
            Uri.parse('$baseUrl/relay/all'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Got relay status: $data');
        return data;
      }
      return {};
    } catch (e) {
      debugPrint('❌ Get relay status error: $e');
      return {};
    }
  }

  // ============ ESP32 SENSOR ENDPOINTS ============
  
  /// Get current sensor readings from ESP32
  /// Reads: Voltage, Current, Power, Daily/Monthly Energy
  static Future<Map<String, dynamic>> getESP32Sensors() async {
    try {
      debugPrint('📊 Fetching ESP32 sensor readings...');
      
      // Direct connection to ESP32 (local network)
      const String esp32Url = 'http://10.168.130.214:80/sensors';
      
      final response = await http
          .get(
            Uri.parse(esp32Url),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ ESP32 Sensors: $data');
        return {
          'success': true,
          'voltage': data['voltage'] ?? 0.0,
          'current': data['current'] ?? 0.0,
          'power': data['power'] ?? 0.0,
          'relay': data['relay'] ?? false,
          'totalEnergy': data['totalEnergy'] ?? 0.0,
          'dailyEnergy': data['dailyEnergy'] ?? 0.0,
          'monthlyEnergy': data['monthlyEnergy'] ?? 0.0,
          'timestamp': data['timestamp'] ?? 0,
        };
      }
      return {'success': false, 'error': 'ESP32 not responding'};
    } catch (e) {
      debugPrint('❌ ESP32 sensor error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Control ESP32 relay ON
  static Future<bool> turnESP32RelayOn() async {
    try {
      debugPrint('🔌 Turning ESP32 relay ON...');
      const String esp32Url = 'http://10.168.130.214:80/relay/on';
      
      final response = await http
          .post(
            Uri.parse(esp32Url),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ Relay turned ON');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Relay ON error: $e');
      return false;
    }
  }

  /// Control ESP32 relay OFF
  static Future<bool> turnESP32RelayOff() async {
    try {
      debugPrint('🔌 Turning ESP32 relay OFF...');
      const String esp32Url = 'http://10.168.130.214:80/relay/off';
      
      final response = await http
          .post(
            Uri.parse(esp32Url),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ Relay turned OFF');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Relay OFF error: $e');
      return false;
    }
  }

  /// Get ESP32 relay status
  static Future<Map<String, dynamic>> getESP32RelayStatus() async {
    try {
      debugPrint('📊 Fetching ESP32 relay status...');
      const String esp32Url = 'http://10.168.130.214:80/relay/status';
      
      final response = await http
          .get(
            Uri.parse(esp32Url),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'relay': data['relay'] ?? false,
          'voltage': data['voltage'] ?? 0.0,
          'current': data['current'] ?? 0.0,
          'power': data['power'] ?? 0.0,
        };
      }
      return {'success': false};
    } catch (e) {
      debugPrint('❌ ESP32 relay status error: $e');
      return {'success': false};
    }
  }

  /// Set logged-in user on ESP32
  static Future<bool> setESP32User(String userId) async {
    try {
      debugPrint('👤 Setting ESP32 user: $userId');
      final String esp32Url = 'http://10.168.130.214:80/user/set?userId=$userId';
      
      final response = await http
          .post(
            Uri.parse(esp32Url),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ ESP32 user set to: $userId');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Set ESP32 user error: $e');
      return false;
    }
  }

  /// Get energy data from ESP32
  static Future<Map<String, dynamic>> getESP32Energy() async {
    try {
      debugPrint('⚡ Fetching ESP32 energy data...');
      const String esp32Url = 'http://10.168.130.214:80/energy';
      
      final response = await http
          .get(
            Uri.parse(esp32Url),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'totalEnergy': data['totalEnergy'] ?? 0.0,
          'dailyEnergy': data['dailyEnergy'] ?? 0.0,
          'monthlyEnergy': data['monthlyEnergy'] ?? 0.0,
        };
      }
      return {'success': false};
    } catch (e) {
      debugPrint('❌ ESP32 energy error: $e');
      return {'success': false};
    }
  }

  // ============ DEVICE CONTROL ENDPOINTS ============
  /// Get device configuration for logged-in user
  static Future<Map<String, dynamic>> getDeviceConfig() async {
    try {
      if (_userId == null) throw Exception('User not authenticated');
      
      debugPrint('📱 Fetching device config for user $_userId');
      final response = await get('/devices/config/$_userId');
      return response;
    } catch (e) {
      debugPrint('❌ Get device config error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update device names
  static Future<bool> updateDeviceNames(String relay1Name, String relay2Name) async {
    try {
      if (_userId == null) throw Exception('User not authenticated');
      
      debugPrint('📝 Updating device names: Relay1=$relay1Name, Relay2=$relay2Name');
      final response = await post('/devices/config', {
        'userId': _userId,
        'relay1Name': relay1Name,
        'relay2Name': relay2Name,
      });

      return response['success'] ?? false;
    } catch (e) {
      debugPrint('❌ Update device names error: $e');
      return false;
    }
  }

  /// Get all relay status for user
  static Future<List<Map<String, dynamic>>> getAllRelayStatus() async {
    try {
      if (_userId == null) throw Exception('User not authenticated');
      
      debugPrint('🔌 Fetching all relay status for user $_userId');
      final response = await get('/devices/relay/status/$_userId');
      
      if (response['success'] == true && response['relayStatus'] is List) {
        return List<Map<String, dynamic>>.from(response['relayStatus']);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Get relay status error: $e');
      return [];
    }
  }

  /// Get specific relay status
  static Future<Map<String, dynamic>> getRelayStatusForRelay(int relayNumber) async {
    try {
      if (_userId == null) throw Exception('User not authenticated');
      
      debugPrint('🔌 Fetching relay $relayNumber status for user $_userId');
      final response = await get('/devices/relay/status/$_userId/$relayNumber');
      return response;
    } catch (e) {
      debugPrint('❌ Get relay $relayNumber status error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Toggle specific relay
  static Future<bool> toggleRelay(int relayNumber) async {
    try {
      if (_userId == null) throw Exception('User not authenticated');
      
      debugPrint('🔌 Toggling relay $relayNumber for user $_userId');
      final response = await post('/devices/relay/toggle', {
        'userId': _userId,
        'relayNumber': relayNumber,
      });

      return response['success'] ?? false;
    } catch (e) {
      debugPrint('❌ Toggle relay $relayNumber error: $e');
      return false;
    }
  }

  /// Turn relay ON
  static Future<bool> turnRelayOn(int relayNumber) async {
    try {
      if (_userId == null) throw Exception('User not authenticated');
      
      debugPrint('🔌 Turning relay $relayNumber ON for user $_userId');
      final response = await post('/devices/relay/on', {
        'userId': _userId,
        'relayNumber': relayNumber,
      });

      return response['success'] ?? false;
    } catch (e) {
      debugPrint('❌ Turn relay $relayNumber ON error: $e');
      return false;
    }
  }

  /// Turn relay OFF
  static Future<bool> turnRelayOff(int relayNumber) async {
    try {
      if (_userId == null) throw Exception('User not authenticated');
      
      debugPrint('🔌 Turning relay $relayNumber OFF for user $_userId');
      final response = await post('/devices/relay/off', {
        'userId': _userId,
        'relayNumber': relayNumber,
      });

      return response['success'] ?? false;
    } catch (e) {
      debugPrint('❌ Turn relay $relayNumber OFF error: $e');
      return false;
    }
  }

  /// Get device control history
  static Future<List<Map<String, dynamic>>> getDeviceControlHistory({int limit = 50}) async {
    try {
      if (_userId == null) throw Exception('User not authenticated');
      
      debugPrint('📋 Fetching device control history for user $_userId');
      final response = await get('/devices/history/$_userId?limit=$limit');
      
      if (response['success'] == true && response['history'] is List) {
        return List<Map<String, dynamic>>.from(response['history']);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Get device control history error: $e');
      return [];
    }
  }

}


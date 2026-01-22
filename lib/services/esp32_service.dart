import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Esp32Service {
  // Backend server - use localhost for web, your PC IP for mobile
  static const String serverUrl = 'http://localhost:4000';
  
  /// Get userId from SharedPreferences
  static Future<String> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('wattBuddyUser');
      if (userData != null) {
        final data = jsonDecode(userData);
        // Convert int to String if needed
        final id = data['id'];
        return (id is int) ? id.toString() : (id ?? 'default_user');
      }
    } catch (e) {
      debugPrint('❌ Error getting userId: $e');
    }
    return 'default_user';
  }

  /// Fetch live sensor data from ESP32 through backend proxy
  static Future<Map<String, dynamic>?> fetchLiveData() async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/esp32/live'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Live ESP32 Data via Backend: $data');
        return data;
      }
    } catch (e) {
      debugPrint('❌ Live ESP32 fetch error: $e');
    }
    return null;
  }

  /// Fetch latest sensor data from backend server
  static Future<Map<String, dynamic>?> fetchLatestData() async {
    try {
      final userId = await _getUserId();
      if (userId == 'default_user') {
        debugPrint('⚠️ User not authenticated, cannot fetch ESP32 data');
        return null;
      }
      final response = await http.get(
        Uri.parse('$serverUrl/api/esp32/latest/$userId'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Latest ESP32 Data for user $userId: $data');
        return data;
      }
    } catch (e) {
      debugPrint('❌ Backend ESP32 fetch error: $e');
    }
    return null;
  }

  /// Fetch last 60 power readings for chart
  static Future<List<PowerReadingModel>?> fetchHistoryData() async {
    try {
      final userId = await _getUserId();
      if (userId == 'default_user') {
        debugPrint('⚠️ User not authenticated, cannot fetch history');
        return null;
      }
      final response = await http.get(
        Uri.parse('$serverUrl/api/esp32/readings/$userId'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('readings')) {
          final readings = (data['readings'] as List)
              .map((e) => PowerReadingModel.fromJson(e))
              .toList();
          debugPrint('✅ Fetched ${readings.length} readings for user $userId');
          return readings;
        }
      }
    } catch (e) {
      debugPrint('❌ History fetch error: $e');
    }
    return null;
  }

  /// Post reading to backend server
  static Future<bool> postReading(Map<String, dynamic> reading) async {
    try {
      final userId = await _getUserId();
      final response = await http.post(
        Uri.parse('$serverUrl/api/esp32/reading'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          ...reading
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('✅ Reading posted to server');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Post reading error: $e');
    }
    return false;
  }

  /// Stream real-time data every 2 seconds via backend
  static Stream<Map<String, dynamic>> streamRealtimeData() async* {
    while (true) {
      try {
        final data = await fetchLiveData();
        if (data != null) {
          yield data;
        }
      } catch (e) {
        debugPrint('❌ Stream error: $e');
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Control Relay - Through Backend
  static Future<bool> controlRelay(String relay, String action) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/esp32/relay/$relay/$action'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ $relay turned $action');
        return true;
      } else if (response.statusCode == 503) {
        debugPrint('⚠️ ESP32 currently unreachable');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Relay control error: $e');
    }
    return false;
  }

  /// Control Relay 1 - ON
  static Future<bool> controlRelay1On() async {
    return await controlRelay('relay1', 'on');
  }

  /// Control Relay 1 - OFF
  static Future<bool> controlRelay1Off() async {
    return await controlRelay('relay1', 'off');
  }

  /// Control Relay 2 - ON
  static Future<bool> controlRelay2On() async {
    return await controlRelay('relay2', 'on');
  }

  /// Control Relay 2 - OFF
  static Future<bool> controlRelay2Off() async {
    return await controlRelay('relay2', 'off');
  }

  /// Get relay status
  static Future<Map<String, bool>?> getRelayStatus() async {
    try {
      final data = await fetchLiveData();
      if (data != null) {
        return {
          'relay1': data['relay1'] ?? false,
          'relay2': data['relay2'] ?? false,
        };
      }
    } catch (e) {
      debugPrint('❌ Get relay status error: $e');
    }
    return null;
  }
}

/// Model for power readings
class PowerReadingModel {
  final double power;
  final double voltage;
  final double current;
  final int timestamp;

  PowerReadingModel({
    required this.power,
    required this.voltage,
    required this.current,
    required this.timestamp,
  });

  factory PowerReadingModel.fromJson(Map<String, dynamic> json) {
    return PowerReadingModel(
      power: (json['power'] as num?)?.toDouble() ?? 0.0,
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'power': power,
      'voltage': voltage,
      'current': current,
      'timestamp': timestamp,
    };
  }
}

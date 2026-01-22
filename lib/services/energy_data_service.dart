import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EnergyDataService {
  static const String baseUrl = 'http://localhost:4000';

  /// Get userId from SharedPreferences
  static Future<String> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('wattBuddyUser');
      if (userData != null) {
        final data = jsonDecode(userData);
        final id = data['id'];
        return (id is int) ? id.toString() : (id ?? 'default_user');
      }
    } catch (e) {
      debugPrint('❌ Error getting userId: $e');
    }
    return 'default_user';
  }

  /// Store ESP32 reading to database
  static Future<bool> storeReading({
    required double voltage,
    required double current,
    required double power,
    required double energy,
    double powerFactor = 0.95,
    double frequency = 50.0,
    double temperature = 25.0,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == 'default_user') {
        debugPrint('⚠️ User not authenticated, cannot store reading');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/esp32/data'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId,
        },
        body: jsonEncode({
          'userId': userId,
          'voltage': voltage,
          'current': current,
          'power': power,
          'energy': energy,
          'pf': powerFactor,
          'frequency': frequency,
          'temperature': temperature,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ ESP32 reading stored successfully');
        return true;
      } else {
        debugPrint('❌ Failed to store reading: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error storing reading: $e');
      return false;
    }
  }

  /// Check for anomalies in power usage
  static Future<Map<String, dynamic>?> checkAnomalies({
    required double voltage,
    required double current,
    required double power,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == 'default_user') {
        debugPrint('⚠️ User not authenticated, cannot check anomalies');
        return null;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/anomaly/check'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': userId,
        },
        body: jsonEncode({
          'userId': userId,
          'voltage': voltage,
          'current': current,
          'power': power,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['hasAnomalies'] == true) {
          debugPrint('🚨 Anomalies detected: ${data['anomalies']}');
        }
        return data;
      }
    } catch (e) {
      debugPrint('❌ Anomaly check error: $e');
    }
    return null;
  }
}

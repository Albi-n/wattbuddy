import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 🔴 Using PC IP address - works with USB debugging
  static const String baseUrl = 'http://172.17.1.150:4000/api/auth';
  // For WiFi on real phone use: http://YOUR_PC_IP:4000/api/auth

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
            Uri.parse('$baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'email': email,
              'consumer_number': consumerNumber,
              'password': password,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Registration request timed out');
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
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      return {'message': 'Error: $e', 'success': false};
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
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Login request timed out');
            },
          );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('wattBuddyUser', jsonEncode(data['user']));
        debugPrint('✅ Login successful');
        return true;
      }

      debugPrint('❌ Login failed: ${data['message']}');
      return false;
    } catch (e) {
      debugPrint('❌ Login error: $e');
      return false;
    }
  }
}

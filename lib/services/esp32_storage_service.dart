import 'api_service.dart';

class ESP32StorageService {
  // 🗄 Store ESP32 reading in PostgreSQL
  static Future<bool> storeReading({
    required String userId,
    required double power,
    required double voltage,
    required double current,
    required double energy,
    required double pf,
    required double frequency,
    required double temperature,
  }) async {
    try {
      final response = await ApiService.post(
        '/esp32/data',
        {
          'userId': userId,
          'power': power,
          'voltage': voltage,
          'current': current,
          'energy': energy,
          'pf': pf,
          'frequency': frequency,
          'temperature': temperature,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      print('✅ ESP32 data stored successfully');
      return response['success'] == true;
    } catch (e) {
      print('❌ Error storing ESP32 data: $e');
      return false;
    }
  }

  // Get latest stored readings
  static Future<List<Map<String, dynamic>>?> getLatestReadings(
    String userId, {
    int limit = 100,
  }) async {
    try {
      final response = await ApiService.get(
        '/esp32/latest/$userId?limit=$limit',
      );

      if (response['success'] == true && response['readings'] != null) {
        return List<Map<String, dynamic>>.from(response['readings']);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching readings: $e');
      return null;
    }
  }

  // Get daily stats
  static Future<Map<String, dynamic>?> getDailyStats(
    String userId, {
    String? date,
  }) async {
    try {
      final dateParam = date ?? DateTime.now().toString().split(' ')[0];
      final response = await ApiService.get(
        '/esp32/stats/$userId?date=$dateParam',
      );

      if (response['success'] == true && response['stats'] != null) {
        return Map<String, dynamic>.from(response['stats']);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching daily stats: $e');
      return null;
    }
  }

  // Get hourly statistics
  static Future<List<Map<String, dynamic>>?> getHourlyStats(
    String userId, {
    String? date,
  }) async {
    try {
      final dateParam = date ?? DateTime.now().toString().split(' ')[0];
      final response = await ApiService.get(
        '/esp32/hourly/$userId?date=$dateParam',
      );

      if (response['success'] == true && response['hourly'] != null) {
        return List<Map<String, dynamic>>.from(response['hourly']);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching hourly stats: $e');
      return null;
    }
  }
}

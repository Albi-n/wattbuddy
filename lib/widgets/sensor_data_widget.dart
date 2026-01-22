import 'dart:async';
import 'package:flutter/material.dart';
import '../services/esp32_service.dart';

class SensorDataWidget extends StatefulWidget {
  const SensorDataWidget({super.key});

  @override
  State<SensorDataWidget> createState() => _SensorDataWidgetState();
}

class _SensorDataWidgetState extends State<SensorDataWidget> {
  double voltage = 0.0;
  double current = 0.0;
  double power = 0.0;
  double energyKwh = 0.0;
  double cost = 0.0;
  bool isLoading = true;
  Timer? _refreshTimer;
  String lastUpdated = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadSensorData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadSensorData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSensorData() async {
    if (!mounted) return;
    try {
      final data = await Esp32Service.fetchLiveData();
      if (!mounted || data == null) return;

      setState(() {
        voltage = (data['voltage'] as num?)?.toDouble() ?? 0.0;
        current = (data['current'] as num?)?.toDouble() ?? 0.0;
        power = (data['power'] as num?)?.toDouble() ?? 0.0;
        energyKwh = (data['energy_kwh'] as num?)?.toDouble() ?? 0.0;
        cost = (data['cost'] as num?)?.toDouble() ?? 0.0;
        isLoading = false;
        
        final now = DateTime.now();
        lastUpdated =
            '${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      });
    } catch (e) {
      debugPrint('❌ Error loading sensor data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: const Color(0xFF1a1a3a),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📊 Sensor Readings',
                style: TextStyle(
                  color: Color(0xFF00d4ff),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isLoading)
                Text(
                  lastUpdated,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (isLoading)
            Center(
              child: Container(
                height: 150,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00d4ff),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Connecting to ESP32...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                _buildSensorCard(
                  icon: '⚡',
                  label: 'Voltage',
                  value: '${voltage.toStringAsFixed(2)} V',
                  color: const Color(0xFF00d4ff),
                ),
                const SizedBox(height: 12),
                _buildSensorCard(
                  icon: '🔌',
                  label: 'Current',
                  value: '${current.toStringAsFixed(3)} A',
                  color: const Color(0xFF00d4ff),
                ),
                const SizedBox(height: 12),
                _buildSensorCard(
                  icon: '⚙️',
                  label: 'Power',
                  value: '${power.toStringAsFixed(1)} W',
                  color: const Color(0xFF00d4ff),
                ),
                const SizedBox(height: 12),
                _buildSensorCard(
                  icon: '💡',
                  label: 'Energy Consumed',
                  value: '${energyKwh.toStringAsFixed(3)} kWh',
                  color: const Color(0xFF00d4ff),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0a0a2a),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF28a745),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '💰 Current Bill:',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${cost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF28a745),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSensorCard({
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0a0a2a),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

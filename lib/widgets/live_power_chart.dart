import 'dart:async';
import 'package:flutter/material.dart';
import '../services/esp32_service.dart';

class LivePowerChart extends StatefulWidget {
  const LivePowerChart({super.key});

  @override
  State<LivePowerChart> createState() => _LivePowerChartState();
}

class _LivePowerChartState extends State<LivePowerChart> {
  List<PowerReadingModel> readings = [];
  Timer? _refreshTimer;
  double maxPower = 100;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadHistoryData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHistoryData() async {
    if (!mounted) return;
    try {
      final data = await Esp32Service.fetchHistoryData();
      if (!mounted) return;
      if (data != null && data.isNotEmpty) {
        setState(() {
          readings = data;
          maxPower = (readings.isEmpty
              ? 100
              : readings.map((r) => r.power).reduce((a, b) => a > b ? a : b));
          maxPower = (maxPower * 1.2).toInt().toDouble();
          if (maxPower < 100) maxPower = 100;
        });
      }
    } catch (e) {
      debugPrint('❌ Chart error: $e');
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
                '⚡ Live Power Usage',
                style: TextStyle(
                  color: Color(0xFF00d4ff),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (readings.isNotEmpty)
                Text(
                  'Current: ${readings.last.power.toStringAsFixed(1)}W',
                  style: const TextStyle(
                    color: Color(0xFF00d4ff),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (readings.isEmpty)
            Center(
              child: Container(
                height: 200,
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
                      'Loading chart data...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 250,
              child: Container(
                color: const Color(0xFF0a0a2a).withValues(alpha: 0.5),
                child: const Center(
                  child: Text(
                    'Chart temporarily disabled\nfor build fix',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF00d4ff),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          if (readings.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0a0a2a),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Peak',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${readings.map((r) => r.power).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}W',
                        style: const TextStyle(
                          color: Color(0xFF00d4ff),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'Avg',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${(readings.map((r) => r.power).reduce((a, b) => a + b) / readings.length).toStringAsFixed(1)}W',
                        style: const TextStyle(
                          color: Color(0xFF00d4ff),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        'Min',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${readings.map((r) => r.power).reduce((a, b) => a < b ? a : b).toStringAsFixed(1)}W',
                        style: const TextStyle(
                          color: Color(0xFF00d4ff),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

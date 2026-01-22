import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/esp32_service.dart';

class RealtimePowerChart extends StatefulWidget {
  const RealtimePowerChart({super.key});

  @override
  State<RealtimePowerChart> createState() => _RealtimePowerChartState();
}

class _RealtimePowerChartState extends State<RealtimePowerChart> {
  final List<FlSpot> powerSpots = [];
  Timer? _fetchTimer;
  double maxPower = 100;
  double avgPower = 0;
  double currentPower = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRealTimeData();
    _fetchTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _fetchRealTimeData(),
    );
  }

  @override
  void dispose() {
    _fetchTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRealTimeData() async {
    if (!mounted) return;
    try {
      final data = await Esp32Service.fetchLiveData();
      if (!mounted || data == null) return;

      setState(() {
        currentPower = (data['power'] as num?)?.toDouble() ?? 0.0;
        
        // Add new data point
        if (powerSpots.length >= 60) {
          powerSpots.removeAt(0);
        }
        powerSpots.add(FlSpot(
          powerSpots.isEmpty ? 0 : powerSpots.last.x + 1,
          currentPower,
        ));

        // Calculate max and average
        if (powerSpots.isNotEmpty) {
          maxPower = powerSpots.map((p) => p.y).reduce((a, b) => a > b ? a : b);
          maxPower = (maxPower * 1.2).toInt().toDouble();
          if (maxPower < 100) maxPower = 100;
          
          avgPower = powerSpots.map((p) => p.y).reduce((a, b) => a + b) / powerSpots.length;
        }
        
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Real-time chart error: $e');
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
                '⚡ Live Power Usage',
                style: TextStyle(
                  color: Color(0xFF00d4ff),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isLoading)
                Text(
                  'Now: ${currentPower.toStringAsFixed(1)}W',
                  style: const TextStyle(
                    color: Color(0xFF00d4ff),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (isLoading)
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
                      'Connecting to ESP32...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: powerSpots.isEmpty ? 10 : powerSpots.last.x.toDouble(),
                  minY: 0,
                  maxY: maxPower,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}W',
                            style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 10,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: powerSpots,
                      isCurved: true,
                      color: const Color(0xFF00d4ff),
                      barWidth: 2,
                      dotData: FlDotData(
                        show: powerSpots.length < 20,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: const Color(0xFF00d4ff),
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF00d4ff).withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!isLoading && powerSpots.isNotEmpty) ...[
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
                        '${powerSpots.map((p) => p.y).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}W',
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
                        '${avgPower.toStringAsFixed(1)}W',
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
                        '${powerSpots.map((p) => p.y).reduce((a, b) => a < b ? a : b).toStringAsFixed(1)}W',
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

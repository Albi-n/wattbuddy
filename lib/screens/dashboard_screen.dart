import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../utils/responsive_scaffold.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String username = "User";
  String userEmail = "user@example.com";
  String consumerNumber = "N/A";

  // ---------------- ESP32 DATA ----------------
  Map<String, dynamic>? esp32Data;
  Timer? _refreshTimer;
  
  // ---------------- STATIC DATA (UNCHANGED) ----------------
  final List<double> monthlyUsage = [110, 130, 145, 140, 155, 135, 124];
  final List<String> months = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'];



  // ---------------- INIT ----------------
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadEsp32Data();

    _refreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _loadEsp32Data());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ---------------- LOAD USER ----------------
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUser = prefs.getString('wattBuddyUser');
    if (storedUser != null) {
      final user = jsonDecode(storedUser);
      setState(() {
        username = user['username'] ?? 'User';
        userEmail = user['email'] ?? 'user@example.com';
        consumerNumber = user['consumer_number'] ?? 'N/A';
      });
    }
  }

  // ---------------- LOAD ESP32 DATA ----------------
  Future<void> _loadEsp32Data() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.233.214:4000/api/esp32/latest'),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        setState(() {
          esp32Data = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('❌ ESP32 fetch error: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentRoute: '/dashboard',
      body: RefreshIndicator(
        onRefresh: _loadEsp32Data,
        color: Colors.cyanAccent,
        backgroundColor: const Color(0xFF1A1A3A),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER with Refresh Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Dashboard",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.cyanAccent, width: 1),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.cyanAccent, size: 28),
                      onPressed: _loadEsp32Data,
                      tooltip: 'Pull down to refresh or tap here',
                      iconSize: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Welcome back, $username! Here's your energy overview.",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
            
            // USER DETAILS CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.cyanAccent,
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0A0A2A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Consumer #: $consumerNumber',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // METRIC CARDS (LIVE DATA)
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 4;
                if (constraints.maxWidth < 1200) crossAxisCount = 2;
                if (constraints.maxWidth < 600) crossAxisCount = 1;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio:
                      MediaQuery.of(context).size.width < 600 ? 3.0 : 3.8,
                  children: [
                    _metricCard(
                      "Current Power",
                      esp32Data?['power']?.toStringAsFixed(1) ?? '2.45',
                      "W",
                      Icons.flash_on,
                    ),
                    _metricCard(
                      "Voltage",
                      esp32Data?['voltage']?.toString() ?? '230',
                      "V",
                      Icons.electric_bolt,
                    ),
                    _metricCard(
                      "Current",
                      esp32Data?['current']?.toString() ?? '1.2',
                      "A",
                      Icons.trending_up,
                    ),
                    _metricCard(
                      "Energy Used",
                      esp32Data?['energy']?.toString() ?? '125.5',
                      "kWh",
                      Icons.battery_charging_full,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            // CHART + LIVE DATA
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [
                      _usageChart(),
                      const SizedBox(height: 20),
                      _liveDataCard(),
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _usageChart()),
                      const SizedBox(width: 20),
                      Expanded(child: _liveDataCard()),
                    ],
                  );
                }
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 28),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                "$value $unit",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------ CHART (UNCHANGED) ------------------
  Widget _usageChart() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Monthly Usage (kWh)",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: isMobile ? 200 : 260,
            child: LineChart(
              LineChartData(
                minY: 100,
                maxY: 160,
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        if (value.toInt() < months.length) {
                          return Text(
                            months[value.toInt()],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: monthlyUsage
                        .asMap()
                        .entries
                        .map(
                          (e) => FlSpot(e.key.toDouble(), e.value),
                        )
                        .toList(),
                    isCurved: true,
                    color: Colors.cyanAccent,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.cyan.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== LIVE ESP32 DATA CARD ====================
  Widget _liveDataCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📊 Live Data",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (esp32Data != null && esp32Data!.isNotEmpty)
            Column(
              children: [
                _buildLiveMetricRow(
                  "⚡ Voltage",
                  "${(esp32Data!['voltage'] ?? 0).toStringAsFixed(1)} V",
                  Colors.cyanAccent,
                ),
                const SizedBox(height: 12),
                _buildLiveMetricRow(
                  "🔌 Current",
                  "${(esp32Data!['current'] ?? 0).toStringAsFixed(2)} A",
                  Colors.greenAccent,
                ),
                const SizedBox(height: 12),
                _buildLiveMetricRow(
                  "⚙️ Power",
                  "${(esp32Data!['power'] ?? 0).toStringAsFixed(1)} W",
                  Colors.orangeAccent,
                ),
                const SizedBox(height: 12),
                _buildLiveMetricRow(
                  "📈 Daily Energy",
                  "${(esp32Data!['daily_energy'] ?? 0).toStringAsFixed(2)} kWh",
                  Colors.blueAccent,
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: const Center(
                child: Text(
                  "Waiting for ESP32 data...",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}



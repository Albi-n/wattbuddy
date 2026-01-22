import 'dart:async';
import 'package:flutter/material.dart';
import '../services/esp32_service.dart';

class RelayControlWidget extends StatefulWidget {
  const RelayControlWidget({super.key});

  @override
  State<RelayControlWidget> createState() => _RelayControlWidgetState();
}

class _RelayControlWidgetState extends State<RelayControlWidget> {
  bool relay1_on = false;
  bool relay2_on = false;
  bool isLoading = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadRelayStatus();
    // Refresh relay status every 5 seconds
    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadRelayStatus(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRelayStatus() async {
    if (!mounted) return;
    try {
      final status = await Esp32Service.getRelayStatus();
      if (!mounted || status == null) return;
      setState(() {
        relay1_on = status['relay1'] ?? false;
        relay2_on = status['relay2'] ?? false;
      });
    } catch (e) {
      debugPrint('❌ Error loading relay status: $e');
    }
  }

  Future<void> _toggleRelay1() async {
    setState(() => isLoading = true);
    try {
      final success = relay1_on
          ? await Esp32Service.controlRelay1Off()
          : await Esp32Service.controlRelay1On();

      if (success && mounted) {
        setState(() => relay1_on = !relay1_on);
        _showNotification('Relay 1 ${relay1_on ? 'turned ON' : 'turned OFF'}');
      } else if (mounted) {
        _showNotification('Failed to control Relay 1', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showNotification('Error: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleRelay2() async {
    setState(() => isLoading = true);
    try {
      final success = relay2_on
          ? await Esp32Service.controlRelay2Off()
          : await Esp32Service.controlRelay2On();

      if (success && mounted) {
        setState(() => relay2_on = !relay2_on);
        _showNotification('Relay 2 ${relay2_on ? 'turned ON' : 'turned OFF'}');
      } else if (mounted) {
        _showNotification('Failed to control Relay 2', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showNotification('Error: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showNotification(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
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
          const Text(
            '🔌 Smart Relay Control',
            style: TextStyle(
              color: Color(0xFF00d4ff),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRelayButton(
                label: 'Relay 1',
                isOn: relay1_on,
                onPressed: isLoading ? null : _toggleRelay1,
              ),
              _buildRelayButton(
                label: 'Relay 2',
                isOn: relay2_on,
                onPressed: isLoading ? null : _toggleRelay2,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0a0a2a),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Relay 1',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      relay1_on ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: relay1_on ? Colors.green : Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: const Color(0xFF2a2a4a),
                ),
                Column(
                  children: [
                    Text(
                      'Relay 2',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      relay2_on ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: relay2_on ? Colors.green : Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelayButton({
    required String label,
    required bool isOn,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isOn
                    ? const Color(0xFF28a745).withValues(alpha: 0.2)
                    : const Color(0xFF0a0a2a),
                foregroundColor: isOn ? Colors.green : Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isOn ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF00d4ff)),
                      ),
                    )
                  : Text(
                      isOn ? '✓ ON' : '⊗ OFF',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DeviceControlWidget extends StatefulWidget {
  const DeviceControlWidget({super.key});

  @override
  State<DeviceControlWidget> createState() => _DeviceControlWidgetState();
}

class _DeviceControlWidgetState extends State<DeviceControlWidget> {
  List<Map<String, dynamic>> relayStatus = [];
  Map<String, dynamic>? deviceConfig;
  bool isLoading = false;
  bool isControlling = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceConfig();
  }

  Future<void> _loadDeviceConfig() async {
    setState(() => isLoading = true);
    
    try {
      final config = await ApiService.getDeviceConfig();
      final statusList = await ApiService.getAllRelayStatus();
      
      if (mounted) {
        setState(() {
          if (config['success'] == true) {
            deviceConfig = config['config'];
          }
          relayStatus = statusList;
          isLoading = false;
        });
      }
      debugPrint('✅ Device config loaded');
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        debugPrint('❌ Error loading device config: $e');
      }
    }
  }

  Future<void> _toggleRelay(int relayNumber) async {
    setState(() => isControlling = true);
    
    try {
      final success = await ApiService.toggleRelay(relayNumber);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Relay $relayNumber toggled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadDeviceConfig();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to toggle relay'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isControlling = false);
    }
  }

  String _getRelayName(int relayNumber) {
    if (deviceConfig == null) return 'Device $relayNumber';
    if (relayNumber == 1) {
      return deviceConfig!['relay1_name'] ?? 'Device 1';
    } else {
      return deviceConfig!['relay2_name'] ?? 'Device 2';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Device Control',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (relayStatus.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No devices configured'),
          )
        else
          ...relayStatus.map((relay) {
            final relayNum = relay['relay_number'] ?? 0;
            final isOn = relay['is_on'] ?? false;
            final name = _getRelayName(relayNum);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(name),
                subtitle: Text(
                  isOn ? '🟢 ON' : '🔴 OFF',
                  style: TextStyle(
                    color: isOn ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Switch(
                  value: isOn,
                  activeColor: Colors.green,
                  onChanged: isControlling
                    ? null
                    : (_) => _toggleRelay(relayNum),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }
}

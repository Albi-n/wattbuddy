import 'package:flutter/material.dart';
import 'screens/login_register.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/bill_history_screen.dart';
import 'screens/reward_screen.dart';
import 'screens/devices_screen.dart';

void main() => runApp(const WattBuddyApp());

class WattBuddyApp extends StatelessWidget {
  const WattBuddyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WattBuddy',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0A0A2A),
        fontFamily: 'Roboto',
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginRegisterScreen(),
        '/dashboard': (context) => DashboardScreen(),
        '/profile': (context) => ProfileScreen(),
        '/bills': (context) => BillHistoryScreen(),
        '/rewards': (context) => const RewardsScreen(),
        '/devices': (context) => const DevicesScreen(),
      },
    );
  }
}

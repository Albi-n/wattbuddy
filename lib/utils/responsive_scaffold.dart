import 'package:flutter/material.dart';
import 'navigation.dart';

class ResponsiveScaffold extends StatelessWidget {
  final String currentRoute;
  final Widget body;

  const ResponsiveScaffold({
    Key? key,
    required this.currentRoute,
    required this.body,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    if (isMobile) {
      // MOBILE → Drawer
      return Scaffold(
        appBar: AppBar(
          title: const Text("Watt Buddy ⚡"),
          backgroundColor: const Color(0xFF0A0A2A),
        ),
        drawer: Drawer(
          backgroundColor: const Color(0xFF0A0A2A),
          child: NavigationHelper.createSidebar(
            context: context,
            currentRoute: currentRoute,
            isOpen: true,
            onToggle: () {},
          ),
        ),
        body: body,
      );
    }

    // DESKTOP → Sidebar
    return Scaffold(
      body: Row(
        children: [
          NavigationHelper.createSidebar(
            context: context,
            currentRoute: currentRoute,
            isOpen: true,
            onToggle: () {},
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

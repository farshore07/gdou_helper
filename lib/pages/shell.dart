import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_month), label: '课表'),
          NavigationDestination(icon: Icon(Icons.home), label: '宿舍'),
          NavigationDestination(
              icon: Icon(Icons.assignment), label: '考试'),
          NavigationDestination(icon: Icon(Icons.menu), label: '更多'),
        ],
      ),
    );
  }
}

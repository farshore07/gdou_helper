import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checking = ref.watch(authProvider).checking;
    return Scaffold(
      body: Stack(
        children: [
          navigationShell,
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: checking
                  ? const _AutoLoginBanner(key: ValueKey('auto-login'))
                  : const SizedBox.shrink(key: ValueKey('idle')),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '课表'),
          NavigationDestination(icon: Icon(Icons.home), label: '宿舍'),
          NavigationDestination(icon: Icon(Icons.assignment), label: '考试'),
          NavigationDestination(icon: Icon(Icons.menu), label: '更多'),
        ],
      ),
    );
  }
}

class _AutoLoginBanner extends StatelessWidget {
  const _AutoLoginBanner({super.key});

  @override
  Widget build(BuildContext context) => Material(
    elevation: 3,
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('正在自动登录…'),
          ],
        ),
      ),
    ),
  );
}

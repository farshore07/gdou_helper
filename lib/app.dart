import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/reminder_provider.dart';
import 'router.dart';
import 'theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 启动时即挂载提醒监听，避免必须打开设置页才会排程课程与考试提醒
    ref.watch(reminderProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'GDOU 助手',
      theme: theme,
      darkTheme: darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

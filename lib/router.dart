import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'pages/login_page.dart';
import 'pages/shell.dart';
import 'pages/schedule_page.dart';
import 'pages/dormitory_page.dart';
import 'pages/exam_score_page.dart';
import 'pages/about_page.dart';
import 'pages/more_page.dart';
import 'pages/settings_page.dart';


final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/schedule',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/schedule', builder: (_, _) => const SchedulePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/dormitory',
                builder: (_, _) => const DormitoryPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/exam-score',
                builder: (_, _) => const ExamScorePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/more', builder: (_, _) => const MorePage()),
          ]),
        ],
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      GoRoute(path: '/about', builder: (_, _) => const AboutPage()),
    ],
  );
});

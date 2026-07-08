import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../widgets/toast.dart';
import 'library_page.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final username = ref.watch(authProvider).username;

    return Scaffold(
      appBar: AppBar(title: const Text('更多')),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: [
          _section('工具', cs.primary),
          _tile(
            icon: Icons.folder_outlined,
            color: Colors.amber.shade700,
            title: '资料库',
            subtitle: '课件、试卷、教材',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LibraryPage()),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          _tile(
            icon: Icons.notifications_active_outlined,
            color: cs.error,
            title: '测试通知',
            subtitle: '立即弹出测试通知',
            onTap: () async {
              await showTestNotification();
              if (context.mounted) {
                Toast.success(context, '通知已弹出，请查看通知栏');
              }
            },
          ),
          const SizedBox(height: 20),
          _section('其他', cs.primary),
          _tile(
            icon: Icons.settings_outlined,
            color: cs.secondary,
            title: '设置',
            subtitle: '学期、提醒、外观',
            onTap: () => context.push('/settings'),
          ),
          _tile(
            icon: Icons.info_outline,
            color: cs.outline,
            title: '关于',
            subtitle: 'GDOU 助手 v1.0.0',
            onTap: () => context.push('/about'),
          ),
          const SizedBox(height: 20),
          _section('账户', cs.primary),
          if (username != null) ...[
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: cs.primary.withAlpha(25),
                child: const Icon(Icons.person, size: 20, color: Colors.blue),
              ),
              title: Text(username, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('教务系统已登录', style: TextStyle(fontSize: 12)),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('退出登录', style: TextStyle(color: Colors.red)),
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ] else ...[
            _tile(
              icon: Icons.login,
              color: cs.primary,
              title: '登录教务系统',
              subtitle: '登录后获取课表、成绩、考试',
              onTap: () => context.push('/login'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Text(title,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withAlpha(25),
          child: Icon(icon, size: 20, color: color),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      );
}

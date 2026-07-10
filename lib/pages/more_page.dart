import 'package:flutter/foundation.dart';
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
    final auth = ref.watch(authProvider);
    final username = auth.username;

    final tools = <Widget>[
      _tile(
        context,
        icon: Icons.folder_outlined,
        color: cs.tertiary,
        title: '资料库',
        subtitle: '课件、试卷、教材',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LibraryPage()),
        ),
      ),
      if (kDebugMode)
        _tile(
          context,
          icon: Icons.notifications_active_outlined,
          color: cs.error,
          title: '测试通知',
          subtitle: '[调试] 立即弹出测试通知',
          onTap: () async {
            await showTestNotification();
            if (context.mounted) Toast.success(context, '通知已弹出，请查看通知栏');
          },
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('更多'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: [
          _accountCard(context, username, () => context.push('/login')),
          if (username != null) _logoutButton(context, ref),
          _section(context, '工具'),
          _groupCard(context, tools),
          if (auth.isAdmin) ...[
            _section(context, '管理'),
            _groupCard(context, [
              _tile(
                context,
                icon: Icons.admin_panel_settings_outlined,
                color: cs.primary,
                title: '管理后台',
                subtitle: '用户、资料与分类管理',
                onTap: () => context.push('/admin'),
              ),
            ]),
          ],
          _section(context, '其他'),
          _groupCard(context, [
            _tile(
              context,
              icon: Icons.settings_outlined,
              color: cs.secondary,
              title: '设置',
              subtitle: '学期、提醒、外观',
              onTap: () => context.push('/settings'),
            ),
            _tile(
              context,
              icon: Icons.info_outline,
              color: cs.outline,
              title: '关于',
              subtitle: 'GDOU 助手 v1.0.0',
              onTap: () => context.push('/about'),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _accountCard(
    BuildContext context,
    String? username,
    VoidCallback onLogin,
  ) {
    final cs = Theme.of(context).colorScheme;
    final loggedIn = username != null;
    final content = Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cs.primaryContainer, cs.surface]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (loggedIn ? cs.primary : cs.outline).withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              loggedIn ? Icons.person : Icons.person_outline,
              size: 24,
              color: loggedIn ? cs.primary : cs.outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username ?? '未登录',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      loggedIn ? Icons.check_circle : Icons.login,
                      size: 12,
                      color: loggedIn ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      loggedIn ? '教务系统已登录' : '点击登录教务系统',
                      style: TextStyle(
                        fontSize: 12,
                        color: loggedIn
                            ? cs.primary.withAlpha(200)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!loggedIn) Icon(Icons.chevron_right, color: cs.outlineVariant),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: loggedIn
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onLogin,
                child: content,
              ),
            ),
    );
  }

  Widget _logoutButton(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: cs.error.withAlpha(15),
          onTap: () => _confirmLogout(context, ref),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '退出登录',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后课表、成绩等数据将需要重新登录获取，确认退出？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('退出', style: TextStyle(color: cs.onError)),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(authProvider.notifier).logout();
  }

  Widget _section(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Container(width: 3, height: 12, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(BuildContext context, List<Widget> tiles) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withAlpha(40)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            for (var index = 0; index < tiles.length; index++) ...[
              if (index > 0)
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 56),
                  color: cs.outlineVariant.withAlpha(30),
                ),
              tiles[index],
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: cs.primaryContainer.withAlpha(40),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 20, color: cs.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  late Future<({List<Map<String, dynamic>> items, int total})> _users;

  @override
  void initState() {
    super.initState();
    _users = _loadUsers();
  }

  Future<({List<Map<String, dynamic>> items, int total})> _loadUsers() {
    final token = ref.read(authProvider).appToken;
    return token == null
        ? Future.error(const ApiException('登录已过期'))
        : fetchAdminUsers(token);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('管理后台')),
        body: const Center(child: Text('正在确认登录状态')),
      );
    }
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('管理后台')),
        body: Center(
          child: Text('无管理员权限', style: TextStyle(color: cs.error)),
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('管理后台'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '用户'),
              Tab(text: '资料'),
              Tab(text: '分类'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _usersView(cs),
            _placeholder('资料管理接口已就绪。', cs),
            _placeholder('分类管理接口已就绪。', cs),
          ],
        ),
      ),
    );
  }

  Widget _usersView(ColorScheme cs) => FutureBuilder(
    future: _users,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Center(child: CircularProgressIndicator(color: cs.primary));
      }
      if (snapshot.hasError) {
        return Center(
          child: FilledButton.tonal(
            onPressed: () => setState(() => _users = _loadUsers()),
            child: const Text('重新加载用户'),
          ),
        );
      }
      final result = snapshot.data!;
      return RefreshIndicator(
        onRefresh: () async => setState(() => _users = _loadUsers()),
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '共 ${result.total} 位用户',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            for (final user in result.items)
              ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    user['is_admin'] == true
                        ? Icons.admin_panel_settings
                        : Icons.person,
                  ),
                ),
                title: Text(
                  user['display_name'] as String? ??
                      user['student_no'] as String? ??
                      '',
                ),
                subtitle: Text(user['student_no'] as String? ?? ''),
                trailing: user['is_admin'] == true
                    ? const Chip(label: Text('管理员'))
                    : null,
              ),
          ],
        ),
      );
    },
  );

  Widget _placeholder(String text, ColorScheme cs) => Center(
    child: Text(text, style: TextStyle(color: cs.onSurfaceVariant)),
  );
}

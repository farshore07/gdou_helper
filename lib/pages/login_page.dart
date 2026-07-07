import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/secure_store.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final sp = await SharedPreferences.getInstance();
    _userCtrl.text = sp.getString('saved_username') ?? '';
    final pwd = await loadPassword();
    _passCtrl.text = pwd ?? '';
    setState(() {});
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    if (username.isEmpty || password.isEmpty) return;

    final sp = await SharedPreferences.getInstance();
    if (_remember) {
      await sp.setString('saved_username', username);
      await savePassword(password);
    } else {
      await sp.remove('saved_username');
      await secureDelete('saved_password');
    }

    await ref.read(authProvider.notifier).login(username, password);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;

    if (auth.isLoggedIn && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school, size: 64, color: cs.primary),
                const SizedBox(height: 12),
                Text('GDOU 助手', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('登录教务系统', style: TextStyle(color: cs.outline)),
                const SizedBox(height: 24),
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: '学号',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Checkbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _remember = !_remember),
                      child: Text('记住密码', style: TextStyle(fontSize: 14, color: cs.outline)),
                    ),
                  ],
                ),
                if (auth.error != null && !auth.loading && !auth.isLoggedIn) ...[
                  const SizedBox(height: 12),
                  Text(auth.error!, style: TextStyle(color: cs.error, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: auth.loading ? null : _login,
                    child: auth.loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('登录'),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '我们重视你的隐私，不会收集、上传或分享任何个人信息。\n所有数据仅存储在你的设备本地。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.outline.withAlpha(150)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

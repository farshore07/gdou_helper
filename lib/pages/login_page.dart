import 'dart:async';

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
  bool _captchaDialogOpen = false;
  bool _mfaDialogOpen = false;
  bool _popped = false;
  late final int _initialSessionVersion;
  late final bool _initialLoggedIn;

  @override
  void initState() {
    super.initState();
    final initialAuth = ref.read(authProvider);
    _initialSessionVersion = initialAuth.sessionVersion;
    _initialLoggedIn = initialAuth.isLoggedIn && !initialAuth.sessionExpired;
    _loadSaved();
    // 若用户从“会话已过期，继续验证”入口进入且已有挂起验证事务，立即弹出验证窗口
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(authProvider);
      if (current.captchaChallenge != null && !_captchaDialogOpen) {
        _openCaptchaDialog();
      } else if (current.mfaChallenge != null && !_mfaDialogOpen) {
        _openMfaDialog();
      }
    });
  }

  Future<void> _loadSaved() async {
    final sp = await SharedPreferences.getInstance();
    _userCtrl.text =
        sp.getString('saved_username') ?? sp.getString('username') ?? '';
    _remember = await loadRememberPassword();
    final pwd = await loadPassword();
    _passCtrl.text = pwd ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool _isAuthCompleted(AuthState auth) {
    if (!auth.isLoggedIn || auth.sessionExpired) return false;
    return auth.sessionVersion != _initialSessionVersion || !_initialLoggedIn;
  }

  void _tryPopAfterSuccess() {
    if (_popped || !mounted || _captchaDialogOpen || _mfaDialogOpen) return;
    if (!_isAuthCompleted(ref.read(authProvider))) return;
    _popped = true;
    if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _login() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    if (username.isEmpty || password.isEmpty) return;

    await ref
        .read(authProvider.notifier)
        .login(username, password, remember: _remember);
  }

  Future<void> _openCaptchaDialog() async {
    if (_captchaDialogOpen || !mounted) return;
    _captchaDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _CaptchaDialog(),
      );
    } finally {
      _captchaDialogOpen = false;
      if (mounted) {
        final current = ref.read(authProvider);
        if (current.captchaChallenge != null) {
          ref.read(authProvider.notifier).cancelChallenge();
        } else if (current.mfaChallenge != null && !_mfaDialogOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _openMfaDialog());
        } else {
          _tryPopAfterSuccess();
        }
      }
    }
  }

  Future<void> _openMfaDialog() async {
    if (_mfaDialogOpen || !mounted) return;
    _mfaDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _MfaDialog(),
      );
    } finally {
      _mfaDialogOpen = false;
      if (mounted) {
        final current = ref.read(authProvider);
        if (current.mfaChallenge != null) {
          ref.read(authProvider.notifier).cancelChallenge();
        } else {
          _tryPopAfterSuccess();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.captchaChallenge != null && !_captchaDialogOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openCaptchaDialog();
        });
      }
      if (next.mfaChallenge != null && !_mfaDialogOpen && !_captchaDialogOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openMfaDialog();
        });
      }
      if (_isAuthCompleted(next) && !_captchaDialogOpen && !_mfaDialogOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _tryPopAfterSuccess();
        });
      }
    });

    final auth = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(authProvider.notifier).cancelChallenge();
            if (context.canPop()) context.pop();
          },
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
                Text(
                  'GDOU 助手',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
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
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
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
                      child: Text(
                        '记住密码',
                        style: TextStyle(fontSize: 14, color: cs.outline),
                      ),
                    ),
                  ],
                ),
                if (auth.error != null &&
                    !auth.loading &&
                    !auth.isLoggedIn) ...[
                  const SizedBox(height: 12),
                  Text(
                    auth.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: auth.loading ? null : _login,
                    child: auth.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('登录'),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '我们重视你的隐私，不会收集、上传或分享任何个人信息。\n所有数据仅存储在你的设备本地。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.outline.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptchaDialog extends ConsumerStatefulWidget {
  const _CaptchaDialog();

  @override
  ConsumerState<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends ConsumerState<_CaptchaDialog> {
  final _codeCtrl = TextEditingController();
  String? _lastToken;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(authProvider.notifier).submitCaptcha(_codeCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final challenge = ref.watch(authProvider).captchaChallenge;
    final cs = Theme.of(context).colorScheme;

    if (challenge == null) {
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      });
      return const SizedBox.shrink();
    }

    if (_lastToken != challenge.captchaToken) {
      _lastToken = challenge.captchaToken;
      _codeCtrl.clear();
    }

    return AlertDialog(
      title: const Text('图形验证码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.memory(
                challenge.imageBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codeCtrl,
            autofocus: true,
            enabled: !challenge.submitting,
            decoration: const InputDecoration(
              labelText: '请输入图中验证码',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          if (challenge.error != null) ...[
            const SizedBox(height: 8),
            Text(
              challenge.error!,
              style: TextStyle(color: cs.error, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: challenge.submitting
              ? null
              : () {
                  ref.read(authProvider.notifier).cancelChallenge();
                  Navigator.of(context).pop();
                },
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: challenge.submitting ? null : _submit,
          child: challenge.submitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确认'),
        ),
      ],
    );
  }
}

class _MfaDialog extends ConsumerStatefulWidget {
  const _MfaDialog();

  @override
  ConsumerState<_MfaDialog> createState() => _MfaDialogState();
}

class _MfaDialogState extends ConsumerState<_MfaDialog> {
  final _codeCtrl = TextEditingController();
  late String _selectedMethod;
  bool _trustDevice = true;
  int _remainingSeconds = 0;
  DateTime? _lastSentAt;
  Timer? _timer;
  bool _initialized = false;

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    if (seconds <= 0) {
      setState(() => _remainingSeconds = 0);
      return;
    }
    setState(() => _remainingSeconds = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  void _sendCode() {
    ref.read(authProvider.notifier).sendMfaCode(_selectedMethod);
  }

  void _verify() {
    ref
        .read(authProvider.notifier)
        .verifyMfaCode(_codeCtrl.text, trustDevice: _trustDevice);
  }

  String _methodLabel(String method) => switch (method) {
    'wechat' => '企业微信',
    'sms' => '手机短信',
    _ => method,
  };

  @override
  Widget build(BuildContext context) {
    final challenge = ref.watch(authProvider).mfaChallenge;
    final cs = Theme.of(context).colorScheme;

    if (challenge == null) {
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      });
      return const SizedBox.shrink();
    }

    if (!_initialized) {
      _selectedMethod = challenge.selectedMethod;
      _initialized = true;
    }

    if (challenge.codeSentAt != null && challenge.codeSentAt != _lastSentAt) {
      _lastSentAt = challenge.codeSentAt;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startCountdown(challenge.countdown);
      });
    }

    final busy = challenge.sending || challenge.verifying;

    return AlertDialog(
      title: const Text('安全二次验证'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              challenge.message,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            if (challenge.availableMethods.length > 1) ...[
              SegmentedButton<String>(
                segments: [
                  for (final m in challenge.availableMethods)
                    ButtonSegment<String>(
                      value: m,
                      label: Text(_methodLabel(m)),
                    ),
                ],
                selected: {_selectedMethod},
                onSelectionChanged: busy
                    ? null
                    : (selection) {
                        if (selection.isEmpty) return;
                        setState(() => _selectedMethod = selection.first);
                      },
              ),
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    enabled: !challenge.verifying,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '动态验证码',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verify(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: (busy || _remainingSeconds > 0)
                        ? null
                        : _sendCode,
                    child: challenge.sending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _remainingSeconds > 0
                                ? '${_remainingSeconds}s'
                                : (challenge.codeSent ? '重新发送' : '获取验证码'),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _trustDevice,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('信任当前设备（下次免验证）', style: TextStyle(fontSize: 13)),
              onChanged: challenge.verifying
                  ? null
                  : (v) => setState(() => _trustDevice = v ?? true),
            ),
            if (challenge.error != null) ...[
              const SizedBox(height: 4),
              Text(
                challenge.error!,
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: challenge.verifying
              ? null
              : () {
                  ref.read(authProvider.notifier).cancelChallenge();
                  Navigator.of(context).pop();
                },
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: challenge.verifying ? null : _verify,
          child: challenge.verifying
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('完成验证'),
        ),
      ],
    );
  }
}

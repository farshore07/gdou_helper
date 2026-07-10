import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/release_info.dart';
import '../services/update_service.dart';
import '../utils/semantic_version.dart';

enum UpdateStatus { idle, checking, latest, updateAvailable, failed }

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final _service = UpdateService();
  UpdateStatus _status = UpdateStatus.idle;
  ReleaseInfo? _release;
  String _currentVersion = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _currentVersion = info.version);
    } catch (_) {
      if (mounted) setState(() => _currentVersion = '未知');
    }
  }

  Future<void> _checkForUpdate() async {
    if (_status == UpdateStatus.checking ||
        _currentVersion.isEmpty ||
        _currentVersion == '未知') {
      return;
    }
    setState(() {
      _status = UpdateStatus.checking;
      _error = null;
      _release = null;
    });
    try {
      final current = SemanticVersion.tryParse(_currentVersion);
      if (current == null) throw const UpdateCheckException('当前版本格式异常');
      final release = await _service.fetchLatestRelease();
      if (!mounted) return;
      setState(() {
        _release = release;
        _status = release.version.compareTo(current) > 0
            ? UpdateStatus.updateAvailable
            : UpdateStatus.latest;
      });
    } on UpdateCheckException catch (error) {
      if (mounted) {
        setState(() {
          _status = UpdateStatus.failed;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = UpdateStatus.failed;
          _error = '检查更新失败，请稍后重试';
        });
      }
    }
  }

  Future<void> _openRelease() async {
    final url = _release?.htmlUrl;
    if (url == null || !UpdateService.isAllowedReleaseUrl(url)) {
      _showError('更新链接无效');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      _showError('无法打开更新页面');
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showError('无法打开更新页面');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          Icon(Icons.school, size: 64, color: cs.primary),
          const SizedBox(height: 12),
          const Text(
            'GDOU 助手',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _currentVersion.isEmpty ? '读取版本中…' : 'v$_currentVersion',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),
          const Divider(indent: 48, endIndent: 48),
          _updateSection(cs),
          const Divider(indent: 48, endIndent: 48),
          _info('广海小助手', Icons.info_outline),
          _info('课表查询 · 考试日程 · 成绩查询 · 宿舍电费', Icons.checklist),
          _info('数据来源：广东海洋大学教务系统', Icons.cloud_outlined),
          _info('仅限个人学习使用', Icons.verified_user_outlined),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => _openUrl(AppConfig.githubRepositoryUrl),
            icon: const Icon(Icons.code, size: 18),
            label: Text(
              AppConfig.githubRepositoryUrl.replaceFirst('https://', ''),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '这是一个开源项目，仅用于学习用途。\n我们不会收集、上传或分享任何个人信息。\n所有数据仅存储在你的设备本地。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _updateSection(ColorScheme cs) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('版本更新', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_status == UpdateStatus.checking)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('正在检查更新……'),
          )
        else if (_status == UpdateStatus.failed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_error ?? '检查更新失败，请稍后重试'),
            subtitle: TextButton(
              onPressed: _checkForUpdate,
              child: const Text('重新检查'),
            ),
          )
        else if (_status == UpdateStatus.latest)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('当前版本 v$_currentVersion'),
            subtitle: const Text('已是最新版本'),
          )
        else if (_status == UpdateStatus.updateAvailable) ...[
          Text('当前版本：v$_currentVersion'),
          Text('最新版本：${_release!.tagName}'),
          if (_release!.body.trim().isNotEmpty)
            Text(
              _release!.body.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.outline),
            ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _openRelease,
            icon: const Icon(Icons.open_in_new),
            label: const Text('立即更新'),
          ),
        ] else
          TextButton.icon(
            onPressed: _currentVersion.isEmpty ? null : _checkForUpdate,
            icon: const Icon(Icons.refresh),
            label: const Text('检查更新'),
          ),
      ],
    ),
  );

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null && await canLaunchUrl(uri)) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Widget _info(String text, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Flexible(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../config/legal_documents.dart';
import '../providers/update_provider.dart';
import '../widgets/toast.dart';
import 'legal_document_page.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final updateState = ref.watch(updateCheckProvider);
    final versionText =
        updateState.currentVersion.isEmpty ? '' : 'v${updateState.currentVersion}';

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          Icon(Icons.school, size: 64, color: cs.primary),
          const SizedBox(height: 12),
          const Text('GDOU 助手',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (versionText.isNotEmpty)
            Text(versionText,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: cs.outline))
          else
            const SizedBox(height: 14),
          const SizedBox(height: 16),
          _buildUpdateSection(context, ref, updateState, cs),
          const Divider(indent: 48, endIndent: 48),
          _info('广海小助手', Icons.info_outline),
          _info('课表查询 · 考试日程 · 成绩查询', Icons.checklist),
          const Divider(indent: 48, endIndent: 48),
          _info('数据来源：广东海洋大学教务系统', Icons.cloud_outlined),
          _info('仅限个人学习使用', Icons.verified_user_outlined),
          const Divider(indent: 48, endIndent: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, size: 20),
                  title: const Text('隐私声明', style: TextStyle(fontSize: 14)),
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: cs.outline,
                  ),
                  onTap: () =>
                      _openLegalDocument(context, LegalDocumentType.privacy),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined, size: 20),
                  title: const Text('用户协议', style: TextStyle(fontSize: 14)),
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: cs.outline,
                  ),
                  onTap: () =>
                      _openLegalDocument(context, LegalDocumentType.terms),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _openUrl(AppConfig.githubRepoUrl),
            icon: const Icon(Icons.code, size: 18),
            label: Text('${AppConfig.githubOwner}/${AppConfig.githubRepo}',
                style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 16),
          Text(
            '这是一个开源项目，仅用于学习用途。\n'
            '我们不会收集、上传或分享任何个人信息。\n'
            '所有数据仅存储在你的设备本地。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.outline.withAlpha(150)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── 更新检查区域 ──
  Widget _buildUpdateSection(
    BuildContext context,
    WidgetRef ref,
    UpdateCheckState state,
    ColorScheme cs,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: switch (state.status) {
        UpdateCheckStatus.idle => _idleView(context, ref, state, cs),
        UpdateCheckStatus.checking => _checkingView(cs),
        UpdateCheckStatus.latest => _latestView(context, ref, state, cs),
        UpdateCheckStatus.updateAvailable =>
          _updateAvailableView(context, ref, state, cs),
        UpdateCheckStatus.failed => _failedView(context, ref, state, cs),
      },
    );
  }

  Widget _idleView(
    BuildContext context,
    WidgetRef ref,
    UpdateCheckState state,
    ColorScheme cs,
  ) {
    return Column(
      children: [
        if (state.currentVersion.isNotEmpty)
          Text('当前版本：v${state.currentVersion}',
              style: TextStyle(fontSize: 13, color: cs.outline)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(updateCheckProvider.notifier).checkForUpdate(),
          icon: const Icon(Icons.system_update, size: 18),
          label: const Text('检查更新'),
        ),
      ],
    );
  }

  Widget _checkingView(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Text('正在检查更新……',
            style: TextStyle(fontSize: 13, color: cs.outline)),
      ],
    );
  }

  Widget _latestView(
    BuildContext context,
    WidgetRef ref,
    UpdateCheckState state,
    ColorScheme cs,
  ) {
    return Column(
      children: [
        if (state.currentVersion.isNotEmpty)
          Text('当前版本：v${state.currentVersion}',
              style: TextStyle(fontSize: 13, color: cs.outline)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
            const SizedBox(width: 6),
            Text('已是最新版本',
                style: TextStyle(
                    fontSize: 13, color: Colors.green.shade600)),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(updateCheckProvider.notifier).checkForUpdate(),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重新检查'),
        ),
      ],
    );
  }

  Widget _updateAvailableView(
    BuildContext context,
    WidgetRef ref,
    UpdateCheckState state,
    ColorScheme cs,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.system_update_alt, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text('发现新版本',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '当前版本：v${state.currentVersion}　→　最新版本：${state.latestVersion ?? ''}',
          style: TextStyle(fontSize: 13, color: cs.outline),
          textAlign: TextAlign.center,
        ),
        if (state.releaseName != null && state.releaseName!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(state.releaseName!,
              style: TextStyle(fontSize: 12, color: cs.outline.withAlpha(180))),
        ],
        if (state.publishedAt != null) ...[
          const SizedBox(height: 4),
          Text('发布日期：${_formatDate(state.publishedAt!)}',
              style: TextStyle(fontSize: 12, color: cs.outline.withAlpha(180))),
        ],
        if (state.releaseNotes != null && state.releaseNotes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  state.releaseNotes!,
                  style: TextStyle(fontSize: 12, color: cs.onSurface),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _openReleaseUrl(context, state.releaseUrl),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('立即更新'),
        ),
      ],
    );
  }

  Widget _failedView(
    BuildContext context,
    WidgetRef ref,
    UpdateCheckState state,
    ColorScheme cs,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 16, color: cs.error),
            const SizedBox(width: 6),
            Text('检查更新失败，请稍后重试',
                style: TextStyle(fontSize: 13, color: cs.error)),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(updateCheckProvider.notifier).checkForUpdate(),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重新检查'),
        ),
      ],
    );
  }

  // ── 外部链接与协议页面 ──

  void _openLegalDocument(BuildContext context, LegalDocumentType type) {
    final path = switch (type) {
      LegalDocumentType.privacy => '/legal/privacy',
      LegalDocumentType.terms => '/legal/terms',
    };
    if (GoRouter.maybeOf(context) != null) {
      context.push(path);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => LegalDocumentPage(type: type)));
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 打开 GitHub Release 页面，校验 URL 合法性
  Future<void> _openReleaseUrl(BuildContext context, String? url) async {
    if (url == null || url.isEmpty || !_isValidGitHubReleaseUrl(url)) {
      Toast.error(context, '更新地址无效');
      return;
    }
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) Toast.error(context, '无法打开更新页面');
      }
    } catch (e) {
      if (context.mounted) Toast.error(context, '打开更新页面失败');
    }
  }

  /// 仅允许打开 GitHub Release 页面
  bool _isValidGitHubReleaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    if (uri.host != 'github.com') return false;
    if (!uri.path.contains('/releases/')) return false;
    return true;
  }

  String _formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  Widget _info(String text, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey),
            const SizedBox(width: 12),
            Flexible(
                child: Text(text, style: const TextStyle(fontSize: 14))),
          ],
        ),
      );
}

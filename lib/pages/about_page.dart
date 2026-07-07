import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
          const Text('GDOU 助手', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('v1.0.0', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.outline)),
          const SizedBox(height: 24),
          const Divider(indent: 48, endIndent: 48),
          _info('广东海洋大学教务系统小助手', Icons.info_outline),
          _info('课表查询 · 考试日程 · 成绩查看 · 宿舍电费', Icons.checklist),
          const Divider(indent: 48, endIndent: 48),
          _info('数据来源：广东海洋大学教务系统', Icons.cloud_outlined),
          _info('仅限个人学习使用', Icons.verified_user_outlined),
          const SizedBox(height: 24),
          Text('我们不会收集、上传或分享任何个人信息。\n所有数据仅存储在你的设备本地。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.outline.withAlpha(150))),
        ],
      ),
    );
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

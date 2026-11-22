import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';
import '../providers/semester_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/cache_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    final semester = ref.watch(semesterProvider);
    final reminder = ref.watch(reminderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _Header('学期'),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('当前学期'),
            trailing: DropdownButton<String>(
              value: semester,
              underline: const SizedBox(),
              items: allSemesters
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(semesterLabel(s)),
                      ))
                  .toList(),
              onChanged: (v) => ref.read(semesterProvider.notifier).select(v!),
            ),
          ),
          const Divider(),
          const _Header('提醒'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('考试提醒'),
            subtitle: const Text('考试前一天提醒'),
            value: reminder.examEnabled,
            onChanged: (v) => ref.read(reminderProvider.notifier).toggleExam(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm_outlined),
            title: const Text('上课提醒'),
            subtitle: const Text('上课前 15 分钟提醒'),
            value: reminder.courseEnabled,
            onChanged: (v) => ref.read(reminderProvider.notifier).toggleCourse(v),
          ),
          const Divider(),
          const _Header('外观'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('深色模式'),
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
          ),
          const Divider(),
          const _Header('数据'),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('刷新缓存'),
            subtitle: const Text('清除本地缓存并重新加载数据'),
            onTap: () async {
              await CacheService.clearAll();
              ref.invalidate(timetableMetaProvider);
              ref.invalidate(timetableProvider);
              ref.invalidate(examsProvider);
              ref.invalidate(gradesProvider);
              ref.invalidate(electricityProvider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('清除所有数据', style: TextStyle(color: Colors.red)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary)),
      );
}

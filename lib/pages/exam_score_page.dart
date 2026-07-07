import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';
import '../widgets/semester_selector.dart';

class ExamScorePage extends ConsumerWidget {
  const ExamScorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('考试'),
          actions: const [SemesterSelector()],
          bottom: const TabBar(tabs: [Tab(text: '考试'), Tab(text: '成绩')]),
        ),
        body: const TabBarView(
          children: [_ExamTab(), _ScoreTab()],
        ),
      ),
    );
  }
}

// ── 考试 Tab ──
class _ExamTab extends ConsumerWidget {
  const _ExamTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final asyncExams = ref.watch(examsProvider);

    return asyncExams.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败\n$e', style: TextStyle(color: cs.error))),
      data: (exams) => exams.isEmpty
          ? Center(child: Text('暂无考试', style: TextStyle(color: cs.outline)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: exams.length,
              itemBuilder: (_, i) {
                final e = exams[i];
                final today = DateTime.now();
                final days = DateTime(e.date.year, e.date.month, e.date.day)
                    .difference(DateTime(today.year, today.month, today.day))
                    .inDays;
                final urgent = days >= 0 && days <= 3;
                final soon = days >= 0 && days <= 7;
                final past = days < 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Column(
                            children: [
                              Text('${e.date.month}月${e.date.day}日',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: past ? cs.surfaceContainerHighest : (urgent ? cs.error : (soon ? Colors.orange[100] : cs.surfaceContainerHighest)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  past ? '已结束' : (days == 0 ? '今天' : '$days天后'),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                      color: past ? cs.outline : (urgent ? cs.onError : (soon ? Colors.orange[800] : cs.outline))),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.courseName,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: past ? cs.outline : null)),
                              const SizedBox(height: 4),
                              _info(Icons.access_time,
                                  '${e.startTime.hour.toString().padLeft(2, '0')}:${e.startTime.minute.toString().padLeft(2, '0')} - ${e.endTime.hour.toString().padLeft(2, '0')}:${e.endTime.minute.toString().padLeft(2, '0')}'),
                              const SizedBox(height: 2),
                              if (e.location.isNotEmpty) _info(Icons.location_on_outlined, e.location),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _info(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ],
      );
}

// ── 成绩 Tab ──
class _ScoreTab extends ConsumerWidget {
  const _ScoreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final asyncScores = ref.watch(gradesProvider);

    return asyncScores.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败\n$e', style: TextStyle(color: cs.error))),
      data: (scores) {
        if (scores.isEmpty) return Center(child: Text('暂无成绩', style: TextStyle(color: cs.outline)));
        final totalCredit = scores.fold<double>(0, (s, r) => s + r.credit);
        final weighted = scores.fold<double>(0, (s, r) => s + r.gpaPoint * r.credit);
        final gpa = totalCredit > 0 ? weighted / totalCredit : 0.0;

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('总学分', totalCredit.toStringAsFixed(0)),
                  _stat('加权绩点', gpa.toStringAsFixed(2)),
                  _stat('课程数', '${scores.length}'),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: scores.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = scores[i];
                  return ListTile(
                    title: Text(r.courseName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.gradeText.isNotEmpty ? r.gradeText : '${r.score.toStringAsFixed(0)}分',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        SizedBox(width: 36,
                            child: Text('绩点 ${r.gpaPoint.toStringAsFixed(1)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      );
}

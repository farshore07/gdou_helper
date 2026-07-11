import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exam.dart';
import '../models/score.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';
import '../widgets/semester_selector.dart';

class ExamScorePage extends ConsumerWidget {
  const ExamScorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('考试'),
          actions: const [SemesterSelector()],
          bottom: TabBar(
            labelColor: cs.primary,
            unselectedLabelColor: cs.outline,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            indicator: _RoundedUnderlineIndicator(cs.primary),
            tabs: const [
              Tab(text: '考试'),
              Tab(text: '成绩'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ExamTab(), _ScoreTab()]),
      ),
    );
  }
}

Widget _loadingWidget(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Center(
    child: Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(60),
        shape: BoxShape.circle,
      ),
      child: CircularProgressIndicator(color: cs.primary, strokeWidth: 3),
    ),
  );
}

Widget _errorWidget(BuildContext context, Object error, VoidCallback onRetry) {
  final cs = Theme.of(context).colorScheme;
  return Center(
    child: Container(
      margin: const EdgeInsets.all(28),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: cs.error),
          const SizedBox(height: 12),
          Text('加载失败', style: TextStyle(fontSize: 16, color: cs.onSurface)),
          const SizedBox(height: 4),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
  );
}

class _ExamTab extends ConsumerWidget {
  const _ExamTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncExams = ref.watch(examsProvider);
    return asyncExams.when(
      loading: () => _loadingWidget(context),
      error: (error, _) =>
          _errorWidget(context, error, () => ref.invalidate(examsProvider)),
      data: (exams) => _ExamList(exams: exams),
    );
  }
}

class _ExamList extends StatelessWidget {
  final List<Exam> exams;
  const _ExamList({required this.exams});

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final upcoming =
        exams.where((exam) => !_dateOnly(exam.date).isBefore(today)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final past =
        exams.where((exam) => _dateOnly(exam.date).isBefore(today)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _GroupHeader(title: '即将到来'),
        if (upcoming.isEmpty)
          _UpcomingEmpty()
        else
          ...upcoming.map(
            (exam) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ExamCard(exam: exam),
            ),
          ),
        if (past.isNotEmpty) ...[
          const SizedBox(height: 20),
          _GroupHeader(title: '已结束'),
          ...past.map(
            (exam) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _ExamCard(exam: exam),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  final Exam exam;
  const _ExamCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = _dateOnly(DateTime.now());
    final date = _dateOnly(exam.date);
    final days = date.difference(today).inDays;
    final past = days < 0;
    final isToday = days == 0;
    final within3 = days > 0 && days <= 3;
    final within7 = days > 3 && days <= 7;
    final dateBackground = past || days > 7
        ? cs.surfaceContainerHighest
        : isToday
        ? cs.primaryContainer
        : within7
        ? cs.tertiaryContainer
        : cs.errorContainer;
    final dateTextColor = isToday ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withAlpha(60)),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: dateBackground,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _examDate(exam.date),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: dateTextColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _weekday(exam.date),
                      style: TextStyle(fontSize: 10, color: cs.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.courseName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: past ? cs.onSurfaceVariant : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ExamInfo(
                        icon: Icons.access_time,
                        text:
                            '${_time(exam.startTime)} - ${_time(exam.endTime)}',
                      ),
                      if (exam.location.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _ExamInfo(
                          icon: Icons.location_on_outlined,
                          text: exam.location,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (past || isToday || within3 || within7)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _StatusPill(days: days),
                ),
            ],
          ),
        ),
        if (!past && days <= 3)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: cs.error,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final int days;
  const _StatusPill({required this.days});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final past = days < 0;
    final today = days == 0;
    final within3 = days <= 3;
    final color = past
        ? cs.surfaceContainerHighest
        : today
        ? cs.error
        : within3
        ? cs.tertiaryContainer
        : cs.primaryContainer;
    final textColor = past
        ? cs.outline
        : today
        ? cs.onError
        : within3
        ? cs.onTertiaryContainer
        : cs.onPrimaryContainer;
    final label = past
        ? '已结束'
        : today
        ? '今天'
        : '$days天后';
    return Container(
      width: 24,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _ExamInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ExamInfo({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.outline),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(width: 18, height: 2, color: cs.outline),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: cs.outline,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UpcomingEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, size: 64, color: cs.outline),
          const SizedBox(height: 12),
          Text('本学期暂无考试，安心学习', style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ScoreTab extends ConsumerWidget {
  const _ScoreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncScores = ref.watch(gradesProvider);
    return asyncScores.when(
      loading: () => _loadingWidget(context),
      error: (error, _) =>
          _errorWidget(context, error, () => ref.invalidate(gradesProvider)),
      data: (scores) =>
          scores.isEmpty ? const _ScoresEmpty() : _ScoresView(scores: scores),
    );
  }
}

class _ScoresView extends StatelessWidget {
  final List<Score> scores;
  const _ScoresView({required this.scores});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalCredit = scores.fold<double>(
      0,
      (sum, score) => sum + score.credit,
    );
    final weighted = scores.fold<double>(
      0,
      (sum, score) => sum + score.gpaPoint * score.credit,
    );
    final gpa = totalCredit > 0 ? weighted / totalCredit : 0.0;
    final gpaColor = _gpaColor(cs, gpa);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primaryContainer, cs.surfaceContainerHighest],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: '总学分',
                      value: totalCredit.toStringAsFixed(1),
                    ),
                  ),
                  _VerticalDivider(color: cs.outlineVariant.withAlpha(50)),
                  Expanded(
                    child: _Stat(
                      label: '加权绩点',
                      value: gpa.toStringAsFixed(2),
                      color: gpaColor,
                      prominent: true,
                    ),
                  ),
                  _VerticalDivider(color: cs.outlineVariant.withAlpha(50)),
                  Expanded(
                    child: _Stat(label: '课程数', value: '${scores.length}'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (gpa / 5).clamp(0, 1),
                  minHeight: 4,
                  color: gpaColor,
                  backgroundColor: cs.surface.withAlpha(120),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            itemCount: scores.length,
            separatorBuilder: (_, _) => Container(
              height: .5,
              margin: const EdgeInsets.only(left: 16),
              color: cs.outlineVariant.withAlpha(40),
            ),
            itemBuilder: (_, index) => _ScoreRow(score: scores[index]),
          ),
        ),
      ],
    );
  }
}

class _ScoreRow extends ConsumerWidget {
  final Score score;
  const _ScoreRow({required this.score});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final color = _scoreColor(cs, score.score);
    final hasNumericGrade = double.tryParse(score.gradeText) != null;
    final display = score.gradeText.isNotEmpty
        ? score.gradeText
        : score.score.toStringAsFixed(0);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showDetail(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    score.courseName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '学分 ${score.credit.toStringAsFixed(1)} · ${score.category == ScoreCategory.elective ? '选修' : '必修'}',
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  display,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (!hasNumericGrade && score.gradeText.isNotEmpty)
                  Text(
                    score.score.toStringAsFixed(0),
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                Text(
                  '绩点 ${score.gpaPoint.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    final cookie = ref.read(authProvider).cookie;
    if (cookie == null) return;
    final future = fetchGradeDetail(cookie, query: score.detailQuery);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const SizedBox(
              height: 180,
              child: Center(child: Text('获取详细成绩失败')),
            );
          }
          final data = snapshot.data?.data ?? const <String, dynamic>{};
          final items = (data['items'] as List<dynamic>? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['course_name'] as String? ?? score.courseName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['name'] as String? ?? ''),
                    subtitle: Text(item['ratio'] as String? ?? ''),
                    trailing: Text(item['score'] as String? ?? ''),
                  ),
                if (items.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('暂无分项成绩'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool prominent;
  const _Stat({
    required this.label,
    required this.value,
    this.color,
    this.prominent = false,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: prominent ? 30 : 20,
            fontWeight: FontWeight.w800,
            color: color ?? cs.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  final Color color;
  const _VerticalDivider({required this.color});
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 42, color: color);
}

class _ScoresEmpty extends StatelessWidget {
  const _ScoresEmpty();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assessment_outlined, size: 64, color: cs.outline),
          const SizedBox(height: 12),
          Text('暂无成绩数据', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            '切换学期或下拉刷新试试',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
        ],
      ),
    );
  }
}

class _RoundedUnderlineIndicator extends Decoration {
  final Color color;
  const _RoundedUnderlineIndicator(this.color);
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _RoundedUnderlinePainter(color);
}

class _RoundedUnderlinePainter extends BoxPainter {
  final Color color;
  _RoundedUnderlinePainter(this.color);
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = Rect.fromLTWH(
      offset.dx + 12,
      offset.dy + size.height - 3,
      size.width - 24,
      3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = color,
    );
  }
}

Color _gpaColor(ColorScheme cs, double gpa) => gpa >= 3.5
    ? cs.primary
    : gpa >= 2
    ? cs.tertiary
    : cs.error;
Color _scoreColor(ColorScheme cs, double score) => score >= 90
    ? cs.primary
    : score >= 80
    ? cs.secondary
    : score >= 70
    ? cs.tertiary
    : score >= 60
    ? cs.tertiary
    : cs.error;
DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String _weekday(DateTime value) =>
    const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][value.weekday - 1];
String _examDate(DateTime value) => value.year == DateTime.now().year
    ? '${value.month}月${value.day}日'
    : '${value.year}年${value.month}月${value.day}日';
String _time(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

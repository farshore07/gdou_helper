import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course.dart';
import '../providers/data_providers.dart';
import '../providers/semester_provider.dart';
import '../widgets/semester_selector.dart';

const _periods = 10;
const _dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const _rowH = 60.0;
const _timeW = 52.0;

// GDOU 节次时间
const _periodTimes = [
  '8:10-8:55',
  '9:00-9:45',
  '10:15-11:00',
  '11:05-11:50',
  '2:30-3:15',
  '3:20-4:05',
  '4:30-5:15',
  '5:20-6:05',
  '7:30-8:15',
  '8:25-9:10',
];

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});
  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

// 学期→开学日期
DateTime _semesterStart(String semester) {
  final parts = semester.split('-');
  final term = parts.length > 2 ? int.tryParse(parts[2]) ?? 1 : 1;
  final y1 = int.tryParse(parts[0]) ?? 2025;
  final y2 = int.tryParse(parts.length > 1 ? parts[1] : parts[0]) ?? y1;
  return DateTime(term == 1 ? y1 : y2, term == 1 ? 9 : 3, 1);
}

int _currentWeekForSemester(String semester) {
  final start = _semesterStart(semester);
  final now = DateTime.now();
  if (now.isBefore(start)) return 1;
  final w = ((now.difference(start).inDays) / 7).floor() + 1;
  return w.clamp(1, 20);
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  PageController? _pageCtrl;
  int _week = 1;
  static const _maxWeek = 20;

  PageController get _pc => _pageCtrl!;

  @override
  void initState() {
    super.initState();
    final semester = ref.read(semesterProvider);
    final cur = _currentWeekForSemester(semester).clamp(1, _maxWeek);
    _week = cur;
    _pageCtrl = PageController(initialPage: cur - 1);
    _pc.addListener(() {
      if (!_pc.hasClients || _pc.page == null) return;
      final w = _pc.page!.round() + 1;
      if (w != _week && w >= 1 && w <= _maxWeek) setState(() => _week = w);
    });
  }

  @override
  void dispose() {
    _pageCtrl?.dispose();
    super.dispose();
  }

  void _goWeek(int w) {
    if (w < 1 || w > _maxWeek || _pageCtrl == null || !_pc.hasClients) return;
    _pc.jumpToPage(w - 1);
  }

  void _showDetail(Course c) {
    final active = c.startWeek <= _week && _week <= c.endWeek;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 14, height: 14,
                    decoration: BoxDecoration(color: Color(c.color), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 10),
                Flexible(child: Text(c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              ],
            ),
            if (!active) ...[
              const SizedBox(height: 4),
              Text('非本周', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
            const SizedBox(height: 16),
            _detail(Icons.person_outline, '教师', c.teacher),
            _detail(Icons.location_on_outlined, '教室', c.classroom),
            _detail(Icons.access_time, '时间',
                '${_dayLabels[c.dayOfWeek - 1]} 第${c.startPeriod}-${c.startPeriod + c.duration - 1}节'),
            _detail(Icons.date_range, '周次', '第${c.startWeek}-${c.endWeek}周'),
            _detail(Icons.school_outlined, '学期', semesterLabel(c.semester)),
            if (c.note != null && c.note!.isNotEmpty)
              _detail(Icons.notes, '备注', c.note!),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gridColor = cs.outlineVariant.withAlpha(100);
    final asyncCourses = ref.watch(timetableProvider);
    final courses = asyncCourses.asData?.value ?? [];

    final semester = ref.watch(semesterProvider);
    final weekStart = _semesterStart(semester).add(Duration(days: (_week - 1) * 7));

    return Scaffold(
      appBar: AppBar(
        title: Column(children: [
          const Text('课表', style: TextStyle(fontSize: 16)),
          Text(semester, style: TextStyle(fontSize: 11, color: cs.outline)),
        ]),
        actions: [
          const SemesterSelector(),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _week > 1 ? () => _goWeek(_week - 1) : null,
          ),
          Text('第$_week周', style: const TextStyle(fontSize: 14)),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _week < _maxWeek ? () => _goWeek(_week + 1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.today, size: 20),
            tooltip: '回到本周',
            onPressed: () {
              final cur = _currentWeekForSemester(ref.read(semesterProvider));
              if (_week != cur) _goWeek(cur);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: asyncCourses.isLoading
          ? const Center(child: CircularProgressIndicator())
          : asyncCourses.hasError
              ? Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.error_outline, size: 48, color: cs.error),
                      const SizedBox(height: 12),
                      Text('加载失败', style: TextStyle(fontSize: 16, color: cs.error)),
                      Text('${asyncCourses.error}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.outline)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(timetableProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ]),
                  ))
              : courses.isEmpty
                  ? Center(child: Text('暂无课表数据', style: TextStyle(color: cs.outline)))
                  : Column(
                      children: [
                        // ── 星期头（固定） ──
                        Row(
                          children: [
                            const SizedBox(width: _timeW),
                            ...List.generate(7, (i) {
                                  final day = weekStart.add(Duration(days: i));
                                  return Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: gridColor)),
                                        color: cs.surfaceContainerHighest.withAlpha(80),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(_dayLabels[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                                          Text('${day.month}/${day.day}', style: TextStyle(fontSize: 9, color: cs.outline)),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                          ],
                        ),
                        // ── 课表网格（PageView 滑动切换周） ──
                        Expanded(
                          child: PageView.builder(
                            controller: _pageCtrl,
                            itemCount: _maxWeek,
                            itemBuilder: (_, pageIndex) => _buildGrid(courses, pageIndex + 1, gridColor, cs),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildGrid(List<Course> courses, int week, Color gridColor, ColorScheme cs) {
    return SingleChildScrollView(
      child: SizedBox(
        height: _periods * _rowH,
        child: Row(
          children: [
            // ── 节次列 ──
            SizedBox(
              width: _timeW,
              child: Column(
                children: List.generate(_periods, (i) => Container(
                      height: _rowH,
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: gridColor)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${i + 1}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface)),
                          Text(_periodTimes[i],
                              style: TextStyle(fontSize: 8, color: cs.outline)),
                        ],
                      ),
                    )),
              ),
            ),
            // ── 每天一列 ──
            ...List.generate(7, (day) {
              final dayCourses = courses.where((c) => c.dayOfWeek == day + 1).toList()
                ..sort((a, b) {
                  final aActive = a.startWeek <= week && week <= a.endWeek;
                  final bActive = b.startWeek <= week && week <= b.endWeek;
                  if (aActive && !bActive) return 1;
                  if (!aActive && bActive) return -1;
                  return 0;
                });
              return Expanded(
                child: Stack(
                  children: [
                    ...List.generate(_periods, (i) => Positioned(
                          top: i * _rowH, left: 0, right: 0,
                          child: Container(
                            height: _rowH,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: gridColor),
                                left: BorderSide(color: gridColor),
                              ),
                            ),
                          ),
                        )),
                    ...(() {
                      final groups = <String, List<Course>>{};
                      for (final c in dayCourses) {
                        final key = '${c.startPeriod}-${c.duration}';
                        groups.putIfAbsent(key, () => []).add(c);
                      }
                      return groups.values.expand((group) {
                        return group.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final c = entry.value;
                          final n = group.length;
                          final active = c.startWeek <= week && week <= c.endWeek;
                          final top = (c.startPeriod - 1) * _rowH + 1;
                          final h = c.duration * _rowH - 2;
                          final leftPad = 1.0 + idx * (1.0 / n);
                          final rightPad = 1.0 + (n - idx - 1) * (1.0 / n);
                          return Positioned(
                            top: top, left: leftPad, right: rightPad, height: h,
                            child: GestureDetector(
                              onTap: () => _showDetail(c),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  gradient: active
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(c.color).withAlpha(230), Color(c.color)],
                                        )
                                      : null,
                                  color: active ? null : const Color(0xFFBDBDBD),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(c.name,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? Colors.white : Colors.grey[600]),
                                        maxLines: 3, overflow: TextOverflow.ellipsis),
                                    if (c.classroom.isNotEmpty)
                                      Text(c.classroom,
                                          style: TextStyle(fontSize: 8, color: active ? const Color(0xCCFFFFFF) : Colors.grey[600]),
                                          maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ),
                          );
                        });
                      }).toList();
                    })(),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text('$label：', style: TextStyle(color: Colors.grey[600])),
            Flexible(child: Text(value)),
          ],
        ),
      );
}

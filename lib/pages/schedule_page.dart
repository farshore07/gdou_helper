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
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Color(c.color),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (!active) ...[
              const SizedBox(height: 4),
              Text(
                '非本周',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            _detail(Icons.person_outline, '教师', c.teacher),
            _detail(Icons.location_on_outlined, '教室', c.classroom),
            _detail(
              Icons.school_outlined,
              '学分',
              (c.credit?.trim().isEmpty ?? true)
                  ? '未知'
                  : '${c.credit!.trim()} 学分',
            ),
            _detail(
              Icons.access_time,
              '时间',
              '${_dayLabels[c.dayOfWeek - 1]} 第${c.startPeriod}-${c.startPeriod + c.duration - 1}节',
            ),
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

  void _showCoursePicker(List<Course> courses) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('选择要查看的课程')),
          ...courses.map(
            (course) => ListTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(course.color),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              title: Text(course.name),
              subtitle: Text(
                '${_dayLabels[course.dayOfWeek - 1]} 第${course.startPeriod}-${course.startPeriod + course.duration - 1}节',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showDetail(course);
              },
            ),
          ),
        ],
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
    final weekStart = _semesterStart(
      semester,
    ).add(Duration(days: (_week - 1) * 7));

    // 计算今天对应星期几（仅当查看本周时有效）
    final todayIdx = () {
      if (_week != _currentWeekForSemester(semester)) {
        return -1;
      }
      final now = DateTime.now();
      for (var i = 0; i < 7; i++) {
        final d = weekStart.add(Duration(days: i));
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          return i;
        }
      }
      return -1;
    }();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('课表', style: TextStyle(fontSize: 16)),
            Text(semester, style: TextStyle(fontSize: 11, color: cs.outline)),
          ],
        ),
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
              if (_week != cur) {
                _goWeek(cur);
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: asyncCourses.isLoading
          ? const Center(child: CircularProgressIndicator())
          : asyncCourses.hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: cs.error),
                    const SizedBox(height: 12),
                    Text(
                      '加载失败',
                      style: TextStyle(fontSize: 16, color: cs.error),
                    ),
                    Text(
                      '${asyncCourses.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.outline),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(timetableProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          : courses.isEmpty
          ? Center(
              child: Text('暂无课表数据', style: TextStyle(color: cs.outline)),
            )
          : Column(
              children: [
                // ── 星期头（固定） ──
                Row(
                  children: [
                    const SizedBox(width: _timeW),
                    ...List.generate(7, (i) {
                      final day = weekStart.add(Duration(days: i));
                      final isToday = i == todayIdx;
                      return Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isToday ? cs.primary : gridColor,
                                width: isToday ? 2 : 1,
                              ),
                            ),
                            color: isToday
                                ? cs.primary.withAlpha(25)
                                : cs.surfaceContainerHighest.withAlpha(80),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _dayLabels[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isToday ? cs.primary : cs.onSurface,
                                ),
                              ),
                              Text(
                                '${day.month}/${day.day}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isToday ? cs.primary : cs.outline,
                                ),
                              ),
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
                    itemBuilder: (_, pageIndex) => _buildGrid(
                      courses,
                      pageIndex + 1,
                      gridColor,
                      cs,
                      todayIdx,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGrid(
    List<Course> courses,
    int week,
    Color gridColor,
    ColorScheme cs,
    int todayIdx,
  ) {
    return SingleChildScrollView(
      child: SizedBox(
        height: _periods * _rowH,
        child: Row(
          children: [
            // ── 节次列 ──
            SizedBox(
              width: _timeW,
              child: Column(
                children: List.generate(_periods, (i) {
                  final isBreak = i == 4 || i == 8;
                  return Container(
                    height: _rowH,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isBreak ? cs.primary.withAlpha(70) : gridColor,
                          width: isBreak ? 1.5 : 1,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          _periodTimes[i],
                          style: TextStyle(fontSize: 8, color: cs.outline),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            // ── 每天一列 ──
            ...List.generate(7, (day) {
              final dayCourses = courses
                  .where((c) => c.dayOfWeek == day + 1)
                  .toList();
              return Expanded(
                child: Stack(
                  children: [
                    // 今天列背景高亮
                    if (day == todayIdx)
                      Positioned.fill(
                        child: Container(color: cs.primary.withAlpha(8)),
                      ),
                    ...List.generate(_periods, (i) {
                      final isBreak = i == 4 || i == 8;
                      return Positioned(
                        top: i * _rowH,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: _rowH,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: isBreak
                                    ? cs.primary.withAlpha(70)
                                    : gridColor,
                                width: isBreak ? 1.5 : 1,
                              ),
                              left: BorderSide(color: gridColor),
                            ),
                          ),
                        ),
                      );
                    }),
                    ..._renderCoursesForDay(dayCourses, week),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Widget> _renderCoursesForDay(List<Course> dayCourses, int week) {
    return groupCoursesForDay(dayCourses, week).map((group) {
      final c = group.visible;
      final top = (c.startPeriod - 1) * _rowH + 1;
      final h = c.duration * _rowH - 2;
      return Positioned(
        top: top,
        left: 1,
        right: 1,
        height: h,
        child: GestureDetector(
          onTap: () => group.courses.length == 1
              ? _showDetail(c)
              : _showCoursePicker(group.courses),
          child: c.startWeek <= week && week <= c.endWeek
              ? _activeCourse(c)
              : _inactiveCourse(c),
        ),
      );
    }).toList();
  }

  /// 本周课程：实心渐变 + 白字 + 阴影
  Widget _activeCourse(Course c) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(c.color).withAlpha(230), Color(c.color)],
      ),
      borderRadius: BorderRadius.circular(5),
      boxShadow: [
        BoxShadow(
          color: Color(c.color).withAlpha(60),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          c.name,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (c.classroom.isNotEmpty)
          Text(
            c.classroom,
            style: const TextStyle(fontSize: 8, color: Color(0xCCFFFFFF)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    ),
  );

  Widget _inactiveCourse(Course c) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Color(c.color).withAlpha(35),
      border: Border.all(color: Color(c.color).withAlpha(100)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Center(
      child: Text(
        c.name,
        style: TextStyle(fontSize: 10, color: Color(c.color).withAlpha(210)),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
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

class CourseDisplayGroup {
  final Course visible;
  final List<Course> courses;
  const CourseDisplayGroup(this.visible, this.courses);
}

List<CourseDisplayGroup> groupCoursesForDay(List<Course> courses, int week) {
  final sorted = [...courses]
    ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
  final groups = <List<Course>>[];
  var current = <Course>[];
  var currentEnd = 0;

  for (final course in sorted) {
    if (current.isNotEmpty && course.startPeriod > currentEnd) {
      groups.add(current);
      current = [];
      currentEnd = 0;
    }
    current.add(course);
    final end = course.startPeriod + course.duration - 1;
    if (end > currentEnd) currentEnd = end;
  }
  if (current.isNotEmpty) groups.add(current);

  return groups.map((group) {
    final visible = group.firstWhere(
      (course) => course.startWeek <= week && week <= course.endWeek,
      orElse: () => group.first,
    );
    return CourseDisplayGroup(visible, group);
  }).toList();
}

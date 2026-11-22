import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../providers/data_providers.dart';
import '../providers/semester_provider.dart';
import '../services/notification_service.dart';

const _prefCourseEnabledKey = 'reminder_course_enabled';
const _prefExamEnabledKey = 'reminder_exam_enabled';

/// GDOU 每节课实际开始时间（小时, 分钟），与课表页面保持一致。
const List<(int, int)> gdouPeriodStartTimes = [
  (8, 10), // 第 1 节
  (9, 0), // 第 2 节
  (10, 15), // 第 3 节
  (11, 5), // 第 4 节
  (14, 30), // 第 5 节
  (15, 20), // 第 6 节
  (16, 30), // 第 7 节
  (17, 20), // 第 8 节
  (19, 30), // 第 9 节
  (20, 25), // 第 10 节
];

class ScheduledReminder {
  final int id;
  final String title;
  final String body;
  final DateTime when;

  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
  });
}

DateTime _semesterStartDate(String semester) {
  final parts = semester.split('-');
  final term = parts.length > 2 ? int.tryParse(parts[2]) ?? 1 : 1;
  final y1 = int.tryParse(parts[0]) ?? DateTime.now().year;
  final y2 = int.tryParse(parts.length > 1 ? parts[1] : parts[0]) ?? y1;
  return DateTime(term == 1 ? y1 : y2, term == 1 ? 9 : 3, 1);
}

int _weekNumberForDate(DateTime date, String semester) {
  final start = _semesterStartDate(semester);
  final dayOnly = DateTime(date.year, date.month, date.day);
  if (dayOnly.isBefore(start)) return 0;
  return (dayOnly.difference(start).inDays ~/ 7) + 1;
}

/// 生成未来 [horizonDays] 天内的精确上课提醒（按真实节次时间与单双周/跳周过滤，避免通知 ID 冲突）。
List<ScheduledReminder> buildCourseReminders(
  List<Course> courses, {
  required String semester,
  DateTime? now,
  int horizonDays = 14,
  int leadMinutes = 15,
}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final reminders = <ScheduledReminder>[];
  final usedIds = <int>{};

  for (var offset = 0; offset < horizonDays; offset++) {
    final day = today.add(Duration(days: offset));
    final week = _weekNumberForDate(day, semester);
    if (week < 1 || week > 25) continue;

    for (final course in courses) {
      if (course.dayOfWeek != day.weekday) continue;
      if (!course.isActiveInWeek(week)) continue;
      if (course.startPeriod < 1 ||
          course.startPeriod > gdouPeriodStartTimes.length) {
        continue;
      }

      final (startHour, startMinute) =
          gdouPeriodStartTimes[course.startPeriod - 1];
      final classStart = DateTime(
        day.year,
        day.month,
        day.day,
        startHour,
        startMinute,
      );
      final notifyTime = classStart.subtract(Duration(minutes: leadMinutes));
      if (!notifyTime.isAfter(current)) continue;

      final key =
          '${course.semester}:${course.id}:${day.year}-${day.month}-${day.day}:${course.startPeriod}';
      var id = 100 + (_stableHash(key) % 9000);
      while (!usedIds.add(id)) {
        id = 100 + ((id - 100 + 1) % 9000);
      }

      final startStr =
          '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
      final place = course.classroom.isNotEmpty ? ' @ ${course.classroom}' : '';
      reminders.add(
        ScheduledReminder(
          id: id,
          title: '上课提醒（$startStr）',
          body: '${course.name}$place',
          when: notifyTime,
        ),
      );
    }
  }
  return reminders;
}

/// 生成未来考试前一天 20:00 的提醒列表（唯一通知 ID 防覆盖）。
List<ScheduledReminder> buildExamReminders(
  List<Exam> exams, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final reminders = <ScheduledReminder>[];
  final usedIds = <int>{};

  for (final exam in exams) {
    final remindDate = exam.date.subtract(const Duration(days: 1));
    final notifyTime = DateTime(
      remindDate.year,
      remindDate.month,
      remindDate.day,
      20,
      0,
    );
    if (!notifyTime.isAfter(current)) continue;

    final key =
        '${exam.id}:${exam.date.year}-${exam.date.month}-${exam.date.day}:${exam.startTime.hour}:${exam.startTime.minute}';
    var id = 10000 + (_stableHash(key) % 9000);
    while (!usedIds.add(id)) {
      id = 10000 + ((id - 10000 + 1) % 9000);
    }

    final startStr =
        '${exam.startTime.hour.toString().padLeft(2, '0')}:${exam.startTime.minute.toString().padLeft(2, '0')}';
    final place = exam.location.isNotEmpty ? ' @ ${exam.location}' : '';
    reminders.add(
      ScheduledReminder(
        id: id,
        title: '考试提醒',
        body: '明天 $startStr ${exam.courseName}$place',
        when: notifyTime,
      ),
    );
  }
  return reminders;
}

int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

class ReminderNotifier extends Notifier<ReminderState> {
  int _scheduleSeq = 0;

  @override
  ReminderState build() {
    ref.listen(timetableProvider, (_, next) {
      next.whenData((_) => _reschedule());
    });
    ref.listen(examsProvider, (_, next) {
      next.whenData((_) => _reschedule());
    });
    ref.listen(semesterProvider, (_, _) {
      _reschedule();
    });

    // 在 build() 返回初始状态后再异步加载持久化开关并执行首次排程，避免访问未初始化 state
    Future.microtask(_loadPrefsAndSchedule);
    return const ReminderState();
  }

  Future<void> _loadPrefsAndSchedule() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      final courseEnabled = sp.getBool(_prefCourseEnabledKey) ?? true;
      final examEnabled = sp.getBool(_prefExamEnabledKey) ?? true;
      state = ReminderState(
        courseEnabled: courseEnabled,
        examEnabled: examEnabled,
      );
      await _reschedule();
    } catch (e) {
      debugPrint('加载提醒配置失败: $e');
    }
  }

  Future<void> toggleCourse(bool v) async {
    state = state.copyWith(courseEnabled: v);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_prefCourseEnabledKey, v);
      if (v) {
        await ensureNotificationPermissions(requestExactAlarm: true);
      }
      await _reschedule();
    } catch (e) {
      debugPrint('更新上课提醒失败: $e');
    }
  }

  Future<void> toggleExam(bool v) async {
    state = state.copyWith(examEnabled: v);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_prefExamEnabledKey, v);
      if (v) {
        await ensureNotificationPermissions(requestExactAlarm: true);
      }
      await _reschedule();
    } catch (e) {
      debugPrint('更新考试提醒失败: $e');
    }
  }

  Future<void> _reschedule() async {
    if (!ref.mounted) return;
    final seq = ++_scheduleSeq;
    final currentState = state;
    final courses = ref.read(timetableProvider).asData?.value ?? const [];
    final exams = ref.read(examsProvider).asData?.value ?? const [];
    final semester = ref.read(semesterProvider);

    try {
      await cancelAllNotifications();
      if (!ref.mounted || seq != _scheduleSeq) return;

      final pending = <ScheduledReminder>[
        if (currentState.courseEnabled)
          ...buildCourseReminders(courses, semester: semester),
        if (currentState.examEnabled) ...buildExamReminders(exams),
      ];

      for (final item in pending) {
        if (!ref.mounted || seq != _scheduleSeq) return;
        await scheduleNotification(
          id: item.id,
          title: item.title,
          body: item.body,
          when: item.when,
          repeatWeekly: false,
        );
      }
    } catch (e) {
      debugPrint('排程提醒通知失败: $e');
    }
  }
}

final reminderProvider = NotifierProvider<ReminderNotifier, ReminderState>(
  ReminderNotifier.new,
);

class ReminderState {
  final bool courseEnabled;
  final bool examEnabled;

  const ReminderState({this.courseEnabled = true, this.examEnabled = true});

  ReminderState copyWith({bool? courseEnabled, bool? examEnabled}) =>
      ReminderState(
        courseEnabled: courseEnabled ?? this.courseEnabled,
        examEnabled: examEnabled ?? this.examEnabled,
      );
}

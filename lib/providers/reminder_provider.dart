import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../providers/data_providers.dart';
import '../services/notification_service.dart';

class ReminderNotifier extends Notifier<ReminderState> {
  @override
  ReminderState build() {
    // 监听课表和考试数据，数据就绪自动排提醒
    ref.listen(timetableProvider, (_, next) {
      next.whenData((courses) {
        if (!state.courseEnabled) return;
        try {
          final exams = ref.read(examsProvider).asData?.value ?? [];
          cancelAllNotifications();
          _scheduleAll(courses, exams);
        } catch (_) {}
      });
    });
    ref.listen(examsProvider, (_, next) {
      next.whenData((exams) {
        if (!state.examEnabled) return;
        try {
          final courses = ref.read(timetableProvider).asData?.value ?? [];
          cancelAllNotifications();
          _scheduleAll(courses, exams);
        } catch (_) {}
      });
    });

    // 如果数据已有，立即排一次
    try {
      final courses = ref.read(timetableProvider).asData?.value ?? [];
      final exams = ref.read(examsProvider).asData?.value ?? [];
      if (courses.isNotEmpty || exams.isNotEmpty) {
        _scheduleAll(courses, exams);
      }
    } catch (_) {
      // provider 可能在 error/loading 状态，忽略
    }

    return const ReminderState();
  }

  void _scheduleAll(List<Course> courses, List<Exam> exams) {
    cancelAllNotifications();
    if (state.courseEnabled) _scheduleCourses(courses);
    if (state.examEnabled) _scheduleExams(exams);
  }

  void toggleCourse(bool v) {
    state = state.copyWith(courseEnabled: v);
    try {
      final courses = ref.read(timetableProvider).asData?.value ?? [];
      final exams = ref.read(examsProvider).asData?.value ?? [];
      _scheduleAll(courses, exams);
    } catch (_) {}
  }

  void toggleExam(bool v) {
    state = state.copyWith(examEnabled: v);
    try {
      final courses = ref.read(timetableProvider).asData?.value ?? [];
      final exams = ref.read(examsProvider).asData?.value ?? [];
      _scheduleAll(courses, exams);
    } catch (_) {}
  }

  void _scheduleCourses(List<Course> courses) {
    final now = DateTime.now();
    for (final c in courses) {
      // 每节 45 分钟，第一节课 8:10 开始
      final startMinutes = 8 * 60 + 10 + (c.startPeriod - 1) * 45;
      final notifyMinutes = startMinutes - 15; // 提前 15 分钟
      final hour = notifyMinutes ~/ 60;
      final minute = notifyMinutes % 60;

      // 计算下一个该周几的日期
      var target = DateTime(now.year, now.month, now.day, hour, minute);
      var dayDiff = c.dayOfWeek - now.weekday;
      if (dayDiff < 0) {
        dayDiff += 7;
      } else if (dayDiff == 0 && target.isBefore(now)) {
        dayDiff = 7;
      }
      target = target.add(Duration(days: dayDiff));

      final id = c.id.hashCode.abs() % 9000 + 100;
      scheduleNotification(
        id: id,
        title: '上课提醒',
        body: '${c.name}${c.classroom.isNotEmpty ? " @ ${c.classroom}" : ""}',
        when: target,
        repeatWeekly: true,
      );
    }
  }

  void _scheduleExams(List<Exam> exams) {
    for (final e in exams) {
      // 考试前一天 20:00 提醒
      final remindDate = e.date.subtract(const Duration(days: 1));
      final notifyTime = DateTime(
          remindDate.year, remindDate.month, remindDate.day, 20, 0);

      // 只提醒未来的考试
      if (notifyTime.isBefore(DateTime.now())) continue;

      final id = 10000 + (e.id.hashCode.abs() % 9000);
      scheduleNotification(
        id: id,
        title: '考试提醒',
        body: '明天 ${e.courseName} @ ${e.location}',
        when: notifyTime,
        repeatWeekly: false,
      );
    }
  }
}

final reminderProvider =
    NotifierProvider<ReminderNotifier, ReminderState>(ReminderNotifier.new);

class ReminderState {
  final bool courseEnabled;
  final bool examEnabled;

  const ReminderState({
    this.courseEnabled = true,
    this.examEnabled = true,
  });

  ReminderState copyWith({bool? courseEnabled, bool? examEnabled}) =>
      ReminderState(
        courseEnabled: courseEnabled ?? this.courseEnabled,
        examEnabled: examEnabled ?? this.examEnabled,
      );
}

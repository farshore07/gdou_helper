import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../providers/data_providers.dart';
import '../providers/semester_provider.dart';
import '../services/notification_service.dart';

const _prefCourseEnabledKey = 'reminder_course_enabled';
const _prefExamEnabledKey = 'reminder_exam_enabled';
const _prefScheduleSignatureKey = 'reminder_schedule_signature';

/// 系统通知底层操作抽象，用于串行排程与并发打断测试注入。
class ReminderNotificationBackend {
  final Future<void> Function() cancelAll;
  final Future<AndroidScheduleMode> Function() resolveMode;
  final Future<void> Function({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required AndroidScheduleMode? androidScheduleMode,
  })
  schedule;
  final Future<void> Function() yieldFrame;

  const ReminderNotificationBackend({
    required this.cancelAll,
    required this.resolveMode,
    required this.schedule,
    required this.yieldFrame,
  });

  static final ReminderNotificationBackend live = ReminderNotificationBackend(
    cancelAll: cancelAllNotifications,
    resolveMode: resolveAndroidScheduleMode,
    schedule: ({
      required int id,
      required String title,
      required String body,
      required DateTime when,
      required AndroidScheduleMode? androidScheduleMode,
    }) => scheduleNotification(
      id: id,
      title: title,
      body: body,
      when: when,
      repeatWeekly: false,
      androidScheduleMode: androidScheduleMode,
    ),
    yieldFrame: () => Future<void>.delayed(const Duration(milliseconds: 16)),
  );
}

final reminderBackendProvider = Provider<ReminderNotificationBackend>(
  (_) => ReminderNotificationBackend.live,
);

/// 单次排程的上课提醒数量上限（预留空间给考试提醒，低于 Android 单应用 500 闹钟限制）。
const int defaultMaxCourseReminders = 300;

/// GDOU 每节课实际开始时间（小时, 分钟），作为后端未返回节次时间时的回退值。
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

DateTime _fallbackSemesterStartDate(String semester) {
  final parts = semester.split('-');
  final term = parts.length > 2 ? int.tryParse(parts[2]) ?? 1 : 1;
  final y1 = int.tryParse(parts[0]) ?? DateTime.now().year;
  final y2 = int.tryParse(parts.length > 1 ? parts[1] : parts[0]) ?? y1;
  return DateTime(term == 1 ? y1 : y2, term == 1 ? 9 : 3, 1);
}

/// 优先采用后端校历的学期起始日，缺失时回退到固定 9 月 1 日 / 3 月 1 日。
DateTime resolveSemesterStartDate(
  String semester, {
  DateTime? overrideStartDate,
}) {
  if (overrideStartDate != null) {
    return DateTime(
      overrideStartDate.year,
      overrideStartDate.month,
      overrideStartDate.day,
    );
  }
  return _fallbackSemesterStartDate(semester);
}

/// 优先采用后端返回的节次开始时间，缺失时回退到内置节次表。
(int, int)? resolvePeriodStartTime(
  int period, {
  Map<int, (int, int)>? overridePeriodStartTimes,
}) {
  final overridden = overridePeriodStartTimes?[period];
  if (overridden != null) return overridden;
  if (period < 1 || period > gdouPeriodStartTimes.length) return null;
  return gdouPeriodStartTimes[period - 1];
}

int _weekNumberForDate(DateTime date, DateTime semesterStart) {
  final dayOnly = DateTime(date.year, date.month, date.day);
  if (dayOnly.isBefore(semesterStart)) return 0;
  final diffDays = DateTime.utc(dayOnly.year, dayOnly.month, dayOnly.day)
      .difference(
        DateTime.utc(semesterStart.year, semesterStart.month, semesterStart.day),
      )
      .inDays;
  return (diffDays ~/ 7) + 1;
}

/// 生成精确上课提醒：
/// - 优先采用后端校历 [semesterStartDate] 与节次时间 [periodStartTimes]，缺失时回退内置默认值；
/// - 未显式指定 [horizonDays] 时覆盖当前学期剩余全部有效教学周（按时间升序最多保留 [maxReminders] 条）。
List<ScheduledReminder> buildCourseReminders(
  List<Course> courses, {
  required String semester,
  DateTime? now,
  DateTime? semesterStartDate,
  Map<int, (int, int)>? periodStartTimes,
  int? horizonDays,
  int maxReminders = defaultMaxCourseReminders,
  int leadMinutes = 15,
}) {
  if (courses.isEmpty || maxReminders <= 0) return const [];
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final start = resolveSemesterStartDate(
    semester,
    overrideStartDate: semesterStartDate,
  );

  late final DateTime scanStart;
  late final DateTime scanEnd;
  if (horizonDays != null) {
    if (horizonDays <= 0) return const [];
    scanStart = today;
    scanEnd = DateTime(today.year, today.month, today.day + horizonDays - 1);
  } else {
    var maxWeek = 0;
    for (final course in courses) {
      final candidate = course.weekNumbers.isNotEmpty
          ? course.weekNumbers.reduce((a, b) => a > b ? a : b)
          : course.endWeek;
      if (candidate > maxWeek) maxWeek = candidate;
    }
    if (maxWeek <= 0) return const [];
    if (maxWeek > 25) maxWeek = 25;
    scanStart = today.isAfter(start) ? today : start;
    scanEnd = DateTime(start.year, start.month, start.day + maxWeek * 7 - 1);
    if (scanStart.isAfter(scanEnd)) return const [];
  }

  final reminders = <ScheduledReminder>[];
  final usedIds = <int>{};

  for (
    var day = scanStart;
    !day.isAfter(scanEnd);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    final week = _weekNumberForDate(day, start);
    if (week < 1 || week > 25) continue;

    for (final course in courses) {
      if (course.dayOfWeek != day.weekday) continue;
      if (!course.isActiveInWeek(week)) continue;
      final periodStart = resolvePeriodStartTime(
        course.startPeriod,
        overridePeriodStartTimes: periodStartTimes,
      );
      if (periodStart == null) continue;

      final (startHour, startMinute) = periodStart;
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

  reminders.sort((a, b) {
    final cmp = a.when.compareTo(b.when);
    return cmp != 0 ? cmp : a.id.compareTo(b.id);
  });
  if (reminders.length > maxReminders) {
    return reminders.sublist(0, maxReminders);
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

/// 计算提醒列表的稳定指纹，用于在数据未变化时跳过重复的全量系统闹钟重写。
String computeReminderSignature(List<ScheduledReminder> reminders) {
  final buf = StringBuffer('${reminders.length}:');
  for (final r in reminders) {
    buf
      ..write(r.id)
      ..write('|')
      ..write(r.when.millisecondsSinceEpoch)
      ..write('|')
      ..write(r.title)
      ..write('|')
      ..write(r.body)
      ..write(';');
  }
  return '${reminders.length}_${_stableHash(buf.toString())}';
}

class ReminderNotifier extends Notifier<ReminderState> {
  int _desiredVersion = 0;
  bool _pendingForce = false;
  Future<void>? _activeWorker;
  Timer? _debounceTimer;
  String? _lastSignature;

  @override
  ReminderState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _desiredVersion++;
    });
    ref.listen(timetableProvider, (_, next) {
      next.whenData((_) => _scheduleDebounced());
    });
    ref.listen(examsProvider, (_, next) {
      next.whenData((_) => _scheduleDebounced());
    });
    ref.listen(semesterProvider, (_, _) {
      _scheduleDebounced();
    });
    ref.listen(timetableMetaProvider, (_, _) {
      _scheduleDebounced();
    });

    // 在 build() 返回初始状态后再异步加载持久化开关并执行首次排程，避免访问未初始化 state
    Future.microtask(_loadPrefsAndSchedule);
    return const ReminderState();
  }

  void _scheduleDebounced({bool force = false}) {
    if (!ref.mounted) return;
    if (force) _pendingForce = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!ref.mounted) return;
      _enqueueReschedule();
    });
  }

  Future<void> _loadPrefsAndSchedule() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      final courseEnabled = sp.getBool(_prefCourseEnabledKey) ?? true;
      final examEnabled = sp.getBool(_prefExamEnabledKey) ?? true;
      _lastSignature = sp.getString(_prefScheduleSignatureKey);
      state = ReminderState(
        courseEnabled: courseEnabled,
        examEnabled: examEnabled,
      );
      _scheduleDebounced();
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
      _debounceTimer?.cancel();
      await _enqueueReschedule(force: true);
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
      _debounceTimer?.cancel();
      await _enqueueReschedule(force: true);
    } catch (e) {
      debugPrint('更新考试提醒失败: $e');
    }
  }

  /// 立即将最新状态加入串行排程队列（供交互切换及测试调用）。
  Future<void> rescheduleNow({bool force = false}) {
    _debounceTimer?.cancel();
    return _enqueueReschedule(force: force);
  }

  Future<void> _enqueueReschedule({bool force = false}) {
    if (!ref.mounted) return Future<void>.value();
    if (force) _pendingForce = true;
    _desiredVersion++;
    _activeWorker ??= _drainRescheduleQueue().whenComplete(() {
      _activeWorker = null;
    });
    return _activeWorker!;
  }

  /// 串行执行系统通知的清除与写入：
  /// 1. 同一时刻只允许一个排程批次操作底层通知，避免并发 cancelAll 与 schedule 交错；
  /// 2. 执行 cancelAll 前先清除旧指纹，确保中途被打断（如 A -> B -> A）时不会误判为已排程；
  /// 3. 仅当整批全部写入完毕且未出现更新批次时，才持久化新指纹。
  Future<void> _drainRescheduleQueue() async {
    final backend = ref.read(reminderBackendProvider);
    var processedVersion = -1;

    while (ref.mounted && processedVersion != _desiredVersion) {
      final targetVersion = _desiredVersion;
      final force = _pendingForce;
      _pendingForce = false;
      processedVersion = targetVersion;

      final currentState = state;
      final courses = ref.read(timetableProvider).asData?.value ?? const [];
      final exams = ref.read(examsProvider).asData?.value ?? const [];
      final semester = ref.read(semesterProvider);
      final meta = ref.read(timetableMetaProvider)[semester];

      try {
        final pending = <ScheduledReminder>[
          if (currentState.courseEnabled)
            ...buildCourseReminders(
              courses,
              semester: semester,
              semesterStartDate: meta?.semesterStartDate,
              periodStartTimes: meta?.periodStartTimes,
            ),
          if (currentState.examEnabled) ...buildExamReminders(exams),
        ];

        final signature = computeReminderSignature(pending);
        if (!force && signature == _lastSignature) {
          continue;
        }

        // 清空系统通知前必须先让旧指纹失效，防止后续切回旧学期时跳过重排
        _lastSignature = null;
        final sp = await SharedPreferences.getInstance();
        await sp.remove(_prefScheduleSignatureKey);
        if (!ref.mounted) return;
        if (targetVersion != _desiredVersion) continue;

        await backend.cancelAll();
        if (!ref.mounted) return;
        if (targetVersion != _desiredVersion) continue;

        final scheduleMode = pending.isEmpty
            ? null
            : await backend.resolveMode();
        if (!ref.mounted) return;
        if (targetVersion != _desiredVersion) continue;

        var interrupted = false;
        for (var i = 0; i < pending.length; i++) {
          if (!ref.mounted) return;
          if (targetVersion != _desiredVersion) {
            interrupted = true;
            break;
          }
          final item = pending[i];
          await backend.schedule(
            id: item.id,
            title: item.title,
            body: item.body,
            when: item.when,
            androidScheduleMode: scheduleMode,
          );
          // 每排程 8 条主动让出一个渲染帧，避免大量平台通道写入阻塞 UI 滑动
          if ((i + 1) % 8 == 0) {
            await backend.yieldFrame();
          }
        }

        if (!ref.mounted) return;
        if (interrupted || targetVersion != _desiredVersion) {
          continue;
        }

        _lastSignature = signature;
        await sp.setString(_prefScheduleSignatureKey, signature);
      } catch (e) {
        debugPrint('排程提醒通知失败: $e');
      }
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

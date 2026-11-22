import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final _plugin = FlutterLocalNotificationsPlugin();
bool _notificationsInitialized = false;

const _reminderNotificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'gdou_reminder',
    '教务提醒',
    channelDescription: '课程和考试提醒',
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  ),
);

Future<void> initNotifications() async {
  if (_notificationsInitialized) return;
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

  const android = AndroidInitializationSettings('ic_notification');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await _plugin.initialize(
    settings: const InitializationSettings(android: android, iOS: ios),
  );
  _notificationsInitialized = true;

  await ensureNotificationPermissions(requestExactAlarm: false);
}

Future<void> ensureNotificationPermissions({
  bool requestExactAlarm = false,
}) async {
  final androidImpl = _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (androidImpl == null) return;
  try {
    await androidImpl.requestNotificationsPermission();
    if (requestExactAlarm) {
      final canExact = await androidImpl.canScheduleExactNotifications();
      if (canExact != true) {
        await androidImpl.requestExactAlarmsPermission();
      }
    }
  } catch (e) {
    debugPrint('通知权限检查失败: $e');
  }
}

Future<AndroidScheduleMode> resolveAndroidScheduleMode() async {
  final androidImpl = _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (androidImpl == null) {
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }
  try {
    final canExact = await androidImpl.canScheduleExactNotifications();
    if (canExact == true) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
  } catch (_) {}
  return AndroidScheduleMode.inexactAllowWhileIdle;
}

Future<void> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime when,
  bool repeatWeekly = false,
  AndroidScheduleMode? androidScheduleMode,
}) async {
  if (!when.isAfter(DateTime.now())) return;
  if (!_notificationsInitialized) {
    await initNotifications();
  }

  final tzDate = tz.TZDateTime.from(when, tz.local);
  final mode = androidScheduleMode ?? await resolveAndroidScheduleMode();
  final matchComponents = repeatWeekly
      ? DateTimeComponents.dayOfWeekAndTime
      : null;

  try {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      notificationDetails: _reminderNotificationDetails,
      androidScheduleMode: mode,
      matchDateTimeComponents: matchComponents,
    );
  } on PlatformException {
    // 精确闹钟权限受限时降级为非精确提醒，确保不静默丢失
    if (mode != AndroidScheduleMode.inexactAllowWhileIdle) {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: _reminderNotificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
      );
    } else {
      rethrow;
    }
  }
}

Future<void> showTestNotification() async {
  if (!_notificationsInitialized) {
    await initNotifications();
  }
  await _plugin.show(
    id: DateTime.now().millisecondsSinceEpoch % 100000,
    title: '测试提醒',
    body: '如果你看到这条通知，说明提醒功能正常工作！',
    notificationDetails: _reminderNotificationDetails,
  );
}

Future<void> cancelAllNotifications() async {
  if (!_notificationsInitialized) return;
  await _plugin.cancelAll();
}

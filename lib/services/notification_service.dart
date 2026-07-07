import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

final _plugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
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

  final androidImpl = _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  // 仅请求通知权限，不请求闹钟权限
  await androidImpl?.requestNotificationsPermission();
}

Future<void> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime when,
  bool repeatWeekly = false,
}) async {
  final tzDate = tz.TZDateTime.from(when, tz.local);
  await _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: tzDate,
    notificationDetails: const NotificationDetails(
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
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents:
        repeatWeekly ? DateTimeComponents.dayOfWeekAndTime : null,
  );
}

Future<void> showTestNotification() async {
  await _plugin.show(
    id: DateTime.now().millisecondsSinceEpoch % 100000,
    title: '测试提醒',
    body: '如果你看到这条通知，说明提醒功能正常工作！',
    notificationDetails: const NotificationDetails(
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
    ),
  );
}

Future<void> cancelAllNotifications() => _plugin.cancelAll();

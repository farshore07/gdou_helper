import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gdou_helper/config/legal_documents.dart';
import 'package:gdou_helper/models/course.dart';
import 'package:gdou_helper/models/exam.dart';
import 'package:gdou_helper/pages/about_page.dart';
import 'package:gdou_helper/pages/legal_document_page.dart';
import 'package:gdou_helper/pages/login_page.dart';
import 'package:gdou_helper/pages/schedule_page.dart';
import 'package:gdou_helper/pages/settings_page.dart';
import 'package:gdou_helper/pages/shell.dart';
import 'package:gdou_helper/providers/auth_provider.dart';
import 'package:gdou_helper/providers/data_providers.dart';
import 'package:gdou_helper/providers/reminder_provider.dart';
import 'package:gdou_helper/providers/semester_provider.dart';
import 'package:gdou_helper/providers/theme_provider.dart';
import 'package:gdou_helper/services/api_service.dart';
import 'package:gdou_helper/services/cache_service.dart';
import 'package:gdou_helper/theme.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState initial;
  final Future<void> Function(
    _MockAuthNotifier notifier,
    String username,
    String password,
  )?
  onLogin;
  final Future<void> Function(
    _MockAuthNotifier notifier,
    String code,
    bool trustDevice,
  )?
  onVerifyMfa;

  _MockAuthNotifier(this.initial, {this.onLogin, this.onVerifyMfa});

  @override
  AuthState build() => initial;

  @override
  Future<void> login(
    String username,
    String password, {
    required bool remember,
  }) async {
    if (onLogin != null) {
      await onLogin!(this, username, password);
    }
  }

  @override
  Future<void> verifyMfaCode(String code, {bool trustDevice = true}) async {
    if (onVerifyMfa != null) {
      await onVerifyMfa!(this, code, trustDevice);
    }
  }

  void setStateForTest(AuthState next) {
    state = next;
  }
}

class _FakeHttpAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  _FakeHttpAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('P2-3 单双周与跳周课表精确周次', () {
    test('优先使用后端 week_numbers，第 2 周不误判为有课', () {
      final course = Course.fromApiJson({
        'course_code': 'CS101',
        'course_name': '算法设计',
        'teacher': '张老师',
        'classroom': '钟海楼0301',
        'weekday': '1',
        'periods': '1-2节',
        'weeks': '1-9周(单)',
        'week_numbers': [1, 3, 5, 7, 9],
      }, '2025-2026-2');

      expect(course.weekNumbers, [1, 3, 5, 7, 9]);
      expect(course.isActiveInWeek(1), isTrue);
      expect(course.isActiveInWeek(2), isFalse);
      expect(course.isActiveInWeek(3), isTrue);
      expect(course.isActiveInWeek(8), isFalse);
      expect(course.isActiveInWeek(9), isTrue);
      expect(course.weeksDisplay, '1-9周(单)');
    });

    test('旧缓存缺少 week_numbers 时准确解析单双周与跳周文本', () {
      final course = Course.fromApiJson({
        'course_code': 'CS102',
        'course_name': '编译原理',
        'weekday': '2',
        'periods': '3-4节',
        'weeks': '1-5周(单),8-10周(双),13周',
      }, '2025-2026-2');

      expect(course.weekNumbers, [1, 3, 5, 8, 10, 13]);
      expect(course.isActiveInWeek(1), isTrue);
      expect(course.isActiveInWeek(2), isFalse);
      expect(course.isActiveInWeek(6), isFalse);
      expect(course.isActiveInWeek(8), isTrue);
      expect(course.isActiveInWeek(9), isFalse);
      expect(course.isActiveInWeek(13), isTrue);
    });

    test('同节次单双周课程按精确周次切换可见课程', () {
      final oddCourse = Course.fromApiJson({
        'course_code': 'ODD',
        'course_name': '单周实验',
        'weekday': '1',
        'periods': '1-2节',
        'weeks': '1-9周(单)',
        'week_numbers': [1, 3, 5, 7, 9],
      }, '2025-2026-2');
      final evenCourse = Course.fromApiJson({
        'course_code': 'EVEN',
        'course_name': '双周实验',
        'weekday': '1',
        'periods': '1-2节',
        'weeks': '2-10周(双)',
        'week_numbers': [2, 4, 6, 8, 10],
      }, '2025-2026-2');

      final week1 = groupCoursesForDay([oddCourse, evenCourse], 1);
      final week2 = groupCoursesForDay([oddCourse, evenCourse], 2);
      expect(week1.single.visible.id, 'ODD');
      expect(week2.single.visible.id, 'EVEN');
    });
  });

  group('P2-1 MFA 验证成功后退出弹窗并返回登录前页面', () {
    testWidgets('真实 GoRouter + LoginPage 在 MFA 完成后返回原页面', (tester) async {
      late _MockAuthNotifier notifier;
      notifier = _MockAuthNotifier(
        const AuthState(),
        onLogin: (n, username, password) async {
          n.setStateForTest(
            n.state.copyWith(
              loading: false,
              mfaChallenge: MfaChallengeState(
                loginToken: 'tok-1',
                defaultMethod: 'wechat',
                selectedMethod: 'wechat',
                availableMethods: const ['wechat', 'sms'],
                message: '统一身份认证平台要求二次验证',
                username: username,
                password: password,
                remember: true,
              ),
            ),
          );
        },
        onVerifyMfa: (n, code, trustDevice) async {
          n.setStateForTest(
            AuthState(
              isLoggedIn: true,
              cookie: 'JSESSIONID=OK',
              username: '202311701234',
              sessionVersion: n.state.sessionVersion + 1,
            ),
          );
        },
      );

      final router = GoRouter(
        initialLocation: '/origin',
        routes: [
          GoRoute(
            path: '/origin',
            builder: (context, _) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('登录前页面'),
                    FilledButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('去登录'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => notifier)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // 从原页面进入登录页
      await tester.tap(find.text('去登录'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      // 输入账密触发 MFA 弹窗
      await tester.enterText(find.byType(TextField).at(0), '202311701234');
      await tester.enterText(find.byType(TextField).at(1), 'Pass@123');
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.text('安全二次验证'), findsOneWidget);

      // 输入动态码提交验证
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '654321',
      );
      await tester.tap(find.text('完成验证'));
      await tester.pumpAndSettle();

      // 同时断言已登录、弹窗与登录页均已关闭、回到登录前页面
      expect(notifier.state.isLoggedIn, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.text('登录前页面'), findsOneWidget);
    });
  });

  group('P2-2 会话过期且静默重登要求人工验证时提供继续验证入口并自动重试原查询', () {
    testWidgets('展示继续验证入口，续接保留事务完成 MFA 后自动重试课表查询', (tester) async {
      final originalAdapter = dio.httpClientAdapter;
      addTearDown(() => dio.httpClientAdapter = originalAdapter);

      var timetableCalls = 0;
      dio.httpClientAdapter = _FakeHttpAdapter((options) async {
        if (options.path == '/api/v1/jwxt/timetable') {
          timetableCalls++;
          final body = options.data as Map<String, dynamic>;
          if (body['cookie'] == 'JSESSIONID=EXPIRED') {
            return _jsonResponse(401, {
              'code': 'SESSION_EXPIRED',
              'message': '教务系统会话已过期',
              'data': null,
            });
          }
          return _jsonResponse(200, {
            'code': 'OK',
            'message': 'ok',
            'data': {
              'courses': [
                {
                  'course_code': 'CS999',
                  'course_name': '分布式系统',
                  'weekday': '1',
                  'periods': '1-2节',
                  'weeks': '1-8周(单)',
                  'week_numbers': [1, 3, 5, 7],
                },
              ],
            },
          });
        }
        return _jsonResponse(404, {
          'code': 'NOT_FOUND',
          'message': 'not found',
          'data': null,
        });
      });

      late _MockAuthNotifier notifier;
      notifier = _MockAuthNotifier(
        const AuthState(
          isLoggedIn: true,
          cookie: 'JSESSIONID=EXPIRED',
          username: '202311701234',
          sessionExpired: true,
          sessionVersion: 1,
          mfaChallenge: MfaChallengeState(
            loginToken: 'preserved-token',
            defaultMethod: 'wechat',
            selectedMethod: 'wechat',
            availableMethods: ['wechat', 'sms'],
            message: '需要完成企业微信二次验证',
            username: '202311701234',
            password: 'pwd',
            remember: true,
          ),
        ),
        onVerifyMfa: (n, code, trustDevice) async {
          n.setStateForTest(
            n.state.copyWith(
              isLoggedIn: true,
              cookie: 'JSESSIONID=FRESH',
              sessionExpired: false,
              clearChallenges: true,
              sessionVersion: n.state.sessionVersion + 1,
            ),
          );
        },
      );

      final router = GoRouter(
        initialLocation: '/schedule',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                AppShell(navigationShell: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/schedule',
                    builder: (_, _) => Consumer(
                      builder: (context, ref, _) {
                        final asyncCourses = ref.watch(timetableProvider);
                        return Scaffold(
                          body: Center(
                            child: Text(
                              asyncCourses.asData?.value
                                      .map((c) => c.name)
                                      .join(',') ??
                                  'loading',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/exam-score',
                    builder: (_, _) => const SizedBox(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(path: '/more', builder: (_, _) => const SizedBox()),
                ],
              ),
            ],
          ),
          GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => notifier)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // AppShell 顶部展示“继续验证”入口
      expect(find.text('继续验证'), findsOneWidget);

      // 点击“继续验证”直接进入 LoginPage 并自动弹出已保留的 MFA 弹窗
      await tester.tap(find.text('继续验证'));
      await tester.pumpAndSettle();
      expect(find.text('安全二次验证'), findsOneWidget);

      // 输入动态码完成验证 -> 关闭弹窗并返回课表页 -> 自动重试原课表查询
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '888888',
      );
      await tester.tap(find.text('完成验证'));
      await tester.pumpAndSettle();

      expect(notifier.state.sessionExpired, isFalse);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.text('继续验证'), findsNothing);
      expect(timetableCalls, greaterThanOrEqualTo(2));
      expect(find.text('分布式系统'), findsOneWidget);
    });
  });

  group('上课与考试提醒排程', () {
    test('按广海大真实节次时间提前 15 分钟、去重 ID 并按单双周过滤', () {
      // 2026-03-01 为 2025-2026-2 学期第 1 周起算日：
      // 2026-03-02（周一）属于第 1 周（单周），2026-03-09（周一）属于第 2 周（双周）
      final courses = [
        Course.fromApiJson({
          'course_code': 'CS101',
          'course_name': '高等数学',
          'classroom': '钟海楼0101',
          'weekday': '1',
          'periods': '1-2节',
          'weeks': '1-9周(单)',
          'week_numbers': [1, 3, 5, 7, 9],
        }, '2025-2026-2'),
        // 同一门课同周另一节（第 5 节 14:30 开始，提前 15 分钟应为 14:15）
        Course.fromApiJson({
          'course_code': 'CS101',
          'course_name': '高等数学',
          'classroom': '钟海楼0101',
          'weekday': '1',
          'periods': '5-6节',
          'weeks': '1-9周(单)',
          'week_numbers': [1, 3, 5, 7, 9],
        }, '2025-2026-2'),
        // 第 9 节 19:30 开始，提前 15 分钟应为 19:15
        Course.fromApiJson({
          'course_code': 'CS202',
          'course_name': '晚间公选',
          'classroom': '主楼0202',
          'weekday': '1',
          'periods': '9-10节',
          'weeks': '1-16周',
        }, '2025-2026-2'),
      ];

      final reminders = buildCourseReminders(
        courses,
        semester: '2025-2026-2',
        now: DateTime(2026, 3, 2, 7, 0),
        horizonDays: 14,
      );

      // 第 1 周周一 3 节 + 第 2 周周一 1 节（单周课 CS101 在第 2 周不排入）= 4 条
      expect(reminders.length, 4);
      final ids = reminders.map((r) => r.id).toSet();
      expect(ids.length, 4);

      final times = reminders.map((r) => r.when).toList();
      expect(times, contains(DateTime(2026, 3, 2, 7, 55)));
      expect(times, contains(DateTime(2026, 3, 2, 14, 15)));
      expect(times, contains(DateTime(2026, 3, 2, 19, 15)));
      expect(times, contains(DateTime(2026, 3, 9, 19, 15)));
      expect(times, isNot(contains(DateTime(2026, 3, 9, 7, 55))));
    });

    test('考试提醒在考试前一天 20:00 触发并跳过过去考试', () {
      final exams = [
        Exam(
          id: 'EX_OLD',
          courseName: '旧考试',
          date: DateTime(2026, 3, 1),
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 11, minute: 0),
          location: '旧考场',
        ),
        Exam(
          id: 'EX_NEW',
          courseName: '数据结构',
          date: DateTime(2026, 3, 10),
          startTime: const TimeOfDay(hour: 14, minute: 30),
          endTime: const TimeOfDay(hour: 16, minute: 30),
          location: '钟海楼0301',
        ),
      ];

      final reminders = buildExamReminders(
        exams,
        now: DateTime(2026, 3, 2, 10, 0),
      );
      expect(reminders.length, 1);
      expect(reminders.single.when, DateTime(2026, 3, 9, 20, 0));
      expect(reminders.single.body, contains('14:30 数据结构 @ 钟海楼0301'));
    });

    test('优先采用后端校历与节次时间计算单双周，避免开机日期偏差导致单双周排反', () {
      final courses = [
        Course.fromApiJson({
          'course_code': 'ODD',
          'course_name': '单周实验',
          'classroom': '实验楼A',
          'weekday': '1',
          'periods': '1-2节',
          'weeks': '1-9周(单)',
          'week_numbers': [1, 3, 5, 7, 9],
        }, '2025-2026-2'),
        Course.fromApiJson({
          'course_code': 'EVEN',
          'course_name': '双周实验',
          'classroom': '实验楼B',
          'weekday': '1',
          'periods': '1-2节',
          'weeks': '2-10周(双)',
          'week_numbers': [2, 4, 6, 8, 10],
        }, '2025-2026-2'),
      ];

      // 实际开学日为 2026-02-23（周一），因此 2026-03-02（周一）已是第 2 周（双周），
      // 若仍按固定 3 月 1 日计算会误排成单周课程。同时后端返回第 1 节 08:00 开始。
      final reminders = buildCourseReminders(
        courses,
        semester: '2025-2026-2',
        now: DateTime(2026, 3, 2, 7, 0),
        semesterStartDate: DateTime(2026, 2, 23),
        periodStartTimes: const {1: (8, 0)},
        horizonDays: 7,
      );

      expect(reminders.length, 1);
      expect(reminders.single.body, contains('双周实验'));
      expect(reminders.single.title, '上课提醒（08:00）');
      expect(reminders.single.when, DateTime(2026, 3, 2, 7, 45));
    });

    test('默认排程覆盖剩余整个学期（不限于 14 天）并遵守数量上限', () {
      final courses = [
        Course.fromApiJson({
          'course_code': 'CS301',
          'course_name': '软件工程',
          'classroom': '钟海楼0501',
          'weekday': '1',
          'periods': '1-2节',
          'weeks': '1-16周',
        }, '2025-2026-2'),
      ];

      // 不传 horizonDays：从第 1 周周一一直排到第 16 周周一，共 16 条（远超 14 天）
      final fullSemester = buildCourseReminders(
        courses,
        semester: '2025-2026-2',
        now: DateTime(2026, 3, 2, 7, 0),
        semesterStartDate: DateTime(2026, 3, 2),
      );
      expect(fullSemester.length, 16);
      expect(fullSemester.first.when, DateTime(2026, 3, 2, 7, 55));
      expect(fullSemester.last.when, DateTime(2026, 6, 15, 7, 55));

      // 验证上限截断后保留时间最早的前 N 条
      final capped = buildCourseReminders(
        courses,
        semester: '2025-2026-2',
        now: DateTime(2026, 3, 2, 7, 0),
        semesterStartDate: DateTime(2026, 3, 2),
        maxReminders: 5,
      );
      expect(capped.length, 5);
      expect(capped.last.when, DateTime(2026, 3, 30, 7, 55));

      // 验证提醒签名在内容一致时稳定、发生变化时不同（用于跳过无变化重排）
      final sig1 = computeReminderSignature(capped);
      final sig2 = computeReminderSignature(List.of(capped));
      final sig3 = computeReminderSignature(fullSemester);
      expect(sig1, sig2);
      expect(sig1, isNot(sig3));
    });
  });

  group('切换学期竞态保护与成绩明细空结果不缓存', () {
    test('切换学期后晚到的旧学期响应不会覆盖新学期课表、成绩与考试数据', () async {
      final originalAdapter = dio.httpClientAdapter;
      addTearDown(() => dio.httpClientAdapter = originalAdapter);

      const oldSemester = '2025-2026-1';
      const newSemester = '2025-2026-2';
      const username = '202311701234';

      // 预置旧学期与新学期缓存，使三个 provider 走“先回缓存 + 后台刷新”分支
      await CacheService.set(
        'timetable_${username}_$oldSemester',
        jsonEncode([
          {
            'course_code': 'OLD_C',
            'course_name': '旧学期缓存课',
            'weekday': '1',
            'periods': '1-2节',
            'weeks': '1-16周',
          },
        ]),
      );
      await CacheService.set(
        'timetable_${username}_$newSemester',
        jsonEncode([
          {
            'course_code': 'NEW_C',
            'course_name': '新学期课表',
            'weekday': '2',
            'periods': '3-4节',
            'weeks': '1-16周',
          },
        ]),
      );
      await CacheService.set(
        'grades_${username}_$oldSemester',
        jsonEncode([
          {'course_code': 'OLD_G', 'course_name': '旧学期成绩', 'grade': '80'},
        ]),
      );
      await CacheService.set(
        'grades_${username}_$newSemester',
        jsonEncode([
          {'course_code': 'NEW_G', 'course_name': '新学期成绩', 'grade': '95'},
        ]),
      );
      await CacheService.set(
        'exams_${username}_$oldSemester',
        jsonEncode([
          {
            'course_code': 'OLD_E',
            'course_name': '旧学期考试',
            'exam_time': '2026-01-10(09:00-11:00)',
          },
        ]),
      );
      await CacheService.set(
        'exams_${username}_$newSemester',
        jsonEncode([
          {
            'course_code': 'NEW_E',
            'course_name': '新学期考试',
            'exam_time': '2026-07-08(14:30-16:30)',
          },
        ]),
      );

      final oldTimetableGate = Completer<void>();
      final oldGradesGate = Completer<void>();
      final oldExamsGate = Completer<void>();

      dio.httpClientAdapter = _FakeHttpAdapter((options) async {
        final body = options.data as Map<String, dynamic>;
        final term = body['term'] as String?;
        if (options.path == '/api/v1/jwxt/timetable') {
          if (term == '3') {
            await oldTimetableGate.future;
            return _jsonResponse(200, {
              'code': 'OK',
              'message': 'ok',
              'data': {
                'courses': [
                  {
                    'course_code': 'OLD_FRESH',
                    'course_name': '晚到的旧课表',
                    'weekday': '1',
                    'periods': '1-2节',
                    'weeks': '1-16周',
                  },
                ],
                'semester_start_date': '2025-09-01',
              },
            });
          }
          return _jsonResponse(200, {
            'code': 'OK',
            'message': 'ok',
            'data': {
              'courses': [
                {
                  'course_code': 'NEW_FRESH',
                  'course_name': '新学期最新课表',
                  'weekday': '2',
                  'periods': '3-4节',
                  'weeks': '1-16周',
                },
              ],
              'semester_start_date': '2026-03-02',
              'period_times': [
                {'period': 1, 'start_time': '08:10', 'end_time': '08:55'},
              ],
            },
          });
        }
        if (options.path == '/api/v1/jwxt/grades') {
          if (term == '3') {
            await oldGradesGate.future;
            return _jsonResponse(200, {
              'code': 'OK',
              'message': 'ok',
              'data': {
                'items': [
                  {
                    'course_code': 'OLD_G_FRESH',
                    'course_name': '晚到的旧成绩',
                    'grade': '60',
                  },
                ],
              },
            });
          }
          return _jsonResponse(200, {
            'code': 'OK',
            'message': 'ok',
            'data': {
              'items': [
                {
                  'course_code': 'NEW_G_FRESH',
                  'course_name': '新学期最新成绩',
                  'grade': '98',
                },
              ],
            },
          });
        }
        if (options.path == '/api/v1/jwxt/exams') {
          if (term == '3') {
            await oldExamsGate.future;
            return _jsonResponse(200, {
              'code': 'OK',
              'message': 'ok',
              'data': {
                'items': [
                  {
                    'course_code': 'OLD_E_FRESH',
                    'course_name': '晚到的旧考试',
                    'exam_time': '2026-01-12(09:00-11:00)',
                  },
                ],
              },
            });
          }
          return _jsonResponse(200, {
            'code': 'OK',
            'message': 'ok',
            'data': {
              'items': [
                {
                  'course_code': 'NEW_E_FRESH',
                  'course_name': '新学期最新考试',
                  'exam_time': '2026-07-09(09:00-11:00)',
                },
              ],
            },
          });
        }
        return _jsonResponse(404, {
          'code': 'NOT_FOUND',
          'message': 'not found',
          'data': null,
        });
      });

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _MockAuthNotifier(
              const AuthState(
                isLoggedIn: true,
                username: username,
                cookie: 'JSESSIONID=OK',
                sessionVersion: 1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // 保持 listener 活跃，模拟页面挂载
      final sub1 = container.listen(timetableProvider, (_, _) {});
      final sub2 = container.listen(gradesProvider, (_, _) {});
      final sub3 = container.listen(examsProvider, (_, _) {});
      addTearDown(() {
        sub1.close();
        sub2.close();
        sub3.close();
      });

      // 1. 先停留在旧学期，等待旧缓存加载并触发延迟后台刷新
      container.read(semesterProvider.notifier).select(oldSemester);
      await container.read(timetableProvider.future);
      await container.read(gradesProvider.future);
      await container.read(examsProvider.future);

      // 2. 切到新学期并等待新学期后台刷新落定
      container.read(semesterProvider.notifier).select(newSemester);
      await container.read(timetableProvider.future);
      await container.read(gradesProvider.future);
      await container.read(examsProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(timetableProvider).asData?.value.single.name,
        '新学期最新课表',
      );
      expect(
        container.read(gradesProvider).asData?.value.single.courseName,
        '新学期最新成绩',
      );
      expect(
        container.read(examsProvider).asData?.value.single.courseName,
        '新学期最新考试',
      );
      // 同步确认后端校历已被写入 timetableMetaProvider
      expect(
        container.read(timetableMetaProvider)[newSemester]?.semesterStartDate,
        DateTime(2026, 3, 2),
      );

      // 3. 放行旧学期的晚到响应，状态必须仍保持新学期数据
      oldTimetableGate.complete();
      oldGradesGate.complete();
      oldExamsGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        container.read(timetableProvider).asData?.value.single.name,
        '新学期最新课表',
      );
      expect(
        container.read(gradesProvider).asData?.value.single.courseName,
        '新学期最新成绩',
      );
      expect(
        container.read(examsProvider).asData?.value.single.courseName,
        '新学期最新考试',
      );
    });

    test('fetchCachedGradeDetail 不缓存空 items 结果，后续恢复后能立即拿到明细', () async {
      final originalAdapter = dio.httpClientAdapter;
      addTearDown(() => dio.httpClientAdapter = originalAdapter);

      var calls = 0;
      dio.httpClientAdapter = _FakeHttpAdapter((options) async {
        calls++;
        if (calls == 1) {
          return _jsonResponse(200, {
            'code': 'OK',
            'message': 'ok',
            'data': {'course_name': '体育', 'items': []},
          });
        }
        return _jsonResponse(200, {
          'code': 'OK',
          'message': 'ok',
          'data': {
            'course_name': '体育',
            'items': [
              {'name': '期末', 'ratio': '100%', 'score': '92'},
            ],
          },
        });
      });

      const cacheKey = 'grade_detail_test_empty';
      final first = await fetchCachedGradeDetail(
        cacheKey,
        'JSESSIONID=OK',
        query: const {'jxb_id': 'J1'},
      );
      expect(first['items'], isEmpty);
      expect(await CacheService.get(cacheKey), isNull);

      final second = await fetchCachedGradeDetail(
        cacheKey,
        'JSESSIONID=OK',
        query: const {'jxb_id': 'J1'},
      );
      expect((second['items'] as List).length, 1);
      expect(calls, 2);

      // 非空结果已缓存，第 3 次直接命中缓存不再请求后端
      final third = await fetchCachedGradeDetail(
        cacheKey,
        'JSESSIONID=OK',
        query: const {'jxb_id': 'J1'},
      );
      expect((third['items'] as List).length, 1);
      expect(calls, 2);
    });

    testWidgets('课表页面在异步校历到达后自动同步所选周次，无需手动点击回到本周', (tester) async {
      final originalAdapter = dio.httpClientAdapter;
      addTearDown(() => dio.httpClientAdapter = originalAdapter);

      final gate = Completer<void>();
      dio.httpClientAdapter = _FakeHttpAdapter((options) async {
        if (options.path == '/api/v1/jwxt/timetable') {
          await gate.future;
          return _jsonResponse(200, {
            'code': 'OK',
            'message': 'ok',
            'data': {
              'courses': [
                {
                  'course_code': 'CS101',
                  'course_name': '算法分析',
                  'weekday': '1',
                  'periods': '1-2节',
                  'weeks': '1-16周',
                },
              ],
              // 实际开学日为 2026-02-23，因此在 2026-03-02 当天应处于第 2 周
              'semester_start_date': '2026-02-23',
            },
          });
        }
        return _jsonResponse(404, {
          'code': 'NOT_FOUND',
          'message': 'not found',
          'data': null,
        });
      });

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _MockAuthNotifier(
              const AuthState(
                isLoggedIn: true,
                username: '202311701234',
                cookie: 'JSESSIONID=OK',
                sessionVersion: 1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(semesterProvider.notifier).select('2025-2026-2');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SchedulePage(nowProvider: () => DateTime(2026, 3, 2, 10, 0)),
          ),
        ),
      );
      await tester.pump();

      // 校历尚未返回时按固定回退日 2026-03-01 计算，显示第 1 周
      expect(find.text('第1周'), findsOneWidget);

      // 放行后端课表与校历响应后，页面应自动同步到第 2 周
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('第2周'), findsOneWidget);
      expect(find.text('算法分析'), findsOneWidget);
    });

    test('本地缓存不因超过 7 天过期删除，仅在主动删除时清理', () async {
      final oneYearAgo = DateTime.now()
          .subtract(const Duration(days: 365))
          .millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'cache_timetable_old': '[{"course_name":"高等数学"}]',
        'cache_timetable_old_ts': oneYearAgo,
      });

      expect(
        await CacheService.get('timetable_old'),
        '[{"course_name":"高等数学"}]',
      );

      await CacheService.remove('timetable_old');
      expect(await CacheService.get('timetable_old'), isNull);

      await CacheService.set('grades_keep', '[]');
      await CacheService.clearAll();
      expect(await CacheService.get('grades_keep'), isNull);
    });
  });

  group('关于页面隐私声明与用户协议', () {
    testWidgets('点击隐私声明与用户协议按钮可分别打开对应内容页并返回', (tester) async {
      final router = GoRouter(
        initialLocation: '/about',
        routes: [
          GoRoute(path: '/about', builder: (_, _) => const AboutPage()),
          GoRoute(
            path: '/legal/privacy',
            builder: (_, _) =>
                const LegalDocumentPage(type: LegalDocumentType.privacy),
          ),
          GoRoute(
            path: '/legal/terms',
            builder: (_, _) =>
                const LegalDocumentPage(type: LegalDocumentType.terms),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      // 滚动到隐私声明入口并点击进入
      await tester.scrollUntilVisible(find.text('隐私声明'), 200);
      await tester.tap(find.text('隐私声明'));
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentPage), findsOneWidget);
      expect(find.text('一、信息处理范围与用途'), findsOneWidget);
      expect(find.textContaining('无数据库架构'), findsOneWidget);

      // 返回关于页
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AboutPage), findsOneWidget);

      // 点击用户协议进入
      await tester.scrollUntilVisible(find.text('用户协议'), 200);
      await tester.tap(find.text('用户协议'));
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentPage), findsOneWidget);
      expect(find.text('一、服务性质与声明'), findsOneWidget);
      expect(find.textContaining('非官方'), findsOneWidget);
    });
  });

  group('设置页面深色模式切换与持久化', () {
    testWidgets('切换深色模式实时生效并持久化，重启后恢复', (tester) async {
      Widget buildTestApp() => ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            final mode = ref.watch(themeModeProvider);
            return MaterialApp(
              theme: theme,
              darkTheme: darkTheme,
              themeMode: mode,
              home: const SettingsPage(),
            );
          },
        ),
      );

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      Brightness currentBrightness() =>
          Theme.of(tester.element(find.byType(SettingsPage))).brightness;

      // 默认浅色（测试环境 platformBrightness 为 light）
      expect(currentBrightness(), Brightness.light);

      // 打开深色模式开关
      await tester.tap(find.text('深色模式'));
      await tester.pumpAndSettle();
      expect(currentBrightness(), Brightness.dark);

      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('app_theme_mode'), 'dark');

      // 重建整个 ProviderScope 模拟重启 App，应自动恢复为深色模式
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(currentBrightness(), Brightness.dark);

      // 再次关闭深色模式开关，切回浅色并持久化
      await tester.tap(find.text('深色模式'));
      await tester.pumpAndSettle();
      expect(currentBrightness(), Brightness.light);
      expect(sp.getString('app_theme_mode'), 'light');
    });
  });
}

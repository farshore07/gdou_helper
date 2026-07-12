import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../models/course.dart';
import '../models/exam.dart';
import '../models/score.dart';
import '../providers/auth_provider.dart';
import '../providers/semester_provider.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

// ── 学期拆分："2025-2026-2" → academicYear: "2025-2026", term: "12" ──
// GDOU正方教务: 第一学期=3, 第二学期=12
// ── 401 自动重登 + 重试 ──
Future<T> _withAutoReLogin<T>(
  Ref ref,
  Future<T> Function(String cookie) fn,
) async {
  try {
    return await fn(ref.read(authProvider).cookie!);
  } on ApiException catch (error) {
    if (!isAuthenticationFailure(error)) rethrow;
    debugPrint('认证：检测到 Cookie 失效');
    if (!await ref.read(authProvider.notifier).silentReLogin()) rethrow;
    final cookie = ref.read(authProvider).cookie;
    if (cookie == null) rethrow;
    debugPrint('认证：开始重试原请求');
    return fn(cookie);
  }
}

const _termMap = {'1': '3', '2': '12'};
(String academicYear, String term) _splitSemester(String s) {
  final parts = s.split('-');
  final year = '${parts[0]}-${parts[1]}';
  final raw = parts.length > 2 ? parts[2] : '1';
  final term = _termMap[raw] ?? raw;
  return (year, term);
}

// ── 课表（缓存优先 + 后台刷新） ──
class TimetableNotifier extends AsyncNotifier<List<Course>> {
  @override
  Future<List<Course>> build() async {
    final auth = ref.watch(authProvider);
    final semester = ref.watch(semesterProvider);
    if (!auth.isLoggedIn || auth.cookie == null) return [];
    final cacheKey = 'timetable_${auth.username}_$semester';

    // 1. 先返回缓存
    final cached = await CacheService.get(cacheKey);
    if (cached != null) {
      final list = (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
      final courses = list.map((c) => Course.fromApiJson(c, semester)).toList();
      // 后台刷新
      _fetchAndCache(
        cacheKey,
        auth.cookie!,
        semester,
      ).catchError((_) => <Course>[]);
      return courses;
    }

    // 2. 无缓存，请求 API
    return _fetchAndCache(
      cacheKey,
      auth.cookie!,
      semester,
    ).catchError((_) => <Course>[]);
  }

  Future<List<Course>> _fetchAndCache(
    String key,
    String cookie,
    String semester,
  ) async {
    final (year, term) = _splitSemester(semester);
    final r = await _withAutoReLogin(
      ref,
      (currentCookie) => fetchTimetable(currentCookie, year, term),
    );
    if (!r.isOk || r.data == null) throw ApiException('课表数据为空');
    final courses = (r.data!['courses'] as List<dynamic>?) ?? [];
    final list = courses.map((c) {
      final m = c as Map<String, dynamic>;
      return Course.fromApiJson(m, semester);
    }).toList();
    // 写缓存
    CacheService.set(key, jsonEncode(r.data!['courses']));
    return list;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

final timetableProvider =
    AsyncNotifierProvider<TimetableNotifier, List<Course>>(
      TimetableNotifier.new,
    );

// ── 考试（缓存优先 + 后台刷新） ──
class ExamsNotifier extends AsyncNotifier<List<Exam>> {
  @override
  Future<List<Exam>> build() async {
    final auth = ref.watch(authProvider);
    final semester = ref.watch(semesterProvider);
    if (!auth.isLoggedIn || auth.cookie == null) return [];
    final cacheKey = 'exams_${auth.username}_$semester';
    final cached = await CacheService.get(cacheKey);
    if (cached != null) {
      final list = (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
      final exams = list.map((e) => Exam.fromApiJson(e)).toList();
      _fetchExams(cacheKey, auth.cookie!, semester).catchError((_) => <Exam>[]);
      return exams;
    }
    return _fetchExams(
      cacheKey,
      auth.cookie!,
      semester,
    ).catchError((_) => <Exam>[]);
  }

  Future<List<Exam>> _fetchExams(
    String key,
    String cookie,
    String semester,
  ) async {
    final (year, term) = _splitSemester(semester);
    final r = await _withAutoReLogin(
      ref,
      (currentCookie) => fetchExams(currentCookie, year, term),
    );
    if (!r.isOk || r.data == null) throw ApiException('考试数据为空');
    final items = (r.data!['items'] as List<dynamic>?) ?? [];
    CacheService.set(key, jsonEncode(items));
    return items
        .map((e) => Exam.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn || auth.cookie == null) return;
    final semester = ref.read(semesterProvider);
    final exams = await _fetchExams(
      'exams_${auth.username}_$semester',
      auth.cookie!,
      semester,
    );
    state = AsyncData(exams);
  }
}

class GradesNotifier extends AsyncNotifier<List<Score>> {
  @override
  Future<List<Score>> build() async {
    final auth = ref.watch(authProvider);
    final semester = ref.watch(semesterProvider);
    if (!auth.isLoggedIn || auth.cookie == null) return [];
    final cacheKey = 'grades_${auth.username}_$semester';
    final cached = await CacheService.get(cacheKey);
    if (cached != null) {
      final list = (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
      final scores = list.map((s) => Score.fromApiJson(s, semester)).toList();
      _fetchGrades(
        cacheKey,
        auth.cookie!,
        semester,
      ).catchError((_) => <Score>[]);
      return scores;
    }
    return _fetchGrades(
      cacheKey,
      auth.cookie!,
      semester,
    ).catchError((_) => <Score>[]);
  }

  Future<List<Score>> _fetchGrades(
    String key,
    String cookie,
    String semester,
  ) async {
    final (year, term) = _splitSemester(semester);
    final r = await _withAutoReLogin(
      ref,
      (currentCookie) => fetchGrades(currentCookie, year, term),
    );
    if (!r.isOk || r.data == null) throw ApiException('成绩数据为空');
    final items = (r.data!['items'] as List<dynamic>?) ?? [];
    CacheService.set(key, jsonEncode(items));
    return items
        .map((s) => Score.fromApiJson(s as Map<String, dynamic>, semester))
        .toList();
  }

  Future<void> refresh() async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn || auth.cookie == null) return;
    final semester = ref.read(semesterProvider);
    final scores = await _fetchGrades(
      'grades_${auth.username}_$semester',
      auth.cookie!,
      semester,
    );
    state = AsyncData(scores);
  }
}

final examsProvider = AsyncNotifierProvider<ExamsNotifier, List<Exam>>(
  ExamsNotifier.new,
);

final gradesProvider = AsyncNotifierProvider<GradesNotifier, List<Score>>(
  GradesNotifier.new,
);

// ── 电费（缓存优先） ──
class ElectricityNotifier extends AsyncNotifier<ElectricityData?> {
  @override
  Future<ElectricityData?> build() async {
    final auth = ref.watch(authProvider);
    final token = auth.electricityToken;
    if (token == null || auth.username == null) return null;

    final cacheKey = 'electricity_${auth.username}';
    String? firstErrorMsg;

    try {
      final data = await _fetchElectricity(token, auth.username!);
      return data;
    } catch (e) {
      firstErrorMsg = handleError(e).message;
      // 有缓存则回退到缓存
      final cached = await CacheService.get(cacheKey);
      if (cached != null) {
        final d = ElectricityData.fromJson(jsonDecode(cached));
        return d;
      }
      if (isAuthenticationFailure(handleError(e))) {
        // 尝试自动重登
        final ok = await ref.read(authProvider.notifier).silentReLogin();
        if (ok) {
          final newToken = ref.read(authProvider).electricityToken;
          if (newToken != null) {
            try {
              return _fetchElectricity(
                newToken,
                ref.read(authProvider).username!,
              );
            } catch (_) {}
          }
        }
        throw ApiException('会话已过期，自动重登失败，请手动重新登录');
      }
      throw ApiException(firstErrorMsg);
    }
  }

  Future<ElectricityData> _fetchElectricity(
    String token,
    String username,
  ) async {
    Object? firstError;
    ApiResponse<Map<String, dynamic>>? balancesR;
    ApiResponse<Map<String, dynamic>>? situationR;
    ({List<ElecRecord> recharges, List<ElecRecord> deductions})? history;

    try {
      balancesR = await fetchElectricityBalances(token);
    } catch (e) {
      firstError = e;
    }
    try {
      situationR = await fetchElectricitySituation(token, username);
    } catch (_) {}
    try {
      history = await _fetchRoomsAndHistory(token, username);
    } catch (_) {}

    if (balancesR == null || !balancesR.isOk || balancesR.data == null) {
      if (firstError != null) throw firstError;
      throw const ApiException('获取电费数据失败');
    }
    final a = balancesR.data!;
    final ac = a['ac'] as Map<String, dynamic>?;
    final light = a['light'] as Map<String, dynamic>?;

    double? curMonth, lastMonth, usageChange;
    if (situationR != null && situationR.isOk && situationR.data != null) {
      curMonth = (situationR.data!['currentMonthUsage'] as num?)?.toDouble();
      lastMonth = (situationR.data!['lastMonthUsage'] as num?)?.toDouble();
      usageChange = (situationR.data!['usageChange'] as num?)?.toDouble();
    }

    final data = ElectricityData(
      acBalance: (ac?['moneyBalance'] as num?)?.toDouble() ?? 0,
      lightBalance: (light?['moneyBalance'] as num?)?.toDouble() ?? 0,
      todayUsage:
          ((ac?['todayBalance'] as num?)?.toDouble() ?? 0) +
          ((light?['todayBalance'] as num?)?.toDouble() ?? 0),
      monthUsage:
          ((ac?['monthBalance'] as num?)?.toDouble() ?? 0) +
          ((light?['monthBalance'] as num?)?.toDouble() ?? 0),
      roomName: light?['areaInfo'] as String? ?? ac?['areaInfo'] as String?,
      currentMonthUsage: curMonth,
      lastMonthUsage: lastMonth,
      usageChange: usageChange,
      recharges: history?.recharges ?? [],
      deductions: history?.deductions ?? [],
    );
    CacheService.set(
      'electricity_${ref.read(authProvider).username}',
      jsonEncode(data.toJson()),
    );
    return data;
  }
}

Future<({List<ElecRecord> recharges, List<ElecRecord> deductions})?>
_fetchRoomsAndHistory(String token, String username) async {
  final roomsR = await fetchElectricityRooms(token);
  if (!roomsR.isOk || roomsR.data == null) return null;
  final rooms = (roomsR.data as List<dynamic>?) ?? [];
  if (rooms.isEmpty) return null;
  final room = rooms[0] as Map<String, dynamic>;
  final roomCode = room['roomCode'] as String? ?? '';
  final name = room['areaInfo'] as String? ?? '';
  final eleTypes = (room['useEleTypeList'] as List<dynamic>?) ?? [];
  final useEleType = eleTypes.isNotEmpty ? '${eleTypes[0]}' : '2';

  final results = await Future.wait([
    fetchElectricityRecharges(token, name, username, roomCode, useEleType),
    fetchElectricityDeductions(token, username, roomCode, useEleType),
  ]);

  List<ElecRecord> parseRecords(dynamic r) {
    if (!r.isOk || r.data == null) return [];
    final list = (r.data!['list'] as List<dynamic>?) ?? [];
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return ElecRecord(
        amount: (m['rechargeSum'] ?? m['amount'] ?? m['moneyUsed'] ?? 0) is num
            ? ((m['rechargeSum'] ?? m['amount'] ?? m['moneyUsed']) as num)
                  .toDouble()
            : 0,
        time: m['rechargeTime'] as String? ?? m['issueTime'] as String? ?? '',
        label:
            m['rechargeChannelName'] as String? ??
            m['rechargeMethodName'] as String? ??
            '',
      );
    }).toList();
  }

  return (
    recharges: parseRecords(results[0] as dynamic),
    deductions: parseRecords(results[1] as dynamic),
  );
}

final electricityProvider =
    AsyncNotifierProvider<ElectricityNotifier, ElectricityData?>(
      ElectricityNotifier.new,
    );

class ElecRecord {
  final double amount;
  final String time;
  final String label;
  const ElecRecord({required this.amount, this.time = '', this.label = ''});
}

class ElectricityData {
  final double acBalance;
  final double lightBalance;
  final double todayUsage;
  final double monthUsage;
  final String? roomName;
  final double? currentMonthUsage;
  final double? lastMonthUsage;
  final double? usageChange;
  final List<ElecRecord> recharges;
  final List<ElecRecord> deductions;
  final Map<int, double> dailyUsage; // day → 度数
  double get totalBalance => acBalance + lightBalance;
  const ElectricityData({
    required this.acBalance,
    required this.lightBalance,
    this.todayUsage = 0,
    this.monthUsage = 0,
    this.roomName,
    this.currentMonthUsage,
    this.lastMonthUsage,
    this.usageChange,
    this.recharges = const [],
    this.deductions = const [],
    this.dailyUsage = const {},
  });

  Map<String, dynamic> toJson() => {
    'ac': acBalance,
    'light': lightBalance,
    'today': todayUsage,
    'month': monthUsage,
    'roomName': roomName,
    'curMonth': currentMonthUsage,
    'lastMonth': lastMonthUsage,
    'change': usageChange,
  };

  factory ElectricityData.fromJson(Map<String, dynamic> json) =>
      ElectricityData(
        acBalance: (json['ac'] as num?)?.toDouble() ?? 0,
        lightBalance: (json['light'] as num?)?.toDouble() ?? 0,
        todayUsage: (json['today'] as num?)?.toDouble() ?? 0,
        monthUsage: (json['month'] as num?)?.toDouble() ?? 0,
        roomName: json['roomName'] as String?,
        currentMonthUsage: (json['curMonth'] as num?)?.toDouble(),
        lastMonthUsage: (json['lastMonth'] as num?)?.toDouble(),
        usageChange: (json['change'] as num?)?.toDouble(),
      );
}

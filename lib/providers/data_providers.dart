import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../models/score.dart';
import '../providers/auth_provider.dart';
import '../providers/semester_provider.dart';
import '../services/api_service.dart';

// ── 学期拆分："2025-2026-2" → academicYear: "2025-2026", term: "12" ──
// GDOU正方教务: 第一学期=3, 第二学期=12
const _termMap = {'1': '3', '2': '12'};
(String academicYear, String term) _splitSemester(String s) {
  final parts = s.split('-');
  final year = '${parts[0]}-${parts[1]}';
  final raw = parts.length > 2 ? parts[2] : '1';
  final term = _termMap[raw] ?? raw;
  return (year, term);
}

// ── 课表 ──
class TimetableNotifier extends AsyncNotifier<List<Course>> {
  @override
  Future<List<Course>> build() async {
    final auth = ref.watch(authProvider);
    final semester = ref.watch(semesterProvider);
    if (!auth.isLoggedIn || auth.cookie == null) return [];
    final (year, term) = _splitSemester(semester);
    final r = await fetchTimetable(auth.cookie!, year, term);
    if (!r.isOk || r.data == null) return [];
    final courses = (r.data!['courses'] as List<dynamic>?) ?? [];
    return courses
        .map((c) => Course.fromApiJson(c as Map<String, dynamic>, semester))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

final timetableProvider =
    AsyncNotifierProvider<TimetableNotifier, List<Course>>(TimetableNotifier.new);

// ── 考试 ──
class ExamsNotifier extends AsyncNotifier<List<Exam>> {
  @override
  Future<List<Exam>> build() async {
    final auth = ref.watch(authProvider);
    final semester = ref.watch(semesterProvider);
    if (!auth.isLoggedIn || auth.cookie == null) return [];
    final (year, term) = _splitSemester(semester);
    final r = await fetchExams(auth.cookie!, year, term);
    if (!r.isOk || r.data == null) return [];
    final items = (r.data!['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => Exam.fromApiJson(e as Map<String, dynamic>))
        .toList();
  }
}

class GradesNotifier extends AsyncNotifier<List<Score>> {
  @override
  Future<List<Score>> build() async {
    final auth = ref.watch(authProvider);
    final semester = ref.watch(semesterProvider);
    if (!auth.isLoggedIn || auth.cookie == null) return [];
    final (year, term) = _splitSemester(semester);
    final r = await fetchGrades(auth.cookie!, year, term);
    if (!r.isOk || r.data == null) return [];
    final items = (r.data!['items'] as List<dynamic>?) ?? [];
    return items
        .map((s) => Score.fromApiJson(s as Map<String, dynamic>, semester))
        .toList();
  }
}

final examsProvider =
    AsyncNotifierProvider<ExamsNotifier, List<Exam>>(ExamsNotifier.new);

final gradesProvider =
    AsyncNotifierProvider<GradesNotifier, List<Score>>(GradesNotifier.new);

// ── 电费（余额 + 月度对比 + 记录） ──
class ElectricityNotifier extends AsyncNotifier<ElectricityData?> {
  @override
  Future<ElectricityData?> build() async {
    final auth = ref.watch(authProvider);
    final token = auth.electricityToken;
    if (token == null || auth.username == null) return null;

    // 分别请求，单独容错
    ApiResponse<Map<String, dynamic>>? balancesR;
    ApiResponse<Map<String, dynamic>>? situationR;
    ({List<ElecRecord> recharges, List<ElecRecord> deductions})? history;

    try {
      balancesR = await fetchElectricityBalances(token);
    } catch (_) {}
    try {
      situationR = await fetchElectricitySituation(token, auth.username!);
    } catch (_) {}
    try {
      history = await _fetchRoomsAndHistory(token, auth.username!);
    } catch (_) {}

    if (balancesR == null || !balancesR.isOk || balancesR.data == null) return null;
    final a = balancesR.data!;
    final ac = a['ac'] as Map<String, dynamic>?;
    final light = a['light'] as Map<String, dynamic>?;

    double? curMonth, lastMonth, usageChange;
    if (situationR != null && situationR.isOk && situationR.data != null) {
      curMonth = (situationR.data!['currentMonthUsage'] as num?)?.toDouble();
      lastMonth = (situationR.data!['lastMonthUsage'] as num?)?.toDouble();
      usageChange = (situationR.data!['usageChange'] as num?)?.toDouble();
    }

    return ElectricityData(
      acBalance: (ac?['moneyBalance'] as num?)?.toDouble() ?? 0,
      lightBalance: (light?['moneyBalance'] as num?)?.toDouble() ?? 0,
      todayUsage: ((ac?['todayBalance'] as num?)?.toDouble() ?? 0) +
          ((light?['todayBalance'] as num?)?.toDouble() ?? 0),
      monthUsage: ((ac?['monthBalance'] as num?)?.toDouble() ?? 0) +
          ((light?['monthBalance'] as num?)?.toDouble() ?? 0),
      roomName: light?['areaInfo'] as String? ?? ac?['areaInfo'] as String?,
      currentMonthUsage: curMonth,
      lastMonthUsage: lastMonth,
      usageChange: usageChange,
      recharges: history?.recharges ?? [],
      deductions: history?.deductions ?? [],
    );
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
        amount: (m['rechargeSum'] ?? m['amount'] ?? m['moneyUsed'] ?? 0)
                is num
            ? ((m['rechargeSum'] ?? m['amount'] ?? m['moneyUsed']) as num)
                .toDouble()
            : 0,
        time: m['rechargeTime'] as String? ??
            m['issueTime'] as String? ??
            '',
        label: m['rechargeChannelName'] as String? ??
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

final electricityProvider = AsyncNotifierProvider<ElectricityNotifier,
    ElectricityData?>(ElectricityNotifier.new);

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
  });
}

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(seconds: 120),
));

String _server = '';
String get apiBaseUrl => _server;

Future<void> setApiServer(String host) async {
  _server = host.startsWith('http') ? host : 'http://$host';
  dio.options.baseUrl = _server;
}

Future<String> loadApiServer() async {
  final sp = await SharedPreferences.getInstance();
  _server =
      _normalizeHost(sp.getString('api_server') ?? const String.fromEnvironment('API_SERVER'));
  dio.options.baseUrl = _server;
  return _server;
}

String _normalizeHost(String host) {
  var h = host.startsWith('http') ? host : 'http://$host';
  while (h.endsWith('/')) {
    h = h.substring(0, h.length - 1);
  }
  return h;
}

Future<void> saveApiServer(String host) async {
  _server = _normalizeHost(host);
  dio.options.baseUrl = _server;
  final sp = await SharedPreferences.getInstance();
  await sp.setString('api_server', _server);
}

// ── 通用响应 ──
class ApiResponse<T> {
  final String code;
  final String message;
  final T? data;
  const ApiResponse({required this.code, required this.message, this.data});
  bool get isOk => code == 'OK';
}

// ── 教务 Auth ──
Future<ApiResponse<Map<String, dynamic>>> loginJwxt(
    String username, String password) async {
  final r = await dio.post('/api/v1/jwxt/login',
      data: {'username': username, 'password': password});
  return ApiResponse(
    code: r.data['code'],
    message: r.data['message'],
    data: r.data['data'] as Map<String, dynamic>?,
  );
}

Future<ApiResponse<Map<String, dynamic>>> validateSession(String cookie) async {
  final r = await dio.post('/api/v1/jwxt/session/validate',
      data: {'cookie': cookie});
  return ApiResponse(
    code: r.data['code'],
    message: r.data['message'],
    data: r.data['data'] as Map<String, dynamic>?,
  );
}

// ── 通用教务查询请求 ──
Map<String, dynamic> _queryBody(String cookie, String academicYear, String term,
    {Map<String, dynamic>? extra}) {
  return {
    'cookie': cookie,
    'academic_year': academicYear,
    'term': term,
    'extra': extra ?? {},
  };
}

// ── 课表 ──
Future<ApiResponse<Map<String, dynamic>>> fetchTimetable(
    String cookie, String academicYear, String term) async {
  final r = await dio
      .post('/api/v1/jwxt/timetable', data: _queryBody(cookie, academicYear, term));
  return _toResponse(r);
}

// ── 成绩 ──
Future<ApiResponse<Map<String, dynamic>>> fetchGrades(
    String cookie, String academicYear, String term) async {
  final r = await dio
      .post('/api/v1/jwxt/grades', data: _queryBody(cookie, academicYear, term));
  return _toResponse(r);
}

// ── 考试 ──
Future<ApiResponse<Map<String, dynamic>>> fetchExams(
    String cookie, String academicYear, String term) async {
  final r = await dio
      .post('/api/v1/jwxt/exams', data: _queryBody(cookie, academicYear, term));
  return _toResponse(r);
}

// ── 电费 Auth ──
Future<ApiResponse<Map<String, dynamic>>> loginElectricity(
    String username, String password) async {
  final r = await dio.post('/api/v1/electricity/login',
      data: {'username': username, 'password': password, 'login_type': 1},
      options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10)));
  return _toResponse(r);
}

// ── 电费查询 ──
Future<ApiResponse<dynamic>> fetchElectricityRooms(String token) async {
  final r = await dio.get('/api/v1/electricity/rooms',
      options: Options(headers: {'X-Electricity-Token': token}));
  return _toResponseAny(r);
}

Future<ApiResponse<Map<String, dynamic>>> fetchElectricityBalances(
    String token, {int roomIndex = 1}) async {
  final r = await dio.get('/api/v1/electricity/balances',
      queryParameters: {'room_index': roomIndex},
      options: Options(headers: {'X-Electricity-Token': token}));
  return _toResponse(r);
}

// ── 电费新接口 ──
Future<ApiResponse<Map<String, dynamic>>> fetchElectricitySituation(
    String token, String username) async {
  final r = await dio.get('/api/v1/electricity/situation',
      queryParameters: {'username': username},
      options: Options(headers: {'X-Electricity-Token': token}));
  return _toResponse(r);
}

Future<ApiResponse<Map<String, dynamic>>> fetchElectricityRecharges(
    String token, String name, String username, String roomCode, String useEleType) async {
  final r = await dio.post('/api/v1/electricity/recharges',
      data: {'name': name, 'username': username, 'roomCode': roomCode, 'useEleType': useEleType, 'pageNumber': 1, 'pageSize': 15},
      options: Options(headers: {'X-Electricity-Token': token}));
  return _toResponse(r);
}

Future<ApiResponse<Map<String, dynamic>>> fetchElectricityDeductions(
    String token, String username, String roomCode, String useEleType) async {
  final r = await dio.post('/api/v1/electricity/deductions',
      data: {'username': username, 'roomCode': roomCode, 'useEleType': useEleType, 'pageNumber': 1, 'pageSize': 15},
      options: Options(headers: {'X-Electricity-Token': token}));
  return _toResponse(r);
}

// ── 绑定/解绑 ──
Future<ApiResponse<dynamic>> fetchBoundRooms(
    String token, String username) async {
  final r = await dio.post('/api/v1/electricity/bound-rooms',
      data: {'username': username, 'pageNumber': 1, 'pageSize': 10},
      options: Options(headers: {'X-Electricity-Token': token}));
  return _toResponseAny(r);
}

Future<ApiResponse<Map<String, dynamic>>> bindRooms(
    String token, String username, List<String> roomCodes) async {
  final r = await dio.post('/api/v1/electricity/bind-rooms',
      data: {'username': username, 'roomCodes': roomCodes},
      options: Options(headers: {'X-Electricity-Token': token}));
  return _toResponse(r);
}

Future<ApiResponse<Map<String, dynamic>>> unbindRooms(
    String token, String username, List<String> roomCodes) async {
  final r = await dio.post('/api/v1/electricity/unbind-rooms',
      data: {'username': username, 'roomCodes': roomCodes},
      options: Options(headers: {'X-Electricity-Token': token}));
  return _toResponse(r);
}

Future<ApiResponse<dynamic>> fetchBuildings(String token) async {
  final r = await dio.get('/api/v1/electricity/buildings',
      queryParameters: {'building_type_code': '1-1'},
      options: Options(headers: {'X-Electricity-Token': token}));
  return _toResponseAny(r);
}

Future<ApiResponse<dynamic>> fetchFloors(String token, String buildingCode) async {
  final r = await dio.get('/api/v1/electricity/floors',
      queryParameters: {'building_code': buildingCode},
      options: Options(headers: {'X-Electricity-Token': token}));
  return _toResponseAny(r);
}

Future<ApiResponse<dynamic>> searchRooms(
    String token, String floorCode, String username) async {
  final r = await dio.post('/api/v1/electricity/rooms/search',
      data: {'floorCode': floorCode, 'roomName': '', 'username': username},
      options: Options(headers: {'X-Electricity-Token': token}));
  return _toResponseAny(r);
}

ApiResponse<Map<String, dynamic>> _toResponse(Response r) {
  final d = r.data['data'];
  return ApiResponse(
    code: r.data['code'],
    message: r.data['message'],
    data: d is Map<String, dynamic> ? d : (d is Map ? Map<String, dynamic>.from(d) : null),
  );
}

ApiResponse<dynamic> _toResponseAny(Response r) => ApiResponse(
      code: r.data['code'],
      message: r.data['message'],
      data: r.data['data'],
    );

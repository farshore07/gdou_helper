import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    validateStatus: (s) => s != null && s < 600,
  ),
);

// ── 请求冷却（同 URL+data 5s 内拦截重复请求） ──
final _lastRequest = <String, DateTime>{};
const _coolDown = Duration(seconds: 5);

bool _checkCooldown(String key) {
  final last = _lastRequest[key];
  if (last != null && DateTime.now().difference(last) < _coolDown) {
    return false;
  }
  _lastRequest[key] = DateTime.now();
  return true;
}

void _setupCooldownInterceptor() {
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final key = '${options.method}:${options.path}:${options.data}';
        if (!_checkCooldown(key)) {
          return handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              message: '请求冷却中，请稍后再试',
            ),
          );
        }
        return handler.next(options);
      },
    ),
  );
}

// 初始化冷却拦截器
void _initDio() {
  _setupCooldownInterceptor();
}

// ── 错误处理 ──
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? apiCode;
  const ApiException(this.message, {this.statusCode, this.apiCode});
  @override
  String toString() => message;
}

bool isAuthenticationFailure(ApiException error) =>
    error.statusCode == 401 ||
    error.statusCode == 403 ||
    const {'UNAUTHORIZED', 'SESSION_EXPIRED'}.contains(error.apiCode);

ApiException handleError(dynamic e) {
  if (e is ApiException) return e;
  if (e is DioException) {
    if (e.type == DioExceptionType.cancel) {
      return const ApiException('操作太频繁，请稍后再试');
    }
    final code = e.response?.statusCode;
    final apiMsg = _apiErrorMessage(e.response?.data);
    if (apiMsg != null) return ApiException(apiMsg, statusCode: code);
    return switch (e.type) {
      DioExceptionType.connectionTimeout => const ApiException('连接超时，请检查网络'),
      DioExceptionType.receiveTimeout => const ApiException('服务器响应超时，请重试'),
      DioExceptionType.connectionError => const ApiException(
        '无法连接服务器，请检查网络或服务器地址',
      ),
      DioExceptionType.badResponse => ApiException(
        _statusMessage(code ?? 0),
        statusCode: code,
      ),
      _ => const ApiException('网络异常，请重试'),
    };
  }
  return const ApiException('未知错误');
}

String _statusMessage(int code) => switch (code) {
  400 => '请求参数错误 (400)',
  401 => '登录已过期，请重新登录 (401)',
  403 => '服务器拒绝访问 (403)',
  404 => '接口不存在 (404)',
  429 => '请求太频繁，请稍后再试 (429)',
  500 => '服务器内部错误 (500)',
  502 => '服务器暂不可用 (502)',
  _ => '服务器返回错误 ($code)',
};

String? _apiErrorMessage(dynamic data) {
  if (data is Map) {
    final msg = data['message'] as String?;
    final code = data['code'] as String?;
    if (code != null && code != 'OK' && msg != null) {
      return _apiCodeMessage(code) ?? msg;
    }
  }
  return null;
}

String? _apiCodeMessage(String code) => switch (code) {
  'UNAUTHORIZED' => '认证失败，请重新登录',
  'BAD_REQUEST' => '请求参数错误',
  'NOT_FOUND' => '请求的资源不存在',
  'FORBIDDEN' => '没有权限访问',
  'RATE_LIMITED' => '请求太频繁，已触发限流',
  'BANNED' => 'IP 已被封禁',
  'SESSION_EXPIRED' => '会话已过期，请重新登录',
  _ => null,
};

String _server = '';
String get apiBaseUrl => _server;

Future<void> setApiServer(String host) async {
  _server = host.startsWith('http') ? host : 'http://$host';
  dio.options.baseUrl = _server;
}

bool _dioReady = false;

Future<String> loadApiServer() async {
  final sp = await SharedPreferences.getInstance();
  _server = _normalizeHost(
    sp.getString('api_server') ?? const String.fromEnvironment('API_SERVER'),
  );
  dio.options.baseUrl = _server;
  if (!_dioReady) {
    _initDio();
    _dioReady = true;
  }
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
  String username,
  String password,
) async {
  final r = await dio.post(
    '/api/v1/jwxt/login',
    data: {'username': username, 'password': password},
  );
  return ApiResponse(
    code: r.data['code'],
    message: r.data['message'],
    data: r.data['data'] as Map<String, dynamic>?,
  );
}

Future<ApiResponse<Map<String, dynamic>>> validateSession(String cookie) async {
  final r = await dio.post(
    '/api/v1/jwxt/session/validate',
    data: {'cookie': cookie},
  );
  return ApiResponse(
    code: r.data['code'],
    message: r.data['message'],
    data: r.data['data'] as Map<String, dynamic>?,
  );
}

// ── 通用教务查询请求 ──
Map<String, dynamic> _queryBody(
  String cookie,
  String academicYear,
  String term, {
  Map<String, dynamic>? extra,
}) {
  return {
    'cookie': cookie,
    'academic_year': academicYear,
    'term': term,
    'extra': extra ?? {},
  };
}

// ── 课表 ──
Future<ApiResponse<Map<String, dynamic>>> fetchTimetable(
  String cookie,
  String academicYear,
  String term,
) async {
  final r = await dio.post(
    '/api/v1/jwxt/timetable',
    data: _queryBody(cookie, academicYear, term),
  );
  return _toResponse(r);
}

// ── 成绩 ──
Future<ApiResponse<Map<String, dynamic>>> fetchGrades(
  String cookie,
  String academicYear,
  String term,
) async {
  final r = await dio.post(
    '/api/v1/jwxt/grades',
    data: _queryBody(cookie, academicYear, term),
  );
  return _toResponse(r);
}

// ── 考试 ──
Future<ApiResponse<Map<String, dynamic>>> fetchExams(
  String cookie,
  String academicYear,
  String term,
) async {
  final r = await dio.post(
    '/api/v1/jwxt/exams',
    data: _queryBody(cookie, academicYear, term),
  );
  return _toResponse(r);
}

// ── 电费 Auth ──
Future<ApiResponse<Map<String, dynamic>>> loginElectricity(
  String username,
  String password,
) async {
  final r = await dio.post(
    '/api/v1/electricity/login',
    data: {'username': username, 'password': password, 'login_type': 1},
    options: Options(
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  return _toResponse(r);
}

// ── 电费查询 ──
Future<ApiResponse<dynamic>> fetchElectricityRooms(String token) async {
  final r = await dio.get(
    '/api/v1/electricity/rooms',
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponseAny(r);
}

Future<ApiResponse<Map<String, dynamic>>> fetchElectricityBalances(
  String token, {
  int roomIndex = 1,
}) async {
  final r = await dio.get(
    '/api/v1/electricity/balances',
    queryParameters: {'room_index': roomIndex},
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponse(r);
}

// ── 电费新接口 ──
Future<ApiResponse<Map<String, dynamic>>> fetchElectricitySituation(
  String token,
  String username,
) async {
  final r = await dio.get(
    '/api/v1/electricity/situation',
    queryParameters: {'username': username},
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponse(r);
}

Future<ApiResponse<Map<String, dynamic>>> fetchElectricityRecharges(
  String token,
  String name,
  String username,
  String roomCode,
  String useEleType,
) async {
  final r = await dio.post(
    '/api/v1/electricity/recharges',
    data: {
      'name': name,
      'username': username,
      'roomCode': roomCode,
      'useEleType': useEleType,
      'pageNumber': 1,
      'pageSize': 15,
    },
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponse(r);
}

Future<ApiResponse<Map<String, dynamic>>> fetchElectricityDeductions(
  String token,
  String username,
  String roomCode,
  String useEleType,
) async {
  final r = await dio.post(
    '/api/v1/electricity/deductions',
    data: {
      'username': username,
      'roomCode': roomCode,
      'useEleType': useEleType,
      'pageNumber': 1,
      'pageSize': 15,
    },
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponse(r);
}

// ── 绑定/解绑 ──
Future<ApiResponse<dynamic>> fetchBoundRooms(
  String token,
  String username,
) async {
  final r = await dio.post(
    '/api/v1/electricity/bound-rooms',
    data: {'username': username, 'pageNumber': 1, 'pageSize': 10},
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponseAny(r);
}

Future<ApiResponse<Map<String, dynamic>>> bindRooms(
  String token,
  String username,
  List<String> roomCodes,
) async {
  final r = await dio.post(
    '/api/v1/electricity/bind-rooms',
    data: {'username': username, 'roomCodes': roomCodes},
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponse(r);
}

Future<ApiResponse<Map<String, dynamic>>> unbindRooms(
  String token,
  String username,
  List<String> roomCodes,
) async {
  final r = await dio.post(
    '/api/v1/electricity/unbind-rooms',
    data: {'username': username, 'roomCodes': roomCodes},
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponse(r);
}

Future<ApiResponse<dynamic>> fetchBuildings(String token) async {
  final r = await dio.get(
    '/api/v1/electricity/buildings',
    queryParameters: {'building_type_code': '1-1'},
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponseAny(r);
}

Future<ApiResponse<dynamic>> fetchFloors(
  String token,
  String buildingCode,
) async {
  final r = await dio.get(
    '/api/v1/electricity/floors',
    queryParameters: {'building_code': buildingCode},
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponseAny(r);
}

Future<ApiResponse<dynamic>> searchRooms(
  String token,
  String floorCode,
  String username,
) async {
  final r = await dio.post(
    '/api/v1/electricity/rooms/search',
    data: {'floorCode': floorCode, 'roomName': '', 'username': username},
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponseAny(r);
}

Future<ApiResponse<Map<String, dynamic>>> fetchElectricityConsume(
  String token,
  String roomCode,
  String startDate,
  String endDate,
) async {
  final r = await dio.post(
    '/api/v1/electricity/consume',
    data: {'roomCode': roomCode, 'startDate': startDate, 'endDate': endDate},
    options: Options(headers: {'X-Electricity-Token': token}),
  );
  return _toResponse(r);
}

ApiResponse<Map<String, dynamic>> _toResponse(Response r) {
  final code = r.data['code'] as String? ?? '';
  if (code != 'OK') {
    throw ApiException(
      r.data['message'] as String? ?? '请求失败',
      apiCode: code,
      statusCode: r.statusCode,
    );
  }
  final d = r.data['data'];
  return ApiResponse(
    code: code,
    message: r.data['message'],
    data: d is Map<String, dynamic>
        ? d
        : (d is Map ? Map<String, dynamic>.from(d) : null),
  );
}

ApiResponse<dynamic> _toResponseAny(Response r) {
  final code = r.data['code'] as String? ?? '';
  if (code != 'OK') {
    throw ApiException(
      r.data['message'] as String? ?? '请求失败',
      apiCode: code,
      statusCode: r.statusCode,
    );
  }
  return ApiResponse(
    code: code,
    message: r.data['message'],
    data: r.data['data'],
  );
}

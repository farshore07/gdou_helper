import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/resource_item.dart';
import 'cache_service.dart';

final dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    validateStatus: (s) => s != null && s < 600,
  ),
);

// ── 请求冷却（同 URL+data 5s 内拦截重复请求；交互式认证接口不冷却） ──
final _lastRequest = <String, DateTime>{};
const _coolDown = Duration(seconds: 5);
const _cooldownBypassPaths = {
  '/api/v1/jwxt/login',
  '/api/v1/jwxt/mfa/send',
  '/api/v1/jwxt/mfa/verify',
};

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
        if (_cooldownBypassPaths.contains(options.path) ||
            options.extra['bypassCooldown'] == true) {
          return handler.next(options);
        }
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
  'METHOD_NOT_ALLOWED' => '请求方法不支持',
  'FORBIDDEN' => '没有权限访问',
  'RATE_LIMITED' => '请求太频繁，已触发限流',
  'BANNED' => 'IP 已被封禁',
  'SESSION_EXPIRED' => '会话已过期，请重新登录',
  'SERVER_BUSY' => '当前登录人数较多，请稍后重试',
  _ => null,
};

String _server = '';
String get apiBaseUrl => _server;

Future<void> setApiServer(String host) async {
  _server = host.startsWith('http') ? host : 'http://$host';
  dio.options.baseUrl = _server;
}

bool _dioReady = false;

const _envApiServer = String.fromEnvironment('API_SERVER');

Future<String> loadApiServer() async {
  final sp = await SharedPreferences.getInstance();
  final configured = _envApiServer.trim().isNotEmpty
      ? _envApiServer.trim()
      : (sp.getString('api_server') ?? const String.fromEnvironment('API_SERVER'));
  _server = _normalizeHost(configured);
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
  final int? statusCode;
  const ApiResponse({
    required this.code,
    required this.message,
    this.data,
    this.statusCode,
  });
  bool get isOk => code == 'OK';
}

ApiResponse<Map<String, dynamic>> _parseMapResponse(Response r) {
  final raw = r.data;
  if (raw is! Map) {
    final status = r.statusCode ?? 0;
    return ApiResponse(
      code: 'HTTP_$status',
      message: _statusMessage(status),
      statusCode: r.statusCode,
    );
  }
  final map = Map<String, dynamic>.from(raw);
  final d = map['data'];
  return ApiResponse(
    code: map['code'] as String? ?? 'UNKNOWN_ERROR',
    message: map['message'] as String? ?? _statusMessage(r.statusCode ?? 0),
    data: d is Map<String, dynamic>
        ? d
        : (d is Map ? Map<String, dynamic>.from(d) : null),
    statusCode: r.statusCode,
  );
}

// ── 教务 Auth ──
Future<ApiResponse<Map<String, dynamic>>> loginJwxt(
  String username,
  String password, {
  String? deviceFingerprint,
  String? captchaToken,
  String? captchaCode,
  String? networkMode,
}) async {
  final body = <String, dynamic>{
    'username': username,
    'password': password,
    if (deviceFingerprint != null && deviceFingerprint.isNotEmpty)
      'device_fingerprint': deviceFingerprint,
    if (captchaToken != null && captchaToken.isNotEmpty)
      'captcha_token': captchaToken,
    if (captchaCode != null && captchaCode.isNotEmpty)
      'captcha_code': captchaCode,
    if (networkMode != null && networkMode.isNotEmpty)
      'network_mode': networkMode,
  };
  final r = await dio.post('/api/v1/jwxt/login', data: body);
  return _parseMapResponse(r);
}

Future<ApiResponse<Map<String, dynamic>>> sendJwxtMfaCode(
  String loginToken, {
  String method = 'auto',
}) async {
  final r = await dio.post(
    '/api/v1/jwxt/mfa/send',
    data: {'login_token': loginToken, 'method': method},
  );
  return _parseMapResponse(r);
}

Future<ApiResponse<Map<String, dynamic>>> verifyJwxtMfaCode(
  String loginToken,
  String code, {
  bool trustDevice = true,
}) async {
  final r = await dio.post(
    '/api/v1/jwxt/mfa/verify',
    data: {
      'login_token': loginToken,
      'code': code,
      'trust_device': trustDevice,
    },
  );
  return _parseMapResponse(r);
}

Future<ApiResponse<Map<String, dynamic>>> validateSession(String cookie) async {
  final r = await dio.post(
    '/api/v1/jwxt/session/validate',
    data: {'cookie': cookie},
  );
  return _parseMapResponse(r);
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
Future<ApiResponse<Map<String, dynamic>>> fetchGradeDetail(
  String cookie, {
  Map<String, String> query = const {},
  bool bypassCooldown = false,
}) async {
  final response = await dio.post(
    '/api/v1/jwxt/grade-detail',
    data: {'cookie': cookie, 'query': query},
    options: bypassCooldown
        ? Options(extra: const {'bypassCooldown': true})
        : null,
  );
  return _toResponse(response);
}

final _pendingGradeDetails = <String, Future<Map<String, dynamic>>>{};
final _staleGradeDetailPrefixes = <String, int>{};
final _refreshedGradeDetailVersion = <String, int>{};
int _gradeDetailStaleSeq = 0;

/// 标记指定前缀（如 `grade_detail_<username>_`）下的分项缓存需在下一次打开时向后端复核刷新，
/// 同时保留本地缓存用于离线或网络失败时回退。
void markGradeDetailsStale(String prefix) {
  _staleGradeDetailPrefixes[prefix] = ++_gradeDetailStaleSeq;
}

int? _matchingStaleVersion(String cacheKey) {
  int? maxVersion;
  for (final entry in _staleGradeDetailPrefixes.entries) {
    if (cacheKey.startsWith(entry.key)) {
      if (maxVersion == null || entry.value > maxVersion) {
        maxVersion = entry.value;
      }
    }
  }
  return maxVersion;
}

Future<Map<String, dynamic>> fetchCachedGradeDetail(
  String cacheKey,
  String cookie, {
  Map<String, String> query = const {},
  bool forceRefresh = false,
}) {
  final pendingKey = '$cacheKey:${forceRefresh ? 'refresh' : 'read'}';
  final pending = _pendingGradeDetails[pendingKey];
  if (pending != null) return pending;

  final future = () async {
    Map<String, dynamic>? cachedData;
    final cached = await CacheService.get(cacheKey);
    if (cached != null) {
      final decoded = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      final cachedItems = decoded['items'];
      if (cachedItems is List && cachedItems.isNotEmpty) {
        cachedData = decoded;
      }
    }

    final staleVersion = _matchingStaleVersion(cacheKey);
    final isStale =
        staleVersion != null &&
        (_refreshedGradeDetailVersion[cacheKey] ?? 0) < staleVersion;

    if (!forceRefresh && !isStale && cachedData != null) {
      return cachedData;
    }

    try {
      final data = (await fetchGradeDetail(
        cookie,
        query: query,
        bypassCooldown: forceRefresh || isStale,
      )).data;
      if (data == null) throw const ApiException('详细成绩数据为空');
      final items = data['items'];
      if (items is List && items.isNotEmpty) {
        await CacheService.set(cacheKey, jsonEncode(data));
      }
      if (staleVersion != null) {
        _refreshedGradeDetailVersion[cacheKey] = staleVersion;
      }
      return data;
    } catch (_) {
      // 非强制手动刷新且本地有缓存（如下拉刷新列表后又断网），优雅回退离线缓存
      if (!forceRefresh && cachedData != null) {
        return cachedData;
      }
      rethrow;
    }
  }();
  _pendingGradeDetails[pendingKey] = future;
  future.then<void>(
    (_) {
      _pendingGradeDetails.remove(pendingKey);
    },
    onError: (Object error, StackTrace stackTrace) {
      _pendingGradeDetails.remove(pendingKey);
    },
  );
  return future;
}

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
  final parsed = _parseMapResponse(r);
  if (!parsed.isOk) {
    throw ApiException(
      parsed.message,
      apiCode: parsed.code,
      statusCode: parsed.statusCode,
    );
  }
  return parsed;
}

ApiResponse<dynamic> _toResponseAny(Response r) {
  final raw = r.data;
  if (raw is! Map) {
    final status = r.statusCode ?? 0;
    throw ApiException(
      _statusMessage(status),
      apiCode: 'HTTP_$status',
      statusCode: r.statusCode,
    );
  }
  final code = raw['code'] as String? ?? '';
  if (code != 'OK') {
    throw ApiException(
      raw['message'] as String? ?? '请求失败',
      apiCode: code,
      statusCode: r.statusCode,
    );
  }
  return ApiResponse(
    code: code,
    message: raw['message'] as String? ?? 'ok',
    data: raw['data'],
    statusCode: r.statusCode,
  );
}

Future<List<LibraryCategory>> fetchLibraryCategories() async {
  final response = _toResponseAny(await dio.get('/api/v1/library/categories'));
  final items = (response.data as List<dynamic>? ?? []);
  return items
      .map(
        (item) =>
            LibraryCategory.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();
}

Future<
  ({
    List<LibraryResource> items,
    int total,
    int page,
    int pageSize,
    int totalPages,
  })
>
fetchLibraryResources({
  int? categoryId,
  String? query,
  int page = 1,
  int pageSize = 20,
  String sort = 'newest',
}) async {
  final response = _toResponse(
    await dio.get(
      '/api/v1/library/resources',
      queryParameters: {
        'category_id': ?categoryId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'page_size': pageSize,
        'sort': sort,
      },
    ),
  );
  final data = response.data ?? const <String, dynamic>{};
  final rawItems = data['items'] as List<dynamic>? ?? [];
  return (
    items: rawItems
        .map(
          (item) =>
              LibraryResource.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    total: (data['total'] as num?)?.toInt() ?? 0,
    page: (data['page'] as num?)?.toInt() ?? page,
    pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
    totalPages: (data['total_pages'] as num?)?.toInt() ?? 0,
  );
}

Future<LibraryResource> fetchLibraryResource(int id) async {
  final response = _toResponse(await dio.get('/api/v1/library/resources/$id'));
  return LibraryResource.fromJson(response.data!);
}

Future<void> recordLibraryDownload(int id) async {
  await dio.post('/api/v1/library/resources/$id/download');
}

Future<ApiResponse<Map<String, dynamic>>> fetchCurrentUser(String token) async {
  final response = await dio.get(
    '/api/v1/me',
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
  return _toResponse(response);
}

Future<({List<Map<String, dynamic>> items, int total})> fetchAdminUsers(
  String token, {
  int page = 1,
  String? query,
}) async {
  final response = _toResponse(
    await dio.get(
      '/api/v1/admin/users',
      queryParameters: {
        'page': page,
        if (query != null && query.isNotEmpty) 'q': query,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    ),
  );
  final data = response.data ?? const <String, dynamic>{};
  return (
    items: (data['items'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(),
    total: (data['total'] as num?)?.toInt() ?? 0,
  );
}

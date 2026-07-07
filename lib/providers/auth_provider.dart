import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/secure_store.dart';

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _loadSaved();
    return const AuthState();
  }

  Future<void> _loadSaved() async {
    await loadApiServer();
    if (state.isLoggedIn) return;
    final cookie = await loadCookie();
    final electricityToken = await loadElectricityToken();
    if (cookie != null) {
      final sp = await SharedPreferences.getInstance();
      final username = sp.getString('username');
      state = AuthState(
        isLoggedIn: true,
        cookie: cookie,
        username: username,
        electricityToken: electricityToken,
      );
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      // 1. 先登录电费
      final elecOk = await doElectricityLogin(username, password);

      // 2. 再登录教务
      final r = await loginJwxt(username, password);
      if (r.isOk && r.data?['status'] == 'success') {
        final cookie = r.data!['cookie'] as String;
        await saveCookie(cookie);
        state = AuthState(
            isLoggedIn: true,
            cookie: cookie,
            username: username,
            electricityToken: elecOk ? state.electricityToken : null);
        final sp = await SharedPreferences.getInstance();
        await sp.setString('username', username);
      } else {
        state = state.copyWith(
            loading: false, error: r.data?['message'] ?? r.message);
      }
    } on DioException catch (e) {
      final msg = e.type == DioExceptionType.connectionTimeout
          ? '连接超时（30秒），请检查网络'
          : e.type == DioExceptionType.receiveTimeout
              ? '服务器响应超时（120秒），登录处理中，重试一次'
              : e.response != null
                  ? '服务器返回错误 ${e.response?.statusCode}'
                  : '网络错误：${e.type.name}';
      state = state.copyWith(loading: false, error: msg);
    } catch (e) {
      state = state.copyWith(loading: false, error: '未知错误\n$e');
    }
  }

  Future<bool> doElectricityLogin(String username, String password) async {
    final r = await loginElectricity(username, password);
    if (r.isOk && r.data?['accessToken'] != null) {
      final token = r.data!['accessToken'] as String;
      await saveElectricityToken(token);
      state = state.copyWith(electricityToken: token, electricityFailed: false);
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    state = const AuthState();
    await secureDelete('jwxt_cookie');
    await secureDelete('electricity_token');
    final sp = await SharedPreferences.getInstance();
    await sp.remove('username');
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthState {
  final bool isLoggedIn;
  final bool loading;
  final bool checking;
  final String? cookie;
  final String? username;
  final String? electricityToken;
  final String? error;
  final bool electricityFailed;

  const AuthState({
    this.isLoggedIn = false,
    this.loading = false,
    this.checking = false,
    this.cookie,
    this.username,
    this.electricityToken,
    this.error,
    this.electricityFailed = false,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? loading,
    bool? checking,
    String? cookie,
    String? username,
    String? electricityToken,
    String? error,
    bool clearError = false,
    bool? electricityFailed,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        loading: loading ?? this.loading,
        checking: checking ?? this.checking,
        cookie: cookie ?? this.cookie,
        username: username ?? this.username,
        electricityToken: electricityToken ?? this.electricityToken,
        error: clearError ? null : (error ?? this.error),
        electricityFailed: electricityFailed ?? this.electricityFailed,
      );
}

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

    final savedCookie = await loadCookie();
    final savedToken = await loadElectricityToken();
    final username = await _loadUsername();

    // 1. 有 cookie，验证是否有效
    if (savedCookie != null && username != null) {
      bool valid = false;
      try {
        final vr = await validateSession(savedCookie);
        valid = vr.isOk && vr.data?['status'] == 'success';
      } catch (_) {}

      if (valid) {
        state = AuthState(
          isLoggedIn: true,
          cookie: savedCookie,
          username: username,
          electricityToken: savedToken,
        );
        return;
      }

      // 2. Cookie 过期，尝试自动重登
      final password = await loadPassword();
      if (password != null) {
        try {
          final r = await loginJwxt(username, password);
          if (r.isOk && r.data?['status'] == 'success') {
            final newCookie = r.data!['cookie'] as String;
            await saveCookie(newCookie);
            // 重登成功，也试电费
            await doElectricityLogin(username, password);
            final newToken = await loadElectricityToken();
            state = AuthState(
              isLoggedIn: true,
              cookie: newCookie,
              username: username,
              electricityToken: newToken ?? savedToken,
            );
            return;
          }
        } catch (_) {}
      }
    }
  }

  Future<String?> _loadUsername() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('username');
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
      state = state.copyWith(
          loading: false, error: handleError(e).message);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
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

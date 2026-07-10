import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/secure_store.dart';

class AuthNotifier extends Notifier<AuthState> {
  Future<bool>? _reloginFuture;

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
    if (savedCookie != null && username != null) {
      try {
        final validation = await validateSession(savedCookie);
        if (validation.isOk && validation.data?['status'] == 'success') {
          state = AuthState(
            isLoggedIn: true,
            cookie: savedCookie,
            username: username,
            electricityToken: savedToken,
          );
          return;
        }
      } catch (_) {
        debugPrint('认证：Cookie 校验失败');
      }
      debugPrint('认证：检测到 Cookie 失效');
      await silentReLogin();
    }
  }

  Future<String?> _loadUsername() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('username');
  }

  Future<void> login(
    String username,
    String password, {
    required bool remember,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final elecOk = await doElectricityLogin(username, password);
      final result = await loginJwxt(username, password);
      if (!result.isOk || result.data?['status'] != 'success') {
        state = state.copyWith(
          loading: false,
          error: result.data?['message'] ?? result.message,
        );
        return;
      }
      final cookie = result.data!['cookie'] as String;
      await saveCookie(cookie);
      final sp = await SharedPreferences.getInstance();
      await sp.setString('username', username);
      if (remember) {
        await sp.setString('saved_username', username);
        await savePassword(password);
        await saveRememberPassword(true);
      } else {
        await sp.remove('saved_username');
        await secureDelete('saved_password');
        await saveRememberPassword(false);
      }
      state = AuthState(
        isLoggedIn: true,
        cookie: cookie,
        username: username,
        electricityToken: elecOk ? state.electricityToken : null,
      );
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: handleError(e).message);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: '未知错误\n$e');
    }
  }

  Future<bool> silentReLogin() {
    final pending = _reloginFuture;
    if (pending != null) {
      debugPrint('认证：正在等待其他登录任务');
      return pending;
    }
    final future = _performSilentReLogin();
    _reloginFuture = future;
    future.whenComplete(() {
      if (identical(_reloginFuture, future)) _reloginFuture = null;
    });
    return future;
  }

  Future<bool> _performSilentReLogin() async {
    if (!await loadRememberPassword()) {
      debugPrint('认证：未开启记住密码');
      return false;
    }
    final username = state.username ?? await _loadUsername();
    final password = await loadPassword();
    if (username == null || password == null) {
      debugPrint('认证：未找到本地凭据');
      return false;
    }
    debugPrint('认证：开始自动登录');
    try {
      final result = await loginJwxt(username, password);
      if (result.isOk && result.data?['status'] == 'success') {
        final cookie = result.data!['cookie'] as String;
        await saveCookie(cookie);
        await doElectricityLogin(username, password);
        final token = await loadElectricityToken();
        state = state.copyWith(
          isLoggedIn: true,
          username: username,
          cookie: cookie,
          electricityToken: token ?? state.electricityToken,
        );
        debugPrint('认证：自动登录成功');
        return true;
      }
    } catch (_) {}
    // 未收到稳定的“密码错误”错误码，保留凭据以避免因网络或服务端故障误删。
    debugPrint('认证：自动登录失败');
    return false;
  }

  Future<bool> doElectricityLogin(String username, String password) async {
    final result = await loginElectricity(username, password);
    if (result.isOk && result.data?['accessToken'] != null) {
      final token = result.data!['accessToken'] as String;
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
    await secureDelete('saved_password');
    await secureDelete('remember_password');
    final sp = await SharedPreferences.getInstance();
    await sp.remove('username');
    await sp.remove('saved_username');
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

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
  }) => AuthState(
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

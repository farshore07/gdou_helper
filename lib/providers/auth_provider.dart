import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/secure_store.dart';

class CaptchaChallengeState {
  final String captchaToken;
  final Uint8List imageBytes;
  final String message;
  final String username;
  final String password;
  final bool remember;
  final bool submitting;
  final String? error;

  const CaptchaChallengeState({
    required this.captchaToken,
    required this.imageBytes,
    required this.message,
    required this.username,
    required this.password,
    required this.remember,
    this.submitting = false,
    this.error,
  });

  CaptchaChallengeState copyWith({
    String? captchaToken,
    Uint8List? imageBytes,
    String? message,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) => CaptchaChallengeState(
    captchaToken: captchaToken ?? this.captchaToken,
    imageBytes: imageBytes ?? this.imageBytes,
    message: message ?? this.message,
    username: username,
    password: password,
    remember: remember,
    submitting: submitting ?? this.submitting,
    error: clearError ? null : (error ?? this.error),
  );
}

class MfaChallengeState {
  final String loginToken;
  final String defaultMethod;
  final String selectedMethod;
  final List<String> availableMethods;
  final String message;
  final String username;
  final String password;
  final bool remember;
  final bool codeSent;
  final int countdown;
  final DateTime? codeSentAt;
  final bool sending;
  final bool verifying;
  final String? error;

  const MfaChallengeState({
    required this.loginToken,
    required this.defaultMethod,
    required this.selectedMethod,
    required this.availableMethods,
    required this.message,
    required this.username,
    required this.password,
    required this.remember,
    this.codeSent = false,
    this.countdown = 0,
    this.codeSentAt,
    this.sending = false,
    this.verifying = false,
    this.error,
  });

  MfaChallengeState copyWith({
    String? selectedMethod,
    String? message,
    bool? codeSent,
    int? countdown,
    DateTime? codeSentAt,
    bool? sending,
    bool? verifying,
    String? error,
    bool clearError = false,
  }) => MfaChallengeState(
    loginToken: loginToken,
    defaultMethod: defaultMethod,
    selectedMethod: selectedMethod ?? this.selectedMethod,
    availableMethods: availableMethods,
    message: message ?? this.message,
    username: username,
    password: password,
    remember: remember,
    codeSent: codeSent ?? this.codeSent,
    countdown: countdown ?? this.countdown,
    codeSentAt: codeSentAt ?? this.codeSentAt,
    sending: sending ?? this.sending,
    verifying: verifying ?? this.verifying,
    error: clearError ? null : (error ?? this.error),
  );
}

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

    final savedToken = await loadAppToken();
    final savedCookie = await loadCookie();
    final savedElectricityToken = await loadElectricityToken();
    final username = await _loadUsername();
    if (savedCookie == null || username == null) return;

    state = state.copyWith(checking: true);
    try {
      final validation = await validateSession(savedCookie);
      if (validation.isOk && validation.data?['status'] == 'success') {
        state = AuthState(
          isLoggedIn: true,
          cookie: savedCookie,
          username: username,
          electricityToken: savedElectricityToken,
          appToken: savedToken,
          sessionVersion: state.sessionVersion + 1,
        );
        return;
      }

      final isExpired =
          validation.code == 'SESSION_EXPIRED' || validation.statusCode == 401;
      if (!isExpired) {
        // 教务维护（502）或上游超时（504）时不误判为 Cookie 失效，保留本地登录态以使用本地缓存
        debugPrint('认证：校验遇上游异常(${validation.code})，暂保留本地会话');
        state = AuthState(
          isLoggedIn: true,
          cookie: savedCookie,
          username: username,
          electricityToken: savedElectricityToken,
          appToken: savedToken,
          sessionVersion: state.sessionVersion + 1,
        );
        return;
      }
    } catch (_) {
      debugPrint('认证：Cookie 校验网络异常，暂保留本地会话');
      state = AuthState(
        isLoggedIn: true,
        cookie: savedCookie,
        username: username,
        electricityToken: savedElectricityToken,
        appToken: savedToken,
        sessionVersion: state.sessionVersion + 1,
      );
      return;
    }

    debugPrint('认证：检测到 Cookie 失效，尝试静默重登');
    state = state.copyWith(
      isLoggedIn: true,
      cookie: savedCookie,
      username: username,
      electricityToken: savedElectricityToken,
      appToken: savedToken,
    );
    final reloginOk = await silentReLogin();
    if (!reloginOk) {
      state = state.copyWith(checking: false, sessionExpired: true);
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
    state = state.copyWith(
      loading: true,
      clearError: true,
      clearChallenges: true,
    );
    try {
      final fingerprint = await loadDeviceFingerprint();
      final result = await loginJwxt(
        username,
        password,
        deviceFingerprint: fingerprint,
      );
      await _handleLoginResponse(
        result,
        username: username,
        password: password,
        remember: remember,
      );
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: handleError(e).message);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: '登录异常\n$e');
    }
  }

  Future<void> submitCaptcha(String captchaCode) async {
    final challenge = state.captchaChallenge;
    if (challenge == null) return;
    final cleanCode = captchaCode.trim();
    if (cleanCode.isEmpty) {
      state = state.copyWith(
        captchaChallenge: challenge.copyWith(error: '请输入图形验证码'),
      );
      return;
    }

    state = state.copyWith(
      captchaChallenge: challenge.copyWith(submitting: true, clearError: true),
    );
    try {
      final fingerprint = await loadDeviceFingerprint();
      final result = await loginJwxt(
        challenge.username,
        challenge.password,
        deviceFingerprint: fingerprint,
        captchaToken: challenge.captchaToken,
        captchaCode: cleanCode,
      );
      if (state.captchaChallenge?.captchaToken != challenge.captchaToken) {
        return;
      }
      await _handleLoginResponse(
        result,
        username: challenge.username,
        password: challenge.password,
        remember: challenge.remember,
        fromCaptchaDialog: true,
      );
    } on DioException catch (e) {
      if (state.captchaChallenge?.captchaToken != challenge.captchaToken) {
        return;
      }
      state = state.copyWith(
        captchaChallenge: challenge.copyWith(
          submitting: false,
          error: handleError(e).message,
        ),
      );
    } catch (e) {
      if (state.captchaChallenge?.captchaToken != challenge.captchaToken) {
        return;
      }
      state = state.copyWith(
        captchaChallenge: challenge.copyWith(
          submitting: false,
          error: '提交验证码失败：$e',
        ),
      );
    }
  }

  Future<void> sendMfaCode(String method) async {
    final challenge = state.mfaChallenge;
    if (challenge == null || challenge.sending) return;

    state = state.copyWith(
      mfaChallenge: challenge.copyWith(
        selectedMethod: method,
        sending: true,
        clearError: true,
      ),
    );
    try {
      final result = await sendJwxtMfaCode(
        challenge.loginToken,
        method: method,
      );
      if (state.mfaChallenge?.loginToken != challenge.loginToken) return;
      if (result.isOk && result.data != null) {
        final data = result.data!;
        final activeMethod = data['method'] as String? ?? method;
        final countdown = (data['countdown'] as num?)?.toInt() ?? 120;
        final msg = data['message'] as String? ?? '验证码已发送';
        state = state.copyWith(
          mfaChallenge: challenge.copyWith(
            selectedMethod: activeMethod,
            codeSent: true,
            countdown: countdown,
            codeSentAt: DateTime.now(),
            message: msg,
            sending: false,
            clearError: true,
          ),
        );
        return;
      }

      if (result.code == 'SESSION_EXPIRED' || result.statusCode == 401) {
        state = state.copyWith(
          clearChallenges: true,
          error: result.message,
        );
        return;
      }

      state = state.copyWith(
        mfaChallenge: challenge.copyWith(
          selectedMethod: method,
          sending: false,
          error: result.message,
        ),
      );
    } on DioException catch (e) {
      if (state.mfaChallenge?.loginToken != challenge.loginToken) return;
      state = state.copyWith(
        mfaChallenge: challenge.copyWith(
          selectedMethod: method,
          sending: false,
          error: handleError(e).message,
        ),
      );
    } catch (e) {
      if (state.mfaChallenge?.loginToken != challenge.loginToken) return;
      state = state.copyWith(
        mfaChallenge: challenge.copyWith(
          selectedMethod: method,
          sending: false,
          error: '发送验证码失败：$e',
        ),
      );
    }
  }

  Future<void> verifyMfaCode(String code, {bool trustDevice = true}) async {
    final challenge = state.mfaChallenge;
    if (challenge == null || challenge.verifying) return;
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      state = state.copyWith(
        mfaChallenge: challenge.copyWith(error: '请输入动态验证码'),
      );
      return;
    }

    state = state.copyWith(
      mfaChallenge: challenge.copyWith(verifying: true, clearError: true),
    );
    try {
      final result = await verifyJwxtMfaCode(
        challenge.loginToken,
        cleanCode,
        trustDevice: trustDevice,
      );
      if (state.mfaChallenge?.loginToken != challenge.loginToken) return;
      if (result.isOk && result.data?['status'] == 'success') {
        await _completeLoginSuccess(
          result.data!,
          username: challenge.username,
          password: challenge.password,
          remember: challenge.remember,
        );
        return;
      }

      if (result.code == 'SESSION_EXPIRED' || result.statusCode == 401) {
        state = state.copyWith(
          clearChallenges: true,
          error: result.message,
        );
        return;
      }

      state = state.copyWith(
        mfaChallenge: challenge.copyWith(
          verifying: false,
          error: result.data?['message'] as String? ?? result.message,
        ),
      );
    } on DioException catch (e) {
      if (state.mfaChallenge?.loginToken != challenge.loginToken) return;
      state = state.copyWith(
        mfaChallenge: challenge.copyWith(
          verifying: false,
          error: handleError(e).message,
        ),
      );
    } catch (e) {
      if (state.mfaChallenge?.loginToken != challenge.loginToken) return;
      state = state.copyWith(
        mfaChallenge: challenge.copyWith(
          verifying: false,
          error: '验证失败：$e',
        ),
      );
    }
  }

  void cancelChallenge() {
    state = state.copyWith(
      loading: false,
      clearChallenges: true,
    );
  }

  Future<void> _handleLoginResponse(
    ApiResponse<Map<String, dynamic>> result, {
    required String username,
    required String password,
    required bool remember,
    bool fromCaptchaDialog = false,
    bool markSessionExpired = false,
  }) async {
    final data = result.data;
    final fingerprint = data?['device_fingerprint'] as String?;
    if (fingerprint != null && fingerprint.isNotEmpty) {
      await saveDeviceFingerprint(fingerprint);
    }

    if (result.isOk && data != null) {
      final status = data['status'] as String?;
      if (status == 'success') {
        await _completeLoginSuccess(
          data,
          username: username,
          password: password,
          remember: remember,
        );
        return;
      }

      if (status == 'need_captcha') {
        final token = data['captcha_token'] as String? ?? '';
        final imageB64 = data['captcha_image'] as String? ?? '';
        final message = data['message'] as String? ?? '请输入图形验证码';
        if (token.isEmpty || imageB64.isEmpty) {
          state = state.copyWith(
            loading: false,
            checking: false,
            sessionExpired: markSessionExpired ? true : state.sessionExpired,
            clearChallenges: true,
            error: '获取图形验证码失败，请重试',
          );
          return;
        }
        try {
          final bytes = base64Decode(imageB64);
          state = state.copyWith(
            loading: false,
            checking: false,
            sessionExpired: markSessionExpired ? true : state.sessionExpired,
            clearError: true,
            clearMfa: true,
            captchaChallenge: CaptchaChallengeState(
              captchaToken: token,
              imageBytes: bytes,
              message: message,
              username: username,
              password: password,
              remember: remember,
              error: fromCaptchaDialog ? message : null,
            ),
          );
        } catch (_) {
          state = state.copyWith(
            loading: false,
            checking: false,
            sessionExpired: markSessionExpired ? true : state.sessionExpired,
            clearChallenges: true,
            error: '图形验证码数据解析失败，请重试',
          );
        }
        return;
      }

      if (status == 'need_mfa') {
        final token = data['login_token'] as String? ?? '';
        final rawMethods = (data['available_methods'] as List<dynamic>? ?? [])
            .map((e) => '$e')
            .where((m) => m == 'wechat' || m == 'sms')
            .toList();
        final available = rawMethods.isEmpty ? ['wechat', 'sms'] : rawMethods;
        final rawDefault = data['default_method'] as String? ?? '';
        final defaultMethod = available.contains(rawDefault)
            ? rawDefault
            : available.first;
        state = state.copyWith(
          loading: false,
          checking: false,
          sessionExpired: markSessionExpired ? true : state.sessionExpired,
          clearError: true,
          clearCaptcha: true,
          mfaChallenge: MfaChallengeState(
            loginToken: token,
            defaultMethod: defaultMethod,
            selectedMethod: defaultMethod,
            availableMethods: available,
            message: data['message'] as String? ?? '统一身份认证平台要求二次验证',
            username: username,
            password: password,
            remember: remember,
          ),
        );
        return;
      }
    }

    state = state.copyWith(
      loading: false,
      checking: false,
      sessionExpired: markSessionExpired ? true : state.sessionExpired,
      clearChallenges: true,
      error: data?['message'] as String? ?? result.message,
    );
  }

  Future<void> _completeLoginSuccess(
    Map<String, dynamic> data, {
    required String username,
    required String password,
    required bool remember,
  }) async {
    final cookie = data['cookie'] as String?;
    if (cookie == null || cookie.isEmpty) {
      state = state.copyWith(
        loading: false,
        checking: false,
        clearChallenges: true,
        error: '登录成功但未返回有效凭证，请重试',
      );
      return;
    }
    final fingerprint = data['device_fingerprint'] as String?;
    if (fingerprint != null && fingerprint.isNotEmpty) {
      await saveDeviceFingerprint(fingerprint);
    }
    final appToken = data['app_token'] as String?;
    if (appToken != null) await saveAppToken(appToken);
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
      appToken: appToken,
      isAdmin: data['is_admin'] == true,
      sessionExpired: false,
      sessionVersion: state.sessionVersion + 1,
    );
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
      state = state.copyWith(checking: false, sessionExpired: true);
      return false;
    }
    final username = state.username ?? await _loadUsername();
    final password = await loadPassword();
    if (username == null || password == null) {
      debugPrint('认证：未找到本地凭据');
      state = state.copyWith(checking: false, sessionExpired: true);
      return false;
    }
    debugPrint('认证：开始自动登录');
    try {
      final fingerprint = await loadDeviceFingerprint();
      final result = await loginJwxt(
        username,
        password,
        deviceFingerprint: fingerprint,
      );
      final newFingerprint = result.data?['device_fingerprint'] as String?;
      if (newFingerprint != null && newFingerprint.isNotEmpty) {
        await saveDeviceFingerprint(newFingerprint);
      }
      final status = result.data?['status'] as String?;
      if (result.isOk && status == 'success') {
        final cookie = result.data!['cookie'] as String;
        final appToken = result.data!['app_token'] as String?;
        if (appToken != null) await saveAppToken(appToken);
        await saveCookie(cookie);
        state = state.copyWith(
          isLoggedIn: true,
          checking: false,
          sessionExpired: false,
          clearChallenges: true,
          clearError: true,
          username: username,
          cookie: cookie,
          appToken: appToken ?? state.appToken,
          sessionVersion: state.sessionVersion + 1,
        );
        debugPrint('认证：自动登录成功');
        return true;
      }

      if (result.isOk && (status == 'need_captcha' || status == 'need_mfa')) {
        // 保留后端签发的验证码或二次验证事务，供用户点击“继续验证”完成验证后自动重试原查询
        await _handleLoginResponse(
          result,
          username: username,
          password: password,
          remember: true,
          markSessionExpired: true,
        );
        debugPrint('认证：静默重登需要人工验证($status)，已保留验证事务');
        return false;
      }
    } catch (_) {}
    // 未收到明确的密码错误或需人工交互，保留本地凭据并标记会话过期供用户重新验证
    state = state.copyWith(checking: false, sessionExpired: true);
    debugPrint('认证：自动登录未完成，已标记会话过期');
    return false;
  }

  Future<bool> doElectricityLogin(String username, String password) async {
    try {
      final result = await loginElectricity(username, password);
      if (result.isOk && result.data?['accessToken'] != null) {
        final token = result.data!['accessToken'] as String;
        await saveElectricityToken(token);
        state = state.copyWith(electricityToken: token, electricityFailed: false);
        return true;
      }
    } catch (_) {
      debugPrint('认证：电费模块暂不可用，已跳过');
    }
    return false;
  }

  Future<void> logout() async {
    state = const AuthState();
    await secureDelete('jwxt_cookie');
    await secureDelete('electricity_token');
    await secureDelete('saved_password');
    await secureDelete('remember_password');
    await deleteAppToken();
    final sp = await SharedPreferences.getInstance();
    await sp.remove('username');
    await sp.remove('saved_username');
    // 故意保留 jwxt_device_fingerprint，避免同设备重新登录反复触发二次验证
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
  final String? appToken;
  final bool isAdmin;
  final bool sessionExpired;
  final int sessionVersion;
  final CaptchaChallengeState? captchaChallenge;
  final MfaChallengeState? mfaChallenge;

  bool get hasPendingChallenge =>
      captchaChallenge != null || mfaChallenge != null;

  bool get needsReverification => sessionExpired || hasPendingChallenge;

  const AuthState({
    this.isLoggedIn = false,
    this.loading = false,
    this.checking = false,
    this.cookie,
    this.username,
    this.electricityToken,
    this.error,
    this.electricityFailed = false,
    this.appToken,
    this.isAdmin = false,
    this.sessionExpired = false,
    this.sessionVersion = 0,
    this.captchaChallenge,
    this.mfaChallenge,
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
    String? appToken,
    bool? isAdmin,
    bool? sessionExpired,
    int? sessionVersion,
    CaptchaChallengeState? captchaChallenge,
    MfaChallengeState? mfaChallenge,
    bool clearCaptcha = false,
    bool clearMfa = false,
    bool clearChallenges = false,
  }) => AuthState(
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    loading: loading ?? this.loading,
    checking: checking ?? this.checking,
    cookie: cookie ?? this.cookie,
    username: username ?? this.username,
    electricityToken: electricityToken ?? this.electricityToken,
    error: clearError ? null : (error ?? this.error),
    electricityFailed: electricityFailed ?? this.electricityFailed,
    appToken: appToken ?? this.appToken,
    isAdmin: isAdmin ?? this.isAdmin,
    sessionExpired: sessionExpired ?? this.sessionExpired,
    sessionVersion: sessionVersion ?? this.sessionVersion,
    captchaChallenge: (clearChallenges || clearCaptcha)
        ? null
        : (captchaChallenge ?? this.captchaChallenge),
    mfaChallenge: (clearChallenges || clearMfa)
        ? null
        : (mfaChallenge ?? this.mfaChallenge),
  );
}

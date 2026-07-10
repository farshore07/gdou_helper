import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/update_service.dart';
import '../utils/version_compare.dart';

/// 更新检查状态
enum UpdateCheckStatus {
  /// 未检查
  idle,

  /// 检查中
  checking,

  /// 已是最新版本
  latest,

  /// 存在新版本
  updateAvailable,

  /// 检查失败
  failed,
}

/// 更新检查状态数据
class UpdateCheckState {
  final UpdateCheckStatus status;
  final String currentVersion;
  final String? latestVersion;
  final String? releaseUrl;
  final String? releaseNotes;
  final String? releaseName;
  final DateTime? publishedAt;
  final String? error;

  bool get hasUpdate => status == UpdateCheckStatus.updateAvailable;

  const UpdateCheckState({
    this.status = UpdateCheckStatus.idle,
    this.currentVersion = '',
    this.latestVersion,
    this.releaseUrl,
    this.releaseNotes,
    this.releaseName,
    this.publishedAt,
    this.error,
  });

  UpdateCheckState copyWith({
    UpdateCheckStatus? status,
    String? currentVersion,
    String? latestVersion,
    String? releaseUrl,
    String? releaseNotes,
    String? releaseName,
    DateTime? publishedAt,
    String? error,
  }) => UpdateCheckState(
    status: status ?? this.status,
    currentVersion: currentVersion ?? this.currentVersion,
    latestVersion: latestVersion ?? this.latestVersion,
    releaseUrl: releaseUrl ?? this.releaseUrl,
    releaseNotes: releaseNotes ?? this.releaseNotes,
    releaseName: releaseName ?? this.releaseName,
    publishedAt: publishedAt ?? this.publishedAt,
    error: error ?? this.error,
  );
}

/// 更新检查 Notifier
class UpdateCheckNotifier extends Notifier<UpdateCheckState> {
  static const _cacheKey = 'update_check_cache';
  static const _cacheTsKey = 'update_check_cache_ts';
  static const _cacheTtl = Duration(hours: 1);

  Future<void>? _checkFuture;

  @override
  UpdateCheckState build() {
    _loadCurrentVersion();
    _loadCachedResult();
    return const UpdateCheckState();
  }

  /// 从 package_info_plus 读取当前应用版本
  Future<void> _loadCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      state = state.copyWith(currentVersion: info.version);
    } catch (e) {
      debugPrint('更新检查：读取版本号失败 $e');
    }
  }

  /// 加载缓存的检查结果（不阻塞启动）
  Future<void> _loadCachedResult() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final ts = sp.getInt(_cacheTsKey) ?? 0;
      if (ts == 0) return;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _cacheTtl.inMilliseconds) return;
      final json = sp.getString(_cacheKey);
      if (json == null) return;
      final map = jsonDecode(json) as Map<String, dynamic>;
      state = state.copyWith(
        status: UpdateCheckStatus.values[map['status'] as int? ?? 0],
        latestVersion: map['latestVersion'] as String?,
        releaseUrl: map['releaseUrl'] as String?,
        releaseNotes: map['releaseNotes'] as String?,
        releaseName: map['releaseName'] as String?,
        publishedAt: map['publishedAt'] != null
            ? DateTime.tryParse(map['publishedAt'] as String)
            : null,
      );
    } catch (e) {
      debugPrint('更新检查：加载缓存失败 $e');
    }
  }

  /// 保存检查结果到缓存
  Future<void> _saveCache(UpdateCheckState s) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final map = {
        'status': s.status.index,
        'latestVersion': s.latestVersion,
        'releaseUrl': s.releaseUrl,
        'releaseNotes': s.releaseNotes,
        'releaseName': s.releaseName,
        'publishedAt': s.publishedAt?.toIso8601String(),
      };
      await sp.setString(_cacheKey, jsonEncode(map));
      await sp.setInt(_cacheTsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('更新检查：保存缓存失败 $e');
    }
  }

  /// 检查更新
  ///
  /// 检查期间避免重复请求。用户主动点击时总是触发新请求。
  Future<void> checkForUpdate() async {
    if (_checkFuture != null) return _checkFuture;
    _checkFuture = _performCheck();
    try {
      await _checkFuture;
    } finally {
      _checkFuture = null;
    }
  }

  Future<void> _performCheck() async {
    state = state.copyWith(status: UpdateCheckStatus.checking, error: null);

    try {
      final release = await fetchLatestRelease();
      final hasUpdate = VersionCompare.isNewer(
        state.currentVersion,
        release.tagName,
      );

      final newState = UpdateCheckState(
        status: hasUpdate
            ? UpdateCheckStatus.updateAvailable
            : UpdateCheckStatus.latest,
        currentVersion: state.currentVersion,
        latestVersion: release.tagName,
        releaseUrl: release.htmlUrl,
        releaseNotes: release.body,
        releaseName: release.name,
        publishedAt: release.publishedAt,
      );
      state = newState;
      await _saveCache(newState);
    } on UpdateCheckException catch (e) {
      final newState = state.copyWith(
        status: UpdateCheckStatus.failed,
        error: e.message,
      );
      state = newState;
    } catch (e) {
      final newState = state.copyWith(
        status: UpdateCheckStatus.failed,
        error: '检查更新失败，请稍后重试',
      );
      state = newState;
    }
  }
}

/// 更新检查 Provider
final updateCheckProvider =
    NotifierProvider<UpdateCheckNotifier, UpdateCheckState>(
      UpdateCheckNotifier.new,
    );

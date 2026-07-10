import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/release_info.dart';

/// 更新检查异常
class UpdateCheckException implements Exception {
  final String message;
  const UpdateCheckException(this.message);

  @override
  String toString() => message;
}

/// 创建 GitHub API 专用 Dio 实例
///
/// 使用独立实例，不与后端 API 的 [dio] 共享配置和拦截器。
Dio createGithubDio() => Dio(
      BaseOptions(
        baseUrl: 'https://api.github.com',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': AppConfig.githubAcceptHeader,
          'X-GitHub-Api-Version': AppConfig.githubApiVersionHeader,
          'User-Agent': AppConfig.userAgent,
        },
        validateStatus: (s) => true,
      ),
    );

Dio? _githubDio;

Dio _getDio() => _githubDio ??= createGithubDio();

/// 仅用于测试：注入自定义 Dio 实例
// ignore: library_private_types_in_api_code
void setGithubDioForTesting(Dio dio) => _githubDio = dio;

/// 仅用于测试：重置 Dio 实例
void resetGithubDioForTesting() => _githubDio = null;

/// 获取 GitHub 最新正式 Release
///
/// 自动过滤 Draft 和 Prerelease。
/// 异常以 [UpdateCheckException] 形式抛出，包含用户可读的错误信息。
Future<ReleaseInfo> fetchLatestRelease({Dio? client}) async {
  final dio = client ?? _getDio();
  try {
    final response = await dio.get(
      '/repos/${AppConfig.githubOwner}/${AppConfig.githubRepo}/releases/latest',
    );

    final status = response.statusCode ?? 0;

    if (status == 404) {
      throw const UpdateCheckException('仓库暂无发布版本');
    }
    if (status == 429) {
      throw const UpdateCheckException('GitHub API 限流，请稍后重试');
    }
    if (status != 200) {
      throw const UpdateCheckException('检查更新失败，请稍后重试');
    }

    final data = response.data;
    if (data is! Map) {
      throw const UpdateCheckException('解析更新信息失败');
    }

    final release = ReleaseInfo.fromJson(Map<String, dynamic>.from(data));

    if (release.draft) {
      throw const UpdateCheckException('暂无正式发布版本');
    }
    if (release.prerelease) {
      throw const UpdateCheckException('暂无正式发布版本');
    }
    if (release.tagName.isEmpty) {
      throw const UpdateCheckException('远程版本信息无效');
    }
    if (release.htmlUrl.isEmpty) {
      throw const UpdateCheckException('更新地址缺失');
    }

    return release;
  } on UpdateCheckException {
    rethrow;
  } on DioException catch (e) {
    throw switch (e.type) {
      DioExceptionType.connectionTimeout =>
        const UpdateCheckException('网络连接超时，请检查网络'),
      DioExceptionType.receiveTimeout =>
        const UpdateCheckException('网络响应超时，请重试'),
      DioExceptionType.connectionError =>
        const UpdateCheckException('网络连接失败，请检查网络'),
      _ => const UpdateCheckException('检查更新失败，请稍后重试'),
    };
  } on FormatException {
    throw const UpdateCheckException('解析更新信息失败');
  } catch (e) {
    throw const UpdateCheckException('检查更新失败，请稍后重试');
  }
}

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/release_info.dart';

class UpdateCheckException implements Exception {
  final String message;
  const UpdateCheckException(this.message);
  @override
  String toString() => message;
}

class UpdateService {
  final Dio _client;
  UpdateService({Dio? client})
    : _client =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              validateStatus: (status) => status != null && status < 600,
            ),
          );

  Future<ReleaseInfo> fetchLatestRelease() async {
    try {
      final response = await _client.get(
        AppConfig.githubReleasesApi,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'gdou-helper',
          },
        ),
      );
      if (response.statusCode != 200) {
        throw UpdateCheckException(_messageForStatus(response.statusCode));
      }
      final data = response.data;
      if (data is! Map) throw const UpdateCheckException('GitHub 返回数据格式异常');
      final release = ReleaseInfo.fromJson(Map<String, dynamic>.from(data));
      if (!isAllowedReleaseUrl(release.htmlUrl)) {
        throw const UpdateCheckException('Release 链接不安全');
      }
      return release;
    } on UpdateCheckException {
      rethrow;
    } on FormatException catch (error) {
      throw UpdateCheckException(error.message);
    } on DioException catch (_) {
      throw const UpdateCheckException('网络连接失败，请检查网络后重试');
    } catch (_) {
      throw const UpdateCheckException('检查更新失败，请稍后重试');
    }
  }

  static bool isAllowedReleaseUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        (uri.host == 'github.com' || uri.host == 'www.github.com') &&
        uri.path.startsWith('/${AppConfig.githubRepositoryPath}/releases/tag/');
  }

  static String _messageForStatus(int? status) => switch (status) {
    404 => 'GitHub 仓库或 Release 不存在',
    403 => 'GitHub 请求过于频繁，请稍后重试',
    _ => 'GitHub 服务暂不可用，请稍后重试',
  };
}

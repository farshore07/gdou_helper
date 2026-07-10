/// 应用统一配置
///
/// 集中管理 GitHub 仓库地址等配置，避免散落在页面代码中。
class AppConfig {
  AppConfig._();

  /// GitHub 仓库所有者
  static const String githubOwner = 'farshore07';

  /// GitHub 仓库名称
  static const String githubRepo = 'gdou_helper';

  /// GitHub 仓库页面地址
  static const String githubRepoUrl =
      'https://github.com/$githubOwner/$githubRepo';

  /// GitHub API 最新 Release 端点
  static const String githubLatestReleaseApi =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  /// 请求头：Accept
  static const String githubAcceptHeader = 'application/vnd.github+json';

  /// 请求头：X-GitHub-Api-Version
  static const String githubApiVersionHeader = '2022-11-28';

  /// 请求头：User-Agent
  static const String userAgent = 'gdou_helper';
}

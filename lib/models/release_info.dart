import '../utils/semantic_version.dart';

class ReleaseInfo {
  final String tagName;
  final String htmlUrl;
  final String name;
  final String body;
  final DateTime? publishedAt;
  final SemanticVersion version;

  const ReleaseInfo({
    required this.tagName,
    required this.htmlUrl,
    required this.name,
    required this.body,
    required this.publishedAt,
    required this.version,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    final url = json['html_url'] as String? ?? '';
    if (json['draft'] == true || json['prerelease'] == true) {
      throw const FormatException('Release 不是正式版本');
    }
    final version = SemanticVersion.tryParse(tag);
    if (version == null || url.isEmpty) {
      throw const FormatException('Release 信息缺少有效版本或链接');
    }
    final published = json['published_at'] as String?;
    return ReleaseInfo(
      tagName: tag,
      htmlUrl: url,
      name: json['name'] as String? ?? tag,
      body: json['body'] as String? ?? '',
      publishedAt: published == null ? null : DateTime.tryParse(published),
      version: version,
    );
  }
}

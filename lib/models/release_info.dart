/// GitHub Release 数据模型
class ReleaseInfo {
  final String tagName;
  final String htmlUrl;
  final String name;
  final String body;
  final DateTime? publishedAt;
  final bool draft;
  final bool prerelease;

  const ReleaseInfo({
    required this.tagName,
    required this.htmlUrl,
    required this.name,
    required this.body,
    this.publishedAt,
    required this.draft,
    required this.prerelease,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    return ReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      draft: json['draft'] as bool? ?? false,
      prerelease: json['prerelease'] as bool? ?? false,
    );
  }
}

/// 版本号解析与比较工具
///
/// 支持标准语义化版本格式：主版本号.次版本号.修订号
/// 例如：1.0.0、v1.2.3、2.0.0
class VersionCompare {
  VersionCompare._();

  /// 从版本标签中移除前缀 `v` 或 `V`
  static String stripPrefix(String tag) {
    var v = tag.trim();
    while (v.isNotEmpty && (v.startsWith('v') || v.startsWith('V'))) {
      v = v.substring(1);
    }
    return v;
  }

  /// 将版本字符串解析为数字列表
  ///
  /// 支持格式：`1.0.0`、`v1.2.3`
  /// 返回 `null` 表示格式无效。
  static List<int>? parse(String version) {
    final cleaned = stripPrefix(version);
    if (cleaned.isEmpty) return null;
    final parts = cleaned.split('.');
    if (parts.isEmpty) return null;
    final nums = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null) return null;
      nums.add(n);
    }
    return nums;
  }

  /// 比较两个版本号列表
  ///
  /// 返回：`-1`（a < b）、`0`（a == b）、`1`（a > b）
  static int compare(List<int> a, List<int> b) {
    final maxLen = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < maxLen; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av < bv) return -1;
      if (av > bv) return 1;
    }
    return 0;
  }

  /// 判断 [remote] 是否比 [current] 新
  ///
  /// 任一版本格式无效时返回 `false`，不误判为存在更新。
  static bool isNewer(String current, String remote) {
    final cur = parse(current);
    final rem = parse(remote);
    if (cur == null || rem == null) return false;
    return compare(rem, cur) > 0;
  }
}

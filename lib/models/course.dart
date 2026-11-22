class Course {
  final String id;
  final String name;
  final String teacher;
  final String classroom;
  final String? credit;
  final int dayOfWeek; // 1=周一, 7=周日
  final int startWeek;
  final int endWeek;
  final List<int> weekNumbers; // 精确上课周次（支持单双周、跳周）
  final String weeksText; // 原始周次描述，如 "1-9周(单)"
  final int startPeriod; // 第几节开始
  final int duration; // 持续节数
  final int color; // 0xAARRGGBB
  final String? note;
  final String semester; // e.g. "2025-2026-2"

  const Course({
    required this.id,
    required this.name,
    this.teacher = '',
    this.classroom = '',
    this.credit = '',
    required this.dayOfWeek,
    required this.startWeek,
    required this.endWeek,
    this.weekNumbers = const [],
    this.weeksText = '',
    required this.startPeriod,
    this.duration = 2,
    this.color = 0xFF4A90D9,
    this.note,
    this.semester = '2025-2026-2',
  });

  /// 判断课程在第 [week] 周是否上课，课表筛选与详情弹窗共用此逻辑。
  bool isActiveInWeek(int week) {
    if (weekNumbers.isNotEmpty) {
      return weekNumbers.contains(week);
    }
    return startWeek <= week && week <= endWeek;
  }

  /// 供课程详情展示的周次文本。
  String get weeksDisplay {
    if (weeksText.trim().isNotEmpty) return weeksText.trim();
    if (weekNumbers.isNotEmpty) {
      return _formatWeekNumbers(weekNumbers);
    }
    return '第$startWeek-$endWeek周';
  }

  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? classroom,
    String? credit,
    int? dayOfWeek,
    int? startWeek,
    int? endWeek,
    List<int>? weekNumbers,
    String? weeksText,
    int? startPeriod,
    int? duration,
    int? color,
    String? note,
    bool clearNote = false,
    String? semester,
  }) => Course(
    id: id ?? this.id,
    name: name ?? this.name,
    teacher: teacher ?? this.teacher,
    classroom: classroom ?? this.classroom,
    credit: credit ?? this.credit,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    startWeek: startWeek ?? this.startWeek,
    endWeek: endWeek ?? this.endWeek,
    weekNumbers: weekNumbers ?? this.weekNumbers,
    weeksText: weeksText ?? this.weeksText,
    startPeriod: startPeriod ?? this.startPeriod,
    duration: duration ?? this.duration,
    color: color ?? this.color,
    note: clearNote ? null : (note ?? this.note),
    semester: semester ?? this.semester,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'classroom': classroom,
    'credit': credit,
    'dayOfWeek': dayOfWeek,
    'startWeek': startWeek,
    'endWeek': endWeek,
    'weekNumbers': weekNumbers,
    'weeksText': weeksText,
    'startPeriod': startPeriod,
    'duration': duration,
    'color': color,
    'note': note,
    'semester': semester,
  };

  factory Course.fromJson(Map<String, dynamic> json) {
    final weeksText = (json['weeksText'] as String?) ?? '';
    var parsedWeeks = _extractWeekNumbers(json['weekNumbers']);
    if (parsedWeeks.isEmpty && weeksText.isNotEmpty) {
      parsedWeeks = parseWeekNumbers(weeksText);
    }
    return Course(
      id: json['id'] as String,
      name: json['name'] as String,
      teacher: (json['teacher'] as String?) ?? '',
      classroom: (json['classroom'] as String?) ?? '',
      credit: (json['credit'] as String?) ?? '',
      dayOfWeek: json['dayOfWeek'] as int,
      startWeek: json['startWeek'] as int,
      endWeek: json['endWeek'] as int,
      weekNumbers: parsedWeeks,
      weeksText: weeksText,
      startPeriod: json['startPeriod'] as int,
      duration: (json['duration'] as int?) ?? 2,
      color: (json['color'] as int?) ?? 0xFF4A90D9,
      note: json['note'] as String?,
      semester: (json['semester'] as String?) ?? '2025-2026-2',
    );
  }

  // ── 从教务 API TimetableCourse 解析 ──
  factory Course.fromApiJson(Map<String, dynamic> json, String semester) {
    final weeksRaw = (json['weeks'] as String? ?? '').trim();
    final periodsRaw = json['periods'] as String? ?? '';
    final periods = _parseRange(periodsRaw);

    // 优先使用后端返回的精确 week_numbers；旧缓存缺失时再解析 weeks 文本
    var exactWeeks = _extractWeekNumbers(json['week_numbers']);
    if (exactWeeks.isEmpty && weeksRaw.isNotEmpty) {
      exactWeeks = parseWeekNumbers(weeksRaw);
    }
    final startWeek = exactWeeks.isNotEmpty ? exactWeeks.first : 1;
    final endWeek = exactWeeks.isNotEmpty ? exactWeeks.last : 18;

    final name = json['course_name'] as String? ?? '';
    return Course(
      id: json['course_code'] as String? ?? name,
      name: name,
      teacher: (json['teacher'] as String?) ?? '',
      classroom: (json['classroom'] as String?) ?? '',
      credit: (json['credit'] as String?) ?? '',
      dayOfWeek: int.tryParse('${json['weekday'] ?? ''}') ?? 1,
      startWeek: startWeek,
      endWeek: endWeek,
      weekNumbers: exactWeeks,
      weeksText: weeksRaw,
      startPeriod: periods.$1,
      duration: (periods.$2 - periods.$1 + 1).clamp(1, 12),
      color: _colorFor(name),
      semester: semester,
    );
  }

  // 解析 periods: "1-2节" → (1, 2)
  static (int, int) _parseRange(String s) {
    final cleaned = s.replaceAll('节', '').trim();
    final parts = cleaned.split('-');
    final a = int.tryParse(parts[0]) ?? 1;
    final b = parts.length > 1 ? (int.tryParse(parts[1]) ?? a) : a;
    return (a, b);
  }

  static List<int> _extractWeekNumbers(dynamic raw) {
    if (raw is! List) return const [];
    final seen = <int>{};
    for (final item in raw) {
      final n = item is num ? item.toInt() : int.tryParse('$item');
      if (n != null && n > 0) seen.add(n);
    }
    final sorted = seen.toList()..sort();
    return List<int>.unmodifiable(sorted);
  }

  /// 解析周次文本为有序精确周次列表：支持 "1-9周(单)"、"2-10周(双)"、"1-5周,8-12周"、"13周" 等格式。
  static List<int> parseWeekNumbers(String s) {
    final normalized = s
        .replaceAll('周', '')
        .replaceAll('，', ',')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .trim();
    if (normalized.isEmpty) return const [];

    final seen = <int>{};
    for (final rawPart in normalized.split(',')) {
      var part = rawPart.trim();
      if (part.isEmpty) continue;
      final isOdd = part.contains('(单)') || part.contains('单');
      final isEven = part.contains('(双)') || part.contains('双');
      part = part
          .replaceAll('(单)', '')
          .replaceAll('(双)', '')
          .replaceAll('单', '')
          .replaceAll('双', '')
          .trim();
      if (part.contains('-')) {
        final range = part.split('-');
        final a = int.tryParse(range[0].trim()) ?? 0;
        final b = range.length > 1 ? (int.tryParse(range[1].trim()) ?? a) : a;
        for (var w = a; w <= b; w++) {
          if (w <= 0) continue;
          if (isOdd && w.isEven) continue;
          if (isEven && w.isOdd) continue;
          seen.add(w);
        }
      } else {
        final n = int.tryParse(part) ?? 0;
        if (n <= 0) continue;
        if (isOdd && n.isEven) continue;
        if (isEven && n.isOdd) continue;
        seen.add(n);
      }
    }
    final sorted = seen.toList()..sort();
    return List<int>.unmodifiable(sorted);
  }

  static String _formatWeekNumbers(List<int> weeks) {
    if (weeks.isEmpty) return '';
    return '第${weeks.join(',')}周';
  }

  static int _colorFor(String name) =>
      _palette[name.hashCode.abs() % _palette.length];

  // 24 色，柔和好看，白字清晰
  static const _palette = [
    0xFF5B8FF9,
    0xFF61DDAA,
    0xFFF6BD16,
    0xFFE8684A,
    0xFF6DC8EC,
    0xFF9270CA,
    0xFFFF9D4D,
    0xFF269A99,
    0xFFFF6B8A,
    0xFF40A9FF,
    0xFF73C0A3,
    0xFFE6A23C,
    0xFFD96C6C,
    0xFF5B9BD5,
    0xFFA77BCA,
    0xFF67C23A,
    0xFFF08F82,
    0xFF3BA0C8,
    0xFFE8A93C,
    0xFF8B9B4E,
    0xFFD97382,
    0xFF5282B0,
    0xFF7DCB84,
    0xFFC9A14E,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Course && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

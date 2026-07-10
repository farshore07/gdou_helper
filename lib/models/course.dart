class Course {
  final String id;
  final String name;
  final String teacher;
  final String classroom;
  final String? credit;
  final int dayOfWeek; // 1=周一, 7=周日
  final int startWeek;
  final int endWeek;
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
    required this.startPeriod,
    this.duration = 2,
    this.color = 0xFF4A90D9,
    this.note,
    this.semester = '2025-2026-2',
  });

  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? classroom,
    String? credit,
    int? dayOfWeek,
    int? startWeek,
    int? endWeek,
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
    'startPeriod': startPeriod,
    'duration': duration,
    'color': color,
    'note': note,
    'semester': semester,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] as String,
    name: json['name'] as String,
    teacher: (json['teacher'] as String?) ?? '',
    classroom: (json['classroom'] as String?) ?? '',
    credit: '',
    dayOfWeek: json['dayOfWeek'] as int,
    startWeek: json['startWeek'] as int,
    endWeek: json['endWeek'] as int,
    startPeriod: json['startPeriod'] as int,
    duration: (json['duration'] as int?) ?? 2,
    color: (json['color'] as int?) ?? 0xFF4A90D9,
    note: json['note'] as String?,
    semester: (json['semester'] as String?) ?? '2025-2026-2',
  );

  // ── 从教务 API TimetableCourse 解析 ──
  factory Course.fromApiJson(Map<String, dynamic> json, String semester) {
    final weeksRaw = json['weeks'] as String? ?? '';
    final periodsRaw = json['periods'] as String? ?? '';
    final periods = _parseRange(periodsRaw);
    final weeks = _parseWeeks(weeksRaw);
    final name = json['course_name'] as String? ?? '';
    return Course(
      id: json['course_code'] as String? ?? name,
      name: name,
      teacher: (json['teacher'] as String?) ?? '',
      classroom: (json['classroom'] as String?) ?? '',
      credit: '',
      dayOfWeek: int.tryParse(json['weekday'] as String? ?? '') ?? 1,
      startWeek: weeks.$1,
      endWeek: weeks.$2,
      startPeriod: periods.$1,
      duration: periods.$2 - periods.$1 + 1,
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

  // 解析 weeks: "1-14周", "1-9周,11-12周", "13周", "2-4周(双)"
  static (int, int) _parseWeeks(String s) {
    var cleaned = s
        .replaceAll('周', '')
        .replaceAll('(单)', '')
        .replaceAll('(双)', '')
        .replaceAll('（单）', '')
        .replaceAll('（双）', '')
        .replaceAll('，', ',')
        .trim();
    if (cleaned.isEmpty) return (1, 18);

    final allWeeks = <int>[];
    for (final part in cleaned.split(',')) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final range = trimmed.split('-');
        final a = int.tryParse(range[0]) ?? 0;
        final b = range.length > 1 ? (int.tryParse(range[1]) ?? a) : a;
        for (var w = a; w <= b; w++) {
          if (w > 0) allWeeks.add(w);
        }
      } else {
        final n = int.tryParse(trimmed) ?? 0;
        if (n > 0) allWeeks.add(n);
      }
    }
    if (allWeeks.isEmpty) return (1, 18);
    return (allWeeks.first, allWeeks.last);
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

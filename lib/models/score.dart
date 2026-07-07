enum ScoreCategory { required, elective }

class Score {
  final String id;
  final String courseName;
  final double score; // 0-100
  final double credit;
  final double gpaPoint; // 4.0 制绩点
  final String semester;
  final ScoreCategory category;
  final String gradeText; // 原始成绩文本("中等"、"86"等)

  const Score({
    required this.id,
    required this.courseName,
    required this.score,
    required this.credit,
    required this.gpaPoint,
    required this.semester,
    this.category = ScoreCategory.required,
    this.gradeText = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseName': courseName,
        'score': score,
        'credit': credit,
        'gpaPoint': gpaPoint,
        'semester': semester,
        'category': category.name,
        'gradeText': gradeText,
      };

  factory Score.fromJson(Map<String, dynamic> json) => Score(
        id: json['id'] as String,
        courseName: json['courseName'] as String,
        score: (json['score'] as num).toDouble(),
        credit: (json['credit'] as num).toDouble(),
        gpaPoint: (json['gpaPoint'] as num).toDouble(),
        semester: json['semester'] as String,
        category: ScoreCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => ScoreCategory.required,
        ),
        gradeText: (json['gradeText'] as String?) ?? '',
      );

  Score copyWith({
    String? id,
    String? courseName,
    double? score,
    double? credit,
    double? gpaPoint,
    String? semester,
    ScoreCategory? category,
    String? gradeText,
  }) =>
      Score(
        id: id ?? this.id,
        courseName: courseName ?? this.courseName,
        score: score ?? this.score,
        credit: credit ?? this.credit,
        gpaPoint: gpaPoint ?? this.gpaPoint,
        semester: semester ?? this.semester,
        category: category ?? this.category,
        gradeText: gradeText ?? this.gradeText,
      );

  // ── 从教务 API GradeRecord 解析 ──
  factory Score.fromApiJson(Map<String, dynamic> json, String semester) {
    final name = json['course_name'] as String? ?? '';
    final rawGrade = json['grade'] as String? ?? '0';
    final numericScore = _toNumeric(rawGrade);
    return Score(
      id: json['course_code'] as String? ?? name,
      courseName: name,
      score: numericScore,
      credit: double.tryParse(json['credit'] as String? ?? '0') ?? 0,
      gpaPoint: double.tryParse(json['grade_point'] as String? ?? '0') ?? 0,
      semester: semester,
      category: _parseCategory(json['course_nature'] as String?),
      gradeText: rawGrade,
    );
  }

  static double _toNumeric(String s) {
    final n = double.tryParse(s);
    if (n != null) return n;
    return _gradeMap[s] ?? 0;
  }

  static const _gradeMap = {
    '优秀': 95.0, '优': 95.0,
    '良好': 85.0, '良': 85.0,
    '中等': 75.0, '中': 75.0,
    '及格': 60.0,
    '不及格': 0.0,
  };

  static ScoreCategory _parseCategory(String? nature) {
    if (nature == null) return ScoreCategory.required;
    return nature.contains('选修') ? ScoreCategory.elective : ScoreCategory.required;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Score && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

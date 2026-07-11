enum ScoreCategory { required, elective }

class Score {
  final String id;
  final String courseName;
  final double score;
  final double credit;
  final double gpaPoint;
  final String semester;
  final ScoreCategory category;
  final String gradeText;
  final Map<String, String> detailQuery;

  const Score({
    required this.id,
    required this.courseName,
    required this.score,
    required this.credit,
    required this.gpaPoint,
    required this.semester,
    this.category = ScoreCategory.required,
    this.gradeText = '',
    this.detailQuery = const {},
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
    'detailQuery': detailQuery,
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
    detailQuery: Map<String, String>.from(
      json['detailQuery'] as Map? ?? const {},
    ),
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
    Map<String, String>? detailQuery,
  }) => Score(
    id: id ?? this.id,
    courseName: courseName ?? this.courseName,
    score: score ?? this.score,
    credit: credit ?? this.credit,
    gpaPoint: gpaPoint ?? this.gpaPoint,
    semester: semester ?? this.semester,
    category: category ?? this.category,
    gradeText: gradeText ?? this.gradeText,
    detailQuery: detailQuery ?? this.detailQuery,
  );

  factory Score.fromApiJson(Map<String, dynamic> json, String semester) {
    final name = json['course_name'] as String? ?? '';
    final rawGrade = json['grade'] as String? ?? '0';
    return Score(
      id: json['course_code'] as String? ?? name,
      courseName: name,
      score: _toNumeric(rawGrade),
      credit: double.tryParse(json['credit'] as String? ?? '0') ?? 0,
      gpaPoint: double.tryParse(json['grade_point'] as String? ?? '0') ?? 0,
      semester: semester,
      category: _parseCategory(json['course_nature'] as String?),
      gradeText: rawGrade,
      detailQuery: _detailQuery(json),
    );
  }

  static Map<String, String> _detailQuery(Map<String, dynamic> json) {
    const keys = ['jxb_id', 'kch_id', 'kch', 'xnm', 'xqm'];
    return {
      for (final key in keys)
        if (json[key] != null && '${json[key]}'.isNotEmpty) key: '${json[key]}',
    };
  }

  static double _toNumeric(String s) {
    final n = double.tryParse(s);
    if (n != null) return n;
    return _gradeMap[s] ?? 0;
  }

  static const _gradeMap = {
    '优秀': 95.0,
    '优': 95.0,
    '良好': 85.0,
    '良': 85.0,
    '中等': 75.0,
    '中': 75.0,
    '及格': 60.0,
    '不及格': 0.0,
  };

  static ScoreCategory _parseCategory(String? nature) =>
      nature?.contains('选修') == true
      ? ScoreCategory.elective
      : ScoreCategory.required;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Score && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

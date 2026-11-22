import 'package:flutter_riverpod/flutter_riverpod.dart';

class SemesterNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(semesterOptionsProvider).first;

  void select(String s) => state = s;
}

final semesterProvider =
    NotifierProvider<SemesterNotifier, String>(SemesterNotifier.new);

final semesterOptionsProvider = Provider<List<String>>(
  (ref) => semestersForDate(DateTime.now()),
);

// 与无校历时的开学日期一致：9 月 1 日进入第一学期，3 月 1 日进入第二学期。
List<String> semestersForDate(DateTime date) {
  final year = date.month >= 9 ? date.year : date.year - 1;
  final secondTerm = date.month >= 3 && date.month < 9;
  return [
    if (secondTerm) '$year-${year + 1}-2',
    '$year-${year + 1}-1',
    for (var previous = year - 1; previous >= 2024; previous--) ...[
      '$previous-${previous + 1}-2',
      '$previous-${previous + 1}-1',
    ],
  ];
}

String semesterLabel(String s) {
  final parts = s.split('-');
  final prefix = '${parts[0]}-${parts[1]}';
  final term = parts[2] == '1' ? '第一学期' : '第二学期';
  return '$prefix $term';
}

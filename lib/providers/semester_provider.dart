import 'package:flutter_riverpod/flutter_riverpod.dart';

class SemesterNotifier extends Notifier<String> {
  @override
  String build() => '2025-2026-2';

  void select(String s) => state = s;
}

final semesterProvider =
    NotifierProvider<SemesterNotifier, String>(SemesterNotifier.new);

const allSemesters = [
  '2026-2027-1',
  '2025-2026-2',
  '2025-2026-1',
  '2024-2025-2',
  '2024-2025-1',
];

String semesterLabel(String s) {
  final parts = s.split('-');
  final prefix = '${parts[0]}-${parts[1]}';
  final term = parts[2] == '1' ? '第一学期' : '第二学期';
  return '$prefix $term';
}

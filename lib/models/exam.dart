import 'package:flutter/material.dart';

class Exam {
  final String id;
  final String courseName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String location;
  final String? seatNo;
  final int remindBefore; // 提前多少分钟提醒

  const Exam({
    required this.id,
    required this.courseName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.location = '',
    this.seatNo,
    this.remindBefore = 30,
  });

  // ponytail: manual TimeOfDay serialization, freezed overkill for 4 fields
  static const _hourKey = 'hour';
  static const _minuteKey = 'minute';

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseName': courseName,
        'date': date.millisecondsSinceEpoch,
        'startTime': {_hourKey: startTime.hour, _minuteKey: startTime.minute},
        'endTime': {_hourKey: endTime.hour, _minuteKey: endTime.minute},
        'location': location,
        'seatNo': seatNo,
        'remindBefore': remindBefore,
      };

  factory Exam.fromJson(Map<String, dynamic> json) => Exam(
        id: json['id'] as String,
        courseName: json['courseName'] as String,
        date:
            DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
        startTime: _timeFromJson(json['startTime'] as Map<String, dynamic>),
        endTime: _timeFromJson(json['endTime'] as Map<String, dynamic>),
        location: (json['location'] as String?) ?? '',
        seatNo: json['seatNo'] as String?,
        remindBefore: (json['remindBefore'] as int?) ?? 30,
      );

  static TimeOfDay _timeFromJson(Map<String, dynamic> json) =>
      TimeOfDay(hour: json[_hourKey] as int, minute: json[_minuteKey] as int);

  Exam copyWith({
    String? id,
    String? courseName,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? location,
    String? seatNo,
    int? remindBefore,
    bool clearSeatNo = false,
  }) =>
      Exam(
        id: id ?? this.id,
        courseName: courseName ?? this.courseName,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        location: location ?? this.location,
        seatNo: clearSeatNo ? null : (seatNo ?? this.seatNo),
        remindBefore: remindBefore ?? this.remindBefore,
      );

  // ── 从教务 API ExamScheduleRecord 解析 ──
  factory Exam.fromApiJson(Map<String, dynamic> json) {
    final name = json['course_name'] as String? ?? '';
    final (date, start, end) = _parseExamTime(json['exam_time'] as String? ?? '');
    return Exam(
      id: json['course_code'] as String? ?? name,
      courseName: name,
      date: date,
      startTime: start,
      endTime: end,
      location: (json['classroom'] as String?) ?? (json['exam_place'] as String?) ?? '',
    );
  }

  // ponytail: "2026-07-08(14:30-16:30)" or "2026-07-08 14:30-16:30"
  static (DateTime, TimeOfDay, TimeOfDay) _parseExamTime(String s) {
    final now = DateTime.now();
    DateTime date = now;
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 11, minute: 0);
    try {
      final cleaned = s.trim();
      // Extract date (before space or paren)
      final dateStr = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(cleaned)?.group(1);
      if (dateStr != null) date = DateTime.tryParse(dateStr) ?? now;
      // Extract time range (e.g. "14:30-16:30")
      final timeMatch = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})').firstMatch(cleaned);
      if (timeMatch != null) {
        final st = timeMatch.group(1)!.split(':');
        final et = timeMatch.group(2)!.split(':');
        start = TimeOfDay(
            hour: int.tryParse(st[0]) ?? 9,
            minute: st.length > 1 ? (int.tryParse(st[1]) ?? 0) : 0);
        end = TimeOfDay(
            hour: int.tryParse(et[0]) ?? 11,
            minute: et.length > 1 ? (int.tryParse(et[1]) ?? 0) : 0);
      }
    } catch (_) {}
    return (date, start, end);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Exam && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

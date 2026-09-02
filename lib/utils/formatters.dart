import 'package:flutter/material.dart';

import 'date_time_utils.dart';

/// รูปแบบวัน/เวลาแบบไทย (ไม่ต้องโหลด locale data)
class Fmt {
  Fmt._();

  /// แสดงปีเป็น พ.ศ. หรือไม่ (ตั้งค่าได้ในหน้าตั้งค่า)
  static bool buddhistYear = true;

  static const List<String> monthsFull = <String>[
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  static const List<String> monthsShort = <String>[
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  /// index 0 = จันทร์
  static const List<String> weekdaysShort = <String>[
    'จ.',
    'อ.',
    'พ.',
    'พฤ.',
    'ศ.',
    'ส.',
    'อา.',
  ];

  static const List<String> weekdaysFull = <String>[
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];

  static String weekdayShort(int weekday) => weekdaysShort[(weekday - 1) % 7];

  static String weekdayFull(int weekday) => weekdaysFull[(weekday - 1) % 7];

  static int displayYear(int year) => buddhistYear ? year + 543 : year;

  static String two(int value) => value.toString().padLeft(2, '0');

  static String time(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

  static String minutesAsTime(int minutes) =>
      '${two(minutes ~/ 60)}:${two(minutes % 60)}';

  static String date(DateTime d) =>
      '${d.day} ${monthsShort[d.month - 1]} ${displayYear(d.year)}';

  static String dateFull(DateTime d) =>
      '${weekdayFull(d.weekday)}ที่ ${d.day} ${monthsFull[d.month - 1]} ${displayYear(d.year)}';

  static String monthYear(DateTime d) =>
      '${monthsFull[d.month - 1]} ${displayYear(d.year)}';

  static String dateTime(DateTime d, {required bool hasTime}) =>
      hasTime ? '${date(d)} • ${time(d)} น.' : '${date(d)} • ทั้งวัน';

  static String weekRange(DateTime start) {
    final DateTime end = start.add(const Duration(days: 6));
    if (start.month == end.month) {
      return '${start.day} - ${end.day} ${monthsFull[start.month - 1]} ${displayYear(start.year)}';
    }
    return '${start.day} ${monthsShort[start.month - 1]} - ${end.day} ${monthsShort[end.month - 1]} ${displayYear(end.year)}';
  }

  /// ข้อความบอกระยะเวลาที่เหลือ เช่น "อีก 3 วัน", "เลยมาแล้ว 2 ชั่วโมง"
  static String relative(DateTime due, {required bool hasTime, DateTime? now}) {
    final DateTime current = now ?? DateTime.now();
    if (!hasTime) {
      final int days = daysBetween(current, due);
      if (days == 0) return 'วันนี้';
      if (days == 1) return 'พรุ่งนี้';
      if (days == -1) return 'เมื่อวาน';
      return days > 0 ? 'อีก $days วัน' : 'เลยมาแล้ว ${-days} วัน';
    }
    final Duration diff = due.difference(current);
    final Duration abs = diff.abs();
    final String amount;
    if (abs.inMinutes < 60) {
      amount = '${abs.inMinutes} นาที';
    } else if (abs.inHours < 24) {
      amount = '${abs.inHours} ชั่วโมง';
    } else if (abs.inDays < 30) {
      amount = '${abs.inDays} วัน';
    } else {
      amount = '${(abs.inDays / 30).floor()} เดือน';
    }
    return diff.isNegative ? 'เลยมาแล้ว $amount' : 'อีก $amount';
  }

  static String timeOfDay(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

  static String daysLabel(List<int> days) {
    if (days.isEmpty) return 'ยังไม่เลือกวัน';
    if (days.length == 7) return 'ทุกวัน';
    final List<int> sorted = List<int>.from(days)..sort();
    if (sorted.join(',') == '1,2,3,4,5') return 'จันทร์ - ศุกร์';
    if (sorted.join(',') == '6,7') return 'เสาร์ - อาทิตย์';
    return sorted.map(weekdayShort).join(' ');
  }
}

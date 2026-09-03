import '../data/models.dart';

/// ช่วงเวลาที่ใช้แบ่ง Section บนหน้าแรก
enum DeadlineBucket {
  overdue,
  today,
  withinDay,
  withinThreeDays,
  withinWeek,
  withinTwoWeeks,
  withinMonth,
  beyondMonth,
  none,
}

extension DeadlineBucketLabel on DeadlineBucket {
  String get title {
    switch (this) {
      case DeadlineBucket.overdue:
        return 'เลยกำหนดแล้ว';
      case DeadlineBucket.today:
        return 'ครบกำหนดวันนี้';
      case DeadlineBucket.withinDay:
        return 'ภายใน 1 วัน';
      case DeadlineBucket.withinThreeDays:
        return 'ภายใน 3 วัน';
      case DeadlineBucket.withinWeek:
        return 'ภายใน 1 สัปดาห์';
      case DeadlineBucket.withinTwoWeeks:
        return 'ภายใน 2 สัปดาห์';
      case DeadlineBucket.withinMonth:
        return 'ภายใน 1 เดือน';
      case DeadlineBucket.beyondMonth:
        return 'มากกว่า 1 เดือน';
      case DeadlineBucket.none:
        return 'ไม่มีกำหนดส่ง';
    }
  }

  String get subtitle {
    switch (this) {
      case DeadlineBucket.overdue:
        return 'ควรจัดการก่อนเป็นอันดับแรก';
      case DeadlineBucket.today:
        return 'ต้องเสร็จภายในวันนี้';
      case DeadlineBucket.withinDay:
        return 'เหลือไม่ถึง 1 วัน';
      case DeadlineBucket.withinThreeDays:
        return 'เหลือไม่ถึง 3 วัน';
      case DeadlineBucket.withinWeek:
        return 'เหลือไม่ถึง 1 สัปดาห์';
      case DeadlineBucket.withinTwoWeeks:
        return 'เหลือไม่ถึง 2 สัปดาห์';
      case DeadlineBucket.withinMonth:
        return 'เหลือไม่ถึง 1 เดือน';
      case DeadlineBucket.beyondMonth:
        return 'ยังมีเวลาอีกนาน';
      case DeadlineBucket.none:
        return 'เก็บไว้ทำเมื่อว่าง';
    }
  }
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// จันทร์เป็นวันแรกของสัปดาห์
DateTime startOfWeek(DateTime d) => startOfDay(d).subtract(Duration(days: d.weekday - 1));

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

DateTime addMonths(DateTime d, int months) {
  final int total = d.year * 12 + (d.month - 1) + months;
  final int year = total ~/ 12;
  final int month = total % 12 + 1;
  final int day = d.day.clamp(1, daysInMonth(year, month));
  return DateTime(year, month, day, d.hour, d.minute);
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// จำนวนวันเต็ม ๆ ระหว่างสองวัน (ไม่สนใจเวลา)
int daysBetween(DateTime from, DateTime to) =>
    startOfDay(to).difference(startOfDay(from)).inDays;

/// จัดกลุ่มงานตามระยะเวลาที่เหลือ
DeadlineBucket bucketOf(Task task, {DateTime? now}) {
  final DateTime current = now ?? DateTime.now();
  final DateTime? due = task.due;
  if (due == null) return DeadlineBucket.none;

  final int days = daysBetween(current, due);
  if (days < 0) return DeadlineBucket.overdue;
  if (days == 0) {
    // ถ้าระบุเวลาไว้และเวลานั้นผ่านไปแล้ว ถือว่าเลยกำหนด
    if (task.hasTime && due.isBefore(current)) return DeadlineBucket.overdue;
    return DeadlineBucket.today;
  }
  if (days <= 1) return DeadlineBucket.withinDay;
  if (days <= 3) return DeadlineBucket.withinThreeDays;
  if (days <= 7) return DeadlineBucket.withinWeek;
  if (days <= 14) return DeadlineBucket.withinTwoWeeks;
  if (days <= 30) return DeadlineBucket.withinMonth;
  return DeadlineBucket.beyondMonth;
}

/// ลำดับ Section บนหน้าแรก: วันนี้ → ใกล้ครบกำหนด → ไม่มีกำหนด
const List<DeadlineBucket> kHomeBucketOrder = <DeadlineBucket>[
  DeadlineBucket.overdue,
  DeadlineBucket.today,
  DeadlineBucket.withinDay,
  DeadlineBucket.withinThreeDays,
  DeadlineBucket.withinWeek,
  DeadlineBucket.withinTwoWeeks,
  DeadlineBucket.withinMonth,
  DeadlineBucket.beyondMonth,
  DeadlineBucket.none,
];

/// จำนวนวันที่เก็บงานที่ทำเสร็จแล้วไว้ในประวัติ ก่อนจะถูกล้างออกอัตโนมัติ
const int kCompletedRetentionDays = 30;

/// วันเวลาที่งานซึ่งทำเสร็จตอน [completedAt] จะถูกล้างออกจากประวัติ
DateTime completedExpiryOf(DateTime completedAt) =>
    completedAt.add(const Duration(days: kCompletedRetentionDays));

/// งานที่ทำเสร็จตอน [completedAt] เกินระยะเวลาที่เก็บไว้แล้วหรือยัง
bool isCompletionExpired(DateTime completedAt, {DateTime? now}) =>
    !completedExpiryOf(completedAt).isAfter(now ?? DateTime.now());

/// จำนวนวันที่เหลือก่อนงานที่ทำเสร็จแล้วจะถูกล้างออก (0 = จะถูกล้างในรอบถัดไป)
int daysLeftBeforePurge(DateTime completedAt, {DateTime? now}) {
  final DateTime current = now ?? DateTime.now();
  final int left = completedExpiryOf(completedAt).difference(current).inDays;
  return left > 0 ? left : 0;
}

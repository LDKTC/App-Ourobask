import 'package:flutter_test/flutter_test.dart';
import 'package:ourobask/data/models.dart';
import 'package:ourobask/utils/date_time_utils.dart';

void main() {
  group('ประวัติงานที่ทำเสร็จแล้ว', () {
    final DateTime completed = DateTime(2026, 3, 10, 12);

    test('เก็บไว้ 30 วันนับจากเวลาที่ทำเสร็จ', () {
      expect(kCompletedRetentionDays, 30);
      expect(completedExpiryOf(completed), DateTime(2026, 4, 9, 12));
    });

    test('ยังไม่ครบ 30 วันถือว่ายังอยู่ในประวัติ', () {
      expect(
        isCompletionExpired(completed, now: DateTime(2026, 4, 8, 12)),
        isFalse,
      );
    });

    test('ครบ 30 วันพอดีและเกินกว่านั้นถือว่าหมดอายุ', () {
      expect(isCompletionExpired(completed, now: DateTime(2026, 4, 9, 12)), isTrue);
      expect(isCompletionExpired(completed, now: DateTime(2026, 4, 20)), isTrue);
    });

    test('นับวันที่เหลือก่อนถูกล้างออก', () {
      expect(daysLeftBeforePurge(completed, now: DateTime(2026, 3, 10, 12)), 30);
      expect(daysLeftBeforePurge(completed, now: DateTime(2026, 4, 6, 12)), 3);
      expect(daysLeftBeforePurge(completed, now: DateTime(2026, 4, 30)), 0);
    });

    test('งานที่ยังไม่เสร็จไม่มีเวลาทำเสร็จ', () {
      expect(Task(title: 'งาน').completedTime, isNull);
    });

    test('งานที่เสร็จแล้วใช้เวลาที่ติ๊กว่าเสร็จ', () {
      final Task task = Task(title: 'งาน', done: true, completedAt: completed);
      expect(task.completedTime, completed);
    });

    test('งานเก่าที่ไม่มี completed_at ใช้เวลาที่แก้ไขล่าสุดแทน', () {
      final Task task = Task.fromMap(<String, Object?>{
        'id': 1,
        'title': 'งานเก่า',
        'done': 1,
        'color': 0xFF6750A4,
        'created_at': 0,
        'updated_at': completed.millisecondsSinceEpoch,
      });
      expect(task.completedAt, isNull);
      expect(task.completedTime, completed);
    });
  });
}

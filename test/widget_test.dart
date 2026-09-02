import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ourobask/data/backup.dart';
import 'package:ourobask/data/models.dart';
import 'package:ourobask/utils/date_time_utils.dart';
import 'package:ourobask/utils/formatters.dart';

void main() {
  group('การจัดกลุ่มตามกำหนดส่ง', () {
    final DateTime now = DateTime(2026, 3, 10, 12);

    Task taskDue(DateTime? due, {bool hasTime = false}) =>
        Task(title: 'งาน', due: due, hasTime: hasTime);

    test('ไม่ระบุวัน = ไม่มีกำหนด', () {
      expect(bucketOf(taskDue(null), now: now), DeadlineBucket.none);
    });

    test('วันเดียวกันคือวันนี้', () {
      expect(bucketOf(taskDue(DateTime(2026, 3, 10)), now: now), DeadlineBucket.today);
    });

    test('เลยเวลาที่ระบุไว้ในวันเดียวกันถือว่าเลยกำหนด', () {
      expect(
        bucketOf(taskDue(DateTime(2026, 3, 10, 9), hasTime: true), now: now),
        DeadlineBucket.overdue,
      );
    });

    test('งานทั้งวันของวันนี้ยังไม่เลยกำหนดแม้เวลาจะบ่ายแล้ว', () {
      expect(bucketOf(taskDue(DateTime(2026, 3, 10)), now: now), DeadlineBucket.today);
    });

    test('ขอบเขตของแต่ละช่วงเวลา', () {
      expect(
        bucketOf(taskDue(DateTime(2026, 3, 11)), now: now),
        DeadlineBucket.withinDay,
      );
      expect(
        bucketOf(taskDue(DateTime(2026, 3, 13)), now: now),
        DeadlineBucket.withinThreeDays,
      );
      expect(
        bucketOf(taskDue(DateTime(2026, 3, 17)), now: now),
        DeadlineBucket.withinWeek,
      );
      expect(
        bucketOf(taskDue(DateTime(2026, 3, 24)), now: now),
        DeadlineBucket.withinTwoWeeks,
      );
      expect(
        bucketOf(taskDue(DateTime(2026, 4, 9)), now: now),
        DeadlineBucket.withinMonth,
      );
      expect(
        bucketOf(taskDue(DateTime(2026, 6, 1)), now: now),
        DeadlineBucket.beyondMonth,
      );
    });

    test('วันก่อนหน้าคือเลยกำหนด', () {
      expect(bucketOf(taskDue(DateTime(2026, 3, 9)), now: now), DeadlineBucket.overdue);
    });
  });

  group('งานทั้งวันและเวลาที่ใช้เตือน', () {
    test('ไม่ระบุเวลา → เตือน 09:00 ของวันนั้น', () {
      final Task task = Task(title: 'ส่งงาน', due: DateTime(2026, 5, 1));
      expect(task.isAllDay, isTrue);
      expect(task.effectiveDue, DateTime(2026, 5, 1, 9));
    });

    test('ระบุเวลา → ใช้เวลานั้นตรง ๆ', () {
      final Task task = Task(
        title: 'ประชุม',
        due: DateTime(2026, 5, 1, 14, 30),
        hasTime: true,
      );
      expect(task.isAllDay, isFalse);
      expect(task.effectiveDue, DateTime(2026, 5, 1, 14, 30));
    });
  });

  group('กิจวัตร', () {
    final Routine routine = Routine(
      title: 'เรียนเลข',
      days: <int>[1, 3, 5],
      startMinutes: 9 * 60,
      endMinutes: 10 * 60 + 30,
    );

    test('เกิดขึ้นเฉพาะวันที่เลือก', () {
      expect(routine.occursOn(DateTime(2026, 3, 9)), isTrue); // จันทร์
      expect(routine.occursOn(DateTime(2026, 3, 10)), isFalse); // อังคาร
    });

    test('ช่วงวันที่จำกัดการเกิดขึ้น', () {
      final Routine limited = Routine(
        title: 'คอร์สสั้น',
        days: <int>[1],
        startDate: DateTime(2026, 3, 16),
      );
      expect(limited.occursOn(DateTime(2026, 3, 9)), isFalse);
      expect(limited.occursOn(DateTime(2026, 3, 16)), isTrue);
    });

    test('คำนวณเวลาเริ่ม-จบของวันได้', () {
      expect(routine.startOn(DateTime(2026, 3, 9)), DateTime(2026, 3, 9, 9));
      expect(routine.endOn(DateTime(2026, 3, 9)), DateTime(2026, 3, 9, 10, 30));
    });
  });

  group('Export / Import', () {
    test('อ่านไฟล์สำรองที่ถูกต้องได้ครบ', () {
      final String json = jsonEncode(<String, Object?>{
        'format': BackupService.magic,
        'version': BackupService.formatVersion,
        'projects': <Object?>[Project(id: 1, name: 'เรียน').toMap()],
        'tasks': <Object?>[Task(id: 1, projectId: 1, title: 'อ่านหนังสือ').toMap()],
        'reminders': <Object?>[
          Reminder(
            id: 1,
            ownerType: ReminderOwner.task,
            ownerId: 1,
            offsetMinutes: 60,
          ).toMap(),
        ],
        'routines': <Object?>[
          Routine(id: 1, title: 'ยิม', days: <int>[2, 4]).toMap(),
        ],
        'ideas': <Object?>[Idea(id: 1, content: 'ทำแอป').toMap()],
      });

      final BackupPayload payload = BackupService.parse(json);
      expect(payload.projects.single.name, 'เรียน');
      expect(payload.tasks.single.title, 'อ่านหนังสือ');
      expect(payload.reminders.single.offsetMinutes, 60);
      expect(payload.routines.single.days, <int>[2, 4]);
      expect(payload.ideas.single.content, 'ทำแอป');
    });

    test('ปฏิเสธไฟล์ที่ไม่ใช่ของแอป', () {
      expect(
        () => BackupService.parse('{"format":"other"}'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('รูปแบบวันเวลา', () {
    test('แปลงเป็น พ.ศ. ได้', () {
      Fmt.buddhistYear = true;
      expect(Fmt.displayYear(2026), 2569);
      Fmt.buddhistYear = false;
      expect(Fmt.displayYear(2026), 2026);
      Fmt.buddhistYear = true;
    });

    test('สัปดาห์เริ่มวันจันทร์', () {
      expect(startOfWeek(DateTime(2026, 3, 12)), DateTime(2026, 3, 9));
    });

    test('บวกเดือนแล้ววันไม่ล้น', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('ข้อความบอกเวลาที่เหลือ', () {
      expect(
        Fmt.relative(DateTime(2026, 3, 11), hasTime: false, now: DateTime(2026, 3, 10)),
        'พรุ่งนี้',
      );
    });
  });
}

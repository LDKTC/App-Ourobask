import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ourobask/data/backup.dart';
import 'package:ourobask/data/models.dart';
import 'package:ourobask/state/app_state.dart';
import 'package:ourobask/utils/formatters.dart';

void main() {
  group('เควสเก็บเงิน (quest)', () {
    test('งานทั่วไปยังคงเป็น normal โดยปริยาย', () {
      final Task task = Task(title: 'งาน');
      expect(task.kind, TaskKind.normal);
      expect(task.isQuest, isFalse);
      expect(task.toMap()['kind'], 'normal');
    });

    test('บันทึกและอ่านค่าเป้าหมายของเควสได้ครบ', () {
      final Task task = Task(
        title: 'เก็บเงินซื้อคอม',
        kind: TaskKind.quest,
        targetAmount: 25000,
      );
      final Task copy = Task.fromMap(task.toMap());
      expect(copy.isQuest, isTrue);
      expect(copy.targetAmount, 25000);
      expect(copy.goalAmount, 25000);
    });

    test('แถวเก่าที่ยังไม่มีคอลัมน์ kind อ่านเป็นงานทั่วไป', () {
      final Task task = Task.fromMap(<String, Object?>{
        'id': 1,
        'title': 'งานเก่า',
        'color': 0xFF6750A4,
        'created_at': 0,
        'updated_at': 0,
      });
      expect(task.kind, TaskKind.normal);
      expect(task.targetAmount, isNull);
      expect(task.goalAmount, 0);
    });

    test('รายการหยอดเงินเก็บค่าได้ครบ', () {
      final QuestEntry entry = QuestEntry(
        taskId: 3,
        amount: 1500.5,
        note: 'เงินเดือน',
        routineId: 9,
      );
      final QuestEntry copy = QuestEntry.fromMap(entry.toMap());
      expect(copy.taskId, 3);
      expect(copy.amount, 1500.5);
      expect(copy.note, 'เงินเดือน');
      expect(copy.routineId, 9);
    });

    test('ยอดรวมของกลุ่มคิดเป็นสัดส่วนได้', () {
      const MoneySummary summary = MoneySummary(
        saved: 2500,
        target: 10000,
        questCount: 2,
        reachedCount: 0,
      );
      expect(summary.progress, 0.25);
      expect(summary.remaining, 7500);
      expect(summary.isEmpty, isFalse);
    });

    test('เก็บเกินเป้าไม่ทำให้แถบความคืบหน้าเกิน 100%', () {
      const MoneySummary summary = MoneySummary(
        saved: 12000,
        target: 10000,
        questCount: 1,
        reachedCount: 1,
      );
      expect(summary.progress, 1.0);
      expect(summary.remaining, 0);
    });

    test('ยังไม่ตั้งเป้า = ความคืบหน้า 0', () {
      const MoneySummary summary = MoneySummary(saved: 500, questCount: 1);
      expect(summary.progress, 0);
    });
  });

  group('กิจวัตรแบบรายเดือน', () {
    Routine monthly(List<int> days) =>
        Routine(title: 'เก็บเงิน', repeat: RoutineRepeat.monthly, monthDays: days);

    test('เกิดขึ้นเฉพาะวันที่ของเดือนที่เลือก', () {
      final Routine routine = monthly(<int>[1, 25]);
      expect(routine.occursOn(DateTime(2026, 3, 1)), isTrue);
      expect(routine.occursOn(DateTime(2026, 3, 25)), isTrue);
      expect(routine.occursOn(DateTime(2026, 3, 24)), isFalse);
      expect(routine.occursOn(DateTime(2026, 4, 25)), isTrue);
    });

    test('วันที่ 31 ในเดือนที่สั้นกว่าเลื่อนมาเป็นวันสุดท้าย', () {
      final Routine routine = monthly(<int>[31]);
      expect(routine.occursOn(DateTime(2026, 2, 28)), isTrue);
      expect(routine.occursOn(DateTime(2026, 2, 27)), isFalse);
      expect(routine.occursOn(DateTime(2026, 1, 31)), isTrue);
      expect(routine.occursOn(DateTime(2026, 4, 30)), isTrue);
    });

    test('ปีอธิกสุรทินเลื่อนไปวันที่ 29 กุมภาพันธ์', () {
      final Routine routine = monthly(<int>[30]);
      expect(routine.occursOn(DateTime(2028, 2, 29)), isTrue);
      expect(routine.occursOn(DateTime(2028, 2, 28)), isFalse);
    });

    test('ช่วงวันที่เริ่ม-สิ้นสุดยังใช้ได้กับรายเดือน', () {
      final Routine routine = monthly(<int>[10])
        ..startDate = DateTime(2026, 3, 1)
        ..endDate = DateTime(2026, 5, 31);
      expect(routine.occursOn(DateTime(2026, 2, 10)), isFalse);
      expect(routine.occursOn(DateTime(2026, 4, 10)), isTrue);
      expect(routine.occursOn(DateTime(2026, 6, 10)), isFalse);
    });

    test('ปิดกิจวัตรแล้วไม่เกิดขึ้น', () {
      final Routine routine = monthly(<int>[10])..active = false;
      expect(routine.occursOn(DateTime(2026, 4, 10)), isFalse);
    });

    test('กิจวัตรรายสัปดาห์ยังทำงานเหมือนเดิม', () {
      final Routine routine = Routine(title: 'เรียน', days: <int>[1, 3]);
      expect(routine.isMonthly, isFalse);
      expect(routine.occursOn(DateTime(2026, 3, 9)), isTrue); // จันทร์
      expect(routine.occursOn(DateTime(2026, 3, 10)), isFalse);
    });

    test('บันทึกและอ่านค่าแผนเก็บเงินได้ครบ', () {
      final Routine routine = Routine(
        title: 'เก็บเงินค่าเทอม',
        repeat: RoutineRepeat.monthly,
        monthDays: <int>[5, 20],
        questTaskId: 7,
        questAmount: 1000,
      );
      final Routine copy = Routine.fromMap(routine.toMap());
      expect(copy.isMonthly, isTrue);
      expect(copy.monthDays, <int>[5, 20]);
      expect(copy.questTaskId, 7);
      expect(copy.questAmount, 1000);
      expect(copy.isQuestPlan, isTrue);
    });

    test('กิจวัตรเก่าที่ไม่มีคอลัมน์ใหม่ยังเป็นรายสัปดาห์', () {
      final Routine routine = Routine.fromMap(<String, Object?>{
        'id': 1,
        'title': 'เก่า',
        'days': '1,2',
        'color': 0xFF2A9D8F,
        'active': 1,
        'created_at': 0,
      });
      expect(routine.repeat, RoutineRepeat.weekly);
      expect(routine.monthDays, isEmpty);
      expect(routine.isQuestPlan, isFalse);
    });

    test('clampMonthDay จำกัดค่าให้อยู่ในเดือนจริง', () {
      expect(clampMonthDay(31, 2026, 2), 28);
      expect(clampMonthDay(31, 2028, 2), 29);
      expect(clampMonthDay(15, 2026, 2), 15);
      expect(clampMonthDay(0, 2026, 2), 1);
    });
  });

  group('รูปแบบจำนวนเงิน', () {
    test('ใส่ตัวคั่นหลักพันและตัดทศนิยมที่ลงตัว', () {
      expect(Fmt.money(1250), '฿1,250');
      expect(Fmt.money(0), '฿0');
      expect(Fmt.money(1234567), '฿1,234,567');
    });

    test('เก็บทศนิยมไว้เมื่อมีเศษสตางค์', () {
      expect(Fmt.money(1250.5), '฿1,250.50');
      expect(Fmt.money(0.75), '฿0.75');
    });

    test('จำนวนติดลบแสดงเครื่องหมายลบ', () {
      expect(Fmt.money(-500), '-฿500');
    });

    test('ปิดสัญลักษณ์สกุลเงินได้', () {
      expect(Fmt.money(2000, symbol: false), '2,000');
    });

    test('ป้ายวันที่ของเดือน', () {
      expect(Fmt.monthDaysLabel(<int>[]), 'ยังไม่เลือกวันที่');
      expect(Fmt.monthDaysLabel(<int>[25, 1]), 'ทุกวันที่ 1, 25');
      expect(Fmt.monthDaysLabel(<int>[1, 2, 3, 4, 5, 6, 7]), 'เดือนละ 7 ครั้ง');
    });

    test('ขนาดไฟล์อ่านง่าย', () {
      expect(Fmt.fileSize(0), '-');
      expect(Fmt.fileSize(512), '512 B');
      expect(Fmt.fileSize(2048), '2.0 KB');
      expect(Fmt.fileSize(25 * 1024 * 1024), '25.0 MB');
    });
  });

  group('Export / Import ของเควส', () {
    test('ไฟล์สำรองพารายการหยอดเงินไปด้วย', () {
      final String content = jsonEncode(<String, Object?>{
        'format': 'ourobask-backup',
        'version': 2,
        'tasks': <Map<String, Object?>>[
          Task(
            id: 1,
            title: 'เก็บเงินเที่ยว',
            kind: TaskKind.quest,
            targetAmount: 9000,
          ).toMap(),
        ],
        'quest_entries': <Map<String, Object?>>[
          QuestEntry(id: 1, taskId: 1, amount: 3000).toMap(),
        ],
      });
      final BackupPayload payload = BackupService.parse(content);
      expect(payload.tasks.single.isQuest, isTrue);
      expect(payload.tasks.single.targetAmount, 9000);
      expect(payload.questEntries.single.amount, 3000);
      expect(payload.counts.questEntries, 1);
    });

    test('ไฟล์สำรองเวอร์ชันเก่ายังอ่านได้ (ไม่มี quest_entries)', () {
      final String content = jsonEncode(<String, Object?>{
        'format': 'ourobask-backup',
        'version': 1,
        'tasks': <Map<String, Object?>>[Task(id: 1, title: 'งานเก่า').toMap()],
      });
      final BackupPayload payload = BackupService.parse(content);
      expect(payload.tasks.single.kind, TaskKind.normal);
      expect(payload.questEntries, isEmpty);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ourobask/data/backup.dart';
import 'package:ourobask/data/models.dart';

void main() {
  group('โน้ตของโฟลเดอร์งาน', () {
    test('หัวข้อว่างจะยืมบรรทัดแรกของเนื้อหามาใช้', () {
      final Note note = Note(
        projectId: 1,
        content: 'สรุปประชุม\nนัดลูกค้าอีกทีวันศุกร์\nส่งใบเสนอราคา',
      );
      expect(note.displayTitle, 'สรุปประชุม');
      expect(note.preview, 'นัดลูกค้าอีกทีวันศุกร์ ส่งใบเสนอราคา');
    });

    test('มีหัวข้อแล้วเนื้อหาย่อจะไม่ตัดบรรทัดแรกทิ้ง', () {
      final Note note = Note(
        projectId: 1,
        title: 'ลิงก์ที่ต้องใช้',
        content: 'ดีไซน์\nสเปก',
      );
      expect(note.displayTitle, 'ลิงก์ที่ต้องใช้');
      expect(note.preview, 'ดีไซน์ สเปก');
    });

    test('โน้ตที่ไม่มีทั้งหัวข้อและเนื้อหานับว่าว่าง', () {
      expect(Note(projectId: 1, title: '  ', content: '\n').isEmpty, isTrue);
      expect(Note(projectId: 1, content: 'จดไว้').isEmpty, isFalse);
      expect(Note(projectId: 1).displayTitle, 'โน้ตไม่มีชื่อ');
    });

    test('ค้นหาได้ทั้งจากหัวข้อและเนื้อหา แบบไม่สนตัวพิมพ์', () {
      final Note note = Note(
        projectId: 1,
        title: 'Sprint 3',
        content: 'ตามงาน API ให้เสร็จ',
      );
      expect(note.matches('sprint'), isTrue);
      expect(note.matches('api'), isTrue);
      expect(note.matches('   '), isTrue);
      expect(note.matches('ยิม'), isFalse);
    });

    test('แปลงเป็นแถวฐานข้อมูลแล้วอ่านกลับได้ครบ', () {
      final Note note = Note(
        id: 7,
        projectId: 3,
        title: 'ของที่ต้องซื้อ',
        content: 'สายชาร์จ\nกระดาษ',
        color: kPalette[4],
        pinned: true,
        sortOrder: 2,
        createdAt: DateTime(2026, 3, 10, 8),
        updatedAt: DateTime(2026, 3, 11, 20, 15),
      );
      final Note copy = Note.fromMap(note.toMap());
      expect(copy.id, 7);
      expect(copy.projectId, 3);
      expect(copy.title, 'ของที่ต้องซื้อ');
      expect(copy.content, 'สายชาร์จ\nกระดาษ');
      expect(copy.color, kPalette[4]);
      expect(copy.pinned, isTrue);
      expect(copy.sortOrder, 2);
      expect(copy.createdAt, DateTime(2026, 3, 10, 8));
      expect(copy.updatedAt, DateTime(2026, 3, 11, 20, 15));
    });
  });

  group('โน้ตในไฟล์สำรองข้อมูล', () {
    test('อ่านโน้ตจากไฟล์สำรองได้', () {
      final String json = jsonEncode(<String, Object?>{
        'format': BackupService.magic,
        'version': BackupService.formatVersion,
        'projects': <Object?>[Project(id: 1, name: 'งานบริษัท').toMap()],
        'notes': <Object?>[
          Note(id: 1, projectId: 1, title: 'สรุปประชุม', pinned: true).toMap(),
        ],
      });

      final BackupPayload payload = BackupService.parse(json);
      expect(payload.notes.single.title, 'สรุปประชุม');
      expect(payload.notes.single.projectId, 1);
      expect(payload.notes.single.pinned, isTrue);
      expect(payload.counts.notes, 1);
    });

    test('ไฟล์สำรองรุ่นเก่าที่ยังไม่มีโน้ตอ่านได้ตามปกติ', () {
      final String json = jsonEncode(<String, Object?>{
        'format': BackupService.magic,
        'version': 2,
        'tasks': <Object?>[Task(id: 1, title: 'อ่านหนังสือ').toMap()],
      });

      final BackupPayload payload = BackupService.parse(json);
      expect(payload.notes, isEmpty);
      expect(payload.counts.notes, 0);
      expect(payload.tasks.single.title, 'อ่านหนังสือ');
    });
  });
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ourobask/data/models.dart';

void main() {
  group('สุ่มไอเดียจากกอง', () {
    Idea idea(int id) => Idea(id: id, content: 'ไอเดีย $id');

    test('กล่องว่างไม่มีอะไรให้สุ่ม', () {
      expect(randomIdeaFrom(<Idea>[]), isNull);
    });

    test('มีใบเดียวก็ได้ใบนั้น', () {
      expect(randomIdeaFrom(<Idea>[idea(1)])?.id, 1);
    });

    test('ไม่สุ่มได้ใบเดิมซ้ำติดกัน', () {
      final List<Idea> pile = <Idea>[idea(1), idea(2), idea(3)];
      for (int seed = 0; seed < 20; seed++) {
        final Idea? picked = randomIdeaFrom(pile, excludeId: 2, random: Random(seed));
        expect(picked?.id, isNot(2));
      }
    });

    test('เหลือใบเดียวและเป็นใบเดิม ก็ยอมให้ซ้ำได้', () {
      expect(randomIdeaFrom(<Idea>[idea(7)], excludeId: 7)?.id, 7);
    });

    test('สุ่มได้ทุกใบในกอง ไม่ติดอยู่ใบเดียว', () {
      final List<Idea> pile = <Idea>[idea(1), idea(2), idea(3)];
      final Set<int?> seen = <int?>{};
      for (int seed = 0; seed < 30; seed++) {
        seen.add(randomIdeaFrom(pile, random: Random(seed))?.id);
      }
      expect(seen, <int>{1, 2, 3});
    });
  });

  group('สร้างโน้ตจากไอเดีย', () {
    test('บรรทัดแรกเป็นหัวข้อ ที่เหลือเป็นเนื้อหา', () {
      final Idea idea = Idea(
        id: 1,
        content: 'ทำแอปจดสูตรอาหาร\nเริ่มจากหน้าค้นหา\nแล้วค่อยทำหน้าบันทึก',
        color: kPalette[5],
      );
      final Note note = Note.fromIdea(idea, projectId: 4);
      expect(note.projectId, 4);
      expect(note.title, 'ทำแอปจดสูตรอาหาร');
      expect(note.content, 'เริ่มจากหน้าค้นหา\nแล้วค่อยทำหน้าบันทึก');
      expect(note.color, kPalette[5]);
      expect(note.isEmpty, isFalse);
    });

    test('ไอเดียบรรทัดเดียวได้โน้ตที่มีแต่หัวข้อ', () {
      final Note note = Note.fromIdea(Idea(content: '  ซื้อของขวัญ  '), projectId: 2);
      expect(note.title, 'ซื้อของขวัญ');
      expect(note.content, isEmpty);
      expect(note.displayTitle, 'ซื้อของขวัญ');
    });
  });
}

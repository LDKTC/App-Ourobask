import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourobask/data/models.dart';
import 'package:ourobask/state/app_state.dart';
import 'package:ourobask/ui/calendar/calendar_page.dart';
import 'package:ourobask/ui/idea_box_page.dart';
import 'package:ourobask/ui/idea_random_sheet.dart';
import 'package:ourobask/ui/note_editor_page.dart';
import 'package:ourobask/ui/project_notes_page.dart';
import 'package:ourobask/ui/task_history_page.dart';
import 'package:ourobask/ui/widgets/note_tile.dart';
import 'package:provider/provider.dart';

/// หน้าเหล่านี้อ่านข้อมูลจาก [AppState] ที่ยังว่าง (ยังไม่เรียก load) จึงไม่แตะฐานข้อมูล
Widget wrap(Widget child) => ChangeNotifierProvider<AppState>(
  create: (_) => AppState(),
  child: MaterialApp(home: child),
);

void main() {
  testWidgets('กล่องไอเดียปิดอยู่ไม่ล้นจอ', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const IdeaBoxPage()));
    await tester.pumpAndSettle();
    expect(find.text('หย่อนไอเดีย'), findsOneWidget);
    expect(find.text('เปิดกล่อง'), findsOneWidget);
    expect(find.text('สุ่มไอเดีย'), findsOneWidget);
    final Rect drop = tester.getRect(find.text('หย่อนไอเดีย'));
    final Rect open = tester.getRect(find.text('เปิดกล่อง'));
    expect(open.top, greaterThan(drop.bottom));
    expect(open.width, lessThan(drop.width));

    // ปุ่มสุ่มไอเดียอยู่ใต้ปุ่มเปิดกล่องและขนาดเท่ากัน
    final Rect openButton = tester.getRect(
      find.widgetWithText(FilledButton, 'เปิดกล่อง'),
    );
    final Rect randomButton = tester.getRect(
      find.widgetWithText(FilledButton, 'สุ่มไอเดีย'),
    );
    expect(randomButton.top, greaterThan(openButton.bottom));
    expect(randomButton.size, openButton.size);
  });

  testWidgets('ประวัติงานว่างเปล่าแสดงข้อความ', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const TaskHistoryPage()));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีงานที่ทำเสร็จ'), findsOneWidget);
  });

  testWidgets('หน้าเขียนโน้ตใหม่ต้องมีหัวข้อหรือเนื้อหาก่อนบันทึก', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const NoteEditorPage(projectId: 1)));
    await tester.pumpAndSettle();
    expect(find.text('โน้ตใหม่'), findsOneWidget);
    await tester.tap(find.text('บันทึก'));
    await tester.pump();
    expect(find.text('เขียนหัวข้อหรือเนื้อหาก่อนบันทึก'), findsOneWidget);
  });

  testWidgets('แผ่นสุ่มไอเดียอ่านอย่างเดียว และปุ่มสองปุ่มกว้างเท่ากัน', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    int kept = 0;
    int created = 0;
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: RandomIdeaSheet(
            idea: Idea(id: 1, content: 'ทำแอปจดสูตรอาหาร'),
            onKeep: () => kept++,
            onCreate: () => created++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // อ่านอย่างเดียว — ไม่มีช่องให้พิมพ์แก้ไอเดียในแผ่นนี้
    expect(find.text('ทำแอปจดสูตรอาหาร'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    final Rect keep = tester.getRect(find.text('เก็บกลับเข้ากล่อง'));
    final Rect create = tester.getRect(find.text('สร้างงาน / โน้ต'));
    final Rect keepButton = tester.getRect(find.byType(OutlinedButton));
    final Rect createButton = tester.getRect(find.byType(FilledButton));
    // ปุ่มอยู่แถวเดียวกันและแบ่งความกว้างเท่ากันพอดี (1:1)
    expect(keep.center.dy, closeTo(create.center.dy, 1));
    expect(keepButton.width, closeTo(createButton.width, 0.5));
    expect(keepButton.right, lessThanOrEqualTo(createButton.left));

    await tester.tap(find.byType(OutlinedButton));
    await tester.tap(find.byType(FilledButton));
    expect(kept, 1);
    expect(created, 1);
  });

  testWidgets('การ์ดโน้ตแสดงหัวข้อ เนื้อหาย่อ และปุ่มปักหมุด', (
    WidgetTester tester,
  ) async {
    bool pinned = false;
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: NoteCard(
            note: Note(
              projectId: 1,
              content: 'สรุปประชุม\nนัดลูกค้าวันศุกร์',
              updatedAt: DateTime(2026, 3, 10, 9, 30),
            ),
            onTogglePin: () => pinned = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('สรุปประชุม'), findsOneWidget);
    expect(find.text('นัดลูกค้าวันศุกร์'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    expect(pinned, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('หน้ารวมโน้ตต้องอยู่ใต้โฟลเดอร์งานที่มีอยู่จริง', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const ProjectNotesPage(projectId: 99)));
    await tester.pumpAndSettle();
    expect(find.text('ไม่พบโฟลเดอร์นี้'), findsOneWidget);
  });

  testWidgets('แตะหัวปฏิทินแล้วเปิดรายการช่วงเวลา', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const CalendarPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
    await tester.pumpAndSettle();
    expect(find.text('ไปยังเดือน'), findsOneWidget);
    expect(find.text('วันนี้'), findsWidgets);
  });
}

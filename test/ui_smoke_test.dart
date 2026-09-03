import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ourobask/state/app_state.dart';
import 'package:ourobask/ui/calendar/calendar_page.dart';
import 'package:ourobask/ui/idea_box_page.dart';
import 'package:ourobask/ui/task_history_page.dart';
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
    final Rect drop = tester.getRect(find.text('หย่อนไอเดีย'));
    final Rect open = tester.getRect(find.text('เปิดกล่อง'));
    expect(open.top, greaterThan(drop.bottom));
    expect(open.width, lessThan(drop.width));
  });

  testWidgets('ประวัติงานว่างเปล่าแสดงข้อความ', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const TaskHistoryPage()));
    await tester.pumpAndSettle();
    expect(find.text('ยังไม่มีงานที่ทำเสร็จ'), findsOneWidget);
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

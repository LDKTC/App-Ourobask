import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'calendar/calendar_page.dart';
import 'home_page.dart';
import 'idea_box_page.dart';
import 'routines_page.dart';
import 'update_page.dart';
import 'work_page.dart';

/// โครงหลักของแอป — สลับหน้าแบบเก็บสถานะไว้ทั้ง 5 หน้า
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  bool _updateChecked = false;

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    CalendarPage(),
    WorkPage(),
    IdeaBoxPage(),
    RoutinesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // ตรวจหาเวอร์ชันใหม่ครั้งเดียวหลังข้อมูล (รวมถึงค่าตั้งค่า) โหลดเสร็จ
    if (!_updateChecked) {
      _updateChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybeAutoCheckForUpdate(context);
      });
    }
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'หน้าแรก',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'ปฏิทิน',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_copy_outlined),
            selectedIcon: Icon(Icons.folder_copy_rounded),
            label: 'งาน',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline_rounded),
            selectedIcon: Icon(Icons.lightbulb_rounded),
            label: 'กล่องไอเดีย',
          ),
          NavigationDestination(
            icon: Icon(Icons.repeat_outlined),
            selectedIcon: Icon(Icons.repeat_rounded),
            label: 'กิจวัตร',
          ),
        ],
      ),
    );
  }
}

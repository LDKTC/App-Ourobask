import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../utils/formatters.dart';
import 'routine_editor_page.dart';
import 'widgets/common.dart';
import 'widgets/task_tile.dart';

/// หน้ากิจวัตร — ตารางที่ทำซ้ำทุกสัปดาห์ แยกตามวัน
class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<Routine> routines = state.routines;
    final List<Routine> weekly = routines.where((Routine r) => !r.isMonthly).toList();
    final List<Routine> monthly = routines.where((Routine r) => r.isMonthly).toList()
      ..sort((Routine a, Routine b) => _firstDay(a).compareTo(_firstDay(b)));
    final DateTime today = DateTime.now();
    final List<Routine> todays = state.routinesOn(today);

    return Scaffold(
      appBar: AppBar(
        title: const Text('กิจวัตร'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'สิ่งที่ทำซ้ำ ๆ เช่น ตารางเรียน — แสดงในหน้าแรกและหน้าปฏิทิน',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const RoutineEditorPage()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('เพิ่มกิจวัตร'),
      ),
      body: routines.isEmpty
          ? EmptyState(
              icon: Icons.repeat_rounded,
              title: 'ยังไม่มีกิจวัตร',
              message:
                  'เพิ่มตารางที่ทำซ้ำ เช่น ตารางเรียน ตารางออกกำลังกาย'
                  ' หรือแผนเก็บเงินรายเดือนของเควส',
              action: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const RoutineEditorPage()),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('เพิ่มกิจวัตร'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: <Widget>[
                if (todays.isNotEmpty) ...<Widget>[
                  SectionHeader(
                    title: 'วันนี้ (${Fmt.weekdayFull(today.weekday)})',
                    subtitle: 'กิจวัตรที่ต้องทำวันนี้',
                    icon: Icons.today_rounded,
                    count: todays.length,
                  ),
                  ...todays.map(
                    (Routine routine) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RoutineTile(
                        routine: routine,
                        onTap: () => _open(context, routine),
                      ),
                    ),
                  ),
                ],
                // กิจวัตรรายเดือน เช่น แผนเก็บเงินของเควส
                if (monthly.isNotEmpty) ...<Widget>[
                  SectionHeader(
                    title: 'ทำซ้ำรายเดือน',
                    subtitle: 'ตามวันที่ของเดือน เช่น แผนเก็บเงินของเควส',
                    icon: Icons.event_repeat_rounded,
                    count: monthly.length,
                  ),
                  ...monthly.map(
                    (Routine routine) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RoutineTile(
                        routine: routine,
                        onTap: () => _open(context, routine),
                      ),
                    ),
                  ),
                ],
                for (int weekday = 1; weekday <= 7; weekday++) ...<Widget>[
                  if (weekly
                      .where((Routine r) => r.days.contains(weekday))
                      .isNotEmpty) ...<Widget>[
                    SectionHeader(
                      title: 'วัน${Fmt.weekdayFull(weekday)}',
                      icon: Icons.calendar_view_day_rounded,
                      count: weekly.where((Routine r) => r.days.contains(weekday)).length,
                    ),
                    ...(weekly.where((Routine r) => r.days.contains(weekday)).toList()
                          ..sort(
                            (Routine a, Routine b) =>
                                a.startMinutes.compareTo(b.startMinutes),
                          ))
                        .map(
                          (Routine routine) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: RoutineTile(
                              routine: routine,
                              onTap: () => _open(context, routine),
                            ),
                          ),
                        ),
                  ],
                ],
              ],
            ),
    );
  }

  /// วันที่แรกของเดือนที่กิจวัตรรายเดือนทำงาน (ใช้เรียงลำดับ)
  static int _firstDay(Routine routine) {
    if (routine.monthDays.isEmpty) return 99;
    return routine.monthDays.reduce((int a, int b) => a < b ? a : b);
  }

  void _open(BuildContext context, Routine routine) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => RoutineEditorPage(routine: routine)),
    );
  }
}

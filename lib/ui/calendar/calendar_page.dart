import 'package:flutter/material.dart';

import '../../utils/date_time_utils.dart';
import '../../utils/formatters.dart';
import '../task_editor_page.dart';
import 'month_view.dart';
import 'period_picker.dart';
import 'week_view.dart';
import 'year_view.dart';

/// หน้าปฏิทิน — เลือกดูเป็นสัปดาห์ / เดือน / ปี
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarMode _mode = CalendarMode.month;
  DateTime _anchor = DateTime.now();

  void _shift(int direction) {
    setState(() {
      switch (_mode) {
        case CalendarMode.week:
          _anchor = _anchor.add(Duration(days: 7 * direction));
        case CalendarMode.month:
          _anchor = addMonths(_anchor, direction);
        case CalendarMode.year:
          _anchor = DateTime(_anchor.year + direction, _anchor.month, 1);
      }
    });
  }

  /// เปิดรายการช่วงเวลาเพื่อกระโดดข้ามไปยังสัปดาห์/เดือน/ปีที่ต้องการ
  Future<void> _openPeriodJump() async {
    final DateTime? picked = await showPeriodJumpSheet(
      context,
      mode: _mode,
      anchor: _anchor,
    );
    if (picked == null || !mounted) return;
    setState(() => _anchor = picked);
  }

  String get _titleText {
    switch (_mode) {
      case CalendarMode.week:
        return Fmt.weekRange(startOfWeek(_anchor));
      case CalendarMode.month:
        return Fmt.monthYear(_anchor);
      case CalendarMode.year:
        return 'ปี ${Fmt.displayYear(_anchor.year)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ปฏิทิน'),
        actions: <Widget>[
          IconButton(
            tooltip: 'กลับมาวันนี้',
            icon: const Icon(Icons.today_rounded),
            onPressed: () => setState(() => _anchor = DateTime.now()),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SegmentedButton<CalendarMode>(
                  segments: const <ButtonSegment<CalendarMode>>[
                    ButtonSegment<CalendarMode>(
                      value: CalendarMode.week,
                      label: Text('สัปดาห์'),
                      icon: Icon(Icons.view_week_rounded, size: 18),
                    ),
                    ButtonSegment<CalendarMode>(
                      value: CalendarMode.month,
                      label: Text('เดือน'),
                      icon: Icon(Icons.calendar_view_month_rounded, size: 18),
                    ),
                    ButtonSegment<CalendarMode>(
                      value: CalendarMode.year,
                      label: Text('ปี'),
                      icon: Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                  ],
                  selected: <CalendarMode>{_mode},
                  onSelectionChanged: (Set<CalendarMode> value) =>
                      setState(() => _mode = value.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _shift(-1),
                    ),
                    // แตะที่ช่วงเวลาเพื่อเปิดรายการสำหรับกระโดดข้ามช่วง
                    Expanded(
                      child: Center(
                        child: Tooltip(
                          message: 'เลือกช่วงเวลา',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _openPeriodJump,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      _titleText,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 22),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _shift(1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TaskEditorPage(
              initialDue: isSameDay(_anchor, DateTime.now()) ? null : _anchor,
            ),
          ),
        ),
        child: const Icon(Icons.add_rounded),
      ),
      body: switch (_mode) {
        CalendarMode.week => WeekTimetableView(
          key: ValueKey<String>('week-${startOfWeek(_anchor)}'),
          anchor: _anchor,
        ),
        CalendarMode.month => MonthCalendarView(anchor: _anchor),
        CalendarMode.year => YearCalendarView(
          anchor: _anchor,
          onOpenMonth: (DateTime month) => setState(() {
            _anchor = month;
            _mode = CalendarMode.month;
          }),
        ),
      },
    );
  }
}

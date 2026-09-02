import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../utils/date_time_utils.dart';
import '../../utils/formatters.dart';
import '../project_detail_page.dart';

/// มุมมองเดือน — ปฏิทินที่งานในวันเดียวกันจะถูกซ้อนกันพร้อมเลขจำนวน
class MonthCalendarView extends StatelessWidget {
  const MonthCalendarView({super.key, required this.anchor});

  final DateTime anchor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final DateTime first = startOfMonth(anchor);
    final DateTime gridStart = startOfWeek(first);
    final int totalCells =
        ((daysInMonth(anchor.year, anchor.month) + first.weekday - 1) / 7).ceil() * 7;
    final int rows = totalCells ~/ 7;
    final DateTime today = DateTime.now();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: List<Widget>.generate(
              7,
              (int index) => Expanded(
                child: Center(
                  child: Text(
                    Fmt.weekdaysShort[index],
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: index >= 5
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Column(
            children: List<Widget>.generate(rows, (int row) {
              return Expanded(
                child: Row(
                  children: List<Widget>.generate(7, (int col) {
                    final DateTime day = gridStart.add(Duration(days: row * 7 + col));
                    return Expanded(
                      child: _DayCell(
                        day: day,
                        inMonth: day.month == anchor.month,
                        isToday: isSameDay(day, today),
                        tasks: state.tasksOn(day),
                        routines: state.routinesOn(day),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.tasks,
    required this.routines,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final List<Task> tasks;
  final List<Routine> routines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int total = tasks.length + routines.length;
    final List<_Chip> chips = <_Chip>[
      ...tasks.map((Task t) => _Chip(t.title, Color(t.color), false)),
      ...routines.map((Routine r) => _Chip(r.title, Color(r.color), true)),
    ];

    return InkWell(
      onTap: () => showDaySheet(context, day),
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: isToday
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : inMonth
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isToday
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${day.day}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: !inMonth
                        ? theme.colorScheme.outline
                        : isToday
                        ? theme.colorScheme.primary
                        : null,
                  ),
                ),
                const Spacer(),
                // เลขจำนวนงานที่ซ้อนกันในวันนี้
                if (total > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 1),
            Expanded(child: _StackedChips(chips: chips)),
          ],
        ),
      ),
    );
  }
}

class _Chip {
  const _Chip(this.title, this.color, this.isRoutine);

  final String title;
  final Color color;
  final bool isRoutine;
}

/// รายการงานในหนึ่งวัน — ถ้ามีหลายรายการจะซ้อนกันและบอกจำนวนที่เหลือ
class _StackedChips extends StatelessWidget {
  const _StackedChips({required this.chips});

  final List<_Chip> chips;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double chipHeight = 13;
        final int fit = (constraints.maxHeight / (chipHeight + 1)).floor().clamp(1, 4);
        final bool overflowing = chips.length > fit;
        final int shown = overflowing ? fit - 1 : chips.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < shown; i++)
              Container(
                height: chipHeight,
                margin: const EdgeInsets.only(bottom: 1),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: chips[i].color.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(3),
                  border: Border(left: BorderSide(color: chips[i].color, width: 2)),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  chips[i].isRoutine ? '⟳ ${chips[i].title}' : chips[i].title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: chips[i].color,
                  ),
                ),
              ),
            if (overflowing)
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  // ชั้นซ้อนด้านหลังเพื่อสื่อว่ามีงานทับกันอยู่
                  Positioned(
                    left: 3,
                    right: 3,
                    top: -2,
                    child: Container(
                      height: chipHeight,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Container(
                    height: chipHeight,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+${chips.length - shown}',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

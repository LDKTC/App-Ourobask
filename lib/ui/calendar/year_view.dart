import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../utils/date_time_utils.dart';
import '../../utils/formatters.dart';
import '../project_detail_page.dart';

/// มุมมองปี — ตาราง 12 เดือน ใช้ระบบซ้อนแบบเดียวกับมุมมองเดือน
class YearCalendarView extends StatelessWidget {
  const YearCalendarView({super.key, required this.anchor, required this.onOpenMonth});

  final DateTime anchor;
  final ValueChanged<DateTime> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: 12,
      itemBuilder: (BuildContext context, int index) =>
          _MiniMonth(month: DateTime(anchor.year, index + 1), onOpenMonth: onOpenMonth),
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({required this.month, required this.onOpenMonth});

  final DateTime month;
  final ValueChanged<DateTime> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final DateTime gridStart = startOfWeek(month);
    final int days = daysInMonth(month.year, month.month);
    final int rows = ((days + month.weekday - 1) / 7).ceil();
    final DateTime today = DateTime.now();
    final bool isCurrentMonth = today.year == month.year && today.month == month.month;

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => onOpenMonth(month),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                Fmt.monthsShort[month.month - 1],
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isCurrentMonth ? theme.colorScheme.primary : null,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: List<Widget>.generate(
                  7,
                  (int i) => Expanded(
                    child: Center(
                      child: Text(
                        Fmt.weekdaysShort[i].replaceAll('.', ''),
                        style: TextStyle(
                          fontSize: 7,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Expanded(
                child: Column(
                  children: List<Widget>.generate(rows, (int row) {
                    return Expanded(
                      child: Row(
                        children: List<Widget>.generate(7, (int col) {
                          final DateTime day = gridStart.add(
                            Duration(days: row * 7 + col),
                          );
                          final bool inMonth = day.month == month.month;
                          final int count = inMonth ? state.itemCountOn(day) : 0;
                          return Expanded(
                            child: GestureDetector(
                              onTap: inMonth ? () => showDaySheet(context, day) : null,
                              child: _MiniDay(
                                day: day,
                                inMonth: inMonth,
                                isToday: isSameDay(day, today),
                                count: count,
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDay extends StatelessWidget {
  const _MiniDay({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.count,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (!inMonth) return const SizedBox.shrink();

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        if (count > 0)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: (0.12 + count * 0.12).clamp(0.12, 0.55),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        if (isToday)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary, width: 1.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 8,
            height: 1,
            fontWeight: count > 0 ? FontWeight.w800 : FontWeight.w400,
            color: isToday ? theme.colorScheme.primary : null,
          ),
        ),
        // มีงานซ้อนกันหลายรายการ → แสดงจำนวนมุมขวาบน
        if (count > 1)
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 6,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

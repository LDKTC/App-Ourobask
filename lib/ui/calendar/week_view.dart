import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../utils/date_time_utils.dart';
import '../../utils/formatters.dart';
import '../project_detail_page.dart';
import '../routine_editor_page.dart';
import '../task_editor_page.dart';
import 'event_layout.dart';

/// มุมมองสัปดาห์ — ตารางเวลาแบบตารางเรียน มีหลักชั่วโมงกำกับ
class WeekTimetableView extends StatefulWidget {
  const WeekTimetableView({super.key, required this.anchor});

  final DateTime anchor;

  @override
  State<WeekTimetableView> createState() => _WeekTimetableViewState();
}

class _WeekTimetableViewState extends State<WeekTimetableView> {
  static const double hourHeight = 62;
  static const double hourColumnWidth = 46;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // เลื่อนไปที่ 7 โมงเช้าให้อัตโนมัติ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo((7 * hourHeight).clamp(0, _scroll.position.maxScrollExtent));
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<TimetableEvent> _eventsFor(BuildContext context, DateTime day) {
    final AppState state = context.read<AppState>();
    final List<TimetableEvent> events = <TimetableEvent>[];

    for (final Task task in state.tasksOn(day)) {
      if (!task.hasTime || task.due == null) continue;
      final DateTime start = task.due!;
      final DateTime end = task.endTime ?? start.add(const Duration(minutes: 45));
      events.add(
        TimetableEvent(
          start: start,
          end: end,
          title: task.title,
          subtitle: Fmt.time(start),
          color: Color(task.color),
          isRoutine: false,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => TaskEditorPage(task: task)),
          ),
        ),
      );
    }
    for (final Routine routine in state.routinesOn(day)) {
      events.add(
        TimetableEvent(
          start: routine.startOn(day),
          end: routine.endOn(day),
          title: routine.title,
          subtitle:
              '${Fmt.minutesAsTime(routine.startMinutes)} - ${Fmt.minutesAsTime(routine.endMinutes)}',
          color: Color(routine.color),
          isRoutine: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => RoutineEditorPage(routine: routine)),
          ),
        ),
      );
    }
    assignLanes(events);
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final DateTime weekStart = startOfWeek(widget.anchor);
    final List<DateTime> days = List<DateTime>.generate(
      7,
      (int i) => weekStart.add(Duration(days: i)),
    );
    final DateTime today = DateTime.now();

    return Column(
      children: <Widget>[
        _WeekHeader(days: days, today: today),
        _AllDayRow(days: days, state: state),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: hourHeight * 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: hourColumnWidth,
                    child: Column(
                      children: List<Widget>.generate(
                        24,
                        (int hour) => SizedBox(
                          height: hourHeight,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6, top: 2),
                              child: Text(
                                '${Fmt.two(hour)}:00',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ...days.map(
                    (DateTime day) => Expanded(
                      child: _DayColumn(
                        day: day,
                        isToday: isSameDay(day, today),
                        hourHeight: hourHeight,
                        events: _eventsFor(context, day),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.days, required this.today});

  final List<DateTime> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 46, right: 0, top: 4, bottom: 4),
      child: Row(
        children: days.map((DateTime day) {
          final bool isToday = isSameDay(day, today);
          return Expanded(
            child: GestureDetector(
              onTap: () => showDaySheet(context, day),
              child: Column(
                children: <Widget>[
                  Text(
                    Fmt.weekdayShort(day.weekday),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? theme.colorScheme.primary : null,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isToday ? theme.colorScheme.onPrimary : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// แถวงานแบบทั้งวัน (ไม่ระบุเวลา) ด้านบนตาราง
class _AllDayRow extends StatelessWidget {
  const _AllDayRow({required this.days, required this.state});

  final List<DateTime> days;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<DateTime, List<Task>> allDay = <DateTime, List<Task>>{
      for (final DateTime day in days)
        day: state.tasksOn(day).where((Task t) => !t.hasTime).toList(),
    };
    if (allDay.values.every((List<Task> list) => list.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.only(left: 46, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: days.map((DateTime day) {
          final List<Task> tasks = allDay[day]!;
          return Expanded(
            child: Column(
              children: tasks
                  .take(3)
                  .map(
                    (Task task) => GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => TaskEditorPage(task: task),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(task.color).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Color(task.color),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.isToday,
    required this.hourHeight,
    required this.events,
  });

  final DateTime day;
  final bool isToday;
  final double hourHeight;
  final List<TimetableEvent> events;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        return GestureDetector(
          onTap: () => showDaySheet(context, day),
          child: Container(
            decoration: BoxDecoration(
              color: isToday ? theme.colorScheme.primary.withValues(alpha: 0.04) : null,
              border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: Stack(
              children: <Widget>[
                // เส้นชั่วโมง
                Column(
                  children: List<Widget>.generate(
                    24,
                    (int hour) => Container(
                      height: hourHeight,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // เส้นเวลาปัจจุบัน
                if (isToday)
                  Positioned(
                    top: (now.hour * 60 + now.minute) * hourHeight / 60,
                    left: 0,
                    right: 0,
                    child: Container(height: 2, color: theme.colorScheme.error),
                  ),
                ...events.map((TimetableEvent event) {
                  final double laneWidth = width / event.laneCount;
                  return Positioned(
                    top: event.startMinutes * hourHeight / 60,
                    height: (event.endMinutes - event.startMinutes) * hourHeight / 60,
                    left: event.lane * laneWidth,
                    width: laneWidth,
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: Material(
                        color: event.color.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          onTap: event.onTap,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 2,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    if (event.isRoutine)
                                      const Icon(
                                        Icons.repeat_rounded,
                                        size: 9,
                                        color: Colors.white,
                                      ),
                                    if (event.isRoutine) const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        event.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          height: 1.15,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

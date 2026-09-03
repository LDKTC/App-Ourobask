import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import 'common.dart';
import 'quest_widgets.dart';

/// การ์ดงานหนึ่งชิ้น ใช้ซ้ำทั้งหน้าแรก หน้าโปรเจกต์ และแผ่นรายวัน
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    this.dense = false,
    this.showProject = true,
  });

  final Task task;
  final VoidCallback onTap;
  final bool dense;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final Project? project = showProject ? state.projectById(task.projectId) : null;
    final Color accent = Color(task.color);
    final bool overdue =
        task.due != null && !task.done && task.effectiveDue!.isBefore(DateTime.now());
    final List<Reminder> reminders = state.remindersOf(ReminderOwner.task, task.id);
    final bool hasAlarm = reminders.any((Reminder r) => r.isAlarm && r.enabled);
    final bool hasReminder = reminders.any((Reminder r) => r.enabled);

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(6, dense ? 4 : 8, 12, dense ? 4 : 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Checkbox(
                value: task.done,
                activeColor: accent,
                shape: const CircleBorder(),
                onChanged: (bool? value) => state.toggleTaskDone(task, value ?? false),
              ),
              Container(
                width: 3,
                height: dense ? 28 : 34,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: task.done ? 0.3 : 1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (task.priority > 0) ...<Widget>[
                          Icon(
                            task.priority > 1
                                ? Icons.priority_high_rounded
                                : Icons.flag_rounded,
                            size: 14,
                            color: task.priority > 1 ? theme.colorScheme.error : accent,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: dense ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: task.done ? TextDecoration.lineThrough : null,
                              color: task.done
                                  ? theme.colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (task.due != null)
                          _Meta(
                            icon: task.hasTime
                                ? Icons.schedule_rounded
                                : Icons.event_rounded,
                            label: task.hasTime
                                ? '${Fmt.date(task.due!)} ${Fmt.time(task.due!)} น.'
                                : '${Fmt.date(task.due!)} • ทั้งวัน',
                            color: overdue ? theme.colorScheme.error : null,
                          )
                        else
                          const _Meta(
                            icon: Icons.all_inclusive_rounded,
                            label: 'ไม่มีกำหนด',
                          ),
                        if (task.due != null && !task.done)
                          _Meta(
                            icon: Icons.hourglass_bottom_rounded,
                            label: Fmt.relative(task.due!, hasTime: task.hasTime),
                            color: overdue ? theme.colorScheme.error : null,
                          ),
                        if (task.isQuest) QuestBadge(color: accent),
                        if (project != null) ProjectChip(project: project, compact: true),
                        if (task.notes.trim().isNotEmpty)
                          const _Meta(icon: Icons.notes_rounded, label: 'มีบันทึก'),
                      ],
                    ),
                    // เควสเก็บเงินมีแถบความคืบหน้าของยอดเงินอยู่ในรายการเลย
                    if (task.isQuest)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 4),
                        child: QuestProgressLine(task: task, compact: dense),
                      ),
                  ],
                ),
              ),
              if (hasReminder)
                Icon(
                  hasAlarm ? Icons.alarm_on_rounded : Icons.notifications_active_rounded,
                  size: 18,
                  color: accent,
                ),
              if (task.isQuest && !task.done)
                IconButton(
                  tooltip: 'หยอดเงินเข้าเควส',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.add_card_rounded, size: 20, color: accent),
                  onPressed: () => showQuestDepositSheet(context, task),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color effective = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: effective),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: effective),
        ),
      ],
    );
  }
}

/// การ์ดกิจวัตร (routine) — แสดงวันและช่วงเวลา
class RoutineTile extends StatelessWidget {
  const RoutineTile({
    super.key,
    required this.routine,
    required this.onTap,
    this.showToggle = true,
  });

  final Routine routine;
  final VoidCallback onTap;
  final bool showToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final Color accent = Color(routine.color);
    final Project? project = state.projectById(routine.projectId);
    final Task? quest = state.taskById(routine.questTaskId);
    final double planAmount = routine.questAmount ?? 0;

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  routine.isQuestPlan
                      ? Icons.savings_rounded
                      : (routine.isMonthly
                            ? Icons.event_repeat_rounded
                            : Icons.repeat_rounded),
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      routine.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        _Meta(
                          icon: routine.isMonthly
                              ? Icons.event_repeat_rounded
                              : Icons.calendar_view_week_rounded,
                          label: routine.isMonthly
                              ? Fmt.monthDaysLabel(routine.monthDays)
                              : Fmt.daysLabel(routine.days),
                        ),
                        _Meta(
                          icon: Icons.schedule_rounded,
                          label:
                              '${Fmt.minutesAsTime(routine.startMinutes)} - ${Fmt.minutesAsTime(routine.endMinutes)}',
                        ),
                        // แผนเก็บเงินของเควส — บอกยอดต่อรอบและเควสปลายทาง
                        if (quest != null)
                          _Meta(
                            icon: Icons.savings_rounded,
                            label: planAmount > 0
                                ? '${Fmt.money(planAmount)} → ${quest.title}'
                                : 'แผนของ ${quest.title}',
                            color: accent,
                          ),
                        if (project != null) ProjectChip(project: project, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
              if (quest != null && !quest.done)
                IconButton(
                  tooltip: 'บันทึกเงินตามแผนนี้',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.add_card_rounded, size: 20, color: accent),
                  onPressed: () => showQuestDepositSheet(
                    context,
                    quest,
                    suggested: planAmount > 0 ? planAmount : null,
                    routineId: routine.id,
                    note: routine.title,
                  ),
                ),
              if (showToggle)
                Switch(
                  value: routine.active,
                  onChanged: (bool value) => state.setRoutineActive(routine, value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../utils/date_time_utils.dart';
import '../utils/formatters.dart';
import 'task_editor_page.dart';
import 'widgets/common.dart';

/// ประวัติงานที่ทำเสร็จแล้ว — เอากลับมาทำต่อได้ และเก็บไว้สูงสุด 30 วัน
class TaskHistoryPage extends StatefulWidget {
  const TaskHistoryPage({super.key});

  @override
  State<TaskHistoryPage> createState() => _TaskHistoryPageState();
}

class _TaskHistoryPageState extends State<TaskHistoryPage> {
  Future<void> _restore(Task task) async {
    final AppState state = context.read<AppState>();
    final String title = task.title;
    await state.restoreTask(task);
    if (!mounted) return;
    showSnack(context, 'เอา "$title" กลับมาทำต่อแล้ว');
  }

  Future<void> _delete(Task task) async {
    final AppState state = context.read<AppState>();
    final bool ok = await confirmDialog(
      context,
      title: 'ลบงานนี้ถาวร?',
      message: 'งาน "${task.title}" จะหายไปจากประวัติและกู้คืนไม่ได้',
      confirmLabel: 'ลบ',
      destructive: true,
    );
    if (!ok) return;
    await state.deleteTasksPermanently(<Task>[task]);
  }

  Future<void> _clearAll(int count) async {
    final AppState state = context.read<AppState>();
    final bool ok = await confirmDialog(
      context,
      title: 'ล้างประวัติทั้งหมด?',
      message: 'งานที่ทำเสร็จแล้ว $count รายการจะถูกลบถาวร',
      confirmLabel: 'ล้างทั้งหมด',
      destructive: true,
    );
    if (!ok) return;
    final int removed = await state.clearCompletedHistory();
    if (!mounted) return;
    showSnack(context, 'ล้างประวัติแล้ว $removed รายการ');
  }

  /// หัวข้อของแต่ละวัน เช่น "วันนี้" / "เมื่อวาน" / วันที่เต็ม
  String _dayLabel(DateTime day, DateTime now) {
    final int diff = daysBetween(day, now);
    if (diff == 0) return 'วันนี้';
    if (diff == 1) return 'เมื่อวาน';
    return Fmt.dateFull(day);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final List<Task> history = state.completedHistory();
    final DateTime now = DateTime.now();

    // จัดกลุ่มตามวันที่ทำเสร็จ (เรียงจากล่าสุดอยู่แล้ว)
    final List<DateTime> days = <DateTime>[];
    final Map<DateTime, List<Task>> byDay = <DateTime, List<Task>>{};
    for (final Task task in history) {
      final DateTime day = startOfDay(task.completedTime ?? task.updatedAt);
      final List<Task> bucket = byDay.putIfAbsent(day, () {
        days.add(day);
        return <Task>[];
      });
      bucket.add(task);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติงานที่เสร็จแล้ว'),
        actions: <Widget>[
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'ล้างประวัติทั้งหมด',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () => _clearAll(history.length),
            ),
        ],
      ),
      body: history.isEmpty
          ? const EmptyState(
              icon: Icons.history_rounded,
              title: 'ยังไม่มีงานที่ทำเสร็จ',
              message: 'งานที่ติ๊กว่าเสร็จแล้วจะมาอยู่ที่นี่\n'
                  'และเก็บไว้ $kCompletedRetentionDays วันก่อนถูกล้างออกอัตโนมัติ',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: <Widget>[
                const SizedBox(height: 8),
                _RetentionNote(count: history.length),
                for (final DateTime day in days) ...<Widget>[
                  SectionHeader(
                    title: _dayLabel(day, now),
                    subtitle: 'ทำเสร็จเมื่อ ${Fmt.date(day)}',
                    icon: Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                    count: byDay[day]!.length,
                  ),
                  ...byDay[day]!.map(
                    (Task task) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _HistoryTile(
                        task: task,
                        now: now,
                        onOpen: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => TaskEditorPage(task: task),
                          ),
                        ),
                        onRestore: () => _restore(task),
                        onDelete: () => _delete(task),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// คำอธิบายว่าเก็บประวัติไว้นานแค่ไหน
class _RetentionNote extends StatelessWidget {
  const _RetentionNote({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: <Widget>[
            Icon(Icons.auto_delete_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'เก็บไว้ $count รายการ',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'งานที่ทำเสร็จจะถูกเก็บไว้ $kCompletedRetentionDays วัน'
                    ' แล้วล้างออกอัตโนมัติ — กดปุ่มย้อนกลับเพื่อเอางานกลับมาทำต่อ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// หนึ่งรายการในประวัติ พร้อมปุ่มกู้คืนและลบถาวร
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.task,
    required this.now,
    required this.onOpen,
    required this.onRestore,
    required this.onDelete,
  });

  final Task task;
  final DateTime now;
  final VoidCallback onOpen;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final Project? project = state.projectById(task.projectId);
    final Color accent = Color(task.color);
    final DateTime completed = task.completedTime ?? task.updatedAt;
    final int daysLeft = daysLeftBeforePurge(completed, now: now);

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 34,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.lineThrough,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        _Meta(
                          icon: Icons.task_alt_rounded,
                          label:
                              'เสร็จ ${Fmt.date(completed)} ${Fmt.time(completed)} น.',
                          color: accent,
                        ),
                        if (task.isQuest)
                          const _Meta(icon: Icons.savings_rounded, label: 'เควสเก็บเงิน'),
                        if (project != null)
                          ProjectChip(project: project, compact: true),
                        _Meta(
                          icon: Icons.auto_delete_rounded,
                          label: daysLeft == 0
                              ? 'จะถูกล้างเร็ว ๆ นี้'
                              : 'ล้างออกในอีก $daysLeft วัน',
                          color: daysLeft <= 3 ? theme.colorScheme.error : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'เอากลับมาทำต่อ',
                icon: const Icon(Icons.restore_rounded),
                color: theme.colorScheme.primary,
                onPressed: onRestore,
              ),
              IconButton(
                tooltip: 'ลบถาวร',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: onDelete,
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

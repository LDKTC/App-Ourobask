import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../utils/date_time_utils.dart';
import '../utils/formatters.dart';
import 'routine_editor_page.dart';
import 'task_editor_page.dart';
import 'widgets/common.dart';
import 'widgets/quest_widgets.dart';
import 'widgets/task_tile.dart';
import 'work_page.dart';

/// รายละเอียดโฟลเดอร์งาน — งานทั้งหมดที่เก็บไว้ในโปรเจกต์นี้
class ProjectDetailPage extends StatelessWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final Project? project = state.projectById(projectId);
    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.folder_off_rounded, title: 'ไม่พบโฟลเดอร์นี้'),
      );
    }

    final Color color = Color(project.color);
    final List<Task> tasks = state.tasksOfProject(projectId);
    final List<Task> open = tasks.where((Task t) => !t.done).toList()
      ..sort((Task a, Task b) {
        final DateTime? da = a.due;
        final DateTime? db = b.due;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    final List<Task> done = tasks.where((Task t) => t.done).toList();
    final List<Routine> routines = state.routines
        .where((Routine r) => r.projectId == projectId)
        .toList();
    final MoneySummary money = state.moneyOf(tasks);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Icon(project.icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(project.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'เพิ่มเควสเก็บเงิน',
            icon: const Icon(Icons.savings_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TaskEditorPage(
                  initialProjectId: projectId,
                  initialKind: TaskKind.quest,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'แก้ไขโฟลเดอร์',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => showProjectEditor(context, project: project),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: color,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TaskEditorPage(initialProjectId: projectId),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('เพิ่มงานในโฟลเดอร์'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          if (project.description.trim().isNotEmpty)
            Card(
              color: color.withValues(alpha: 0.10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(project.description, style: theme.textTheme.bodyMedium),
              ),
            ),
          // ยอดเงินรวมของเควสทั้งโฟลเดอร์ พร้อมแถบความคืบหน้า
          if (!money.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            MoneySummaryCard(summary: money, color: color),
          ],
          if (tasks.isEmpty && routines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: EmptyState(
                icon: Icons.assignment_outlined,
                title: 'โฟลเดอร์นี้ยังว่าง',
                message: 'เพิ่มงานที่ต้องการเก็บไว้ทำในโปรเจกต์นี้',
                action: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => TaskEditorPage(initialProjectId: projectId),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('เพิ่มงาน'),
                ),
              ),
            ),
          if (open.isNotEmpty) ...<Widget>[
            SectionHeader(
              title: 'กำลังทำ',
              subtitle: 'เรียงตามกำหนดส่ง',
              color: color,
              count: open.length,
            ),
            ...open.map(
              (Task task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskTile(
                  task: task,
                  showProject: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => TaskEditorPage(task: task)),
                  ),
                ),
              ),
            ),
          ],
          if (routines.isNotEmpty) ...<Widget>[
            SectionHeader(
              title: 'กิจวัตรของโฟลเดอร์นี้',
              icon: Icons.repeat_rounded,
              color: color,
              count: routines.length,
            ),
            ...routines.map(
              (Routine routine) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RoutineTile(
                  routine: routine,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RoutineEditorPage(routine: routine),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (done.isNotEmpty) ...<Widget>[
            SectionHeader(
              title: 'เสร็จแล้ว',
              color: theme.colorScheme.outline,
              count: done.length,
            ),
            ...done.map(
              (Task task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskTile(
                  task: task,
                  dense: true,
                  showProject: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => TaskEditorPage(task: task)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// แผ่นแสดงงานของวันหนึ่ง ๆ (ใช้จากหน้าปฏิทิน)
Future<void> showDaySheet(BuildContext context, DateTime day) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (BuildContext context, ScrollController controller) =>
          _DaySheet(day: day, controller: controller),
    ),
  );
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.day, required this.controller});

  final DateTime day;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<Task> tasks = state.tasksOn(day);
    final List<Routine> routines = state.routinesOn(day);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SectionHeader(
                title: _title(day),
                subtitle: '${tasks.length} งาน • ${routines.length} กิจวัตร',
                icon: Icons.event_note_rounded,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TaskEditorPage(initialDue: day),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('เพิ่ม'),
            ),
          ],
        ),
        if (tasks.isEmpty && routines.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: EmptyState(
              icon: Icons.event_available_rounded,
              title: 'วันนี้ว่าง',
              message: 'ยังไม่มีงานหรือกิจวัตรในวันนี้',
            ),
          ),
        ...tasks.map(
          (Task task) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskTile(
              task: task,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => TaskEditorPage(task: task)),
                );
              },
            ),
          ),
        ),
        ...routines.map(
          (Routine routine) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RoutineTile(
              routine: routine,
              showToggle: false,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RoutineEditorPage(routine: routine),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _title(DateTime day) {
    final DateTime now = DateTime.now();
    if (isSameDay(day, now)) return 'วันนี้';
    if (isSameDay(day, now.add(const Duration(days: 1)))) return 'พรุ่งนี้';
    return Fmt.dateFull(day);
  }
}

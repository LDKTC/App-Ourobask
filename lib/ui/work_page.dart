import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../utils/formatters.dart';
import 'project_detail_page.dart';
import 'task_editor_page.dart';
import 'widgets/common.dart';
import 'widgets/quest_widgets.dart';
import 'widgets/task_tile.dart';

/// หน้างาน — โฟลเดอร์งาน (Work Project) แบบการ์ด
class WorkPage extends StatelessWidget {
  const WorkPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<Project> projects = state.projects;
    final List<Task> loose = state.tasks
        .where((Task t) => t.projectId == null && (!t.done || state.showCompleted))
        .toList();
    final MoneySummary money = state.moneyOverall;

    return Scaffold(
      appBar: AppBar(
        title: const Text('งาน'),
        actions: <Widget>[
          IconButton(
            tooltip: 'เพิ่มเควสเก็บเงิน',
            icon: const Icon(Icons.savings_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const TaskEditorPage(initialKind: TaskKind.quest),
              ),
            ),
          ),
          IconButton(
            tooltip: 'สร้างโฟลเดอร์ใหม่',
            icon: const Icon(Icons.create_new_folder_rounded),
            onPressed: () => showProjectEditor(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const TaskEditorPage()),
        ),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('เพิ่มงาน'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: <Widget>[
          if (!money.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            MoneySummaryCard(
              summary: money,
              color: Theme.of(context).colorScheme.primary,
              title: 'ยอดเงินรวมของทุกเควส',
            ),
          ],
          const SectionHeader(
            title: 'โฟลเดอร์งาน',
            subtitle: 'จัดกลุ่มงานเป็นโปรเจกต์',
            icon: Icons.folder_copy_rounded,
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
            children: <Widget>[
              ...projects.map(
                (Project project) => _ProjectCard(project: project, state: state),
              ),
              _NewProjectCard(onTap: () => showProjectEditor(context)),
            ],
          ),
          if (loose.isNotEmpty) ...<Widget>[
            SectionHeader(
              title: 'งานที่ยังไม่อยู่ในโฟลเดอร์',
              icon: Icons.inbox_rounded,
              count: loose.length,
            ),
            ...loose.map(
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
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.state});

  final Project project;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = Color(project.color);
    final List<Task> tasks = state.tasksOfProject(project.id!);
    final int done = tasks.where((Task t) => t.done).length;
    final double progress = tasks.isEmpty ? 0 : done / tasks.length;
    final MoneySummary money = state.moneyOf(tasks);

    return Card(
      color: color.withValues(alpha: 0.10),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ProjectDetailPage(projectId: project.id!),
          ),
        ),
        onLongPress: () => showProjectEditor(context, project: project),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(project.icon, color: color),
                  ),
                  const Spacer(),
                  Text(
                    '${tasks.length - done}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                project.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                tasks.isEmpty ? 'ยังไม่มีงาน' : 'เสร็จ $done จาก ${tasks.length} งาน',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              // ยอดเงินรวมของเควสในโฟลเดอร์นี้ พร้อมแถบความคืบหน้า
              if (!money.isEmpty) ...<Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.savings_rounded, size: 13, color: color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        money.target > 0
                            ? '${Fmt.money(money.saved)} / ${Fmt.money(money.target)}'
                            : Fmt.money(money.saved),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                MoneyProgressBar(progress: money.progress, color: color, height: 5),
                const SizedBox(height: 8),
              ],
              MoneyProgressBar(progress: progress, color: color, height: 5),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewProjectCard extends StatelessWidget {
  const _NewProjectCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.create_new_folder_rounded,
                size: 30,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'สร้างโฟลเดอร์ใหม่',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// แผ่นสร้าง/แก้ไขโฟลเดอร์งาน
Future<void> showProjectEditor(BuildContext context, {Project? project}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ProjectSheet(project: project),
    ),
  );
}

class _ProjectSheet extends StatefulWidget {
  const _ProjectSheet({this.project});

  final Project? project;

  @override
  State<_ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends State<_ProjectSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.project?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.project?.description ?? '',
  );
  late int _color = widget.project?.color ?? kPalette.first;
  late int _icon = widget.project?.iconIndex ?? 0;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'ใส่ชื่อโฟลเดอร์ก่อน');
      return;
    }
    final Project project = widget.project ?? Project(name: name);
    project
      ..name = name
      ..description = _description.text.trim()
      ..color = _color
      ..iconIndex = _icon;
    await context.read<AppState>().saveProject(project);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final Project? project = widget.project;
    if (project == null) return;
    final AppState state = context.read<AppState>();
    final int taskCount = state.tasksOfProject(project.id!).length;
    final bool? deleteTasks = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('ลบโฟลเดอร์ "${project.name}"?'),
        content: Text(
          taskCount == 0
              ? 'โฟลเดอร์นี้ยังไม่มีงาน'
              : 'มี $taskCount งานอยู่ข้างใน จะเก็บงานไว้หรือลบไปพร้อมกัน?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('เก็บงานไว้'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบงานด้วย'),
          ),
        ],
      ),
    );
    if (deleteTasks == null || !mounted) return;
    await state.deleteProject(project, deleteTasks: deleteTasks);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.project == null ? 'โฟลเดอร์งานใหม่' : 'แก้ไขโฟลเดอร์',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                autofocus: widget.project == null,
                decoration: const InputDecoration(
                  labelText: 'ชื่อโฟลเดอร์',
                  prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'คำอธิบาย (ไม่บังคับ)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ไอคอน',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              IconChoiceRow(
                value: _icon,
                color: _color,
                onChanged: (int value) => setState(() => _icon = value),
              ),
              const SizedBox(height: 16),
              Text(
                'สี',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ColorChoiceRow(
                value: _color,
                onChanged: (int value) => setState(() => _color = value),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  if (widget.project != null)
                    TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('ลบโฟลเดอร์'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  const Spacer(),
                  FilledButton(onPressed: _save, child: const Text('บันทึก')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

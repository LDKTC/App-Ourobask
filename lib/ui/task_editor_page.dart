import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../utils/formatters.dart';
import 'routine_editor_page.dart';
import 'widgets/common.dart';
import 'widgets/quest_widgets.dart';
import 'widgets/reminder_editor.dart';
import 'widgets/task_tile.dart';

/// หน้าสร้าง/แก้ไขงาน — วันและเวลาเป็นทางเลือกทั้งคู่
class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({
    super.key,
    this.task,
    this.initialProjectId,
    this.initialDue,
    this.initialKind,
  });

  final Task? task;
  final int? initialProjectId;
  final DateTime? initialDue;

  /// ใช้เปิดหน้านี้ในโหมด "เควสเก็บเงิน" ได้ทันที
  final TaskKind? initialKind;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  late final TextEditingController _title = TextEditingController(
    text: widget.task?.title ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.task?.notes ?? '',
  );
  final TextEditingController _target = TextEditingController();

  TaskKind _kind = TaskKind.normal;
  int? _projectId;
  DateTime? _date;
  TimeOfDay? _time;
  int? _durationMinutes;
  int _priority = 0;
  int _color = kPalette.first;
  List<Reminder> _reminders = <Reminder>[];

  bool get _isNew => widget.task?.id == null;

  @override
  void initState() {
    super.initState();
    final Task? task = widget.task;
    _kind = task?.kind ?? widget.initialKind ?? TaskKind.normal;
    final double? goal = task?.targetAmount;
    if (goal != null && goal > 0) {
      _target.text = goal == goal.roundToDouble()
          ? goal.round().toString()
          : goal.toString();
    }
    _projectId = task?.projectId ?? widget.initialProjectId;
    _priority = task?.priority ?? 0;
    _color = task?.color ?? kPalette.first;
    _durationMinutes = task?.durationMinutes;
    final DateTime? due = task?.due ?? widget.initialDue;
    if (due != null) {
      _date = DateTime(due.year, due.month, due.day);
      if (task?.hasTime ?? (widget.initialDue != null && widget.task != null)) {
        _time = TimeOfDay(hour: due.hour, minute: due.minute);
      }
    }
    if (task?.id != null) {
      _reminders = context
          .read<AppState>()
          .remindersOf(ReminderOwner.task, task!.id)
          .map((Reminder r) => r.copy())
          .toList();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _target.dispose();
    super.dispose();
  }

  DateTime? get _due {
    final DateTime? date = _date;
    if (date == null) return null;
    final TimeOfDay? time = _time;
    if (time == null) return DateTime(date.year, date.month, date.day);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: 'เลือกวันครบกำหนด',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'เลือกเวลาครบกำหนด',
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDuration() async {
    final List<int> options = <int>[15, 30, 45, 60, 90, 120, 180, 240];
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ListTile(title: Text('ระยะเวลาของงาน')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                ...options.map(
                  (int minutes) => ActionChip(
                    label: Text(
                      minutes < 60
                          ? '$minutes นาที'
                          : '${(minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1)} ชม.',
                    ),
                    onPressed: () => Navigator.pop(context, minutes),
                  ),
                ),
                ActionChip(
                  label: const Text('ไม่ระบุ'),
                  onPressed: () => Navigator.pop(context, 0),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _durationMinutes = picked == 0 ? null : picked);
    }
  }

  Future<void> _save() async {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      showSnack(context, 'ใส่ชื่องานก่อนบันทึก');
      return;
    }
    final double? goal = parseAmount(_target.text);
    if (_kind == TaskKind.quest && goal == null) {
      showSnack(context, 'เควสเก็บเงินต้องระบุจำนวนเงินเป้าหมาย');
      return;
    }
    final AppState state = context.read<AppState>();
    final Task task = widget.task ?? Task(title: title);
    task
      ..title = title
      ..notes = _notes.text.trim()
      ..kind = _kind
      ..targetAmount = _kind == TaskKind.quest ? goal : null
      ..projectId = _projectId
      ..due = _due
      ..hasTime = _date != null && _time != null
      ..durationMinutes = _time == null ? null : _durationMinutes
      ..priority = _priority
      ..color = _color;

    await state.saveTask(task, reminders: _reminders);
    if (_reminders.any((Reminder r) => r.enabled)) {
      await NotificationService.instance.requestPermissions();
    }
    if (mounted) Navigator.pop(context, task);
  }

  Future<void> _delete() async {
    final Task? task = widget.task;
    if (task == null) return;
    final bool ok = await confirmDialog(
      context,
      title: 'ลบงานนี้?',
      message: 'งาน "${task.title}" และการเตือนทั้งหมดจะถูกลบถาวร',
      confirmLabel: 'ลบ',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().deleteTask(task);
    if (mounted) Navigator.pop(context);
  }

  /// แผงของเควสเก็บเงิน — เป้าหมาย ความคืบหน้า แผนรายเดือน และประวัติการหยอดเงิน
  Widget _questSection(BuildContext context, AppState state) {
    final ThemeData theme = Theme.of(context);
    final Task? task = widget.task;
    final bool hasId = task?.id != null;
    final Color color = Color(_color);
    final List<QuestEntry> entries = hasId
        ? state.questEntriesOf(task!.id)
        : <QuestEntry>[];
    final List<Routine> plans = hasId ? state.questPlansOf(task!.id) : <Routine>[];
    final int? months = hasId ? state.monthsToGoal(task!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.savings_rounded, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              'แผนเก็บเงิน',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        MoneyField(controller: _target, label: 'เป้าหมายที่ต้องเก็บ'),
        const SizedBox(height: 6),
        Text(
          'ต้องระบุจำนวนเงินเป้าหมาย แอปจะคิดเป็นแถบความคืบหน้าให้ทั้งในรายการงาน'
          ' และยอดรวมของโฟลเดอร์',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (!hasId)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'บันทึกเควสนี้ก่อน แล้วจะหยอดเงินและตั้งแผนเก็บเงินรายเดือนได้',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          )
        else ...<Widget>[
          const SizedBox(height: 14),
          QuestProgressLine(task: task!),
          if (months != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                months == 0
                    ? 'ตามแผนนี้เก็บครบเป้าแล้ว'
                    : 'ตามแผนที่ตั้งไว้ จะครบเป้าในอีกประมาณ $months เดือน',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: () => showQuestDepositSheet(context, task),
                  icon: const Icon(Icons.add_card_rounded, size: 18),
                  label: const Text('หยอดเงิน'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RoutineEditorPage(
                        initialQuestTaskId: task.id,
                        initialProjectId: _projectId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.event_repeat_rounded, size: 18),
                  label: const Text('แผนรายเดือน'),
                ),
              ),
            ],
          ),
          if (plans.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'แผนเก็บเงินประจำ',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...plans.map(
              (Routine routine) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RoutineTile(
                  routine: routine,
                  showToggle: false,
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
          const SizedBox(height: 12),
          Text(
            entries.isEmpty
                ? 'ยังไม่มีการหยอดเงิน'
                : 'ประวัติการหยอดเงิน (${entries.length} ครั้ง)',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          ...entries
              .take(20)
              .map((QuestEntry entry) => _EntryTile(entry: entry, color: color)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew
              ? (_kind == TaskKind.quest ? 'เควสใหม่' : 'งานใหม่')
              : (_kind == TaskKind.quest ? 'แก้ไขเควส' : 'แก้ไขงาน'),
        ),
        actions: <Widget>[
          if (!_isNew)
            IconButton(
              tooltip: 'ลบงาน',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('บันทึก'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          TextField(
            controller: _title,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.titleLarge,
            decoration: InputDecoration(
              hintText: _kind == TaskKind.quest ? 'จะเก็บเงินไปทำอะไร?' : 'จะทำอะไร?',
              prefixIcon: const Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'รายละเอียด / โน้ตเพิ่มเติม',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),

          // ------------------------------------------------------ ประเภทงาน
          _FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ประเภทของงาน',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<TaskKind>(
                  segments: const <ButtonSegment<TaskKind>>[
                    ButtonSegment<TaskKind>(
                      value: TaskKind.normal,
                      label: Text('งานทั่วไป'),
                      icon: Icon(Icons.check_circle_outline_rounded),
                    ),
                    ButtonSegment<TaskKind>(
                      value: TaskKind.quest,
                      label: Text('เควสเก็บเงิน'),
                      icon: Icon(Icons.savings_rounded),
                    ),
                  ],
                  selected: <TaskKind>{_kind},
                  onSelectionChanged: (Set<TaskKind> value) =>
                      setState(() => _kind = value.first),
                ),
              ],
            ),
          ),
          if (_kind == TaskKind.quest) ...<Widget>[
            const SizedBox(height: 12),
            _FieldCard(child: _questSection(context, state)),
          ],
          const SizedBox(height: 12),

          // ---------------------------------------------------- โฟลเดอร์งาน
          _FieldCard(
            child: DropdownButtonFormField<int?>(
              initialValue: _projectId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'โฟลเดอร์งาน (Work Project)',
                prefixIcon: Icon(Icons.folder_rounded),
              ),
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('ไม่อยู่ในโฟลเดอร์'),
                ),
                ...state.projects.map(
                  (Project project) => DropdownMenuItem<int?>(
                    value: project.id,
                    child: Row(
                      children: <Widget>[
                        Icon(project.icon, size: 18, color: Color(project.color)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(project.name, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (int? value) => setState(() => _projectId = value),
            ),
          ),
          const SizedBox(height: 12),

          // -------------------------------------------------- วันที่และเวลา
          _FieldCard(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _date != null,
                  title: const Text('กำหนดวันครบกำหนด'),
                  subtitle: Text(
                    _date == null ? 'ไม่ระบุ = งานไม่มีกำหนดส่ง' : Fmt.dateFull(_date!),
                  ),
                  secondary: const Icon(Icons.event_rounded),
                  onChanged: (bool value) async {
                    if (!value) {
                      setState(() {
                        _date = null;
                        _time = null;
                      });
                      return;
                    }
                    await _pickDate();
                  },
                ),
                if (_date != null) ...<Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded),
                    title: const Text('วันที่'),
                    subtitle: Text(Fmt.dateFull(_date!)),
                    trailing: TextButton(
                      onPressed: _pickDate,
                      child: const Text('เปลี่ยน'),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _time != null,
                    title: const Text('ระบุเวลา'),
                    subtitle: Text(
                      _time == null
                          ? 'ไม่ระบุเวลา = นับเป็นทั้งวัน'
                          : '${Fmt.timeOfDay(_time!)} น.',
                    ),
                    secondary: const Icon(Icons.schedule_rounded),
                    onChanged: (bool value) async {
                      if (!value) {
                        setState(() {
                          _time = null;
                          _durationMinutes = null;
                        });
                        return;
                      }
                      await _pickTime();
                    },
                  ),
                  if (_time != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.timelapse_rounded),
                      title: const Text('ระยะเวลา'),
                      subtitle: Text(
                        _durationMinutes == null ? 'ไม่ระบุ' : '$_durationMinutes นาที',
                      ),
                      trailing: TextButton(
                        onPressed: _pickDuration,
                        child: const Text('เลือก'),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ------------------------------------------------ ความสำคัญและสี
          _FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ความสำคัญ',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 0, label: Text('ปกติ')),
                    ButtonSegment<int>(value: 1, label: Text('สำคัญ')),
                    ButtonSegment<int>(value: 2, label: Text('ด่วนมาก')),
                  ],
                  selected: <int>{_priority},
                  onSelectionChanged: (Set<int> value) =>
                      setState(() => _priority = value.first),
                ),
                const SizedBox(height: 16),
                Text(
                  'สี',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ColorChoiceRow(
                  value: _color,
                  onChanged: (int value) => setState(() => _color = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ------------------------------------------------------ การเตือน
          _FieldCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ReminderListSection(
                  reminders: _reminders,
                  ownerTitle: _title.text,
                  onChanged: (List<Reminder> value) => setState(() => _reminders = value),
                ),
                if (_date == null && _reminders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'งานนี้ยังไม่มีวันครบกำหนด การเตือนจะเริ่มทำงานเมื่อกำหนดวันแล้ว',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 14), child: child),
    );
  }
}

/// หนึ่งบรรทัดของประวัติการหยอด/ถอนเงินของเควส
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.color});

  final QuestEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool withdraw = entry.amount < 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        withdraw ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
        color: withdraw ? theme.colorScheme.error : color,
      ),
      title: Text(
        Fmt.money(entry.amount),
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        entry.note.trim().isEmpty
            ? Fmt.date(entry.createdAt)
            : '${Fmt.date(entry.createdAt)} • ${entry.note.trim()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'ลบรายการนี้',
        icon: const Icon(Icons.close_rounded, size: 18),
        onPressed: () async {
          final AppState state = context.read<AppState>();
          final bool ok = await confirmDialog(
            context,
            title: 'ลบรายการเงินนี้?',
            message: 'ยอด ${Fmt.money(entry.amount)} จะถูกหักออกจากความคืบหน้าของเควส',
            confirmLabel: 'ลบ',
            destructive: true,
          );
          if (!ok) return;
          await state.deleteQuestEntry(entry);
        },
      ),
    );
  }
}

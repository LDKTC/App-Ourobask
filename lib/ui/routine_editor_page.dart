import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../utils/formatters.dart';
import 'widgets/common.dart';
import 'widgets/quest_widgets.dart';
import 'widgets/reminder_editor.dart';

/// หน้าสร้าง/แก้ไขกิจวัตร (ทำซ้ำทุกสัปดาห์ เช่น ตารางเรียน)
class RoutineEditorPage extends StatefulWidget {
  const RoutineEditorPage({
    super.key,
    this.routine,
    this.initialProjectId,
    this.initialQuestTaskId,
  });

  final Routine? routine;
  final int? initialProjectId;

  /// เปิดหน้านี้เป็น "แผนเก็บเงินรายเดือน" ของเควสที่ระบุ
  final int? initialQuestTaskId;

  @override
  State<RoutineEditorPage> createState() => _RoutineEditorPageState();
}

class _RoutineEditorPageState extends State<RoutineEditorPage> {
  late final TextEditingController _title = TextEditingController(
    text: widget.routine?.title ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.routine?.notes ?? '',
  );

  late Set<int> _days = <int>{...?widget.routine?.days};
  late Set<int> _monthDays = <int>{...?widget.routine?.monthDays};
  late RoutineRepeat _repeat =
      widget.routine?.repeat ??
      (widget.initialQuestTaskId != null ? RoutineRepeat.monthly : RoutineRepeat.weekly);
  late int? _questTaskId = widget.routine?.questTaskId ?? widget.initialQuestTaskId;
  final TextEditingController _questAmount = TextEditingController();
  late int _start = widget.routine?.startMinutes ?? 8 * 60;
  late int _end = widget.routine?.endMinutes ?? 9 * 60;
  late int _color = widget.routine?.color ?? kPalette[2];
  late bool _active = widget.routine?.active ?? true;
  late int? _projectId = widget.routine?.projectId ?? widget.initialProjectId;
  late DateTime? _startDate = widget.routine?.startDate;
  late DateTime? _endDate = widget.routine?.endDate;
  List<Reminder> _reminders = <Reminder>[];

  bool get _isNew => widget.routine?.id == null;

  bool get _isQuestPlan => _questTaskId != null;

  @override
  void initState() {
    super.initState();
    final double? amount = widget.routine?.questAmount;
    if (amount != null && amount > 0) {
      _questAmount.text = amount == amount.roundToDouble()
          ? amount.round().toString()
          : amount.toString();
    }
    // แผนเก็บเงินที่เพิ่งสร้าง — ตั้งค่าเริ่มต้นให้พร้อมใช้ทันที
    if (widget.routine == null && widget.initialQuestTaskId != null) {
      if (_monthDays.isEmpty) _monthDays = <int>{DateTime.now().day};
      final Task? quest = context.read<AppState>().taskById(widget.initialQuestTaskId);
      if (quest != null && _title.text.isEmpty) {
        _title.text = 'เก็บเงิน: ${quest.title}';
      }
    }
    if (widget.routine?.id != null) {
      _reminders = context
          .read<AppState>()
          .remindersOf(ReminderOwner.routine, widget.routine!.id)
          .map((Reminder r) => r.copy())
          .toList();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _questAmount.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final int current = isStart ? _start : _end;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      helpText: isStart ? 'เวลาเริ่ม' : 'เวลาสิ้นสุด',
    );
    if (picked == null) return;
    setState(() {
      final int minutes = picked.hour * 60 + picked.minute;
      if (isStart) {
        _start = minutes;
        if (_end <= _start) _end = (_start + 60).clamp(0, 24 * 60 - 1);
      } else {
        _end = minutes;
        if (_end <= _start) _start = (_end - 60).clamp(0, 24 * 60 - 1);
      }
    });
  }

  Future<void> _pickRangeDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: isStart ? 'เริ่มใช้ตั้งแต่' : 'ใช้ถึงวันที่',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      showSnack(context, 'ใส่ชื่อกิจวัตรก่อนบันทึก');
      return;
    }
    if (_repeat == RoutineRepeat.weekly && _days.isEmpty) {
      showSnack(context, 'เลือกอย่างน้อย 1 วันในสัปดาห์');
      return;
    }
    if (_repeat == RoutineRepeat.monthly && _monthDays.isEmpty) {
      showSnack(context, 'เลือกอย่างน้อย 1 วันที่ของเดือน');
      return;
    }
    final AppState state = context.read<AppState>();
    // เควสที่ผูกไว้อาจถูกลบไปแล้ว จึงยืนยันอีกครั้งก่อนบันทึก
    final int? questId = state.taskById(_questTaskId)?.id;
    final double? planAmount = parseAmount(_questAmount.text);
    if (questId != null && planAmount == null) {
      showSnack(context, 'แผนเก็บเงินต้องระบุจำนวนเงินต่อรอบ');
      return;
    }
    final Routine routine = widget.routine ?? Routine(title: title);
    routine
      ..title = title
      ..notes = _notes.text.trim()
      ..projectId = _projectId
      ..days = (_days.toList()..sort())
      ..repeat = _repeat
      ..monthDays = (_monthDays.toList()..sort())
      ..questTaskId = questId
      ..questAmount = questId == null ? null : planAmount
      ..startMinutes = _start
      ..endMinutes = _end
      ..color = _color
      ..active = _active
      ..startDate = _startDate
      ..endDate = _endDate;

    await state.saveRoutine(routine, reminders: _reminders);
    if (_reminders.any((Reminder r) => r.enabled)) {
      await NotificationService.instance.requestPermissions();
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final Routine? routine = widget.routine;
    if (routine == null) return;
    final bool ok = await confirmDialog(
      context,
      title: 'ลบกิจวัตรนี้?',
      message: '"${routine.title}" จะถูกลบพร้อมการเตือนทั้งหมด',
      confirmLabel: 'ลบ',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().deleteRoutine(routine);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final List<Task> quests = state.quests;
    // เควสที่ผูกไว้อาจถูกลบไปแล้ว จึงต้องเช็คก่อนส่งค่าให้ dropdown
    final int? questValue = quests.any((Task t) => t.id == _questTaskId)
        ? _questTaskId
        : null;
    final double planPerRound = parseAmount(_questAmount.text) ?? 0;
    final double planPerMonth = _repeat == RoutineRepeat.monthly
        ? planPerRound * _monthDays.length
        : planPerRound * _days.length * 52 / 12;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew
              ? (_isQuestPlan ? 'แผนเก็บเงินใหม่' : 'กิจวัตรใหม่')
              : (_isQuestPlan ? 'แก้ไขแผนเก็บเงิน' : 'แก้ไขกิจวัตร'),
        ),
        actions: <Widget>[
          if (!_isNew)
            IconButton(
              tooltip: 'ลบ',
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
            style: theme.textTheme.titleLarge,
            decoration: InputDecoration(
              hintText: _isQuestPlan
                  ? 'เช่น เก็บเงินค่าเทอม'
                  : 'เช่น เรียนวิชาคณิตศาสตร์',
              prefixIcon: Icon(
                _isQuestPlan ? Icons.savings_rounded : Icons.repeat_rounded,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'รายละเอียด เช่น ห้อง/อาจารย์'),
          ),
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'รูปแบบการทำซ้ำ',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<RoutineRepeat>(
                    segments: const <ButtonSegment<RoutineRepeat>>[
                      ButtonSegment<RoutineRepeat>(
                        value: RoutineRepeat.weekly,
                        label: Text('ทุกสัปดาห์'),
                        icon: Icon(Icons.calendar_view_week_rounded),
                      ),
                      ButtonSegment<RoutineRepeat>(
                        value: RoutineRepeat.monthly,
                        label: Text('ทุกเดือน'),
                        icon: Icon(Icons.event_repeat_rounded),
                      ),
                    ],
                    selected: <RoutineRepeat>{_repeat},
                    onSelectionChanged: (Set<RoutineRepeat> value) =>
                        setState(() => _repeat = value.first),
                  ),
                  const SizedBox(height: 14),
                  if (_repeat == RoutineRepeat.weekly) ...<Widget>[
                    Text(
                      'วันที่ทำซ้ำในสัปดาห์',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List<Widget>.generate(7, (int index) {
                        final int weekday = index + 1;
                        final bool selected = _days.contains(weekday);
                        return FilterChip(
                          label: Text(Fmt.weekdayShort(weekday)),
                          selected: selected,
                          onSelected: (bool value) => setState(() {
                            if (value) {
                              _days.add(weekday);
                            } else {
                              _days.remove(weekday);
                            }
                          }),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => _days = <int>{1, 2, 3, 4, 5}),
                            icon: const Icon(Icons.work_outline_rounded, size: 16),
                            label: const Text('จ - ศ'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _days = <int>{1, 2, 3, 4, 5, 6, 7}),
                            icon: const Icon(Icons.calendar_month_rounded, size: 16),
                            label: const Text('ทุกวัน'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...<Widget>[
                    // ระบุวันที่ของเดือน เช่น ทุกวันที่ 1 และ 25 (ใช้กับแผนเก็บเงิน)
                    Text(
                      'วันที่ของเดือน',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.monthDaysLabel(_monthDays.toList()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List<Widget>.generate(31, (int index) {
                        final int day = index + 1;
                        final bool selected = _monthDays.contains(day);
                        return FilterChip(
                          visualDensity: VisualDensity.compact,
                          labelPadding: EdgeInsets.zero,
                          label: SizedBox(
                            width: 24,
                            child: Text('$day', textAlign: TextAlign.center),
                          ),
                          selected: selected,
                          showCheckmark: false,
                          onSelected: (bool value) => setState(() {
                            if (value) {
                              _monthDays.add(day);
                            } else {
                              _monthDays.remove(day);
                            }
                          }),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _monthDays = <int>{1}),
                            child: const Text('ต้นเดือน'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _monthDays = <int>{1, 16}),
                            child: const Text('ทุกครึ่งเดือน'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _monthDays = <int>{31}),
                            child: const Text('สิ้นเดือน'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'เดือนที่ไม่มีวันที่ที่เลือก (เช่น 31 ในเดือนกุมภาพันธ์)'
                      ' จะเลื่อนมาเป็นวันสุดท้ายของเดือนให้อัตโนมัติ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: const Text('เวลาเริ่ม'),
                  trailing: Text(
                    '${Fmt.minutesAsTime(_start)} น.',
                    style: theme.textTheme.titleMedium,
                  ),
                  onTap: () => _pickTime(isStart: true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.stop_rounded),
                  title: const Text('เวลาสิ้นสุด'),
                  trailing: Text(
                    '${Fmt.minutesAsTime(_end)} น.',
                    style: theme.textTheme.titleMedium,
                  ),
                  onTap: () => _pickTime(isStart: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ------------------------------------------------ แผนเก็บเงินของเควส
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.savings_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ใช้เป็นแผนเก็บเงินของเควส',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: questValue,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'เควสปลายทาง',
                      prefixIcon: Icon(Icons.flag_rounded),
                    ),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ไม่ผูกกับเควส (กิจวัตรธรรมดา)'),
                      ),
                      ...quests.map(
                        (Task quest) => DropdownMenuItem<int?>(
                          value: quest.id,
                          child: Text(quest.title, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (int? value) => setState(() => _questTaskId = value),
                  ),
                  if (_isQuestPlan) ...<Widget>[
                    const SizedBox(height: 12),
                    MoneyField(
                      controller: _questAmount,
                      label: 'เงินที่จะเก็บต่อรอบ',
                      onSubmitted: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      planPerMonth > 0
                          ? 'รวมประมาณ ${Fmt.money(planPerMonth)} ต่อเดือน'
                                ' • ถึงรอบแล้วกดปุ่มบันทึกเงินได้จากรายการกิจวัตร'
                          : 'ระบุจำนวนเงินต่อรอบ แล้วแอปจะเตือนและให้กดบันทึกเงิน'
                                ' เข้าเควสได้ทันทีเมื่อถึงวันที่กำหนด',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DropdownButtonFormField<int?>(
                    initialValue: _projectId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'อยู่ในโฟลเดอร์งาน',
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
                          child: Text(project.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (int? value) => setState(() => _projectId = value),
                  ),
                  const SizedBox(height: 14),
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
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _active,
                    title: const Text('ใช้งานกิจวัตรนี้'),
                    subtitle: const Text('ปิดชั่วคราวได้โดยไม่ต้องลบ'),
                    onChanged: (bool value) => setState(() => _active = value),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.date_range_rounded),
                    title: const Text('ช่วงที่ใช้ (ไม่บังคับ)'),
                    subtitle: Text(
                      '${_startDate == null ? 'ตั้งแต่วันนี้' : 'ตั้งแต่ ${Fmt.date(_startDate!)}'}'
                      ' • ${_endDate == null ? 'ไม่มีวันสิ้นสุด' : 'ถึง ${Fmt.date(_endDate!)}'}',
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickRangeDate(isStart: true),
                          child: const Text('เลือกวันเริ่ม'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickRangeDate(isStart: false),
                          child: const Text('เลือกวันสิ้นสุด'),
                        ),
                      ),
                      if (_startDate != null || _endDate != null)
                        IconButton(
                          tooltip: 'ล้างช่วงวันที่',
                          onPressed: () => setState(() {
                            _startDate = null;
                            _endDate = null;
                          }),
                          icon: const Icon(Icons.clear_rounded),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: ReminderListSection(
                reminders: _reminders,
                ownerTitle: _title.text,
                onChanged: (List<Reminder> value) => setState(() => _reminders = value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

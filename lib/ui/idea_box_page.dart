import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../utils/formatters.dart';
import 'idea_random_sheet.dart';
import 'widgets/common.dart';

/// กล่องไอเดีย — โน้ตข้างในจะไม่แสดงจนกว่าจะเปิดกล่อง
class IdeaBoxPage extends StatefulWidget {
  const IdeaBoxPage({super.key});

  @override
  State<IdeaBoxPage> createState() => _IdeaBoxPageState();
}

class _IdeaBoxPageState extends State<IdeaBoxPage> {
  bool _open = false;
  final Set<int> _selected = <int>{};
  final Random _random = Random();

  /// ใบที่เพิ่งสุ่มได้ ใช้กันไม่ให้สุ่มซ้ำใบเดิมติดกัน
  int? _lastRandomId;

  void _toggleBox() {
    setState(() {
      _open = !_open;
      if (!_open) _selected.clear();
    });
  }

  Future<void> _addIdea() async {
    final Idea? idea = await showIdeaEditor(context);
    if (idea == null || !mounted) return;
    showSnack(context, _open ? 'เพิ่มไอเดียแล้ว' : 'หย่อนไอเดียลงกล่องแล้ว');
  }

  /// สุ่มไอเดียขึ้นมาหนึ่งใบจากกองทั้งหมด แล้วเปิดดูแบบอ่านอย่างเดียว
  Future<void> _randomIdea() async {
    final AppState state = context.read<AppState>();
    final Idea? idea = randomIdeaFrom(
      state.ideas,
      excludeId: _lastRandomId,
      random: _random,
    );
    if (idea == null) {
      showSnack(context, 'กล่องยังว่างอยู่ ลองหย่อนไอเดียลงไปก่อน');
      return;
    }
    _lastRandomId = idea.id;
    final RandomIdeaAction? action = await showRandomIdeaSheet(context, idea);
    if (action != RandomIdeaAction.create || !mounted) return;
    await _createFromIdea(idea);
  }

  /// เอาไอเดียใบเดียวไปสร้างเป็นงานหรือโน้ต (ไอเดียจะออกจากกล่องไปเลย)
  Future<void> _createFromIdea(Idea idea) async {
    final AppState state = context.read<AppState>();
    final IdeaTarget? target = await showIdeaTargetSheet(context);
    if (target == null || !mounted) return;

    if (target == IdeaTarget.task) {
      final _ConvertOptions? options = await showModalBottomSheet<_ConvertOptions>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext context) => const _ConvertSheet(count: 1),
      );
      if (options == null) return;
      await state.convertIdeaToTask(
        idea,
        projectId: options.projectId,
        due: options.due,
        hasTime: options.hasTime,
      );
      if (mounted) showSnack(context, 'สร้างงานจากไอเดียนี้แล้ว');
      return;
    }

    if (state.projects.isEmpty) {
      showSnack(context, 'โน้ตต้องอยู่ในโฟลเดอร์งาน — สร้างโฟลเดอร์ก่อนนะ');
      return;
    }
    final int? projectId = await showNoteProjectPicker(context);
    if (projectId == null || !mounted) return;
    await state.convertIdeaToNote(idea, projectId: projectId);
    if (!mounted) return;
    final Project? project = state.projectById(projectId);
    showSnack(
      context,
      project == null
          ? 'สร้างโน้ตจากไอเดียนี้แล้ว'
          : 'สร้างโน้ตไว้ในโฟลเดอร์ "${project.name}" แล้ว',
    );
  }

  Future<void> _convertSelected() async {
    final AppState state = context.read<AppState>();
    final List<Idea> ideas = state.ideas
        .where((Idea i) => _selected.contains(i.id))
        .toList();
    if (ideas.isEmpty) return;

    final _ConvertOptions? options = await showModalBottomSheet<_ConvertOptions>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => _ConvertSheet(count: ideas.length),
    );
    if (options == null) return;

    for (final Idea idea in ideas) {
      await state.convertIdeaToTask(
        idea,
        projectId: options.projectId,
        due: options.due,
        hasTime: options.hasTime,
        keepIdea: false,
      );
    }
    if (!mounted) return;
    setState(() => _selected.clear());
    showSnack(context, 'ย้าย ${ideas.length} ไอเดียไปเป็นงานแล้ว');
  }

  Future<void> _deleteSelected() async {
    final AppState state = context.read<AppState>();
    final List<Idea> ideas = state.ideas
        .where((Idea i) => _selected.contains(i.id))
        .toList();
    final bool ok = await confirmDialog(
      context,
      title: 'ลบไอเดีย ${ideas.length} รายการ?',
      message: 'ไอเดียที่ลบแล้วจะกู้คืนไม่ได้',
      confirmLabel: 'ลบ',
      destructive: true,
    );
    if (!ok) return;
    for (final Idea idea in ideas) {
      await state.deleteIdea(idea);
    }
    if (mounted) setState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final List<Idea> ideas = state.ideas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('กล่องไอเดีย'),
        actions: <Widget>[
          IconButton(
            tooltip: 'สุ่มไอเดียหนึ่งใบ',
            icon: const Icon(Icons.casino_rounded),
            onPressed: _randomIdea,
          ),
          if (_open)
            TextButton.icon(
              onPressed: _toggleBox,
              icon: const Icon(Icons.inventory_2_rounded, size: 18),
              label: const Text('ปิดกล่อง'),
            ),
        ],
      ),
      // กล่องปิดอยู่จะใช้ปุ่ม "หย่อนไอเดีย" กลางจอแทน FAB
      floatingActionButton: _open
          ? FloatingActionButton.extended(
              onPressed: _addIdea,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('หย่อนไอเดีย'),
            )
          : null,
      bottomNavigationBar: _selected.isEmpty
          ? null
          : BottomAppBar(
              child: Row(
                children: <Widget>[
                  Text('เลือกไว้ ${_selected.length}'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('ลบ'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _convertSelected,
                    icon: const Icon(Icons.move_to_inbox_rounded, size: 18),
                    label: const Text('ย้ายไปเป็นงาน'),
                  ),
                ],
              ),
            ),
      body: _open
          ? _OpenBox(
              ideas: ideas,
              selected: _selected,
              onSelect: (Idea idea) => setState(() {
                if (_selected.contains(idea.id)) {
                  _selected.remove(idea.id);
                } else {
                  _selected.add(idea.id!);
                }
              }),
              onEdit: (Idea idea) => showIdeaEditor(context, idea: idea),
              onClose: _toggleBox,
            )
          : _ClosedBox(onOpen: _toggleBox, onDrop: _addIdea),
    );
  }
}

/// กล่องปิด — ตั้งใจไม่แสดงเนื้อหาหรือจำนวนไอเดียข้างใน
///
/// ปุ่ม "หย่อนไอเดีย" อยู่กลางจอและอยู่หน้ากล่อง ส่วนปุ่ม "เปิดกล่อง"
/// เป็นปุ่มเล็กกว่าอยู่ใต้ปุ่มหย่อนไอเดีย
class _ClosedBox extends StatelessWidget {
  const _ClosedBox({required this.onOpen, required this.onDrop});

  final VoidCallback onOpen;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                _BoxArt(onTap: onOpen),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: onDrop,
                      style: FilledButton.styleFrom(
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('หย่อนไอเดีย'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: onOpen,
                      style: FilledButton.styleFrom(
                        elevation: 2,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.lock_open_rounded, size: 15),
                      label: const Text('เปิดกล่อง'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              'กล่องปิดอยู่',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'ไอเดียข้างในจะไม่แสดงจนกว่าจะเปิดกล่อง\nหย่อนไอเดียใหม่ได้ตลอดโดยไม่ต้องเปิด',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// รูปกล่องที่ปิดฝาอยู่ (แตะที่กล่องก็เปิดได้เหมือนกัน)
class _BoxArt extends StatelessWidget {
  const _BoxArt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 230,
        height: 190,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 44,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 22,
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenBox extends StatelessWidget {
  const _OpenBox({
    required this.ideas,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onClose,
  });

  final List<Idea> ideas;
  final Set<int> selected;
  final ValueChanged<Idea> onSelect;
  final ValueChanged<Idea> onEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (ideas.isEmpty) {
      return EmptyState(
        icon: Icons.lightbulb_outline_rounded,
        title: 'กล่องว่างเปล่า',
        message: 'กด "หย่อนไอเดีย" เพื่อเขียนไอเดียเก็บไว้ก่อน',
        action: OutlinedButton.icon(
          onPressed: onClose,
          icon: const Icon(Icons.inventory_2_rounded),
          label: const Text('ปิดกล่อง'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
      children: <Widget>[
        SectionHeader(
          title: 'ไอเดียในกล่อง',
          subtitle: 'แตะเพื่อเลือก • แตะค้างเพื่อแก้ไข',
          icon: Icons.lightbulb_rounded,
          count: ideas.length,
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ideas
              .map(
                (Idea idea) => _IdeaNote(
                  idea: idea,
                  selected: selected.contains(idea.id),
                  onTap: () => onSelect(idea),
                  onLongPress: () => onEdit(idea),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _IdeaNote extends StatelessWidget {
  const _IdeaNote({
    required this.idea,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Idea idea;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = Color(idea.color);
    final double width = (MediaQuery.of(context).size.width - 38) / 2;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.transparent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.sticky_note_2_rounded, size: 14, color: color),
                const Spacer(),
                if (selected) Icon(Icons.check_circle_rounded, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              idea.content,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              Fmt.date(idea.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// เขียน/แก้ไขไอเดีย
Future<Idea?> showIdeaEditor(BuildContext context, {Idea? idea}) async {
  final TextEditingController controller = TextEditingController(
    text: idea?.content ?? '',
  );
  int color = idea?.color ?? kPalette[4];
  final AppState state = context.read<AppState>();

  final bool? saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  idea == null ? 'หย่อนไอเดียใหม่' : 'แก้ไขไอเดีย',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'คิดอะไรอยู่? เขียนทิ้งไว้ก่อนได้เลย',
                  ),
                ),
                const SizedBox(height: 14),
                ColorChoiceRow(
                  value: color,
                  onChanged: (int value) => setSheetState(() => color = value),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    if (idea != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () async {
                          await state.deleteIdea(idea);
                          if (context.mounted) Navigator.pop(context, false);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('ลบ'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('บันทึก'),
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

  if (saved != true) return null;
  final String content = controller.text.trim();
  if (content.isEmpty) return null;
  final Idea result = idea ?? Idea(content: content);
  result
    ..content = content
    ..color = color;
  await state.saveIdea(result);
  return result;
}

class _ConvertOptions {
  const _ConvertOptions({this.projectId, this.due, this.hasTime = false});

  final int? projectId;
  final DateTime? due;
  final bool hasTime;
}

/// ตัวเลือกตอนย้ายไอเดียไปเป็นงาน (เลือกโฟลเดอร์และกำหนดส่งได้)
class _ConvertSheet extends StatefulWidget {
  const _ConvertSheet({required this.count});

  final int count;

  @override
  State<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends State<_ConvertSheet> {
  int? _projectId;
  DateTime? _date;
  TimeOfDay? _time;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'ย้าย ${widget.count} ไอเดียไปเป็นงาน',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'เลือกโฟลเดอร์ปลายทางและกำหนดส่ง (ไม่บังคับ)',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _projectId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'โยนใส่โฟลเดอร์',
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
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: const Text('วันครบกำหนด'),
              subtitle: Text(_date == null ? 'ไม่ระบุ' : Fmt.dateFull(_date!)),
              trailing: Wrap(
                children: <Widget>[
                  if (_date != null)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() {
                        _date = null;
                        _time = null;
                      }),
                    ),
                  TextButton(
                    onPressed: () async {
                      final DateTime now = DateTime.now();
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _date ?? now,
                        firstDate: DateTime(now.year - 1),
                        lastDate: DateTime(now.year + 10),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: const Text('เลือก'),
                  ),
                ],
              ),
            ),
            if (_date != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('เวลา'),
                subtitle: Text(_time == null ? 'ทั้งวัน' : '${Fmt.timeOfDay(_time!)} น.'),
                trailing: TextButton(
                  onPressed: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (picked != null) setState(() => _time = picked);
                  },
                  child: const Text('เลือก'),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    DateTime? due;
                    if (_date != null) {
                      due = _time == null
                          ? DateTime(_date!.year, _date!.month, _date!.day)
                          : DateTime(
                              _date!.year,
                              _date!.month,
                              _date!.day,
                              _time!.hour,
                              _time!.minute,
                            );
                    }
                    Navigator.pop(
                      context,
                      _ConvertOptions(
                        projectId: _projectId,
                        due: due,
                        hasTime: _time != null,
                      ),
                    );
                  },
                  child: const Text('ย้ายไปเป็นงาน'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

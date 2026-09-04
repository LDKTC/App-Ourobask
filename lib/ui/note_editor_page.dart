import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../utils/formatters.dart';
import 'widgets/common.dart';

/// หน้าเขียน/แก้ไขโน้ตของโฟลเดอร์งาน
///
/// เปิดได้จากในโฟลเดอร์งานเท่านั้น จึงต้องรู้ [projectId] เสมอ
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.projectId, this.note});

  final int projectId;
  final Note? note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _title = TextEditingController(
    text: widget.note?.title ?? '',
  );
  late final TextEditingController _content = TextEditingController(
    text: widget.note?.content ?? '',
  );
  late int _color = widget.note?.color ?? kPalette[1];
  late bool _pinned = widget.note?.pinned ?? false;

  bool get _isNew => widget.note?.id == null;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String title = _title.text.trim();
    final String content = _content.text.trim();
    if (title.isEmpty && content.isEmpty) {
      showSnack(context, 'เขียนหัวข้อหรือเนื้อหาก่อนบันทึก');
      return;
    }
    final AppState state = context.read<AppState>();
    final Note note = widget.note ?? Note(projectId: widget.projectId);
    note
      ..title = title
      ..content = content
      ..color = _color
      ..pinned = _pinned;
    await state.saveNote(note);
    if (mounted) Navigator.pop(context, note);
  }

  Future<void> _delete() async {
    final Note? note = widget.note;
    if (note == null) return;
    final bool ok = await confirmDialog(
      context,
      title: 'ลบโน้ตนี้?',
      message: 'โน้ต "${note.displayTitle}" จะถูกลบถาวร',
      confirmLabel: 'ลบ',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<AppState>().deleteNote(note);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Project? project = context.watch<AppState>().projectById(widget.projectId);
    final Color color = Color(_color);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'โน้ตใหม่' : 'แก้ไขโน้ต'),
        actions: <Widget>[
          IconButton(
            tooltip: _pinned ? 'เลิกปักหมุด' : 'ปักหมุดไว้บนสุด',
            icon: Icon(
              _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: _pinned ? color : null,
            ),
            onPressed: () => setState(() => _pinned = !_pinned),
          ),
          if (!_isNew)
            IconButton(
              tooltip: 'ลบโน้ต',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
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
          if (project != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: <Widget>[
                  ProjectChip(project: project),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'โน้ตนี้อยู่ในโฟลเดอร์งานนี้เท่านั้น',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _title,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.titleLarge,
            decoration: const InputDecoration(
              hintText: 'หัวข้อโน้ต (ไม่บังคับ)',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 10,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'จดอะไรไว้ก็ได้ เช่น สรุปประชุม ลิงก์ หรือสิ่งที่ต้องจำ',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'สี',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ColorChoiceRow(
            value: _color,
            onChanged: (int value) => setState(() => _color = value),
          ),
          if (!_isNew) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              'สร้างเมื่อ ${Fmt.date(widget.note!.createdAt)}'
              ' • แก้ไขล่าสุด ${Fmt.date(widget.note!.updatedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

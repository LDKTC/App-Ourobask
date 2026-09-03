import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import 'common.dart';

/// รายการการเตือนของงาน/กิจวัตร พร้อมสวิตช์เปิด-ปิดแต่ละอัน
class ReminderListSection extends StatelessWidget {
  const ReminderListSection({
    super.key,
    required this.reminders,
    required this.onChanged,
    this.ownerTitle = '',
  });

  final List<Reminder> reminders;
  final ValueChanged<List<Reminder>> onChanged;
  final String ownerTitle;

  Future<void> _add(BuildContext context) async {
    final AppState state = context.read<AppState>();
    final Reminder? created = await showReminderSheet(
      context,
      defaultSoundUri: state.defaultSoundUri,
      defaultSoundName: state.defaultSoundName,
    );
    if (created == null) return;
    onChanged(<Reminder>[...reminders, created]);
  }

  Future<void> _edit(BuildContext context, int index) async {
    final Reminder? updated = await showReminderSheet(context, initial: reminders[index]);
    if (updated == null) return;
    final List<Reminder> next = List<Reminder>.from(reminders);
    next[index] = updated;
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.notifications_active_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'การแจ้งเตือน / ปลุก',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('เพิ่ม'),
            ),
          ],
        ),
        if (reminders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'ยังไม่มีการเตือน — เพิ่มได้ เช่น ก่อน 1 ชั่วโมง / 1 วัน / 1 สัปดาห์',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...List<Widget>.generate(reminders.length, (int index) {
            final Reminder reminder = reminders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: theme.colorScheme.surfaceContainerLow,
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 12, right: 4),
                leading: Icon(
                  reminder.isAlarm ? Icons.alarm_rounded : Icons.notifications_rounded,
                  color: reminder.enabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                title: Text(reminder.label),
                subtitle: Text(
                  reminder.isAlarm
                      ? 'ปลุก • ${reminder.soundName ?? 'เสียงปลุกของระบบ'}'
                      : 'แจ้งเตือนปกติ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _edit(context, index),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // เปิด/ปิดได้อิสระโดยไม่ต้องลบการเตือนออก
                    Switch(
                      value: reminder.enabled,
                      onChanged: (bool value) {
                        final List<Reminder> next = List<Reminder>.from(reminders);
                        next[index] = reminder..enabled = value;
                        onChanged(next);
                      },
                    ),
                    IconButton(
                      tooltip: 'ลบการเตือน',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        final List<Reminder> next = List<Reminder>.from(reminders)
                          ..removeAt(index);
                        onChanged(next);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// แผ่นตั้งค่าการเตือนหนึ่งรายการ
Future<Reminder?> showReminderSheet(
  BuildContext context, {
  Reminder? initial,
  String? defaultSoundUri,
  String? defaultSoundName,
}) {
  return showModalBottomSheet<Reminder>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ReminderSheet(
        initial: initial,
        defaultSoundUri: defaultSoundUri,
        defaultSoundName: defaultSoundName,
      ),
    ),
  );
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({this.initial, this.defaultSoundUri, this.defaultSoundName});

  final Reminder? initial;
  final String? defaultSoundUri;
  final String? defaultSoundName;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

/// ค่าพิเศษของ dropdown ที่หมายถึง "กำหนดเวลาเตือนเอง"
const int _customOffsetValue = -1;

class _ReminderSheetState extends State<_ReminderSheet> {
  late int _offset = widget.initial?.offsetMinutes ?? 60;
  late bool _isAlarm = widget.initial?.isAlarm ?? false;
  late bool _enabled = widget.initial?.enabled ?? true;
  late String? _soundUri = widget.initial?.soundUri ?? widget.defaultSoundUri;
  late String? _soundName = widget.initial?.soundName ?? widget.defaultSoundName;

  Future<void> _pickSystemSound() async {
    final PickedSound? picked = await SoundService.instance.pickSystemSound(
      currentUri: _soundUri,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _soundUri = picked.uri;
      _soundName = picked.name;
    });
  }

  Future<void> _pickFileSound() async {
    final PickedSound? picked = await SoundService.instance.pickAudioFile();
    if (picked == null || !mounted) return;
    setState(() {
      _soundUri = picked.uri;
      _soundName = picked.name;
    });
  }

  Future<void> _preview() async {
    final String? uri = _soundUri;
    if (uri == null) {
      showSnack(context, 'ยังไม่ได้เลือกเสียง — จะใช้เสียงปลุกเริ่มต้นของระบบ');
      return;
    }
    final bool ok = await SoundService.instance.preview(uri);
    if (!mounted) return;
    if (!ok) showSnack(context, 'เล่นเสียงนี้ไม่ได้บนเครื่องนี้');
  }

  /// ตัวเลือกใน dropdown — ค่าสำเร็จรูป บวกค่าที่กำหนดเองไว้แล้ว (ถ้ามี)
  List<int> get _offsetOptions {
    final List<int> options = List<int>.from(kReminderPresets);
    if (!options.contains(_offset)) options.add(_offset);
    options.sort();
    return options;
  }

  Future<void> _customOffset() async {
    final TextEditingController controller = TextEditingController(text: '$_offset');
    final int? minutes = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('กำหนดเวลาเตือนเอง'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'เตือนล่วงหน้ากี่นาที',
            helperText: 'เช่น 90 = ก่อน 1 ชั่วโมง 30 นาที',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
    if (minutes != null && minutes >= 0) setState(() => _offset = minutes);
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
                'ตั้งการเตือน',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'เลือกว่าจะเตือนล่วงหน้านานเท่าไรก่อนถึงกำหนด',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              // เลือกเวลาเตือนแบบ dropdown (เลือกจากรายการ / กำหนดเองเป็นนาที)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'เตือนล่วงหน้า',
                  prefixIcon: Icon(Icons.schedule_rounded),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _offset,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(14),
                    items: <DropdownMenuItem<int>>[
                      ..._offsetOptions.map(
                        (int minutes) => DropdownMenuItem<int>(
                          value: minutes,
                          child: Text(Reminder.offsetLabel(minutes)),
                        ),
                      ),
                      const DropdownMenuItem<int>(
                        value: _customOffsetValue,
                        child: Text('กำหนดเอง (ระบุนาที)...'),
                      ),
                    ],
                    onChanged: (int? value) {
                      if (value == null) return;
                      if (value == _customOffsetValue) {
                        _customOffset();
                        return;
                      }
                      setState(() => _offset = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isAlarm,
                onChanged: (bool value) => setState(() => _isAlarm = value),
                title: const Text('ปลุกด้วยเสียง (Alarm)'),
                subtitle: const Text('เสียงดังต่อเนื่องแบบนาฬิกาปลุก'),
                secondary: const Icon(Icons.alarm_rounded),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (bool value) => setState(() => _enabled = value),
                title: const Text('เปิดใช้งานการเตือนนี้'),
                subtitle: const Text('ปิดไว้ก่อนได้โดยไม่ต้องลบทิ้ง'),
                secondary: const Icon(Icons.toggle_on_rounded),
              ),
              if (_isAlarm) ...<Widget>[
                const Divider(height: 24),
                Text(
                  'เสียงปลุก',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _soundName ?? 'ยังไม่เลือก — ใช้เสียงปลุกเริ่มต้นของระบบ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: _pickSystemSound,
                      icon: const Icon(Icons.library_music_rounded, size: 18),
                      label: const Text('เสียงในระบบ'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickFileSound,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('ไฟล์เสียงในเครื่อง'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _preview,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('ลองฟัง'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => SoundService.instance.stopPreview(),
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      label: const Text('หยุด'),
                    ),
                    if (_soundUri != null)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _soundUri = null;
                          _soundName = null;
                        }),
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        label: const Text('ใช้เสียงระบบ'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  if (widget.initial != null)
                    TextButton.icon(
                      onPressed: () async {
                        final Reminder preview = Reminder(
                          ownerType: widget.initial!.ownerType,
                          ownerId: widget.initial!.ownerId,
                          offsetMinutes: _offset,
                          isAlarm: _isAlarm,
                          soundUri: _soundUri,
                          soundName: _soundName,
                        );
                        await NotificationService.instance.showPreview(
                          preview,
                          'ทดสอบการเตือน',
                        );
                      },
                      icon: const Icon(Icons.notifications_active_rounded, size: 18),
                      label: const Text('ทดสอบ'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final Reminder result =
                          widget.initial ??
                          Reminder(
                            ownerType: ReminderOwner.task,
                            ownerId: 0,
                            offsetMinutes: _offset,
                          );
                      result
                        ..offsetMinutes = _offset
                        ..isAlarm = _isAlarm
                        ..enabled = _enabled
                        ..soundUri = _soundUri
                        ..soundName = _soundName;
                      Navigator.pop(context, result);
                    },
                    child: const Text('บันทึก'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// แถวการเตือนบนหน้าแรก (สลับเปิด/ปิดได้ทันที)
class ReminderSwitchTile extends StatelessWidget {
  const ReminderSwitchTile({super.key, required this.view});

  final ReminderView view;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.read<AppState>();
    final Color accent = Color(view.color);
    final DateTime? fireAt = view.fireAt;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: view.reminder.enabled ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          view.reminder.isAlarm ? Icons.alarm_rounded : Icons.notifications_rounded,
          size: 20,
          color: view.reminder.enabled ? accent : theme.colorScheme.outline,
        ),
      ),
      title: Text(
        view.ownerTitle.isEmpty ? '(ไม่มีชื่อ)' : view.ownerTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: view.reminder.enabled ? null : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        <String>[
          view.reminder.label,
          if (view.isRoutine) 'กิจวัตร',
          if (fireAt != null)
            'เตือน ${Fmt.date(fireAt)} ${Fmt.time(fireAt)} น.'
          else
            'ยังไม่มีกำหนดเตือน',
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Switch(
        value: view.reminder.enabled,
        onChanged: (bool value) => state.setReminderEnabled(view.reminder, value),
      ),
    );
  }
}

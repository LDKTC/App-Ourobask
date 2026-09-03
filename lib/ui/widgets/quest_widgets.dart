import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import 'common.dart';

/// แถบความคืบหน้าของเงินที่เก็บได้ ใช้ซ้ำทั้งในรายการงานและบนการ์ดโฟลเดอร์
class MoneyProgressBar extends StatelessWidget {
  const MoneyProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 6,
  });

  final double progress;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: color.withValues(alpha: 0.18),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// บรรทัดยอดเงิน + แถบความคืบหน้าของเควสหนึ่งอัน (ใช้ในรายการงาน)
class QuestProgressLine extends StatelessWidget {
  const QuestProgressLine({super.key, required this.task, this.compact = false});

  final Task task;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final Color color = Color(task.color);
    final double saved = state.savedOf(task);
    final double progress = state.progressOf(task);
    final bool reached = state.reachedGoal(task);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                task.goalAmount > 0
                    ? '${Fmt.money(saved)} / ${Fmt.money(task.goalAmount)}'
                    : '${Fmt.money(saved)} (ยังไม่ได้ตั้งเป้า)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: reached ? color : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              reached ? 'ครบเป้าแล้ว' : '${(progress * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 3 : 5),
        MoneyProgressBar(progress: progress, color: color, height: compact ? 5 : 6),
      ],
    );
  }
}

/// การ์ดสรุปยอดเงินรวมของกลุ่มเควส (โฟลเดอร์งาน / ทั้งแอป)
class MoneySummaryCard extends StatelessWidget {
  const MoneySummaryCard({
    super.key,
    required this.summary,
    required this.color,
    this.title = 'ยอดเงินรวมในโฟลเดอร์นี้',
  });

  final MoneySummary summary;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.savings_rounded, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${(summary.progress * 100).round()}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              Fmt.money(summary.saved),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              summary.target > 0
                  ? 'จากเป้าหมาย ${Fmt.money(summary.target)}'
                        ' • เหลืออีก ${Fmt.money(summary.remaining)}'
                  : 'ยังไม่ได้ตั้งเป้าหมายของเควส',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            MoneyProgressBar(progress: summary.progress, color: color, height: 8),
            const SizedBox(height: 8),
            Text(
              'เควส ${summary.questCount} รายการ • ครบเป้าแล้ว ${summary.reachedCount}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ป้ายบอกว่างานนี้เป็นเควสเก็บเงิน
class QuestBadge extends StatelessWidget {
  const QuestBadge({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.savings_rounded, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            'เควสเก็บเงิน',
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// ช่องกรอกจำนวนเงิน (ใช้ทั้งตอนตั้งเป้าและตอนหยอดเงิน)
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    this.label = 'จำนวนเงิน',
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.payments_rounded),
        prefixText: '฿ ',
      ),
    );
  }
}

/// อ่านจำนวนเงินจากข้อความที่ผู้ใช้พิมพ์ (คืน null ถ้าไม่ใช่ตัวเลขที่ใช้ได้)
double? parseAmount(String raw) {
  final String text = raw.replaceAll(',', '').replaceAll('฿', '').trim();
  if (text.isEmpty) return null;
  final double? value = double.tryParse(text);
  if (value == null || value <= 0) return null;
  return value;
}

/// แผ่นหยอดเงินเข้าเควส — บันทึกทันทีเมื่อกดยืนยัน
Future<void> showQuestDepositSheet(
  BuildContext context,
  Task task, {
  double? suggested,
  int? routineId,
  String note = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _DepositSheet(
        task: task,
        suggested: suggested,
        routineId: routineId,
        note: note,
      ),
    ),
  );
}

class _DepositSheet extends StatefulWidget {
  const _DepositSheet({
    required this.task,
    this.suggested,
    this.routineId,
    this.note = '',
  });

  final Task task;
  final double? suggested;
  final int? routineId;
  final String note;

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.suggested == null ? '' : _plain(widget.suggested!),
  );
  late final TextEditingController _note = TextEditingController(text: widget.note);
  bool _withdraw = false;
  bool _saving = false;

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toString();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final double? amount = parseAmount(_amount.text);
    if (amount == null) {
      showSnack(context, 'ใส่จำนวนเงินให้ถูกต้องก่อน');
      return;
    }
    setState(() => _saving = true);
    final AppState state = context.read<AppState>();
    await state.addQuestEntry(
      widget.task,
      amount: _withdraw ? -amount : amount,
      note: _note.text.trim(),
      routineId: _withdraw ? null : widget.routineId,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final Color color = Color(widget.task.color);
    final double saved = state.savedOf(widget.task);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _withdraw ? 'ถอนเงินออกจากเควส' : 'หยอดเงินเข้าเควส',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.task.title} • เก็บแล้ว ${Fmt.money(saved)}'
                '${widget.task.goalAmount > 0 ? ' จาก ${Fmt.money(widget.task.goalAmount)}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              MoneyField(controller: _amount, autofocus: true),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final double quick in <double>[20, 50, 100, 500, 1000])
                    ActionChip(
                      label: Text(Fmt.money(quick)),
                      onPressed: () => setState(() => _amount.text = _plain(quick)),
                    ),
                  if (widget.suggested != null)
                    ActionChip(
                      avatar: Icon(Icons.repeat_rounded, size: 16, color: color),
                      label: Text('ตามแผน ${Fmt.money(widget.suggested!)}'),
                      onPressed: () =>
                          setState(() => _amount.text = _plain(widget.suggested!)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'บันทึกช่วยจำ (ไม่บังคับ)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _withdraw,
                title: const Text('ถอนเงินออกแทน'),
                subtitle: const Text('ใช้เมื่อดึงเงินที่เก็บไว้ออกไปใช้'),
                secondary: const Icon(Icons.undo_rounded),
                onChanged: (bool value) => setState(() => _withdraw = value),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: Icon(
                      _withdraw ? Icons.remove_rounded : Icons.add_rounded,
                      size: 18,
                    ),
                    label: Text(_withdraw ? 'ถอนออก' : 'หยอดเงิน'),
                    style: FilledButton.styleFrom(backgroundColor: color),
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

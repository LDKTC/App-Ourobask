import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../utils/date_time_utils.dart';
import '../utils/formatters.dart';
import 'routine_editor_page.dart';
import 'settings_page.dart';
import 'task_editor_page.dart';
import 'task_history_page.dart';
import 'widgets/common.dart';
import 'widgets/quest_widgets.dart';
import 'widgets/reminder_editor.dart';
import 'widgets/task_tile.dart';

/// หน้าแรก — เรียงงานตามความใกล้ของกำหนดส่ง และรวมการเตือนทั้งหมดไว้ด้านบน
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _remindersExpanded = false;

  Color _bucketColor(DeadlineBucket bucket, ColorScheme scheme) {
    switch (bucket) {
      case DeadlineBucket.overdue:
        return scheme.error;
      case DeadlineBucket.today:
        return const Color(0xFFE76F51);
      case DeadlineBucket.withinDay:
        return const Color(0xFFE9A319);
      case DeadlineBucket.withinThreeDays:
        return const Color(0xFF43A047);
      case DeadlineBucket.withinWeek:
        return const Color(0xFF2A9D8F);
      case DeadlineBucket.withinTwoWeeks:
        return const Color(0xFF3F72AF);
      case DeadlineBucket.withinMonth:
        return const Color(0xFF6750A4);
      case DeadlineBucket.beyondMonth:
        return const Color(0xFF8E7DBE);
      case DeadlineBucket.none:
        return scheme.outline;
    }
  }

  IconData _bucketIcon(DeadlineBucket bucket) {
    switch (bucket) {
      case DeadlineBucket.overdue:
        return Icons.warning_amber_rounded;
      case DeadlineBucket.today:
        return Icons.today_rounded;
      case DeadlineBucket.none:
        return Icons.all_inclusive_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  Future<void> _openTask(Task task) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => TaskEditorPage(task: task)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();
    final Map<DeadlineBucket, List<Task>> sections = state.homeSections();
    final List<ReminderView> reminderViews = state.reminderViews();
    final List<Routine> routines = state.routines;
    final bool empty =
        sections.values.every((List<Task> l) => l.isEmpty) && routines.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ourobask'),
        actions: <Widget>[
          IconButton(
            tooltip: 'ประวัติงานที่เสร็จแล้ว',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const TaskHistoryPage()),
            ),
          ),
          IconButton(
            tooltip: 'ตั้งค่า',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const TaskEditorPage()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('เพิ่มงาน'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: <Widget>[
          _SummaryCard(state: state),
          const SizedBox(height: 14),
          _ReminderPanel(
            views: reminderViews,
            expanded: _remindersExpanded,
            onToggle: () => setState(() => _remindersExpanded = !_remindersExpanded),
          ),
          if (empty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: 'ยังไม่มีงานในระบบ',
                message: 'กดปุ่ม "เพิ่มงาน" เพื่อเริ่มบันทึกสิ่งที่ต้องทำ',
              ),
            ),
          for (final DeadlineBucket bucket in kHomeBucketOrder) ...<Widget>[
            if (bucket == DeadlineBucket.none && routines.isNotEmpty) ...<Widget>[
              SectionHeader(
                title: 'กิจวัตรที่ทำซ้ำ',
                subtitle: 'ตารางประจำ เช่น ตารางเรียน (ไม่มีวันครบกำหนด)',
                icon: Icons.repeat_rounded,
                color: const Color(0xFF00897B),
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
            if ((sections[bucket] ?? <Task>[]).isNotEmpty) ...<Widget>[
              SectionHeader(
                title: bucket.title,
                subtitle: bucket.subtitle,
                icon: _bucketIcon(bucket),
                color: _bucketColor(bucket, theme.colorScheme),
                count: sections[bucket]!.length,
              ),
              ...sections[bucket]!.map(
                (Task task) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TaskTile(task: task, onTap: () => _openTask(task)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final MoneySummary money = state.moneyOverall;
    final Color onContainer = theme.colorScheme.onPrimaryContainer;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              Fmt.dateFull(now),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              state.todayTaskCount > 0
                  ? 'วันนี้มี ${state.todayTaskCount} งานที่ต้องส่ง'
                  : 'วันนี้ยังไม่มีงานครบกำหนด',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                _Stat(
                  label: 'ค้างอยู่',
                  value: '${state.openTaskCount}',
                  icon: Icons.playlist_add_check_rounded,
                ),
                const SizedBox(width: 18),
                _Stat(
                  label: 'โฟลเดอร์',
                  value: '${state.projects.length}',
                  icon: Icons.folder_rounded,
                ),
                const SizedBox(width: 18),
                _Stat(
                  label: 'กิจวัตร',
                  value: '${state.routines.length}',
                  icon: Icons.repeat_rounded,
                ),
                const SizedBox(width: 18),
                _Stat(
                  label: 'ไอเดีย',
                  value: '${state.ideas.length}',
                  icon: Icons.lightbulb_rounded,
                ),
              ],
            ),
            // ยอดเงินรวมของเควสทั้งหมด พร้อมแถบความคืบหน้า
            if (!money.isEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Icon(Icons.savings_rounded, size: 16, color: onContainer),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      money.target > 0
                          ? 'เก็บเงินแล้ว ${Fmt.money(money.saved)}'
                                ' จาก ${Fmt.money(money.target)}'
                          : 'เก็บเงินแล้ว ${Fmt.money(money.saved)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onContainer,
                      ),
                    ),
                  ),
                  Text(
                    '${(money.progress * 100).round()}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: onContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              MoneyProgressBar(progress: money.progress, color: onContainer, height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

/// กล่องรวมการแจ้งเตือน/ปลุกทั้งหมด พร้อมสวิตช์เปิด-ปิดรายตัว
class _ReminderPanel extends StatelessWidget {
  const _ReminderPanel({
    required this.views,
    required this.expanded,
    required this.onToggle,
  });

  final List<ReminderView> views;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int activeCount = views.where((ReminderView v) => v.reminder.enabled).length;

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: views.isEmpty ? null : onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.notifications_active_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'การแจ้งเตือน & ปลุก',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          views.isEmpty
                              ? 'ยังไม่ได้ตั้งการเตือน'
                              : 'เปิดอยู่ $activeCount จาก ${views.length} รายการ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (views.isNotEmpty)
                    Icon(
                      expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    ),
                ],
              ),
            ),
          ),
          if (expanded && views.isNotEmpty) ...<Widget>[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Column(
                children: views
                    .map((ReminderView view) => ReminderSwitchTile(view: view))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

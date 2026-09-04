import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../utils/formatters.dart';

/// สิ่งที่ผู้ใช้เลือกทำกับไอเดียที่สุ่มขึ้นมา
enum RandomIdeaAction {
  /// เก็บกลับเข้ากล่องตามเดิม
  keep,

  /// เอาไปสร้างเป็นงานหรือโน้ต
  create,
}

/// ปลายทางของไอเดียที่หยิบออกจากกล่อง
enum IdeaTarget { task, note }

/// เปิดไอเดียที่สุ่มได้แบบอ่านอย่างเดียว
Future<RandomIdeaAction?> showRandomIdeaSheet(BuildContext context, Idea idea) {
  return showModalBottomSheet<RandomIdeaAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => RandomIdeaSheet(
      idea: idea,
      onKeep: () => Navigator.pop(context, RandomIdeaAction.keep),
      onCreate: () => Navigator.pop(context, RandomIdeaAction.create),
    ),
  );
}

/// เนื้อหาของแผ่นสุ่มไอเดีย — อ่านได้อย่างเดียว แก้ไขในนี้ไม่ได้
///
/// ใต้ข้อความมีปุ่มสองปุ่มในแถวเดียวกัน กว้างเท่ากันพอดี (1:1)
class RandomIdeaSheet extends StatelessWidget {
  const RandomIdeaSheet({
    super.key,
    required this.idea,
    required this.onKeep,
    required this.onCreate,
  });

  final Idea idea;
  final VoidCallback onKeep;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = Color(idea.color);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.casino_rounded, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ไอเดียที่สุ่มได้',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'หยิบขึ้นมาดูเฉย ๆ แก้ไขในนี้ไม่ได้',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 120, maxHeight: 320),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: SelectableText(idea.content, style: theme.textTheme.bodyLarge),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'หย่อนลงกล่องเมื่อ ${Fmt.date(idea.createdAt)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onKeep,
                    icon: const Icon(Icons.inventory_2_rounded, size: 18),
                    label: const Text(
                      'เก็บกลับเข้ากล่อง',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: color),
                    onPressed: onCreate,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text(
                      'สร้างงาน / โน้ต',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ถามว่าจะเอาไอเดียนี้ไปสร้างเป็นงานหรือโน้ต
Future<IdeaTarget?> showIdeaTargetSheet(BuildContext context) {
  return showModalBottomSheet<IdeaTarget>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'สร้างเป็นอะไรดี?',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_task_rounded),
              title: const Text('งาน (Task)'),
              subtitle: const Text('ตั้งกำหนดส่งและการเตือนต่อได้'),
              onTap: () => Navigator.pop(context, IdeaTarget.task),
            ),
            ListTile(
              leading: const Icon(Icons.sticky_note_2_rounded),
              title: const Text('โน้ตในโฟลเดอร์งาน'),
              subtitle: const Text('เก็บไว้อ่านในโฟลเดอร์ ไม่มีกำหนดส่ง'),
              onTap: () => Navigator.pop(context, IdeaTarget.note),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

/// เลือกโฟลเดอร์งานปลายทางของโน้ต (โน้ตอยู่นอกโฟลเดอร์ไม่ได้)
Future<int?> showNoteProjectPicker(BuildContext context) {
  final List<Project> projects = context.read<AppState>().projects;
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'เก็บโน้ตไว้ในโฟลเดอร์ไหน?',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: projects
                    .map(
                      (Project project) => ListTile(
                        leading: Icon(project.icon, color: Color(project.color)),
                        title: Text(project.name, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.pop(context, project.id),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

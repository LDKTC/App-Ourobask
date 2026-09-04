import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../utils/formatters.dart';

/// การ์ดโน้ตหนึ่งใบ ใช้ทั้งในหน้าโฟลเดอร์งานและหน้ารวมโน้ตของโฟลเดอร์
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onTogglePin,
    this.previewLines = 3,
  });

  final Note note;
  final VoidCallback? onTap;
  final VoidCallback? onTogglePin;

  /// จำนวนบรรทัดของเนื้อหาย่อที่แสดงบนการ์ด
  final int previewLines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = Color(note.color);
    final String preview = note.preview;

    return Card(
      margin: EdgeInsets.zero,
      color: color.withValues(alpha: 0.10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Icon(Icons.sticky_note_2_rounded, size: 18, color: color),
                  ),
                  Expanded(
                    child: Text(
                      note.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onTogglePin != null)
                    IconButton(
                      tooltip: note.pinned ? 'เลิกปักหมุด' : 'ปักหมุดไว้บนสุด',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        size: 18,
                        color: note.pinned ? color : theme.colorScheme.outline,
                      ),
                      onPressed: onTogglePin,
                    )
                  else if (note.pinned)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Icons.push_pin_rounded, size: 16, color: color),
                    ),
                ],
              ),
              if (preview.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    preview,
                    maxLines: previewLines,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'แก้ไขล่าสุด ${Fmt.date(note.updatedAt)} • ${Fmt.time(note.updatedAt)} น.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

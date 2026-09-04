import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import 'note_editor_page.dart';
import 'widgets/common.dart';
import 'widgets/note_tile.dart';

/// โน้ตทั้งหมดของโฟลเดอร์งานหนึ่ง — เปิดได้จากในโฟลเดอร์เท่านั้น
class ProjectNotesPage extends StatefulWidget {
  const ProjectNotesPage({super.key, required this.projectId});

  final int projectId;

  @override
  State<ProjectNotesPage> createState() => _ProjectNotesPageState();
}

class _ProjectNotesPageState extends State<ProjectNotesPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor({Note? note}) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => NoteEditorPage(projectId: widget.projectId, note: note),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final Project? project = state.projectById(widget.projectId);
    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.folder_off_rounded, title: 'ไม่พบโฟลเดอร์นี้'),
      );
    }

    final Color color = Color(project.color);
    final List<Note> all = state.notesOfProject(widget.projectId);
    final List<Note> notes = all.where((Note n) => n.matches(_query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Icon(Icons.sticky_note_2_rounded, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text('โน้ตของ ${project.name}', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: color,
        foregroundColor: Colors.white,
        onPressed: _openEditor,
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('เขียนโน้ต'),
      ),
      body: Column(
        children: <Widget>[
          if (all.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'ค้นหาในโน้ตของโฟลเดอร์นี้',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (String value) => setState(() => _query = value),
              ),
            ),
          Expanded(
            child: notes.isEmpty
                ? EmptyState(
                    icon: all.isEmpty
                        ? Icons.sticky_note_2_outlined
                        : Icons.search_off_rounded,
                    title: all.isEmpty
                        ? 'ยังไม่มีโน้ตในโฟลเดอร์นี้'
                        : 'ไม่พบโน้ตที่ค้นหา',
                    message: all.isEmpty
                        ? 'โน้ตจะอยู่ในโฟลเดอร์งานนี้เท่านั้น ไม่ไปโผล่ที่หน้าแรกหรือปฏิทิน'
                        : 'ลองเปลี่ยนคำค้นหาดู',
                    action: all.isEmpty
                        ? FilledButton.icon(
                            onPressed: _openEditor,
                            icon: const Icon(Icons.note_add_rounded),
                            label: const Text('เขียนโน้ตแรก'),
                          )
                        : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final Note note = notes[index];
                      return NoteCard(
                        note: note,
                        previewLines: 4,
                        onTap: () => _openEditor(note: note),
                        onTogglePin: () => state.setNotePinned(note, !note.pinned),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

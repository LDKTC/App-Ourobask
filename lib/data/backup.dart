import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'repository.dart';

/// ผลลัพธ์ของการ import
class ImportResult {
  const ImportResult({
    required this.projects,
    required this.tasks,
    required this.reminders,
    required this.routines,
    required this.ideas,
  });

  final int projects;
  final int tasks;
  final int reminders;
  final int routines;
  final int ideas;

  String get summary =>
      'โปรเจกต์ $projects • งาน $tasks • การเตือน $reminders • กิจวัตร $routines • ไอเดีย $ideas';
}

/// ข้อมูลสำรองทั้งชุด (ใช้ทั้ง export และ import)
class BackupPayload {
  BackupPayload({
    required this.projects,
    required this.tasks,
    required this.reminders,
    required this.routines,
    required this.ideas,
  });

  final List<Project> projects;
  final List<Task> tasks;
  final List<Reminder> reminders;
  final List<Routine> routines;
  final List<Idea> ideas;

  ImportResult get counts => ImportResult(
    projects: projects.length,
    tasks: tasks.length,
    reminders: reminders.length,
    routines: routines.length,
    ideas: ideas.length,
  );
}

/// Export / Import ข้อมูลเป็นไฟล์ JSON
class BackupService {
  BackupService(this._repo);

  final Repository _repo;

  static const int formatVersion = 1;
  static const String magic = 'ourobask-backup';

  Future<Map<String, Object?>> buildBackup() async {
    final List<Project> projects = await _repo.projects();
    final List<Task> tasks = await _repo.tasks();
    final List<Reminder> reminders = await _repo.reminders();
    final List<Routine> routines = await _repo.routines();
    final List<Idea> ideas = await _repo.ideas();
    return <String, Object?>{
      'format': magic,
      'version': formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'projects': projects.map((Project e) => e.toMap()).toList(),
      'tasks': tasks.map((Task e) => e.toMap()).toList(),
      'reminders': reminders.map((Reminder e) => e.toMap()).toList(),
      'routines': routines.map((Routine e) => e.toMap()).toList(),
      'ideas': ideas.map((Idea e) => e.toMap()).toList(),
    };
  }

  String defaultFileName() {
    final DateTime now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'ourobask-${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}.json';
  }

  /// เขียนไฟล์สำรองลงเครื่อง (ผู้ใช้เลือกที่เก็บเอง) — คืน path ที่บันทึก
  Future<String?> exportToFile() async {
    final String json = const JsonEncoder.withIndent('  ').convert(await buildBackup());
    final Uint8List bytes = Uint8List.fromList(utf8.encode(json));
    return FilePicker.platform.saveFile(
      dialogTitle: 'บันทึกไฟล์สำรองข้อมูล',
      fileName: defaultFileName(),
      type: FileType.custom,
      allowedExtensions: <String>['json'],
      bytes: bytes,
    );
  }

  /// แชร์ไฟล์สำรองผ่านแอปอื่น (Drive, อีเมล, ฯลฯ)
  Future<void> shareBackup() async {
    final String json = const JsonEncoder.withIndent('  ').convert(await buildBackup());
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/${defaultFileName()}');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'application/json')],
        subject: 'Ourobask backup',
      ),
    );
  }

  /// อ่านไฟล์สำรองที่ผู้ใช้เลือก
  Future<BackupPayload?> pickBackup() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'เลือกไฟล์สำรองข้อมูล',
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final PlatformFile picked = result.files.first;
    final String content = picked.bytes != null
        ? utf8.decode(picked.bytes!)
        : await File(picked.path!).readAsString();
    return parse(content);
  }

  static BackupPayload parse(String content) {
    final Object? decoded = jsonDecode(content);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('ไฟล์สำรองไม่ถูกต้อง');
    }
    if (decoded['format'] != magic) {
      throw const FormatException('ไฟล์นี้ไม่ใช่ไฟล์สำรองของ Ourobask');
    }
    final int version = (decoded['version'] as num?)?.toInt() ?? 0;
    if (version > formatVersion) {
      throw const FormatException('ไฟล์สำรองมาจากแอปเวอร์ชันใหม่กว่า กรุณาอัปเดตแอปก่อน');
    }
    List<Map<String, Object?>> rows(String key) =>
        ((decoded[key] as List<Object?>?) ?? <Object?>[]).cast<Map<String, Object?>>();

    return BackupPayload(
      projects: rows('projects').map(Project.fromMap).toList(),
      tasks: rows('tasks').map(Task.fromMap).toList(),
      reminders: rows('reminders').map(Reminder.fromMap).toList(),
      routines: rows('routines').map(Routine.fromMap).toList(),
      ideas: rows('ideas').map(Idea.fromMap).toList(),
    );
  }
}

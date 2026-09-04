import 'package:flutter/material.dart';

import '../data/backup.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../services/notification_service.dart';
import '../utils/date_time_utils.dart';
import '../utils/formatters.dart';

/// การเตือนหนึ่งรายการพร้อมข้อมูลเจ้าของ สำหรับแสดงบนหน้าแรก
class ReminderView {
  const ReminderView({
    required this.reminder,
    required this.ownerTitle,
    required this.isRoutine,
    required this.fireAt,
    required this.color,
  });

  final Reminder reminder;
  final String ownerTitle;
  final bool isRoutine;
  final DateTime? fireAt;
  final int color;
}

/// ยอดเงินรวมของกลุ่มเควส (ใช้กับโฟลเดอร์งานและภาพรวมทั้งแอป)
class MoneySummary {
  const MoneySummary({
    this.saved = 0,
    this.target = 0,
    this.questCount = 0,
    this.reachedCount = 0,
  });

  /// เงินที่เก็บได้แล้ว
  final double saved;

  /// เป้าหมายรวมของทุกเควสในกลุ่ม
  final double target;
  final int questCount;

  /// จำนวนเควสที่เก็บครบเป้าแล้ว
  final int reachedCount;

  bool get isEmpty => questCount == 0;

  double get remaining {
    final double left = target - saved;
    return left > 0 ? left : 0;
  }

  /// 0.0 - 1.0 (ยังไม่ตั้งเป้า = 0)
  double get progress {
    if (target <= 0) return 0;
    final double value = saved / target;
    return value.clamp(0.0, 1.0);
  }
}

/// สถานะกลางของแอปทั้งหมด (โหลดจาก SQLite เก็บไว้ในหน่วยความจำ)
class AppState extends ChangeNotifier {
  AppState({Repository? repository, NotificationService? notifications})
    : _repo = repository ?? Repository(),
      _notifications = notifications ?? NotificationService.instance {
    _backup = BackupService(_repo);
  }

  final Repository _repo;
  final NotificationService _notifications;
  late final BackupService _backup;

  static const String keyThemeMode = 'theme_mode';
  static const String keyBuddhistYear = 'buddhist_year';
  static const String keyDefaultSoundUri = 'default_sound_uri';
  static const String keyDefaultSoundName = 'default_sound_name';
  static const String keyShowCompleted = 'show_completed';
  static const String keyUpdateAutoCheck = 'update_auto_check';
  static const String keyUpdateLastCheck = 'update_last_check';
  static const String keyUpdateSkippedVersion = 'update_skipped_version';

  List<Project> _projects = <Project>[];
  List<Task> _tasks = <Task>[];
  List<Reminder> _reminders = <Reminder>[];
  List<Routine> _routines = <Routine>[];
  List<Idea> _ideas = <Idea>[];
  List<QuestEntry> _questEntries = <QuestEntry>[];
  List<Note> _notes = <Note>[];
  Map<String, String> _settings = <String, String>{};
  bool _loading = true;

  List<Project> get projects => List<Project>.unmodifiable(_projects);
  List<Task> get tasks => List<Task>.unmodifiable(_tasks);
  List<Routine> get routines => List<Routine>.unmodifiable(_routines);
  List<Idea> get ideas => List<Idea>.unmodifiable(_ideas.where((Idea i) => !i.archived));
  List<Reminder> get reminders => List<Reminder>.unmodifiable(_reminders);
  List<QuestEntry> get questEntries => List<QuestEntry>.unmodifiable(_questEntries);

  /// โน้ตทั้งหมด — เข้าถึงได้ผ่านโฟลเดอร์งานเท่านั้น ดู [notesOfProject]
  List<Note> get notes => List<Note>.unmodifiable(_notes);
  bool get isLoading => _loading;

  ThemeMode get themeMode {
    switch (_settings[keyThemeMode]) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  bool get buddhistYear => (_settings[keyBuddhistYear] ?? '1') == '1';

  /// ตรวจหาเวอร์ชันใหม่ให้อัตโนมัติตอนเปิดแอป
  bool get updateAutoCheck => (_settings[keyUpdateAutoCheck] ?? '1') == '1';

  DateTime? get updateLastCheck {
    final int? ms = int.tryParse(_settings[keyUpdateLastCheck] ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// เวอร์ชันที่ผู้ใช้กด "ข้ามไปก่อน" ไว้
  String? get updateSkippedVersion => _settings[keyUpdateSkippedVersion];
  bool get showCompleted => (_settings[keyShowCompleted] ?? '0') == '1';
  String? get defaultSoundUri => _settings[keyDefaultSoundUri];
  String? get defaultSoundName => _settings[keyDefaultSoundName];

  // ------------------------------------------------------------------- load
  Future<void> load() async {
    _settings = await _repo.settings();
    Fmt.buddhistYear = buddhistYear;
    _projects = await _repo.projects();
    _tasks = await _repo.tasks();
    _reminders = await _repo.reminders();
    _routines = await _repo.routines();
    _ideas = await _repo.ideas();
    _questEntries = await _repo.questEntries();
    _notes = await _repo.notes();
    _loading = false;
    // งานที่ทำเสร็จเกินระยะเวลาที่เก็บไว้จะถูกล้างออกทุกครั้งที่เปิดแอป
    await _purgeExpiredCompleted(silent: true);
    notifyListeners();
    await _notifications.rescheduleAll(
      tasks: _tasks,
      routines: _routines,
      reminders: _reminders,
    );
  }

  Future<void> _reloadAll() async {
    _projects = await _repo.projects();
    _tasks = await _repo.tasks();
    _reminders = await _repo.reminders();
    _routines = await _repo.routines();
    _ideas = await _repo.ideas();
    _questEntries = await _repo.questEntries();
    _notes = await _repo.notes();
    notifyListeners();
  }

  // --------------------------------------------------------------- settings
  Future<void> setSetting(String key, String? value) async {
    await _repo.setSetting(key, value);
    if (value == null) {
      _settings.remove(key);
    } else {
      _settings[key] = value;
    }
    Fmt.buddhistYear = buddhistYear;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) => setSetting(keyThemeMode, switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  });

  Future<void> setBuddhistYear(bool value) =>
      setSetting(keyBuddhistYear, value ? '1' : '0');

  Future<void> setShowCompleted(bool value) =>
      setSetting(keyShowCompleted, value ? '1' : '0');

  Future<void> setUpdateAutoCheck(bool value) =>
      setSetting(keyUpdateAutoCheck, value ? '1' : '0');

  Future<void> markUpdateChecked() =>
      setSetting(keyUpdateLastCheck, DateTime.now().millisecondsSinceEpoch.toString());

  Future<void> skipUpdateVersion(String? tag) => setSetting(keyUpdateSkippedVersion, tag);

  Future<void> setDefaultSound(String? uri, String? name) async {
    await _repo.setSetting(keyDefaultSoundUri, uri);
    await _repo.setSetting(keyDefaultSoundName, name);
    if (uri == null) {
      _settings.remove(keyDefaultSoundUri);
      _settings.remove(keyDefaultSoundName);
    } else {
      _settings[keyDefaultSoundUri] = uri;
      if (name != null) _settings[keyDefaultSoundName] = name;
    }
    notifyListeners();
  }

  // --------------------------------------------------------------- projects
  Project? projectById(int? id) {
    if (id == null) return null;
    for (final Project project in _projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  List<Task> tasksOfProject(int projectId) =>
      _tasks.where((Task t) => t.projectId == projectId).toList();

  Future<void> saveProject(Project project) async {
    if (project.id == null) {
      project.sortOrder = _projects.length;
      await _repo.insertProject(project);
    } else {
      await _repo.updateProject(project);
    }
    _projects = await _repo.projects();
    notifyListeners();
  }

  Future<void> deleteProject(Project project, {bool deleteTasks = false}) async {
    final int? id = project.id;
    if (id == null) return;
    if (deleteTasks) {
      for (final Task task in tasksOfProject(id)) {
        await _cancelRemindersOf(ReminderOwner.task, task.id!);
      }
    }
    await _repo.deleteProject(id, deleteTasks: deleteTasks);
    await _reloadAll();
  }

  // ------------------------------------------------------------------ tasks
  Task? taskById(int? id) {
    if (id == null) return null;
    for (final Task task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// บันทึกงาน พร้อมชุดการเตือนที่ผู้ใช้ตั้งไว้
  Future<Task> saveTask(Task task, {List<Reminder>? reminders}) async {
    if (task.id == null) {
      await _repo.insertTask(task);
    } else {
      await _repo.updateTask(task);
    }
    if (reminders != null) {
      await _syncReminders(ReminderOwner.task, task.id!, reminders);
    }
    _tasks = await _repo.tasks();
    _reminders = await _repo.reminders();
    notifyListeners();
    await _rescheduleOwner(ReminderOwner.task, task.id!);
    return task;
  }

  Future<void> toggleTaskDone(Task task, bool done) async {
    task.done = done;
    task.completedAt = done ? DateTime.now() : null;
    await _repo.updateTask(task);
    _tasks = await _repo.tasks();
    notifyListeners();
    await _rescheduleOwner(ReminderOwner.task, task.id!);
  }

  Future<void> deleteTask(Task task) async {
    final int? id = task.id;
    if (id == null) return;
    await _cancelRemindersOf(ReminderOwner.task, id);
    await _repo.deleteTask(id);
    _tasks = await _repo.tasks();
    _reminders = await _repo.reminders();
    notifyListeners();
  }

  Future<void> moveTaskToProject(Task task, int? projectId) async {
    task.projectId = projectId;
    await _repo.updateTask(task);
    _tasks = await _repo.tasks();
    notifyListeners();
  }

  // ---------------------------------------------------------- ประวัติงาน
  /// งานที่ทำเสร็จแล้วทั้งหมด เรียงจากที่เพิ่งเสร็จล่าสุดไปหาเก่าสุด
  List<Task> completedHistory() {
    final List<Task> list = _tasks.where((Task t) => t.done).toList()
      ..sort((Task a, Task b) {
        final DateTime? ta = a.completedTime;
        final DateTime? tb = b.completedTime;
        if (ta == null && tb == null) return (b.id ?? 0).compareTo(a.id ?? 0);
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
    return list;
  }

  /// เอางานกลับมาทำต่อ — ล้างสถานะเสร็จและตั้งการเตือนใหม่ให้
  Future<void> restoreTask(Task task) => toggleTaskDone(task, false);

  /// ลบงานที่เลือกไว้ในประวัติทิ้งถาวร
  Future<void> deleteTasksPermanently(Iterable<Task> tasks) async {
    final List<Task> targets = tasks.where((Task t) => t.id != null).toList();
    if (targets.isEmpty) return;
    for (final Task task in targets) {
      await _cancelRemindersOf(ReminderOwner.task, task.id!);
      await _repo.deleteTask(task.id!);
    }
    _tasks = await _repo.tasks();
    _reminders = await _repo.reminders();
    _questEntries = await _repo.questEntries();
    notifyListeners();
  }

  /// ล้างประวัติงานที่ทำเสร็จแล้วทั้งหมดทันที
  Future<int> clearCompletedHistory() async {
    final List<Task> done = completedHistory();
    await deleteTasksPermanently(done);
    return done.length;
  }

  /// ล้างงานที่ทำเสร็จเกิน [kCompletedRetentionDays] วันออกจากประวัติ
  Future<int> purgeExpiredCompletedTasks({DateTime? now}) =>
      _purgeExpiredCompleted(now: now);

  Future<int> _purgeExpiredCompleted({DateTime? now, bool silent = false}) async {
    final List<Task> expired = _tasks.where((Task t) {
      final DateTime? at = t.completedTime;
      return at != null && isCompletionExpired(at, now: now);
    }).toList();
    if (expired.isEmpty) return 0;
    for (final Task task in expired) {
      if (task.id == null) continue;
      await _cancelRemindersOf(ReminderOwner.task, task.id!);
      await _repo.deleteTask(task.id!);
    }
    _tasks = await _repo.tasks();
    _reminders = await _repo.reminders();
    _questEntries = await _repo.questEntries();
    if (!silent) notifyListeners();
    return expired.length;
  }

  // ----------------------------------------------------------------- quests
  /// เควสเก็บเงินทั้งหมด (Task ประเภท [TaskKind.quest])
  List<Task> get quests => _tasks.where((Task t) => t.isQuest).toList();

  List<QuestEntry> questEntriesOf(int? taskId) {
    if (taskId == null) return <QuestEntry>[];
    return _questEntries.where((QuestEntry e) => e.taskId == taskId).toList()
      ..sort((QuestEntry a, QuestEntry b) => b.createdAt.compareTo(a.createdAt));
  }

  /// เงินที่หยอดเข้าเควสนี้แล้วทั้งหมด
  double savedOf(Task task) {
    final int? id = task.id;
    if (id == null) return 0;
    double total = 0;
    for (final QuestEntry entry in _questEntries) {
      if (entry.taskId == id) total += entry.amount;
    }
    return total;
  }

  /// ความคืบหน้าของเควส 0.0 - 1.0
  double progressOf(Task task) {
    if (task.goalAmount <= 0) return 0;
    return (savedOf(task) / task.goalAmount).clamp(0.0, 1.0);
  }

  double remainingOf(Task task) {
    final double left = task.goalAmount - savedOf(task);
    return left > 0 ? left : 0;
  }

  bool reachedGoal(Task task) => task.goalAmount > 0 && savedOf(task) >= task.goalAmount;

  /// ยอดเงินรวมของเควสในชุดที่ให้มา
  MoneySummary moneyOf(Iterable<Task> tasks) {
    double saved = 0;
    double target = 0;
    int count = 0;
    int reached = 0;
    for (final Task task in tasks) {
      if (!task.isQuest) continue;
      count++;
      final double current = savedOf(task);
      saved += current;
      target += task.goalAmount;
      if (task.goalAmount > 0 && current >= task.goalAmount) reached++;
    }
    return MoneySummary(
      saved: saved,
      target: target,
      questCount: count,
      reachedCount: reached,
    );
  }

  /// ยอดเงินรวมของเควสในโฟลเดอร์งานหนึ่ง (null = งานที่ไม่อยู่ในโฟลเดอร์)
  MoneySummary moneyOfProject(int? projectId) =>
      moneyOf(_tasks.where((Task t) => t.projectId == projectId));

  MoneySummary get moneyOverall => moneyOf(_tasks);

  /// แผนเก็บเงินประจำ (กิจวัตร) ที่ผูกกับเควสนี้
  List<Routine> questPlansOf(int? taskId) {
    if (taskId == null) return <Routine>[];
    return _routines.where((Routine r) => r.questTaskId == taskId).toList();
  }

  /// เงินที่แผนทั้งหมดของเควสนี้จะหยอดให้ต่อเดือนโดยประมาณ
  double monthlyPlanAmount(int? taskId) {
    double total = 0;
    for (final Routine routine in questPlansOf(taskId)) {
      if (!routine.active) continue;
      final double amount = routine.questAmount ?? 0;
      if (amount <= 0) continue;
      total += routine.isMonthly
          ? amount * routine.monthDays.length
          // สัปดาห์หนึ่งมี 52 รอบต่อปี จึงเฉลี่ยเป็นเดือนได้ประมาณนี้
          : amount * routine.days.length * 52 / 12;
    }
    return total;
  }

  /// จำนวนเดือนโดยประมาณที่จะเก็บครบเป้าตามแผน (null = ยังไม่มีแผนที่คำนวณได้)
  int? monthsToGoal(Task task) {
    final double perMonth = monthlyPlanAmount(task.id);
    if (perMonth <= 0 || task.goalAmount <= 0) return null;
    final double left = remainingOf(task);
    if (left <= 0) return 0;
    return (left / perMonth).ceil();
  }

  /// หยอดเงินเข้าเควส (จำนวนติดลบ = ถอนออก)
  Future<void> addQuestEntry(
    Task task, {
    required double amount,
    String note = '',
    int? routineId,
  }) async {
    final int? id = task.id;
    if (id == null || amount == 0) return;
    await _repo.insertQuestEntry(
      QuestEntry(taskId: id, amount: amount, note: note, routineId: routineId),
    );
    _questEntries = await _repo.questEntries();
    await _syncQuestCompletion(id);
    notifyListeners();
  }

  Future<void> deleteQuestEntry(QuestEntry entry) async {
    final int? id = entry.id;
    if (id == null) return;
    await _repo.deleteQuestEntry(id);
    _questEntries = await _repo.questEntries();
    await _syncQuestCompletion(entry.taskId);
    notifyListeners();
  }

  /// เควสที่เก็บครบเป้าแล้วให้ถือว่าเสร็จเอง (และย้อนกลับได้ถ้าลบเงินออก)
  Future<void> _syncQuestCompletion(int taskId) async {
    final Task? task = taskById(taskId);
    if (task == null || !task.isQuest || task.goalAmount <= 0) return;
    final bool reached = savedOf(task) >= task.goalAmount;
    if (reached == task.done) return;
    task.done = reached;
    task.completedAt = reached ? DateTime.now() : null;
    await _repo.updateTask(task);
    _tasks = await _repo.tasks();
    await _rescheduleOwner(ReminderOwner.task, taskId);
  }

  // --------------------------------------------------------------- routines
  Future<void> saveRoutine(Routine routine, {List<Reminder>? reminders}) async {
    if (routine.id == null) {
      await _repo.insertRoutine(routine);
    } else {
      await _repo.updateRoutine(routine);
    }
    if (reminders != null) {
      await _syncReminders(ReminderOwner.routine, routine.id!, reminders);
    }
    _routines = await _repo.routines();
    _reminders = await _repo.reminders();
    notifyListeners();
    await _rescheduleOwner(ReminderOwner.routine, routine.id!);
  }

  Future<void> setRoutineActive(Routine routine, bool active) async {
    routine.active = active;
    await _repo.updateRoutine(routine);
    _routines = await _repo.routines();
    notifyListeners();
    await _rescheduleOwner(ReminderOwner.routine, routine.id!);
  }

  Future<void> deleteRoutine(Routine routine) async {
    final int? id = routine.id;
    if (id == null) return;
    await _cancelRemindersOf(ReminderOwner.routine, id);
    await _repo.deleteRoutine(id);
    _routines = await _repo.routines();
    _reminders = await _repo.reminders();
    notifyListeners();
  }

  // ------------------------------------------------------------------ ideas
  Future<void> saveIdea(Idea idea) async {
    if (idea.id == null) {
      await _repo.insertIdea(idea);
    } else {
      await _repo.updateIdea(idea);
    }
    _ideas = await _repo.ideas();
    notifyListeners();
  }

  Future<void> deleteIdea(Idea idea) async {
    if (idea.id == null) return;
    await _repo.deleteIdea(idea.id!);
    _ideas = await _repo.ideas();
    notifyListeners();
  }

  /// ย้ายไอเดียออกจากกล่องไปเป็น Task (เลือกโฟลเดอร์/กำหนดส่งได้)
  Future<Task> convertIdeaToTask(
    Idea idea, {
    int? projectId,
    DateTime? due,
    bool hasTime = false,
    bool keepIdea = false,
  }) async {
    final List<String> lines = idea.content.trim().split('\n');
    final Task task = Task(
      title: lines.first.trim().isEmpty ? 'ไอเดียใหม่' : lines.first.trim(),
      notes: lines.length > 1 ? lines.sublist(1).join('\n').trim() : '',
      projectId: projectId,
      due: due,
      hasTime: hasTime,
      color: idea.color,
    );
    await _repo.insertTask(task);
    if (keepIdea) {
      idea.convertedTaskId = task.id;
      await _repo.updateIdea(idea);
    } else {
      await _repo.deleteIdea(idea.id!);
    }
    _tasks = await _repo.tasks();
    _ideas = await _repo.ideas();
    notifyListeners();
    return task;
  }

  // ------------------------------------------------------------------ notes
  /// โน้ตของโฟลเดอร์งานหนึ่ง — ปักหมุดขึ้นก่อน แล้วเรียงจากที่แก้ไขล่าสุด
  List<Note> notesOfProject(int? projectId) {
    if (projectId == null) return <Note>[];
    final List<Note> list = _notes.where((Note n) => n.projectId == projectId).toList()
      ..sort((Note a, Note b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return list;
  }

  int noteCountOfProject(int? projectId) {
    if (projectId == null) return 0;
    return _notes.where((Note n) => n.projectId == projectId).length;
  }

  /// บันทึกโน้ต — โน้ตที่ไม่มีทั้งหัวข้อและเนื้อหาจะถูกทิ้ง (คืน false)
  Future<bool> saveNote(Note note) async {
    if (note.isEmpty) {
      if (note.id != null) await deleteNote(note);
      return false;
    }
    if (note.id == null) {
      note.sortOrder = noteCountOfProject(note.projectId);
      await _repo.insertNote(note);
    } else {
      await _repo.updateNote(note);
    }
    _notes = await _repo.notes();
    notifyListeners();
    return true;
  }

  Future<void> setNotePinned(Note note, bool pinned) async {
    if (note.id == null || note.pinned == pinned) return;
    note.pinned = pinned;
    // ปักหมุดไม่ใช่การแก้เนื้อหา จึงไม่ขยับเวลาแก้ไขล่าสุดและลำดับของโน้ต
    await _repo.updateNote(note, touch: false);
    _notes = await _repo.notes();
    notifyListeners();
  }

  Future<void> deleteNote(Note note) async {
    final int? id = note.id;
    if (id == null) return;
    await _repo.deleteNote(id);
    _notes = await _repo.notes();
    notifyListeners();
  }

  // -------------------------------------------------------------- reminders
  List<Reminder> remindersOf(String ownerType, int? ownerId) {
    if (ownerId == null) return <Reminder>[];
    return _reminders
        .where((Reminder r) => r.ownerType == ownerType && r.ownerId == ownerId)
        .toList()
      ..sort((Reminder a, Reminder b) => b.offsetMinutes.compareTo(a.offsetMinutes));
  }

  bool taskHasEnabledReminder(Task task) => _reminders.any(
    (Reminder r) =>
        r.ownerType == ReminderOwner.task && r.ownerId == task.id && r.enabled,
  );

  /// เปิด/ปิดการเตือนทั้งหมดของงานหนึ่งชิ้นรวดเดียว (ใช้จากสวิตช์ในรายการงาน)
  Future<void> setTaskRemindersEnabled(Task task, bool enabled) async {
    final int? id = task.id;
    if (id == null) return;
    final List<Reminder> owned = remindersOf(ReminderOwner.task, id);
    if (owned.isEmpty) return;
    for (final Reminder reminder in owned) {
      if (reminder.enabled == enabled) continue;
      reminder.enabled = enabled;
      await _repo.updateReminder(reminder);
    }
    _reminders = await _repo.reminders();
    notifyListeners();
    await _rescheduleOwner(ReminderOwner.task, id);
  }

  /// เปิด/ปิดการเตือนได้อิสระโดยไม่ต้องลบทิ้ง
  Future<void> setReminderEnabled(Reminder reminder, bool enabled) async {
    reminder.enabled = enabled;
    await _repo.updateReminder(reminder);
    _reminders = await _repo.reminders();
    notifyListeners();
    await _rescheduleOwner(reminder.ownerType, reminder.ownerId);
  }

  Future<void> deleteReminder(Reminder reminder) async {
    if (reminder.id == null) return;
    await _notifications.cancelReminder(reminder);
    await _repo.deleteReminder(reminder.id!);
    _reminders = await _repo.reminders();
    notifyListeners();
  }

  Future<void> _syncReminders(
    String ownerType,
    int ownerId,
    List<Reminder> wanted,
  ) async {
    final List<Reminder> existing = remindersOf(ownerType, ownerId);
    final Set<int> keepIds = wanted.map((Reminder r) => r.id).whereType<int>().toSet();
    for (final Reminder old in existing) {
      if (!keepIds.contains(old.id)) {
        await _notifications.cancelReminder(old);
        await _repo.deleteReminder(old.id!);
      }
    }
    for (final Reminder reminder in wanted) {
      reminder.ownerType = ownerType;
      reminder.ownerId = ownerId;
      if (reminder.id == null) {
        await _repo.insertReminder(reminder);
      } else {
        await _repo.updateReminder(reminder);
      }
    }
  }

  Future<void> _cancelRemindersOf(String ownerType, int ownerId) async {
    for (final Reminder reminder in remindersOf(ownerType, ownerId)) {
      await _notifications.cancelReminder(reminder);
    }
  }

  Future<void> _rescheduleOwner(String ownerType, int ownerId) async {
    for (final Reminder reminder in remindersOf(ownerType, ownerId)) {
      if (ownerType == ReminderOwner.task) {
        final Task? task = taskById(ownerId);
        if (task != null) {
          await _notifications.scheduleTaskReminder(task, reminder);
        }
      } else {
        final Routine? routine = routineById(ownerId);
        if (routine != null) {
          await _notifications.scheduleRoutineReminder(routine, reminder);
        }
      }
    }
  }

  Routine? routineById(int? id) {
    if (id == null) return null;
    for (final Routine routine in _routines) {
      if (routine.id == id) return routine;
    }
    return null;
  }

  /// รายการการเตือนทั้งหมดพร้อมเวลาที่จะเตือนครั้งถัดไป (ใช้บนหน้าแรก)
  List<ReminderView> reminderViews() {
    final List<ReminderView> views = <ReminderView>[];
    for (final Reminder reminder in _reminders) {
      if (reminder.ownerType == ReminderOwner.task) {
        final Task? task = taskById(reminder.ownerId);
        if (task == null || task.done) continue;
        final DateTime? due = task.effectiveDue;
        views.add(
          ReminderView(
            reminder: reminder,
            ownerTitle: task.title,
            isRoutine: false,
            fireAt: due?.subtract(Duration(minutes: reminder.offsetMinutes)),
            color: task.color,
          ),
        );
      } else {
        final Routine? routine = routineById(reminder.ownerId);
        if (routine == null) continue;
        views.add(
          ReminderView(
            reminder: reminder,
            ownerTitle: routine.title,
            isRoutine: true,
            fireAt: _nextRoutineFire(routine, reminder.offsetMinutes),
            color: routine.color,
          ),
        );
      }
    }
    views.sort((ReminderView a, ReminderView b) {
      if (a.fireAt == null && b.fireAt == null) return 0;
      if (a.fireAt == null) return 1;
      if (b.fireAt == null) return -1;
      return a.fireAt!.compareTo(b.fireAt!);
    });
    return views;
  }

  DateTime? _nextRoutineFire(Routine routine, int offsetMinutes) {
    final bool monthly = routine.isMonthly;
    if ((monthly ? routine.monthDays : routine.days).isEmpty) return null;
    final DateTime now = DateTime.now();
    // กิจวัตรรายเดือนอาจเว้นห่างเกินสองสัปดาห์ จึงต้องมองไปข้างหน้าไกลกว่า
    final int horizon = monthly ? 62 : 14;
    for (int i = 0; i <= horizon; i++) {
      final DateTime day = startOfDay(now).add(Duration(days: i));
      if (!routine.occursOn(day)) continue;
      final DateTime fire = routine
          .startOn(day)
          .subtract(Duration(minutes: offsetMinutes));
      if (fire.isAfter(now)) return fire;
    }
    return null;
  }

  // ---------------------------------------------------------------- queries
  /// จัดกลุ่มงานตาม Section ของหน้าแรก
  Map<DeadlineBucket, List<Task>> homeSections() {
    final Map<DeadlineBucket, List<Task>> map = <DeadlineBucket, List<Task>>{};
    final DateTime now = DateTime.now();
    for (final Task task in _tasks) {
      if (task.done && !showCompleted) continue;
      map.putIfAbsent(bucketOf(task, now: now), () => <Task>[]).add(task);
    }
    for (final List<Task> list in map.values) {
      list.sort(_compareTasks);
    }
    return map;
  }

  int _compareTasks(Task a, Task b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final DateTime? da = a.due;
    final DateTime? db = b.due;
    if (da != null && db != null) {
      final int byDue = da.compareTo(db);
      if (byDue != 0) return byDue;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }
    if (a.priority != b.priority) return b.priority.compareTo(a.priority);
    return (a.id ?? 0).compareTo(b.id ?? 0);
  }

  List<Task> tasksOn(DateTime day) {
    final List<Task> list =
        _tasks
            .where(
              (Task t) =>
                  t.due != null && isSameDay(t.due!, day) && (!t.done || showCompleted),
            )
            .toList()
          ..sort(_compareTasks);
    return list;
  }

  List<Routine> routinesOn(DateTime day) {
    final List<Routine> list = _routines.where((Routine r) => r.occursOn(day)).toList()
      ..sort((Routine a, Routine b) => a.startMinutes.compareTo(b.startMinutes));
    return list;
  }

  int itemCountOn(DateTime day) => tasksOn(day).length + routinesOn(day).length;

  List<Task> upcomingTasks({int limit = 5}) {
    final DateTime now = DateTime.now();
    final List<Task> list =
        _tasks
            .where((Task t) => !t.done && t.due != null && !t.due!.isBefore(now))
            .toList()
          ..sort(_compareTasks);
    return list.take(limit).toList();
  }

  int get openTaskCount => _tasks.where((Task t) => !t.done).length;

  int get todayTaskCount {
    final DateTime now = DateTime.now();
    return _tasks
        .where((Task t) => !t.done && t.due != null && isSameDay(t.due!, now))
        .length;
  }

  // ------------------------------------------------------- export / import
  BackupService get backup => _backup;

  Future<String?> exportToFile() => _backup.exportToFile();

  Future<void> shareBackup() => _backup.shareBackup();

  Future<ImportResult?> importFromFile({required bool replace}) async {
    final BackupPayload? payload = await _backup.pickBackup();
    if (payload == null) return null;
    if (replace) {
      await _notifications.cancelAll();
      await _repo.replaceAll(
        projects: payload.projects,
        tasks: payload.tasks,
        reminders: payload.reminders,
        routines: payload.routines,
        ideas: payload.ideas,
        questEntries: payload.questEntries,
        notes: payload.notes,
      );
    } else {
      await _repo.mergeAll(
        projects: payload.projects,
        tasks: payload.tasks,
        reminders: payload.reminders,
        routines: payload.routines,
        ideas: payload.ideas,
        questEntries: payload.questEntries,
        notes: payload.notes,
      );
    }
    await _reloadAll();
    await _notifications.rescheduleAll(
      tasks: _tasks,
      routines: _routines,
      reminders: _reminders,
    );
    return payload.counts;
  }

  Future<void> clearAllData() async {
    await _notifications.cancelAll();
    await _repo.clearAll();
    await _reloadAll();
  }

  Future<String> databasePath() => AppDatabase.instance.path();
}

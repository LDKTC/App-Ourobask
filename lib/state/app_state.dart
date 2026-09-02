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

  List<Project> _projects = <Project>[];
  List<Task> _tasks = <Task>[];
  List<Reminder> _reminders = <Reminder>[];
  List<Routine> _routines = <Routine>[];
  List<Idea> _ideas = <Idea>[];
  Map<String, String> _settings = <String, String>{};
  bool _loading = true;

  List<Project> get projects => List<Project>.unmodifiable(_projects);
  List<Task> get tasks => List<Task>.unmodifiable(_tasks);
  List<Routine> get routines => List<Routine>.unmodifiable(_routines);
  List<Idea> get ideas => List<Idea>.unmodifiable(_ideas.where((Idea i) => !i.archived));
  List<Reminder> get reminders => List<Reminder>.unmodifiable(_reminders);
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
    _loading = false;
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
    if (routine.days.isEmpty) return null;
    final DateTime now = DateTime.now();
    for (int i = 0; i <= 14; i++) {
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
      );
    } else {
      await _repo.mergeAll(
        projects: payload.projects,
        tasks: payload.tasks,
        reminders: payload.reminders,
        routines: payload.routines,
        ideas: payload.ideas,
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

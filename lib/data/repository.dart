import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'models.dart';

/// ชั้นเข้าถึงข้อมูลทั้งหมด (SQLite)
class Repository {
  Repository([AppDatabase? db]) : _appDb = db ?? AppDatabase.instance;

  final AppDatabase _appDb;

  Future<Database> get _db => _appDb.database;

  // ---------------------------------------------------------------- projects
  Future<List<Project>> projects() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'projects',
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(Project.fromMap).toList();
  }

  Future<int> insertProject(Project project) async {
    final Database db = await _db;
    final Map<String, Object?> map = project.toMap()..remove('id');
    final int id = await db.insert('projects', map);
    project.id = id;
    return id;
  }

  Future<void> updateProject(Project project) async {
    final Database db = await _db;
    await db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[project.id],
    );
  }

  Future<void> deleteProject(int id, {bool deleteTasks = false}) async {
    final Database db = await _db;
    if (deleteTasks) {
      final List<Map<String, Object?>> rows = await db.query(
        'tasks',
        columns: <String>['id'],
        where: 'project_id = ?',
        whereArgs: <Object?>[id],
      );
      for (final Map<String, Object?> row in rows) {
        await deleteTask(row['id']! as int);
      }
    } else {
      await db.update(
        'tasks',
        <String, Object?>{'project_id': null},
        where: 'project_id = ?',
        whereArgs: <Object?>[id],
      );
    }
    await db.update(
      'routines',
      <String, Object?>{'project_id': null},
      where: 'project_id = ?',
      whereArgs: <Object?>[id],
    );
    await db.delete('projects', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // ------------------------------------------------------------------- tasks
  Future<List<Task>> tasks() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'tasks',
      orderBy: 'due_at IS NULL, due_at ASC, id ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<int> insertTask(Task task) async {
    final Database db = await _db;
    final Map<String, Object?> map = task.toMap()..remove('id');
    final int id = await db.insert('tasks', map);
    task.id = id;
    return id;
  }

  Future<void> updateTask(Task task) async {
    final Database db = await _db;
    task.updatedAt = DateTime.now();
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[task.id],
    );
  }

  Future<void> deleteTask(int id) async {
    final Database db = await _db;
    await db.delete(
      'reminders',
      where: 'owner_type = ? AND owner_id = ?',
      whereArgs: <Object?>[ReminderOwner.task, id],
    );
    await db.delete('tasks', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // --------------------------------------------------------------- reminders
  Future<List<Reminder>> reminders() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'reminders',
      orderBy: 'offset_minutes DESC',
    );
    return rows.map(Reminder.fromMap).toList();
  }

  Future<int> insertReminder(Reminder reminder) async {
    final Database db = await _db;
    final Map<String, Object?> map = reminder.toMap()..remove('id');
    final int id = await db.insert('reminders', map);
    reminder.id = id;
    return id;
  }

  Future<void> updateReminder(Reminder reminder) async {
    final Database db = await _db;
    await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[reminder.id],
    );
  }

  Future<void> deleteReminder(int id) async {
    final Database db = await _db;
    await db.delete('reminders', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // ---------------------------------------------------------------- routines
  Future<List<Routine>> routines() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'routines',
      orderBy: 'start_minutes ASC, id ASC',
    );
    return rows.map(Routine.fromMap).toList();
  }

  Future<int> insertRoutine(Routine routine) async {
    final Database db = await _db;
    final Map<String, Object?> map = routine.toMap()..remove('id');
    final int id = await db.insert('routines', map);
    routine.id = id;
    return id;
  }

  Future<void> updateRoutine(Routine routine) async {
    final Database db = await _db;
    await db.update(
      'routines',
      routine.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[routine.id],
    );
  }

  Future<void> deleteRoutine(int id) async {
    final Database db = await _db;
    await db.delete(
      'reminders',
      where: 'owner_type = ? AND owner_id = ?',
      whereArgs: <Object?>[ReminderOwner.routine, id],
    );
    await db.delete('routines', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // ------------------------------------------------------------------- ideas
  Future<List<Idea>> ideas() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query(
      'ideas',
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(Idea.fromMap).toList();
  }

  Future<int> insertIdea(Idea idea) async {
    final Database db = await _db;
    final Map<String, Object?> map = idea.toMap()..remove('id');
    final int id = await db.insert('ideas', map);
    idea.id = id;
    return id;
  }

  Future<void> updateIdea(Idea idea) async {
    final Database db = await _db;
    await db.update(
      'ideas',
      idea.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[idea.id],
    );
  }

  Future<void> deleteIdea(int id) async {
    final Database db = await _db;
    await db.delete('ideas', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // ---------------------------------------------------------------- settings
  Future<Map<String, String>> settings() async {
    final Database db = await _db;
    final List<Map<String, Object?>> rows = await db.query('settings');
    return <String, String>{
      for (final Map<String, Object?> row in rows)
        row['key']! as String: (row['value'] as String?) ?? '',
    };
  }

  Future<void> setSetting(String key, String? value) async {
    final Database db = await _db;
    if (value == null) {
      await db.delete('settings', where: 'key = ?', whereArgs: <Object?>[key]);
      return;
    }
    await db.insert('settings', <String, Object?>{
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ------------------------------------------------------------- maintenance
  Future<void> clearAll() async {
    final Database db = await _db;
    final Batch batch = db.batch();
    for (final String table in <String>[
      'reminders',
      'tasks',
      'routines',
      'ideas',
      'projects',
    ]) {
      batch.delete(table);
    }
    await batch.commit(noResult: true);
  }

  /// เขียนข้อมูลทั้งชุดทับของเดิม (ใช้ตอน import แบบแทนที่)
  Future<void> replaceAll({
    required List<Project> projects,
    required List<Task> tasks,
    required List<Reminder> reminders,
    required List<Routine> routines,
    required List<Idea> ideas,
  }) async {
    final Database db = await _db;
    await db.transaction((Transaction txn) async {
      for (final String table in <String>[
        'reminders',
        'tasks',
        'routines',
        'ideas',
        'projects',
      ]) {
        await txn.delete(table);
      }
      for (final Project item in projects) {
        await txn.insert('projects', item.toMap());
      }
      for (final Task item in tasks) {
        await txn.insert('tasks', item.toMap());
      }
      for (final Routine item in routines) {
        await txn.insert('routines', item.toMap());
      }
      for (final Idea item in ideas) {
        await txn.insert('ideas', item.toMap());
      }
      for (final Reminder item in reminders) {
        await txn.insert('reminders', item.toMap());
      }
    });
  }

  /// เพิ่มข้อมูลเข้าไปโดยไม่ลบของเดิม (ใช้ตอน import แบบรวม)
  Future<void> mergeAll({
    required List<Project> projects,
    required List<Task> tasks,
    required List<Reminder> reminders,
    required List<Routine> routines,
    required List<Idea> ideas,
  }) async {
    final Map<int, int> projectIdMap = <int, int>{};
    final Map<int, int> taskIdMap = <int, int>{};
    final Map<int, int> routineIdMap = <int, int>{};

    for (final Project project in projects) {
      final int? oldId = project.id;
      project.id = null;
      final int newId = await insertProject(project);
      if (oldId != null) projectIdMap[oldId] = newId;
    }
    for (final Task task in tasks) {
      final int? oldId = task.id;
      task.id = null;
      task.projectId = task.projectId == null ? null : projectIdMap[task.projectId];
      final int newId = await insertTask(task);
      if (oldId != null) taskIdMap[oldId] = newId;
    }
    for (final Routine routine in routines) {
      final int? oldId = routine.id;
      routine.id = null;
      routine.projectId = routine.projectId == null
          ? null
          : projectIdMap[routine.projectId];
      final int newId = await insertRoutine(routine);
      if (oldId != null) routineIdMap[oldId] = newId;
    }
    for (final Idea idea in ideas) {
      idea.id = null;
      idea.convertedTaskId = idea.convertedTaskId == null
          ? null
          : taskIdMap[idea.convertedTaskId];
      await insertIdea(idea);
    }
    for (final Reminder reminder in reminders) {
      final int? owner = reminder.ownerType == ReminderOwner.task
          ? taskIdMap[reminder.ownerId]
          : routineIdMap[reminder.ownerId];
      if (owner == null) continue;
      reminder.id = null;
      reminder.ownerId = owner;
      reminder.notificationId = Reminder(
        ownerType: reminder.ownerType,
        ownerId: owner,
        offsetMinutes: reminder.offsetMinutes,
      ).notificationId;
      await insertReminder(reminder);
    }
  }
}

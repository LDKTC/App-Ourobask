import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// ตัวจัดการฐานข้อมูล SQLite ของแอป
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String fileName = 'ourobask.db';
  static const int schemaVersion = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<String> path() async => p.join(await getDatabasesPath(), fileName);

  Future<Database> _open() async {
    return openDatabase(
      await path(),
      version: schemaVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        final Batch batch = db.batch();
        for (final String stmt in _createStatements) {
          batch.execute(stmt);
        }
        await batch.commit(noResult: true);
      },
    );
  }

  /// ปิดและเปิดใหม่ (ใช้หลัง import ที่เขียนทับไฟล์ฐานข้อมูล)
  Future<void> reopen() async {
    await _db?.close();
    _db = null;
    await database;
  }

  static const List<String> _createStatements = <String>[
    '''
    CREATE TABLE projects (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      color INTEGER NOT NULL,
      icon_index INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0,
      archived INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
      title TEXT NOT NULL,
      notes TEXT NOT NULL DEFAULT '',
      due_at INTEGER,
      has_time INTEGER NOT NULL DEFAULT 0,
      duration_minutes INTEGER,
      priority INTEGER NOT NULL DEFAULT 0,
      done INTEGER NOT NULL DEFAULT 0,
      completed_at INTEGER,
      color INTEGER NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX idx_tasks_due ON tasks(due_at)',
    'CREATE INDEX idx_tasks_project ON tasks(project_id)',
    '''
    CREATE TABLE reminders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      owner_type TEXT NOT NULL,
      owner_id INTEGER NOT NULL,
      offset_minutes INTEGER NOT NULL DEFAULT 0,
      enabled INTEGER NOT NULL DEFAULT 1,
      is_alarm INTEGER NOT NULL DEFAULT 0,
      sound_uri TEXT,
      sound_name TEXT,
      notification_id INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX idx_reminders_owner ON reminders(owner_type, owner_id)',
    '''
    CREATE TABLE routines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      notes TEXT NOT NULL DEFAULT '',
      project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
      days TEXT NOT NULL DEFAULT '',
      start_minutes INTEGER NOT NULL DEFAULT 480,
      end_minutes INTEGER NOT NULL DEFAULT 540,
      color INTEGER NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      start_date INTEGER,
      end_date INTEGER,
      created_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE ideas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      content TEXT NOT NULL,
      color INTEGER NOT NULL,
      converted_task_id INTEGER,
      archived INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT
    )
    ''',
  ];
}

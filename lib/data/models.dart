import 'package:flutter/material.dart';

/// ค่าคงที่สีที่เลือกได้สำหรับ Task / Project / Idea / Routine
const List<int> kPalette = <int>[
  0xFF6750A4, // ม่วง
  0xFF3F72AF, // น้ำเงิน
  0xFF2A9D8F, // เขียวน้ำทะเล
  0xFF43A047, // เขียว
  0xFFE9A319, // เหลืองส้ม
  0xFFE76F51, // ส้มแดง
  0xFFD1495B, // แดง
  0xFF8E7DBE, // ม่วงอ่อน
  0xFF546E7A, // เทาน้ำเงิน
  0xFF00897B, // เขียวเข้ม
];

int paletteAt(int index) => kPalette[index % kPalette.length];

/// ไอคอนที่ใช้กับ Work Project (เก็บเป็น index เพื่อให้ tree-shake icon ได้)
const List<IconData> kProjectIcons = <IconData>[
  Icons.folder_rounded,
  Icons.work_rounded,
  Icons.school_rounded,
  Icons.home_rounded,
  Icons.favorite_rounded,
  Icons.rocket_launch_rounded,
  Icons.code_rounded,
  Icons.brush_rounded,
  Icons.fitness_center_rounded,
  Icons.shopping_bag_rounded,
  Icons.attach_money_rounded,
  Icons.travel_explore_rounded,
];

IconData projectIconAt(int index) => kProjectIcons[index % kProjectIcons.length];

int? _msOf(DateTime? d) => d?.millisecondsSinceEpoch;
DateTime? _dateOf(Object? v) =>
    v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
bool _boolOf(Object? v) => (v as int? ?? 0) == 1;
double? _amountOf(Object? v) => (v as num?)?.toDouble();
List<int> _intsOf(Object? v) => (v as String? ?? '')
    .split(',')
    .where((String s) => s.trim().isNotEmpty)
    .map(int.parse)
    .toList();

/// โฟลเดอร์งาน (Work Project) ที่ครอบ Task อีกชั้นหนึ่ง
class Project {
  Project({
    this.id,
    required this.name,
    this.description = '',
    this.color = 0xFF6750A4,
    this.iconIndex = 0,
    this.sortOrder = 0,
    this.archived = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int? id;
  String name;
  String description;
  int color;
  int iconIndex;
  int sortOrder;
  bool archived;
  DateTime createdAt;

  IconData get icon => projectIconAt(iconIndex);

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'name': name,
    'description': description,
    'color': color,
    'icon_index': iconIndex,
    'sort_order': sortOrder,
    'archived': archived ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static Project fromMap(Map<String, Object?> m) => Project(
    id: m['id'] as int?,
    name: m['name'] as String? ?? '',
    description: m['description'] as String? ?? '',
    color: m['color'] as int? ?? 0xFF6750A4,
    iconIndex: m['icon_index'] as int? ?? 0,
    sortOrder: m['sort_order'] as int? ?? 0,
    archived: _boolOf(m['archived']),
    createdAt: _dateOf(m['created_at']) ?? DateTime.now(),
  );

  Project copy() => Project.fromMap(toMap());
}

/// ประเภทของงาน
///
/// * [TaskKind.normal] — งานทั่วไป ทำเสร็จแล้วติ๊กถูก
/// * [TaskKind.quest] — เควสเก็บเงิน ต้องระบุยอดเป้าหมาย แล้วทยอยหยอดเงินเข้าไป
enum TaskKind { normal, quest }

extension TaskKindDb on TaskKind {
  String get dbValue => this == TaskKind.quest ? 'quest' : 'normal';

  String get label => this == TaskKind.quest ? 'เควสเก็บเงิน' : 'งานทั่วไป';

  IconData get icon =>
      this == TaskKind.quest ? Icons.savings_rounded : Icons.check_circle_outline_rounded;
}

TaskKind taskKindFromDb(Object? value) =>
    (value as String?) == 'quest' ? TaskKind.quest : TaskKind.normal;

/// งานหนึ่งชิ้น (คล้ายโน้ต) — ระบุวัน/เวลาหรือไม่ก็ได้
///
/// * [due] == null  → ไม่มีกำหนด
/// * [due] != null และ [hasTime] == false → ทั้งวัน (all-day)
/// * [due] != null และ [hasTime] == true  → ระบุเวลาแน่นอน
class Task {
  Task({
    this.id,
    this.projectId,
    required this.title,
    this.notes = '',
    this.kind = TaskKind.normal,
    this.targetAmount,
    this.due,
    this.hasTime = false,
    this.durationMinutes,
    this.priority = 0,
    this.done = false,
    this.completedAt,
    this.color = 0xFF6750A4,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  int? id;
  int? projectId;
  String title;
  String notes;
  TaskKind kind;

  /// ยอดเงินเป้าหมายของเควส (ใช้เฉพาะ [TaskKind.quest])
  double? targetAmount;
  DateTime? due;
  bool hasTime;
  int? durationMinutes;
  int priority; // 0 = ปกติ, 1 = สำคัญ, 2 = ด่วนมาก
  bool done;
  DateTime? completedAt;
  int color;
  int sortOrder;
  DateTime createdAt;
  DateTime updatedAt;

  bool get isAllDay => due != null && !hasTime;

  bool get isQuest => kind == TaskKind.quest;

  /// เวลาที่ทำเสร็จ ใช้กับประวัติงาน
  /// (งานเก่าที่ไม่มี [completedAt] ใช้เวลาที่แก้ไขล่าสุดแทน)
  DateTime? get completedTime => done ? (completedAt ?? updatedAt) : null;

  /// ยอดเป้าหมายที่ใช้คำนวณจริง (0 = ยังไม่ได้ตั้งเป้า)
  double get goalAmount => targetAmount ?? 0;

  /// เวลาที่ใช้เตือนจริง ๆ — งานทั้งวันถือว่าครบกำหนด 09:00 ของวันนั้น
  DateTime? get effectiveDue {
    final DateTime? d = due;
    if (d == null) return null;
    return hasTime ? d : DateTime(d.year, d.month, d.day, 9);
  }

  DateTime? get endTime {
    final DateTime? d = due;
    if (d == null || !hasTime || durationMinutes == null) return null;
    return d.add(Duration(minutes: durationMinutes!));
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'project_id': projectId,
    'title': title,
    'notes': notes,
    'kind': kind.dbValue,
    'target_amount': targetAmount,
    'due_at': _msOf(due),
    'has_time': hasTime ? 1 : 0,
    'duration_minutes': durationMinutes,
    'priority': priority,
    'done': done ? 1 : 0,
    'completed_at': _msOf(completedAt),
    'color': color,
    'sort_order': sortOrder,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  static Task fromMap(Map<String, Object?> m) => Task(
    id: m['id'] as int?,
    projectId: m['project_id'] as int?,
    title: m['title'] as String? ?? '',
    notes: m['notes'] as String? ?? '',
    kind: taskKindFromDb(m['kind']),
    targetAmount: _amountOf(m['target_amount']),
    due: _dateOf(m['due_at']),
    hasTime: _boolOf(m['has_time']),
    durationMinutes: m['duration_minutes'] as int?,
    priority: m['priority'] as int? ?? 0,
    done: _boolOf(m['done']),
    completedAt: _dateOf(m['completed_at']),
    color: m['color'] as int? ?? 0xFF6750A4,
    sortOrder: m['sort_order'] as int? ?? 0,
    createdAt: _dateOf(m['created_at']) ?? DateTime.now(),
    updatedAt: _dateOf(m['updated_at']) ?? DateTime.now(),
  );

  Task copy() => Task.fromMap(toMap());
}

/// เจ้าของการเตือน — ใช้ตารางเดียวกันทั้ง Task และ Routine
class ReminderOwner {
  static const String task = 'task';
  static const String routine = 'routine';
}

/// การเตือนล่วงหน้าก่อนถึงกำหนด (เช่น 1 ชั่วโมง / 1 วัน / 1 สัปดาห์)
class Reminder {
  Reminder({
    this.id,
    required this.ownerType,
    required this.ownerId,
    required this.offsetMinutes,
    this.enabled = true,
    this.isAlarm = false,
    this.soundUri,
    this.soundName,
    int? notificationId,
  }) : notificationId = notificationId ?? _nextNotificationId();

  static int _seed = DateTime.now().millisecondsSinceEpoch % 100000;
  static int _nextNotificationId() {
    _seed = (_seed + 1) % 2000000;
    return _seed;
  }

  int? id;
  String ownerType;
  int ownerId;

  /// จำนวนนาทีก่อนถึงกำหนด (0 = ตรงเวลา)
  int offsetMinutes;

  /// เปิด/ปิดได้อิสระโดยไม่ต้องลบการเตือนทิ้ง
  bool enabled;

  /// true = ปลุกแบบ alarm (เสียงดังต่อเนื่อง + เต็มจอ)
  bool isAlarm;
  String? soundUri;
  String? soundName;
  int notificationId;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'owner_type': ownerType,
    'owner_id': ownerId,
    'offset_minutes': offsetMinutes,
    'enabled': enabled ? 1 : 0,
    'is_alarm': isAlarm ? 1 : 0,
    'sound_uri': soundUri,
    'sound_name': soundName,
    'notification_id': notificationId,
  };

  static Reminder fromMap(Map<String, Object?> m) => Reminder(
    id: m['id'] as int?,
    ownerType: m['owner_type'] as String? ?? ReminderOwner.task,
    ownerId: m['owner_id'] as int? ?? 0,
    offsetMinutes: m['offset_minutes'] as int? ?? 0,
    enabled: _boolOf(m['enabled']),
    isAlarm: _boolOf(m['is_alarm']),
    soundUri: m['sound_uri'] as String?,
    soundName: m['sound_name'] as String?,
    notificationId: m['notification_id'] as int?,
  );

  Reminder copy() => Reminder.fromMap(toMap());

  String get label => offsetLabel(offsetMinutes);

  static String offsetLabel(int minutes) {
    if (minutes <= 0) return 'ตรงเวลา';
    if (minutes % 10080 == 0) return 'ก่อน ${minutes ~/ 10080} สัปดาห์';
    if (minutes % 1440 == 0) return 'ก่อน ${minutes ~/ 1440} วัน';
    if (minutes % 60 == 0) return 'ก่อน ${minutes ~/ 60} ชั่วโมง';
    return 'ก่อน $minutes นาที';
  }
}

/// ตัวเลือกเวลาเตือนสำเร็จรูป
const List<int> kReminderPresets = <int>[
  0,
  5,
  10,
  15,
  30,
  60, // 1 ชั่วโมง
  180, // 3 ชั่วโมง
  1440, // 1 วัน
  2880, // 2 วัน
  10080, // 1 สัปดาห์
  20160, // 2 สัปดาห์
];

/// เงินที่หยอดเข้าเควสหนึ่งครั้ง
class QuestEntry {
  QuestEntry({
    this.id,
    required this.taskId,
    required this.amount,
    this.note = '',
    this.routineId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int? id;
  int taskId;

  /// บวก = หยอดเงินเข้า, ลบ = ถอนออก
  double amount;
  String note;

  /// ถ้าบันทึกมาจากแผนกิจวัตร จะอ้างอิงกิจวัตรนั้นไว้
  int? routineId;
  DateTime createdAt;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'task_id': taskId,
    'amount': amount,
    'note': note,
    'routine_id': routineId,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static QuestEntry fromMap(Map<String, Object?> m) => QuestEntry(
    id: m['id'] as int?,
    taskId: m['task_id'] as int? ?? 0,
    amount: _amountOf(m['amount']) ?? 0,
    note: m['note'] as String? ?? '',
    routineId: m['routine_id'] as int?,
    createdAt: _dateOf(m['created_at']) ?? DateTime.now(),
  );

  QuestEntry copy() => QuestEntry.fromMap(toMap());
}

/// รูปแบบการทำซ้ำของกิจวัตร
///
/// * [RoutineRepeat.weekly]  — ซ้ำตามวันในสัปดาห์ (จ-อา)
/// * [RoutineRepeat.monthly] — ซ้ำตามวันที่ของเดือน (เช่น ทุกวันที่ 1 และ 25)
enum RoutineRepeat { weekly, monthly }

extension RoutineRepeatDb on RoutineRepeat {
  String get dbValue => this == RoutineRepeat.monthly ? 'monthly' : 'weekly';

  String get label => this == RoutineRepeat.monthly ? 'ทุกเดือน' : 'ทุกสัปดาห์';
}

RoutineRepeat routineRepeatFromDb(Object? value) =>
    (value as String?) == 'monthly' ? RoutineRepeat.monthly : RoutineRepeat.weekly;

/// วันที่ของเดือนที่เลือกไว้ ปรับให้ไม่เกินจำนวนวันจริงของเดือนนั้น
/// (เช่น เลือกวันที่ 31 เดือนกุมภาพันธ์จะกลายเป็นวันสุดท้ายของเดือน)
int clampMonthDay(int day, int year, int month) {
  final int last = DateTime(year, month + 1, 0).day;
  return day < 1 ? 1 : (day > last ? last : day);
}

/// กิจวัตรที่ทำซ้ำ ๆ เช่น ตารางเรียน (วัน + ช่วงเวลาเริ่ม-จบ)
class Routine {
  Routine({
    this.id,
    required this.title,
    this.notes = '',
    this.projectId,
    List<int>? days,
    this.repeat = RoutineRepeat.weekly,
    List<int>? monthDays,
    this.questTaskId,
    this.questAmount,
    this.startMinutes = 8 * 60,
    this.endMinutes = 9 * 60,
    this.color = 0xFF2A9D8F,
    this.active = true,
    this.startDate,
    this.endDate,
    DateTime? createdAt,
  }) : days = days ?? <int>[],
       monthDays = monthDays ?? <int>[],
       createdAt = createdAt ?? DateTime.now();

  int? id;
  String title;
  String notes;
  int? projectId;

  /// 1 = จันทร์ ... 7 = อาทิตย์ (ตรงกับ DateTime.weekday) — ใช้กับ [RoutineRepeat.weekly]
  List<int> days;

  RoutineRepeat repeat;

  /// วันที่ของเดือน 1-31 — ใช้กับ [RoutineRepeat.monthly]
  List<int> monthDays;

  /// เควสเก็บเงินที่กิจวัตรนี้เป็นแผนหยอดเงินให้
  int? questTaskId;

  /// ยอดเงินที่ตั้งใจหยอดในแต่ละรอบของแผน
  double? questAmount;
  int startMinutes;
  int endMinutes;
  int color;
  bool active;
  DateTime? startDate;
  DateTime? endDate;
  DateTime createdAt;

  bool get isQuestPlan => questTaskId != null;

  bool get isMonthly => repeat == RoutineRepeat.monthly;

  /// วันที่ในรอบนี้ถูกเลือกไว้หรือไม่ (ยังไม่รวมช่วงวันที่เริ่ม/สิ้นสุด)
  bool matchesCycle(DateTime day) {
    if (isMonthly) {
      if (monthDays.isEmpty) return false;
      return monthDays.any(
        (int wanted) => clampMonthDay(wanted, day.year, day.month) == day.day,
      );
    }
    return days.contains(day.weekday);
  }

  bool occursOn(DateTime day) {
    if (!active) return false;
    final DateTime d = DateTime(day.year, day.month, day.day);
    if (!matchesCycle(d)) return false;
    final DateTime? s = startDate;
    final DateTime? e = endDate;
    if (s != null && d.isBefore(DateTime(s.year, s.month, s.day))) return false;
    if (e != null && d.isAfter(DateTime(e.year, e.month, e.day))) return false;
    return true;
  }

  DateTime startOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, startMinutes ~/ 60, startMinutes % 60);

  DateTime endOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, endMinutes ~/ 60, endMinutes % 60);

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'title': title,
    'notes': notes,
    'project_id': projectId,
    'days': days.join(','),
    'repeat_mode': repeat.dbValue,
    'month_days': monthDays.join(','),
    'quest_task_id': questTaskId,
    'quest_amount': questAmount,
    'start_minutes': startMinutes,
    'end_minutes': endMinutes,
    'color': color,
    'active': active ? 1 : 0,
    'start_date': _msOf(startDate),
    'end_date': _msOf(endDate),
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static Routine fromMap(Map<String, Object?> m) => Routine(
    id: m['id'] as int?,
    title: m['title'] as String? ?? '',
    notes: m['notes'] as String? ?? '',
    projectId: m['project_id'] as int?,
    days: _intsOf(m['days']),
    repeat: routineRepeatFromDb(m['repeat_mode']),
    monthDays: _intsOf(m['month_days']),
    questTaskId: m['quest_task_id'] as int?,
    questAmount: _amountOf(m['quest_amount']),
    startMinutes: m['start_minutes'] as int? ?? 8 * 60,
    endMinutes: m['end_minutes'] as int? ?? 9 * 60,
    color: m['color'] as int? ?? 0xFF2A9D8F,
    active: _boolOf(m['active']),
    startDate: _dateOf(m['start_date']),
    endDate: _dateOf(m['end_date']),
    createdAt: _dateOf(m['created_at']) ?? DateTime.now(),
  );

  Routine copy() => Routine.fromMap(toMap());
}

/// ไอเดียที่หย่อนไว้ในกล่อง — จะไม่แสดงจนกว่าจะเปิดกล่อง
class Idea {
  Idea({
    this.id,
    required this.content,
    this.color = 0xFFE9A319,
    this.convertedTaskId,
    this.archived = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int? id;
  String content;
  int color;
  int? convertedTaskId;
  bool archived;
  DateTime createdAt;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'content': content,
    'color': color,
    'converted_task_id': convertedTaskId,
    'archived': archived ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static Idea fromMap(Map<String, Object?> m) => Idea(
    id: m['id'] as int?,
    content: m['content'] as String? ?? '',
    color: m['color'] as int? ?? 0xFFE9A319,
    convertedTaskId: m['converted_task_id'] as int?,
    archived: _boolOf(m['archived']),
    createdAt: _dateOf(m['created_at']) ?? DateTime.now(),
  );

  Idea copy() => Idea.fromMap(toMap());
}

/// โน้ตของโฟลเดอร์งาน — สร้างและอ่านได้เฉพาะภายใน Work Project เท่านั้น
///
/// ต่างจาก [Task] ตรงที่ไม่มีกำหนดส่ง ไม่มีการเตือน และไม่โผล่ในหน้าแรก/ปฏิทิน
/// จึงใช้เก็บข้อมูลประกอบของโปรเจกต์ เช่น สรุปประชุม ลิงก์ หรือรายการที่ต้องจำ
class Note {
  Note({
    this.id,
    required this.projectId,
    this.title = '',
    this.content = '',
    this.color = 0xFF3F72AF,
    this.pinned = false,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  int? id;

  /// โฟลเดอร์งานที่โน้ตนี้สังกัด — โน้ตอยู่นอกโฟลเดอร์ไม่ได้
  int projectId;
  String title;
  String content;
  int color;

  /// ปักหมุดให้ลอยอยู่บนสุดของโฟลเดอร์
  bool pinned;
  int sortOrder;
  DateTime createdAt;
  DateTime updatedAt;

  bool get isEmpty => title.trim().isEmpty && content.trim().isEmpty;

  /// หัวข้อที่ใช้แสดงจริง — ถ้าไม่ได้ตั้งชื่อจะยืมบรรทัดแรกของเนื้อหามาใช้
  String get displayTitle {
    final String name = title.trim();
    if (name.isNotEmpty) return name;
    final String first = content.trim().split('\n').first.trim();
    return first.isEmpty ? 'โน้ตไม่มีชื่อ' : first;
  }

  /// เนื้อหาย่อสำหรับการ์ด (ข้ามบรรทัดแรกถ้าถูกยืมไปเป็นหัวข้อแล้ว)
  String get preview {
    final List<String> lines = content.trim().split('\n');
    final Iterable<String> body = title.trim().isEmpty ? lines.skip(1) : lines;
    return body.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// ค้นหาจากทั้งหัวข้อและเนื้อหา
  bool matches(String query) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return title.toLowerCase().contains(needle) || content.toLowerCase().contains(needle);
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'project_id': projectId,
    'title': title,
    'content': content,
    'color': color,
    'pinned': pinned ? 1 : 0,
    'sort_order': sortOrder,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  static Note fromMap(Map<String, Object?> m) => Note(
    id: m['id'] as int?,
    projectId: m['project_id'] as int? ?? 0,
    title: m['title'] as String? ?? '',
    content: m['content'] as String? ?? '',
    color: m['color'] as int? ?? 0xFF3F72AF,
    pinned: _boolOf(m['pinned']),
    sortOrder: m['sort_order'] as int? ?? 0,
    createdAt: _dateOf(m['created_at']) ?? DateTime.now(),
    updatedAt: _dateOf(m['updated_at']) ?? DateTime.now(),
  );

  Note copy() => Note.fromMap(toMap());
}

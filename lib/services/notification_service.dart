import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';

/// จัดการการแจ้งเตือนและเสียงปลุกทั้งหมดของแอป
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String reminderChannelId = 'ourobask_reminders';
  static const String alarmChannelBaseId = 'ourobask_alarm';

  bool _ready = false;
  final Set<String> _createdChannels = <String>{};

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready || !isSupported) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // ถ้าหา timezone ของเครื่องไม่เจอ ใช้ค่า default ของ package ไปก่อน
    }

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const DarwinInitializationSettings darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: darwin));

    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        reminderChannelId,
        'การแจ้งเตือนงาน',
        description: 'แจ้งเตือนก่อนถึงกำหนดงานที่ตั้งไว้',
        importance: Importance.high,
      ),
    );
    _ready = true;
  }

  /// ขอสิทธิ์แจ้งเตือน + ตั้งเวลาแบบแม่นยำ
  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    await init();
    bool granted = true;
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? false;
      await android.requestExactAlarmsPermission();
    }
    final IOSFlutterLocalNotificationsPlugin? ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return granted;
  }

  /// ปลุกแต่ละเสียงต้องมี channel ของตัวเอง เพราะ Android ผูกเสียงไว้กับ channel
  String _channelIdFor(Reminder reminder) {
    if (!reminder.isAlarm) return reminderChannelId;
    final String uri = reminder.soundUri ?? 'default';
    return '${alarmChannelBaseId}_${uri.hashCode.toUnsigned(32)}';
  }

  Future<void> _ensureAlarmChannel(Reminder reminder) async {
    final String id = _channelIdFor(reminder);
    if (id == reminderChannelId || _createdChannels.contains(id)) return;
    final String? uri = reminder.soundUri;
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        id,
        'ปลุก ${reminder.soundName ?? 'เสียงระบบ'}',
        description: 'เสียงปลุกสำหรับงานที่ตั้งเวลาไว้',
        importance: Importance.max,
        playSound: true,
        sound: uri == null ? null : UriAndroidNotificationSound(uri),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
      ),
    );
    _createdChannels.add(id);
  }

  Future<NotificationDetails> _detailsFor(Reminder reminder) async {
    await _ensureAlarmChannel(reminder);
    final String channelId = _channelIdFor(reminder);
    final String? uri = reminder.soundUri;
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      channelId,
      reminder.isAlarm ? 'ปลุกงาน' : 'การแจ้งเตือนงาน',
      channelDescription: 'แจ้งเตือนก่อนถึงกำหนดงานที่ตั้งไว้',
      importance: reminder.isAlarm ? Importance.max : Importance.high,
      priority: reminder.isAlarm ? Priority.max : Priority.high,
      category: reminder.isAlarm
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      audioAttributesUsage: reminder.isAlarm
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      sound: reminder.isAlarm && uri != null ? UriAndroidNotificationSound(uri) : null,
      fullScreenIntent: reminder.isAlarm,
      playSound: true,
      enableVibration: true,
      ticker: 'Ourobask',
    );
    final DarwinNotificationDetails darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: reminder.isAlarm
          ? InterruptionLevel.critical
          : InterruptionLevel.active,
    );
    return NotificationDetails(android: android, iOS: darwin);
  }

  int _routineNotificationId(Reminder reminder, int weekday) =>
      reminder.notificationId * 10 + weekday;

  /// ตั้งการเตือนของงานหนึ่งชิ้น
  Future<void> scheduleTaskReminder(Task task, Reminder reminder) async {
    if (!isSupported) return;
    await init();
    await cancelReminder(reminder);
    final DateTime? due = task.effectiveDue;
    if (!reminder.enabled || task.done || due == null) return;

    final DateTime fireAt = due.subtract(Duration(minutes: reminder.offsetMinutes));
    if (fireAt.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      reminder.notificationId,
      task.title.isEmpty ? 'งานที่ตั้งเตือนไว้' : task.title,
      _bodyForTask(task, reminder),
      tz.TZDateTime.from(fireAt, tz.local),
      await _detailsFor(reminder),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'task:${task.id}',
    );
  }

  String _bodyForTask(Task task, Reminder reminder) {
    final DateTime? due = task.due;
    if (due == null) return reminder.label;
    final String time = task.hasTime
        ? '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')} น.'
        : 'ทั้งวัน';
    return '${reminder.label} • กำหนด ${due.day}/${due.month}/${due.year} $time';
  }

  /// ตั้งการเตือนของกิจวัตร (ซ้ำทุกสัปดาห์ตามวันที่เลือก)
  Future<void> scheduleRoutineReminder(Routine routine, Reminder reminder) async {
    if (!isSupported) return;
    await init();
    await cancelReminder(reminder);
    if (!reminder.enabled || !routine.active || routine.days.isEmpty) return;

    final NotificationDetails details = await _detailsFor(reminder);
    for (final int weekday in routine.days) {
      final DateTime next = _nextOccurrence(
        weekday,
        routine.startMinutes,
        reminder.offsetMinutes,
      );
      await _plugin.zonedSchedule(
        _routineNotificationId(reminder, weekday),
        routine.title.isEmpty ? 'กิจวัตร' : routine.title,
        '${reminder.label} • ${_hhmm(routine.startMinutes)} - ${_hhmm(routine.endMinutes)}',
        tz.TZDateTime.from(next, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'routine:${routine.id}',
      );
    }
  }

  static String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  DateTime _nextOccurrence(int weekday, int startMinutes, int offsetMinutes) {
    final DateTime now = DateTime.now();
    DateTime candidate = DateTime(
      now.year,
      now.month,
      now.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    ).subtract(Duration(minutes: offsetMinutes));
    // เดินไปข้างหน้าจนกว่าจะตรงวันที่ต้องการและอยู่ในอนาคต
    int guard = 0;
    while ((candidate.weekday != weekday || !candidate.isAfter(now)) && guard < 14) {
      candidate = candidate.add(const Duration(days: 1));
      guard++;
    }
    return candidate;
  }

  Future<void> cancelReminder(Reminder reminder) async {
    if (!isSupported) return;
    await _plugin.cancel(reminder.notificationId);
    for (int weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(_routineNotificationId(reminder, weekday));
    }
  }

  Future<void> cancelAll() async {
    if (!isSupported) return;
    await init();
    await _plugin.cancelAll();
  }

  /// ตั้งเวลาการเตือนใหม่ทั้งหมด (เรียกตอนเปิดแอปและหลัง import)
  Future<void> rescheduleAll({
    required List<Task> tasks,
    required List<Routine> routines,
    required List<Reminder> reminders,
  }) async {
    if (!isSupported) return;
    await init();
    await _plugin.cancelAll();
    final Map<int, Task> taskById = <int, Task>{
      for (final Task t in tasks)
        if (t.id != null) t.id!: t,
    };
    final Map<int, Routine> routineById = <int, Routine>{
      for (final Routine r in routines)
        if (r.id != null) r.id!: r,
    };
    for (final Reminder reminder in reminders) {
      if (!reminder.enabled) continue;
      if (reminder.ownerType == ReminderOwner.task) {
        final Task? task = taskById[reminder.ownerId];
        if (task != null) await scheduleTaskReminder(task, reminder);
      } else {
        final Routine? routine = routineById[reminder.ownerId];
        if (routine != null) await scheduleRoutineReminder(routine, reminder);
      }
    }
  }

  /// ทดสอบการเตือน/เสียงปลุกทันที
  Future<void> showPreview(Reminder reminder, String title) async {
    if (!isSupported) return;
    await init();
    await _plugin.show(
      900000 + (reminder.notificationId % 1000),
      title,
      reminder.isAlarm ? 'ทดสอบเสียงปลุก' : 'ทดสอบการแจ้งเตือน',
      await _detailsFor(reminder),
    );
  }
}

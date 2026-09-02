import 'package:flutter/material.dart';

/// เหตุการณ์หนึ่งช่องบนตารางเวลา (งานที่ระบุเวลา หรือกิจวัตร)
class TimetableEvent {
  TimetableEvent({
    required this.start,
    required this.end,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isRoutine,
    required this.onTap,
  });

  final DateTime start;
  final DateTime end;
  final String title;
  final String subtitle;
  final Color color;
  final bool isRoutine;
  final VoidCallback onTap;

  int lane = 0;
  int laneCount = 1;

  int get startMinutes => start.hour * 60 + start.minute;
  int get endMinutes {
    final int value = end.hour * 60 + end.minute;
    // อย่างน้อย 30 นาทีเพื่อให้กดได้
    return value <= startMinutes ? startMinutes + 30 : value;
  }
}

/// จัดเลนของเหตุการณ์ที่เวลาทับกัน เพื่อให้แสดงเคียงกันได้
void assignLanes(List<TimetableEvent> events) {
  events.sort(
    (TimetableEvent a, TimetableEvent b) => a.startMinutes.compareTo(b.startMinutes),
  );

  final List<TimetableEvent> cluster = <TimetableEvent>[];
  int clusterEnd = -1;

  void closeCluster() {
    if (cluster.isEmpty) return;
    final int lanes = cluster.fold<int>(
      1,
      (int max, TimetableEvent e) => e.lane + 1 > max ? e.lane + 1 : max,
    );
    for (final TimetableEvent event in cluster) {
      event.laneCount = lanes;
    }
    cluster.clear();
  }

  final List<int> laneEnds = <int>[];
  for (final TimetableEvent event in events) {
    if (event.startMinutes >= clusterEnd) {
      closeCluster();
      laneEnds.clear();
    }
    int lane = laneEnds.indexWhere((int end) => end <= event.startMinutes);
    if (lane == -1) {
      laneEnds.add(event.endMinutes);
      lane = laneEnds.length - 1;
    } else {
      laneEnds[lane] = event.endMinutes;
    }
    event.lane = lane;
    cluster.add(event);
    if (event.endMinutes > clusterEnd) clusterEnd = event.endMinutes;
  }
  closeCluster();
}

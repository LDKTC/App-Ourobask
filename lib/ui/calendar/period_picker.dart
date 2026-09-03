import 'package:flutter/material.dart';

import '../../utils/date_time_utils.dart';
import '../../utils/formatters.dart';

/// มุมมองของหน้าปฏิทิน
enum CalendarMode { week, month, year }

/// แผ่นเลือกช่วงเวลาเพื่อกระโดดข้ามไปยังสัปดาห์ / เดือน / ปีที่ต้องการ
///
/// คืนค่าเป็นวันที่ของช่วงที่เลือก (null = ปิดแผ่นทิ้งโดยไม่เลือก)
Future<DateTime?> showPeriodJumpSheet(
  BuildContext context, {
  required CalendarMode mode,
  required DateTime anchor,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => _PeriodJumpSheet(mode: mode, anchor: anchor),
  );
}

class _PeriodJumpSheet extends StatefulWidget {
  const _PeriodJumpSheet({required this.mode, required this.anchor});

  final CalendarMode mode;
  final DateTime anchor;

  @override
  State<_PeriodJumpSheet> createState() => _PeriodJumpSheetState();
}

class _PeriodJumpSheetState extends State<_PeriodJumpSheet> {
  static const double _itemExtent = 58;

  /// จำนวนช่วงเวลาที่แสดงย้อนหลัง/ไปข้างหน้าจากช่วงปัจจุบัน
  static const Map<CalendarMode, int> _span = <CalendarMode, int>{
    CalendarMode.week: 78, // ปีครึ่งทั้งสองฝั่ง
    CalendarMode.month: 36, // 3 ปีทั้งสองฝั่ง
    CalendarMode.year: 12,
  };

  late final List<DateTime> _options = _buildOptions();
  late final int _currentIndex = _span[widget.mode]!;
  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _currentIndex > 2 ? (_currentIndex - 2) * _itemExtent : 0,
  );

  List<DateTime> _buildOptions() {
    final int span = _span[widget.mode]!;
    final DateTime anchor = widget.anchor;
    return List<DateTime>.generate(span * 2 + 1, (int index) {
      final int step = index - span;
      switch (widget.mode) {
        case CalendarMode.week:
          return startOfWeek(anchor).add(Duration(days: 7 * step));
        case CalendarMode.month:
          return startOfMonth(addMonths(startOfMonth(anchor), step));
        case CalendarMode.year:
          return DateTime(anchor.year + step);
      }
    });
  }

  String _labelOf(DateTime value) {
    switch (widget.mode) {
      case CalendarMode.week:
        return Fmt.weekRange(value);
      case CalendarMode.month:
        return Fmt.monthYear(value);
      case CalendarMode.year:
        return 'ปี ${Fmt.displayYear(value.year)}';
    }
  }

  /// ช่วงเวลานี้ครอบวันนี้อยู่หรือเปล่า
  bool _containsToday(DateTime value) {
    final DateTime now = DateTime.now();
    switch (widget.mode) {
      case CalendarMode.week:
        final DateTime end = value.add(const Duration(days: 6));
        return !startOfDay(now).isBefore(value) && !startOfDay(now).isAfter(end);
      case CalendarMode.month:
        return value.year == now.year && value.month == now.month;
      case CalendarMode.year:
        return value.year == now.year;
    }
  }

  String get _title {
    switch (widget.mode) {
      case CalendarMode.week:
        return 'ไปยังสัปดาห์';
      case CalendarMode.month:
        return 'ไปยังเดือน';
      case CalendarMode.year:
        return 'ไปยังปี';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, DateTime.now()),
                    icon: const Icon(Icons.today_rounded, size: 18),
                    label: const Text('วันนี้'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _controller,
                itemExtent: _itemExtent,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _options.length,
                itemBuilder: (BuildContext context, int index) {
                  final DateTime value = _options[index];
                  final bool selected = index == _currentIndex;
                  final bool today = _containsToday(value);
                  return ListTile(
                    selected: selected,
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                    title: Text(
                      _labelOf(value),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: selected || today
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: today
                        ? Text(
                            'วันนี้',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                    onTap: () => Navigator.pop(context, value),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

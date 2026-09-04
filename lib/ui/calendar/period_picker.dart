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

/// หนึ่ง "หน้า" ของตาราง เช่น หนึ่งเดือน (กองสัปดาห์) หรือหนึ่งปี (กองเดือน)
class _PeriodPage {
  const _PeriodPage({required this.title, required this.values});

  /// ชื่อที่เขียนกำกับไว้ด้านบนของหน้า
  final String title;
  final List<DateTime> values;
}

class _PeriodJumpSheet extends StatefulWidget {
  const _PeriodJumpSheet({required this.mode, required this.anchor});

  final CalendarMode mode;
  final DateTime anchor;

  @override
  State<_PeriodJumpSheet> createState() => _PeriodJumpSheetState();
}

class _PeriodJumpSheetState extends State<_PeriodJumpSheet> {
  /// ขนาดคงที่ของตาราง ใช้ทั้งวาดและคำนวณจุดเริ่มเลื่อน
  static const int _columns = 3;
  static const double _tileHeight = 56;
  static const double _spacing = 8;
  static const double _headerHeight = 40;
  static const double _pageGap = 14;
  static const double _topPadding = 4;

  /// จำนวนช่วงเวลาที่แสดงย้อนหลัง/ไปข้างหน้าจากช่วงปัจจุบัน
  static const Map<CalendarMode, int> _span = <CalendarMode, int>{
    CalendarMode.week: 78, // ปีครึ่งทั้งสองฝั่ง
    CalendarMode.month: 36, // 3 ปีทั้งสองฝั่ง
    CalendarMode.year: 12,
  };

  late final List<DateTime> _options = _buildOptions();
  late final int _currentIndex = _span[widget.mode]!;
  late final List<_PeriodPage> _pages = _buildPages();

  /// หน้าที่ช่วงปัจจุบันอยู่ — เปิดแผ่นมาแล้วเลื่อนไปให้เห็นหัวข้อของหน้านั้นเลย
  late final int _currentPage = _pageIndexOf(_options[_currentIndex]);
  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _offsetOfPage(_currentPage),
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

  /// จัดช่วงเวลาลงเป็นหน้า ๆ — สัปดาห์กองตามเดือน เดือนกองตามปี ปีกองตามทศวรรษ
  List<_PeriodPage> _buildPages() {
    final List<_PeriodPage> pages = <_PeriodPage>[];
    String? currentTitle;
    List<DateTime> bucket = <DateTime>[];
    for (final DateTime value in _options) {
      final String title = _pageTitleOf(value);
      if (title != currentTitle) {
        if (currentTitle != null) {
          pages.add(_PeriodPage(title: currentTitle, values: bucket));
        }
        currentTitle = title;
        bucket = <DateTime>[];
      }
      bucket.add(value);
    }
    if (currentTitle != null) {
      pages.add(_PeriodPage(title: currentTitle, values: bucket));
    }
    return pages;
  }

  String _pageTitleOf(DateTime value) {
    switch (widget.mode) {
      case CalendarMode.week:
        return Fmt.monthYear(value);
      case CalendarMode.month:
        return 'ปี ${Fmt.displayYear(value.year)}';
      case CalendarMode.year:
        final int start = value.year - value.year % 10;
        return 'ปี ${Fmt.displayYear(start)} - ${Fmt.displayYear(start + 9)}';
    }
  }

  int _pageIndexOf(DateTime value) {
    final String title = _pageTitleOf(value);
    final int index = _pages.indexWhere((_PeriodPage p) => p.title == title);
    return index < 0 ? 0 : index;
  }

  /// ระยะเลื่อนจนถึงหัวข้อของหน้าที่ [pageIndex]
  double _offsetOfPage(int pageIndex) {
    double offset = _topPadding;
    for (int i = 0; i < pageIndex; i++) {
      offset += _pageHeight(_pages[i].values.length);
    }
    return offset;
  }

  double _pageHeight(int itemCount) {
    final int rows = (itemCount + _columns - 1) ~/ _columns;
    return _headerHeight + rows * _tileHeight + (rows - 1) * _spacing + _pageGap;
  }

  /// ป้ายในช่องตาราง — สั้นได้เพราะมีชื่อหน้ากำกับอยู่ด้านบนแล้ว
  String _tileLabelOf(DateTime value) {
    switch (widget.mode) {
      case CalendarMode.week:
        final DateTime end = value.add(const Duration(days: 6));
        if (value.month == end.month) return '${value.day} - ${end.day}';
        return '${value.day} ${Fmt.monthsShort[value.month - 1]} - '
            '${end.day} ${Fmt.monthsShort[end.month - 1]}';
      case CalendarMode.month:
        return Fmt.monthsShort[value.month - 1];
      case CalendarMode.year:
        return '${Fmt.displayYear(value.year)}';
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CustomScrollView(
                  controller: _controller,
                  slivers: <Widget>[
                    const SliverToBoxAdapter(
                      child: SizedBox(height: _topPadding),
                    ),
                    for (final _PeriodPage page in _pages) ...<Widget>[
                      SliverToBoxAdapter(
                        child: _PageTitle(title: page.title),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: _pageGap),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _columns,
                                mainAxisExtent: _tileHeight,
                                crossAxisSpacing: _spacing,
                                mainAxisSpacing: _spacing,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) {
                              final DateTime value = page.values[index];
                              return _PeriodTile(
                                label: _tileLabelOf(value),
                                selected: value == _options[_currentIndex],
                                today: _containsToday(value),
                                onTap: () => Navigator.pop(context, value),
                              );
                            },
                            childCount: page.values.length,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ชื่อกำกับด้านบนของแต่ละหน้าในตาราง
class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: _PeriodJumpSheetState._headerHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// หนึ่งช่องในตาราง — ช่วงที่กำลังดูอยู่จะถูกไฮไลต์ ส่วนช่วงที่มีวันนี้จะขึ้นขอบ
class _PeriodTile extends StatelessWidget {
  const _PeriodTile({
    required this.label,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color background = selected
        ? colors.primaryContainer
        : colors.surfaceContainerLow;
    final Color foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurface;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: today && !selected
            ? BorderSide(color: colors.primary, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: selected || today
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

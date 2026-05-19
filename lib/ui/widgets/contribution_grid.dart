import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';


class ContributionGrid extends StatefulWidget {
  final Map<DateTime, int> completionsByDay;
  final AppColors col;
  // Accepts the summary data type from stats_view.dart via duck-typing.
  final dynamic summary; // _ContribSummary from stats_view

  const ContributionGrid({
    super.key,
    required this.completionsByDay,
    required this.col,
    required this.summary,
  });

  @override
  State<ContributionGrid> createState() => _ContributionGridState();
}

class _ContributionGridState extends State<ContributionGrid> {
  DateTime? _hovered;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  static List<DateTime> _buildDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.subtract(const Duration(days: 364));
    final weekday = cutoff.weekday;
    final startMonday = cutoff.subtract(Duration(days: weekday - 1));
    final days = <DateTime>[];
    var d = startMonday;
    while (!d.isAfter(today)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }
    return days;
  }

  Color _colorForDay(DateTime day) {
    final count = widget.completionsByDay[day] ?? 0;
    if (count == 0) return widget.col.bg3;
    final t = (count / 4).clamp(0.0, 1.0);
    return Color.lerp(widget.col.bg3, widget.col.green, t)!;
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.col;
    final days = _buildDays();

    // Group into weekly columns.
    final weeks = <List<DateTime>>[];
    for (var i = 0; i < days.length; i += 7) {
      final end = (i + 7).clamp(0, days.length);
      weeks.add(days.sublist(i, end));
    }

    const cellSize = 10.0;
    const gap = 2.0;
    const dowLabels = ['M', '', 'W', '', 'F', '', 'S'];

    // Build each week column.
    final weekCols = <Widget>[];
    for (final week in weeks) {
      final cells = <Widget>[];
      for (var row = 0; row < 7; row++) {
        Widget cell;
        if (row < week.length) {
          final day = week[row];
          cell = Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: _Cell(
              day: day,
              color: _colorForDay(day),
              size: cellSize,
              hovered: _hovered == day,
              count: widget.completionsByDay[day] ?? 0,
              col: col,
              onHover: (isHovered) =>
                  setState(() => _hovered = isHovered ? day : null),
            ),
          );
        } else {
          cell = Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: SizedBox(width: cellSize, height: cellSize),
          );
        }
        cells.add(cell);
      }
      weekCols.add(Column(children: cells));
    }

    // Day-of-week axis.
    final dowAxis = <Widget>[];
    for (var i = 0; i < 7; i++) {
      dowAxis.add(
        SizedBox(
          height: cellSize + gap,
          width: 14,
          child: dowLabels[i].isNotEmpty
              ? Text(dowLabels[i],
                  style: TextStyle(color: col.fgMute, fontSize: 8))
              : null,
        ),
      );
    }

    // Legend cells.
    final legendCells = <Widget>[];
    for (var level = 0; level <= 4; level++) {
      final t = level / 4;
      final c = level == 0
          ? col.bg3
          : Color.lerp(col.bg3, col.green, t)!;
      legendCells.add(Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: c,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ));
      if (level < 4) legendCells.add(const SizedBox(width: gap));
    }

    final s = widget.summary;
    final summaryText =
        s != null ? '// ${s.daysTracked} days tracked · ${s.avgPct}% avg · ${s.perfectDays} perfect days' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid — DOW labels fixed, week columns horizontally scrollable.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: dowAxis),
            const SizedBox(width: 2),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _scrollCtrl,
                child: Wrap(spacing: gap, children: weekCols),
              ),
            ),
          ],
        ),
        const SizedBox(height: TH.s8),
        // Legend
        Row(
          children: [
            Text('// less',
                style: TextStyle(color: col.fgMute, fontSize: 10)),
            const SizedBox(width: 6),
            ...legendCells,
            const SizedBox(width: 6),
            Text('more',
                style: TextStyle(color: col.fgMute, fontSize: 10)),
          ],
        ),
        if (summaryText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(summaryText,
              style: TextStyle(color: col.fgMute, fontSize: 10)),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final DateTime day;
  final Color color;
  final double size;
  final bool hovered;
  final int count;
  final AppColors col;
  final ValueChanged<bool> onHover;

  const _Cell({
    required this.day,
    required this.color,
    required this.size,
    required this.hovered,
    required this.count,
    required this.col,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    final suffix = count == 1 ? '' : 's';
    final label = '${day.year}-$mm-$dd: $count completion$suffix';
    return Tooltip(
      message: label,
      textStyle: TextStyle(color: col.fg, fontSize: 11),
      decoration: BoxDecoration(
        color: col.bg3,
        borderRadius: const BorderRadius.all(TH.r4),
        border: Border.all(color: col.line2),
      ),
      child: MouseRegion(
        onEnter: (event) => onHover(true),
        onExit: (event) => onHover(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: hovered ? Color.lerp(color, Colors.white, 0.2) : color,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
          ),
        ),
      ),
    );
  }
}

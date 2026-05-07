import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class WeekStrip extends StatelessWidget {
  final DateTime today;
  const WeekStrip({super.key, required this.today});

  @override
  Widget build(BuildContext context) {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      children: [
        for (int i = 0; i < 7; i++) ...[
          _DayCell(
            label: labels[i],
            date: days[i],
            isToday: _sameDay(days[i], today),
          ),
          if (i < 6) const SizedBox(width: 4),
        ],
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isToday;

  const _DayCell({
    required this.label,
    required this.date,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isToday ? TH.bg3 : TH.bg1,
          border: Border.all(
              color: isToday ? TH.green : TH.line, width: 1),
          borderRadius: BorderRadius.all(TH.r4),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: isToday ? TH.green : TH.fgMute,
                    fontSize: 11)),
            const SizedBox(height: 2),
            Text('${date.day}',
                style: TextStyle(
                    color: isToday ? TH.green : TH.fgDim,
                    fontSize: 12,
                    fontWeight:
                        isToday ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

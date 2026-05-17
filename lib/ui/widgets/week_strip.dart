import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

class WeekStrip extends ConsumerWidget {
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final selected = ref.watch(selectedDayProvider);
    final today = DateTime.now();
    final ratios = ref.watch(weeklyRatiosProvider);

    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final monday = DateTime(
      selected.year,
      selected.month,
      selected.day - (selected.weekday - 1),
    );
    final days = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NavArrow(
          label: '<',
          col: col,
          onTap: () {
            final delta = selected.weekday == 1 ? 1 : 7;
            ref.read(selectedDayProvider.notifier).state =
                DateTime(selected.year, selected.month, selected.day - delta);
          },
        ),
        const SizedBox(width: 4),
        for (int i = 0; i < 7; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(selectedDayProvider.notifier).state = days[i],
              behavior: HitTestBehavior.opaque,
              child: _DayCell(
                col: col,
                label: labels[i],
                date: days[i],
                isSelected: _sameDay(days[i], selected),
                isToday: _sameDay(days[i], today),
                ratio: i < ratios.length ? ratios[i].ratio : 0,
                shielded: i < ratios.length ? ratios[i].shielded : false,
              ),
            ),
          ),
          if (i < 6) const SizedBox(width: 4),
        ],
        const SizedBox(width: 4),
        _NavArrow(
          label: '>',
          col: col,
          onTap: () {
            final delta = selected.weekday == 7 ? 1 : 7;
            ref.read(selectedDayProvider.notifier).state =
                DateTime(selected.year, selected.month, selected.day + delta);
          },
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _NavArrow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final AppColors col;
  const _NavArrow({required this.label, required this.onTap, required this.col});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 20,
        height: 56,
        child: Center(
          child: Text(label,
              style: TextStyle(color: col.fgMute, fontSize: 14)),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final double ratio;
  final AppColors col;
  final bool shielded;

  const _DayCell({
    required this.label,
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.ratio,
    required this.col,
    this.shielded = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? col.amber
        : isToday
            ? col.fg
            : col.fgMute;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(color: col.fgMute, fontSize: 10)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? col.bg3 : Colors.transparent,
            borderRadius: const BorderRadius.all(TH.r4),
          ),
          child: Center(
            child: Text(
              isSelected ? '*${date.day}' : '${date.day}',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _IntensityBar(ratio: ratio, col: col, shielded: shielded),
      ],
    );
  }
}

class _IntensityBar extends StatelessWidget {
  final double ratio;
  final AppColors col;
  final bool shielded;
  const _IntensityBar({required this.ratio, required this.col, this.shielded = false});

  @override
  Widget build(BuildContext context) {
    // Shielded incomplete day → full blue bar.
    // Otherwise → amber bar at completion ratio.
    final isProtected = shielded && ratio < 1.0;
    final fillWidth = isProtected ? 1.0 : ratio;
    final fillColor = isProtected ? col.blue : col.amber;

    return SizedBox(
      height: 6,
      child: LayoutBuilder(builder: (_, constraints) {
        final width = constraints.maxWidth;
        return Stack(children: [
          Container(
            width: width,
            height: 6,
            decoration: BoxDecoration(
              color: col.bg2,
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
          ),
          if (fillWidth > 0)
            Container(
              width: width * fillWidth,
              height: 6,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
        ]);
      }),
    );
  }
}

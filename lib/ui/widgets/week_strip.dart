import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';

class WeekStrip extends ConsumerWidget {
  const WeekStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          onTap: () => ref.read(selectedDayProvider.notifier).state =
              DateTime(selected.year, selected.month, selected.day - 7),
        ),
        const SizedBox(width: 4),
        for (int i = 0; i < 7; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(selectedDayProvider.notifier).state = days[i],
              behavior: HitTestBehavior.opaque,
              child: _DayCell(
                label: labels[i],
                date: days[i],
                isSelected: _sameDay(days[i], selected),
                isToday: _sameDay(days[i], today),
                ratio: i < ratios.length ? ratios[i].ratio : 0,
              ),
            ),
          ),
          if (i < 6) const SizedBox(width: 4),
        ],
        const SizedBox(width: 4),
        _NavArrow(
          label: '>',
          onTap: () => ref.read(selectedDayProvider.notifier).state =
              DateTime(selected.year, selected.month, selected.day + 7),
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
  const _NavArrow({required this.label, required this.onTap});

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
              style: const TextStyle(color: TH.fgMute, fontSize: 14)),
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

  const _DayCell({
    required this.label,
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? TH.amber
        : isToday
            ? TH.fg
            : TH.fgMute;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(color: TH.fgMute, fontSize: 10)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? TH.bg3 : Colors.transparent,
            borderRadius: BorderRadius.all(TH.r4),
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
        _IntensityBar(ratio: ratio),
      ],
    );
  }
}

class _IntensityBar extends StatelessWidget {
  final double ratio;
  const _IntensityBar({required this.ratio});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: LayoutBuilder(builder: (_, constraints) {
        final width = constraints.maxWidth;
        return Stack(children: [
          Container(
            width: width,
            height: 6,
            decoration: BoxDecoration(
              color: TH.bg2,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          Container(
            width: width * ratio,
            height: 6,
            decoration: BoxDecoration(
              color: TH.amber,
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
        ]);
      }),
    );
  }
}

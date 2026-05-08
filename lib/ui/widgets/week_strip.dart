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

    // Start of week containing selected day (Monday)
    final monday = DateTime(
      selected.year,
      selected.month,
      selected.day - (selected.weekday - 1),
    );
    final days = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      children: [
        _NavArrow(
          label: '<',
          onTap: () {
            final prev = DateTime(selected.year, selected.month, selected.day - 7);
            ref.read(selectedDayProvider.notifier).state = prev;
          },
        ),
        const SizedBox(width: 4),
        for (int i = 0; i < 7; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  ref.read(selectedDayProvider.notifier).state = days[i],
              child: _DayCell(
                label: labels[i],
                date: days[i],
                isSelected: _sameDay(days[i], selected),
                isToday: _sameDay(days[i], today),
              ),
            ),
          ),
          if (i < 6) const SizedBox(width: 4),
        ],
        const SizedBox(width: 4),
        _NavArrow(
          label: '>',
          onTap: () {
            final next = DateTime(selected.year, selected.month, selected.day + 7);
            ref.read(selectedDayProvider.notifier).state = next;
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

  const _NavArrow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 20,
        child: Center(
          child: Text(label,
              style: const TextStyle(color: TH.fgMute, fontSize: 13)),
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

  const _DayCell({
    required this.label,
    required this.date,
    required this.isSelected,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? TH.green
        : isToday
            ? TH.fgMute
            : TH.line;
    final textColor = isSelected
        ? TH.green
        : isToday
            ? TH.fgDim
            : TH.fgMute;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? TH.bg3 : TH.bg1,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.all(TH.r4),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: textColor, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            '${date.day}',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

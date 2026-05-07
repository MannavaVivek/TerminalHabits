import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/schedule.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';

class InspectorPane extends ConsumerWidget {
  const InspectorPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusedId = ref.watch(focusedHabitIdProvider);
    DailyHabit? focused;

    if (focusedId != null) {
      ref.watch(dailyStateProvider).whenData((state) {
        for (final g in state.groups) {
          for (final h in g.habits) {
            if (h.habit.id == focusedId) focused = h;
          }
        }
      });
    }

    return SizedBox(
      width: 280,
      child: focused == null
          ? const _EmptyInspector()
          : _HabitInspector(dailyHabit: focused!),
    );
  }
}

class _EmptyInspector extends StatelessWidget {
  const _EmptyInspector();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'select a habit\nto inspect',
        textAlign: TextAlign.center,
        style: TextStyle(color: TH.fgFaint, fontSize: 12),
      ),
    );
  }
}

class _HabitInspector extends StatelessWidget {
  final DailyHabit dailyHabit;
  const _HabitInspector({required this.dailyHabit});

  @override
  Widget build(BuildContext context) {
    final h = dailyHabit.habit;
    final s = dailyHabit.streaks;

    return ListView(
      padding: const EdgeInsets.all(TH.s14),
      children: [
        Text('${h.icon} ${h.name}',
            style: const TextStyle(
                color: TH.fg, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: TH.s14),
        _Block(label: 'streak', children: [
          _Row('current', '${s.current}'),
          _Row('longest', '${s.longest}'),
          _Row('shields', '${s.shields}'),
        ]),
        const SizedBox(height: TH.s8),
        _Block(label: 'habit', children: [
          _Row('tracking', h.tracking),
          _Row('schedule', scheduleLabel(h.schedule)),
          if (h.note != null && h.note!.isNotEmpty)
            _Row('note', h.note!),
        ]),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _Block({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: TH.line),
        borderRadius: BorderRadius.all(TH.r4),
      ),
      padding: const EdgeInsets.all(TH.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('── $label',
              style:
                  const TextStyle(color: TH.fgMute, fontSize: 11)),
          const SizedBox(height: TH.s4),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text('$label:',
                style:
                    const TextStyle(color: TH.fgDim, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: TH.fg, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shortcuts/intents.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(currentViewProvider);

    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: TH.s14),
          _NavItem(
            label: 'daily',
            selected: view == 'daily',
            onTap: () =>
                ref.read(currentViewProvider.notifier).state = 'daily',
          ),
          _NavItem(
            label: 'stats',
            selected: view == 'stats',
            onTap: () =>
                ref.read(currentViewProvider.notifier).state = 'stats',
          ),
          _NavItem(
            label: 'profile',
            selected: view == 'profile',
            onTap: () =>
                ref.read(currentViewProvider.notifier).state = 'profile',
          ),
          const Spacer(),
          _AddHabitButton(),
          const SizedBox(height: TH.s14),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? TH.green : TH.fgDim;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: selected ? TH.bg2 : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: TH.s14, vertical: TH.s8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: selected
                  ? const Text('▸',
                      style: TextStyle(
                          color: TH.amber,
                          fontSize: 17,
                          fontWeight: FontWeight.w600))
                  : null,
            ),
            Text(label,
                style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class _AddHabitButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Actions.invoke(context, const NewHabitIntent()),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: TH.s14),
        padding: const EdgeInsets.symmetric(vertical: TH.s8),
        decoration: BoxDecoration(
          border: Border.all(color: TH.line2),
          borderRadius: BorderRadius.all(TH.r4),
        ),
        child: const Center(
          child: Text('[ + new habit ]',
              style: TextStyle(color: TH.fgDim, fontSize: 12)),
        ),
      ),
    );
  }
}

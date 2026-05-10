import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../modals/user_window.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final view = ref.watch(currentViewProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final initial = (user?.displayName.isNotEmpty == true)
        ? user!.displayName[0].toUpperCase()
        : '?';
    final displayName = user?.displayName ?? '';

    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: TH.s14),
          _NavItem(label: 'daily', selected: view == 'daily',
              onTap: () => ref.read(currentViewProvider.notifier).state = 'daily'),
          _NavItem(label: 'stats', selected: view == 'stats',
              onTap: () => ref.read(currentViewProvider.notifier).state = 'stats'),
          const Spacer(),
          GestureDetector(
            onTap: () => showUserWindow(context),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(
                  horizontal: TH.s14, vertical: TH.s8),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      border: Border.all(color: col.fgMute),
                      borderRadius: const BorderRadius.all(TH.r4),
                    ),
                    child: Center(
                      child: Text(initial,
                          style: TextStyle(
                              color: col.fgDim,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: TH.s8),
                  Expanded(
                    child: Text(displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: col.fgDim, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: TH.s8),
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
    final col = context.col;
    final fg = selected ? col.green : col.fgDim;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: selected ? col.bg2 : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: TH.s14, vertical: TH.s8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: selected
                  ? Text('▸',
                      style: TextStyle(
                          color: col.amber,
                          fontSize: 17,
                          fontWeight: FontWeight.w600))
                  : null,
            ),
            Text(label,
                style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

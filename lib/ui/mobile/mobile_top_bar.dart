import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

class MobileTopBar extends ConsumerWidget {
  const MobileTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final view = ref.watch(currentViewProvider);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: col.bg,
        border: Border(bottom: BorderSide(color: col.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: TH.s14),
      child: Row(
        children: [
          _Tab(label: 'daily',   view: 'daily',   current: view, col: col, ref: ref),
          const SizedBox(width: TH.s8),
          _Tab(label: 'stats',   view: 'stats',   current: view, col: col, ref: ref),
          const SizedBox(width: TH.s8),
          _Tab(label: 'profile', view: 'profile', current: view, col: col, ref: ref),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String view;
  final String current;
  final AppColors col;
  final WidgetRef ref;

  const _Tab({
    required this.label,
    required this.view,
    required this.current,
    required this.col,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == view;
    return GestureDetector(
      onTap: () => ref.read(currentViewProvider.notifier).state = view,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: TH.s8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: active ? col.green : col.line),
          borderRadius: const BorderRadius.all(TH.r4),
        ),
        child: Text(
          '[ $label ]',
          style: TextStyle(
            color: active ? col.green : col.fgMute,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final dailyAV = ref.watch(dailyStateProvider);
    final isDesktop = Platform.isMacOS || Platform.isLinux;

    final statusText = dailyAV.when(
      data: (state) => '${state.totalDone}/${state.totalHabits} done today',
      loading: () => 'loading...',
      error: (_, __) => 'error',
    );

    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: col.bg1,
        border: Border(top: BorderSide(color: col.line, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: TH.s14),
      child: Row(
        children: [
          Text(statusText,
              style: TextStyle(color: col.fgMute, fontSize: 11)),
          const Spacer(),
          if (isDesktop)
            Text(
              '⌘K palette  ·  ⌘N new habit  ·  j/k navigate',
              style: TextStyle(color: col.fgFaint, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

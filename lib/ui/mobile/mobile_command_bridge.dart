import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../modals/new_habit_dialog.dart';
import '../modals/settings_dialog.dart';

Future<void> showMobileCommandBridge(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, _, __) => const _MobileCommandBridge(),
      transitionDuration: const Duration(milliseconds: 120),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _MobileCommandBridge extends ConsumerWidget {
  const _MobileCommandBridge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;

    void go(String view) {
      ref.read(currentViewProvider.notifier).state = view;
      Navigator.of(context).pop();
    }

    final cells = [
      _Cell(
        label: '[ new ]',
        desc: 'create habit',
        col: col,
        onTap: () {
          Navigator.of(context).pop();
          NewHabitDialog.show(context);
        },
      ),
      _Cell(label: '[ daily ]',   desc: 'daily view',    col: col, onTap: () => go('daily')),
      _Cell(label: '[ stats ]',   desc: 'stats view',    col: col, onTap: () => go('stats')),
      _Cell(label: '[ profile ]', desc: 'profile view',  col: col, onTap: () => go('profile')),
      _Cell(label: '[ vacation ]', desc: 'vacation mode', col: col, onTap: () => go('vacation')),
      _Cell(label: '[ archive ]',  desc: 'archived habits', col: col, onTap: () => go('archive')),
      _Cell(
        label: '[ settings ]',
        desc: 'preferences',
        col: col,
        onTap: () {
          Navigator.of(context).pop();
          SettingsDialog.show(context);
        },
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TH.s22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '> command',
              style: TextStyle(
                  color: col.green, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: TH.s14),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: TH.s8,
                crossAxisSpacing: TH.s8,
                childAspectRatio: 2.2,
                children: cells,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: TH.s14, vertical: TH.s8),
                  decoration: BoxDecoration(
                    border: Border.all(color: col.line),
                    borderRadius: const BorderRadius.all(TH.r4),
                  ),
                  child: Text('[ cancel ]',
                      style: TextStyle(color: col.fgMute, fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String desc;
  final VoidCallback onTap;
  final AppColors col;

  const _Cell({
    required this.label,
    required this.desc,
    required this.onTap,
    required this.col,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(TH.s8),
        decoration: BoxDecoration(
          color: col.bg2,
          border: Border.all(color: col.line2),
          borderRadius: const BorderRadius.all(TH.r4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    color: col.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(desc,
                style: TextStyle(color: col.fgMute, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

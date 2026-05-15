import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

Future<void> showVacationManager(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _VacationManagerDialog(),
    );

class _VacationManagerDialog extends ConsumerWidget {
  const _VacationManagerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final vacsAV = ref.watch(vacationsProvider);
    final vacs = vacsAV.valueOrNull ?? const [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Split into upcoming (start > today) and past (end < today),
    // excluding currently active (today is in [start, end] AND active=true).
    final upcoming = <Vacation>[];
    final past = <Vacation>[];
    for (final v in vacs) {
      final start = DateTime(v.start.toLocal().year, v.start.toLocal().month,
          v.start.toLocal().day);
      final end = DateTime(v.end.toLocal().year, v.end.toLocal().month,
          v.end.toLocal().day);
      final isCurrentlyActive =
          v.active && !today.isBefore(start) && !today.isAfter(end);
      if (isCurrentlyActive) continue; // shown in user window
      if (start.isAfter(today)) {
        upcoming.add(v);
      } else if (end.isBefore(today)) {
        past.add(v);
      }
    }
    upcoming.sort((a, b) => a.start.compareTo(b.start));
    past.sort((a, b) => b.end.compareTo(a.end)); // newest first

    return Dialog(
      backgroundColor: col.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(r'$ vacation --manage',
                      style: TextStyle(color: col.fg, fontSize: 13)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('[close]',
                        style: TextStyle(color: col.fgMute, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: TH.s14),

              if (upcoming.isEmpty && past.isEmpty)
                Text('no vacation history.',
                    style: TextStyle(color: col.fgDim, fontSize: 12))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (upcoming.isNotEmpty) ...[
                          Text('── upcoming',
                              style: TextStyle(
                                  color: col.fgMute, fontSize: 11)),
                          const SizedBox(height: TH.s8),
                          for (final v in upcoming)
                            _VacRow(
                              vacation: v,
                              col: col,
                              actionLabel: '[cancel]',
                              actionColor: col.red,
                              onAction: () => ref
                                  .read(dbProvider)
                                  .deleteVacation(v.id),
                            ),
                        ],
                        if (upcoming.isNotEmpty && past.isNotEmpty) ...[
                          const SizedBox(height: TH.s14),
                          _Divider90(col: col),
                          const SizedBox(height: TH.s14),
                        ],
                        if (past.isNotEmpty) ...[
                          Text('── past',
                              style: TextStyle(
                                  color: col.fgMute, fontSize: 11)),
                          const SizedBox(height: TH.s8),
                          for (final v in past)
                            _VacRow(
                              vacation: v,
                              col: col,
                              actionLabel: '[delete]',
                              actionColor: col.fgMute,
                              onAction: () => ref
                                  .read(dbProvider)
                                  .deleteVacation(v.id),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VacRow extends StatelessWidget {
  final Vacation vacation;
  final AppColors col;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onAction;

  const _VacRow({
    required this.vacation,
    required this.col,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
  });

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TH.s8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_fmt(vacation.start)} → ${_fmt(vacation.end)}',
              style: TextStyle(color: col.fgDim, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel,
                style: TextStyle(color: actionColor, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _Divider90 extends StatelessWidget {
  final AppColors col;
  const _Divider90({required this.col});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.9,
      child: Divider(color: col.line2, height: 1),
    );
  }
}

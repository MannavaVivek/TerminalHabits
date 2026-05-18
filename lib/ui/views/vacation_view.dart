import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../widgets/prompt_line.dart';

String _fmtDate(DateTime d) {
  final local = d.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

class VacationView extends ConsumerWidget {
  const VacationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);
    final vacsAV = ref.watch(vacationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(TH.s14),
          child: PromptLine(user: userName, command: 'vacation'),
        ),
        Expanded(
          child: vacsAV.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Center(
              child: Text('error: $e',
                  style: const TextStyle(color: Colors.red)),
            ),
            data: (vacs) {
              final active = vacs.where((v) => v.active).firstOrNull;
              final past = vacs.where((v) => !v.active).toList();
              return _VacationContent(
                active: active,
                past: past,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VacationContent extends ConsumerWidget {
  final Vacation? active;
  final List<Vacation> past;

  const _VacationContent({required this.active, required this.past});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: TH.s22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active != null)
            _ActiveVacation(vacation: active!, col: col)
          else
            _NoVacation(col: col),
          if (past.isNotEmpty) ...[
            const SizedBox(height: TH.s22),
            _PastVacations(past: past, col: col),
          ],
          const SizedBox(height: TH.s22),
        ],
      ),
    );
  }
}

class _ActiveVacation extends ConsumerWidget {
  final Vacation vacation;
  final AppColors col;
  const _ActiveVacation({required this.vacation, required this.col});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final start = vacation.start.toLocal();
    final end = vacation.end.toLocal();
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final today = DateTime(now.year, now.month, now.day);
    final dayN = today.difference(startDay).inDays + 1;
    final totalDays = endDay.difference(startDay).inDays + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'on vacation.  ${_fmtDate(vacation.start)} → ${_fmtDate(vacation.end)}.',
          style: TextStyle(color: col.fg, fontSize: 13),
        ),
        Text(
          'day $dayN of $totalDays.',
          style: TextStyle(color: col.fgDim, fontSize: 12),
        ),
        const SizedBox(height: TH.s14),
        Row(
          children: [
            _ActionButton(
              label: '[ extend ]',
              col: col,
              color: col.amber,
              onTap: () => _showExtendDialog(context, ref),
            ),
            const SizedBox(width: TH.s14),
            _ActionButton(
              label: '[ end now ]',
              col: col,
              color: col.red,
              onTap: () => _endNow(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showExtendDialog(BuildContext context, WidgetRef ref) async {
    final days = await _promptDays(context, col, title: 'extend by how many days?');
    if (days == null || days <= 0) return;
    if (!context.mounted) return;
    final newEnd = vacation.end.toLocal();
    final extended = DateTime(newEnd.year, newEnd.month, newEnd.day + days).toUtc();
    await ref.read(dbProvider).extendVacation(vacation.id, extended);
  }

  Future<void> _endNow(BuildContext context, WidgetRef ref) async {
    await ref.read(dbProvider).endVacationNow(vacation.id);
  }
}

class _NoVacation extends ConsumerWidget {
  final AppColors col;
  const _NoVacation({required this.col});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('no active vacation.',
            style: TextStyle(color: col.fgDim, fontSize: 13)),
        const SizedBox(height: TH.s14),
        _ActionButton(
          label: '[ start vacation ]',
          col: col,
          color: col.green,
          onTap: () => _showStartDialog(context, ref),
        ),
      ],
    );
  }

  Future<void> _showStartDialog(BuildContext context, WidgetRef ref) async {
    final days = await _promptDays(context, col, title: 'vacation for how many days?');
    if (days == null || days <= 0) return;
    if (!context.mounted) return;
    final userId = ref.read(currentUserIdProvider);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final end = DateTime(now.year, now.month, now.day + days - 1).toUtc();
    await ref.read(dbProvider).startVacation(userId, start, end);
  }
}

class _PastVacations extends StatelessWidget {
  final List<Vacation> past;
  final AppColors col;
  const _PastVacations({required this.past, required this.col});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: col.line),
        borderRadius: const BorderRadius.all(TH.r4),
      ),
      padding: const EdgeInsets.all(TH.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('── past vacations',
              style: TextStyle(color: col.fgMute, fontSize: 11)),
          const SizedBox(height: TH.s4),
          for (final v in past)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${_fmtDate(v.start)} → ${_fmtDate(v.end)}',
                style: TextStyle(color: col.fgDim, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final AppColors col;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.col,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: TH.s14, vertical: TH.s8),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: const BorderRadius.all(TH.r4),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 13)),
      ),
    );
  }
}

Future<int?> _promptDays(
    BuildContext context, AppColors col, {required String title}) async {
  final ctrl = TextEditingController();
  return showDialog<int>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: col.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: col.fg, fontSize: 14)),
              const SizedBox(height: TH.s14),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: col.fg, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'days',
                  hintStyle: TextStyle(color: col.fgFaint, fontSize: 14),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: col.line2),
                      borderRadius: const BorderRadius.all(TH.r4)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: col.green),
                      borderRadius: const BorderRadius.all(TH.r4)),
                  fillColor: col.bg1,
                  filled: true,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: TH.s8, vertical: TH.s8),
                ),
                onSubmitted: (v) {
                  final n = int.tryParse(v.trim());
                  Navigator.of(ctx).pop(n);
                },
              ),
              const SizedBox(height: TH.s14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Text('[ cancel ]',
                        style: TextStyle(color: col.fgMute, fontSize: 12)),
                  ),
                  const SizedBox(width: TH.s14),
                  GestureDetector(
                    onTap: () {
                      final n = int.tryParse(ctrl.text.trim());
                      Navigator.of(ctx).pop(n);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s14, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.green),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text('[ ok ]',
                          style: TextStyle(color: col.green, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

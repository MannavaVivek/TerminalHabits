import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../../data/database.dart';
import '../../data/sync_service.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../views/login_view.dart';
import 'settings_dialog.dart';
import 'vacation_manager_dialog.dart';

Future<void> showUserWindow(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _UserWindowDialog(),
    );

class _UserWindowDialog extends ConsumerStatefulWidget {
  const _UserWindowDialog();

  @override
  ConsumerState<_UserWindowDialog> createState() => _UserWindowDialogState();
}

class _UserWindowDialogState extends ConsumerState<_UserWindowDialog> {
  late final TextEditingController _nameCtrl;
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName(User user) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || name == user.displayName) {
      setState(() => _editingName = false);
      return;
    }
    await ref.read(dbProvider).updateDisplayName(user.id, name);
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(data: {'display_name': name}));
    } catch (_) {}
    setState(() => _editingName = false);
  }

  Future<void> _logOut() async {
    SyncService.stopRealtime();
    final db = ref.read(dbProvider);
    await db.clearAllUserData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('seenOnboarding');
    await prefs.remove('last_auth_uid');
    try { await Supabase.instance.client.auth.signOut(); } catch (_) {}
    ref.read(currentViewProvider.notifier).state = 'daily';
    ref.read(currentUserIdProvider.notifier).state = 0;
    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const LoginView(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }

  Future<void> _addVacation(AppColors col, int userId) async {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // ── Step 1: pick date range ───────────────────────────────────────────────
    DateTime tempStart = now;
    DateTime? tempEnd;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: col.bg2,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(TH.r10)),
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: TH.s14, vertical: TH.s8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Text('[cancel]',
                          style:
                              TextStyle(color: col.fgMute, fontSize: 12)),
                    ),
                    const Spacer(),
                    Text(r'$ vacation --schedule',
                        style: TextStyle(color: col.fg, fontSize: 13)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Text('[done]',
                          style:
                              TextStyle(color: col.green, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Divider(color: col.line, height: 1),
              Padding(
                padding: const EdgeInsets.all(TH.s14),
                child: SfDateRangePicker(
                  selectionMode: DateRangePickerSelectionMode.range,
                  initialSelectedRange:
                      PickerDateRange(tempStart, tempEnd),
                  backgroundColor: col.bg2,
                  selectionColor: col.green,
                  startRangeSelectionColor: col.green,
                  endRangeSelectionColor: col.green,
                  rangeSelectionColor:
                      col.green.withValues(alpha: 0.2),
                  todayHighlightColor: col.green,
                  headerStyle: DateRangePickerHeaderStyle(
                    backgroundColor: col.bg2,
                    textStyle:
                        TextStyle(color: col.fg, fontSize: 13),
                  ),
                  monthCellStyle: DateRangePickerMonthCellStyle(
                    textStyle:
                        TextStyle(color: col.fg, fontSize: 12),
                    todayTextStyle:
                        TextStyle(color: col.green, fontSize: 12),
                    leadingDatesTextStyle:
                        TextStyle(color: col.fgFaint, fontSize: 12),
                    trailingDatesTextStyle:
                        TextStyle(color: col.fgFaint, fontSize: 12),
                  ),
                  yearCellStyle: DateRangePickerYearCellStyle(
                    textStyle:
                        TextStyle(color: col.fg, fontSize: 12),
                    todayTextStyle:
                        TextStyle(color: col.green, fontSize: 12),
                    leadingDatesTextStyle:
                        TextStyle(color: col.fgFaint, fontSize: 12),
                  ),
                  onSelectionChanged:
                      (DateRangePickerSelectionChangedArgs args) {
                    if (args.value is PickerDateRange) {
                      final range = args.value as PickerDateRange;
                      tempStart = range.startDate ?? tempStart;
                      tempEnd = range.endDate;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // Normalize: picker startDate is first-tapped, endDate is second-tapped,
    // so dragging backwards gives startDate > endDate. Always sort them.
    final rawA = tempStart;
    final rawB = tempEnd ?? tempStart; // single-tap = single-day vacation
    final first = rawA.isBefore(rawB) ? rawA : rawB;
    final last = rawA.isBefore(rawB) ? rawB : rawA;
    final startMidnight = DateTime(first.year, first.month, first.day);
    final endMidnight = DateTime(last.year, last.month, last.day);

    // ── Step 2: validate ──────────────────────────────────────────────────────
    final habits = ref.read(habitsProvider).valueOrNull ?? const [];
    final habitIds = habits.map((h) => h.id).toList();
    final yesterdayMidnight =
        todayMidnight.subtract(const Duration(days: 1));

    if (startMidnight.isBefore(todayMidnight)) {
      final pastEnd = endMidnight.isBefore(todayMidnight)
          ? endMidnight
          : yesterdayMidnight;
      final hasProgress = await ref.read(dbProvider).hasCompletionsInRange(
          habitIds, startMidnight.toUtc(), pastEnd.toUtc());
      if (!mounted) return;
      if (hasProgress) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: col.bg2,
            shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(TH.r10)),
            title: Text('Cannot set vacation',
                style: TextStyle(color: col.fg, fontSize: 14)),
            content: Text(
              'You have tracked habits on days within the selected vacation '
              'period. Setting a vacation over days with existing progress '
              'is not allowed.',
              style: TextStyle(color: col.fgDim, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('OK', style: TextStyle(color: col.green)),
              ),
            ],
          ),
        );
        return;
      }
    }

    final todayInRange = !startMidnight.isAfter(todayMidnight) &&
        !endMidnight.isBefore(todayMidnight);
    if (todayInRange) {
      final hasToday = await ref.read(dbProvider).hasCompletionsInRange(
          habitIds, todayMidnight.toUtc(), todayMidnight.toUtc());
      if (!mounted) return;
      if (hasToday) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: col.bg2,
            shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(TH.r10)),
            title: Text('Progress will be lost',
                style: TextStyle(color: col.fg, fontSize: 14)),
            content: Text(
              'Your progress today will be lost if today falls within the '
              'vacation period. Would you like to proceed?',
              style: TextStyle(color: col.fgDim, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel',
                    style: TextStyle(color: col.fgDim)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Proceed',
                    style: TextStyle(color: col.red)),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    // ── Step 3: save ──────────────────────────────────────────────────────────
    await ref
        .read(dbProvider)
        .startVacation(userId, startMidnight.toUtc(), endMidnight.toUtc());
  }

  Future<void> _endVacation(int vacationId) async {
    await ref.read(dbProvider).endVacationNow(vacationId);
  }

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final userAV = ref.watch(currentUserProvider);
    final vacsAV = ref.watch(vacationsProvider);
    final dailyAV = ref.watch(dailyStateProvider);

    return Dialog(
      backgroundColor: col.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: userAV.when(
            loading: () => Center(
              child: Text('loading...',
                  style: TextStyle(color: col.fgDim, fontSize: 12)),
            ),
            error: (e, _) =>
                Text('error: $e', style: TextStyle(color: col.red, fontSize: 12)),
            data: (user) {
              if (user == null) return const SizedBox();
              if (_nameCtrl.text.isEmpty && !_editingName) {
                _nameCtrl.text = user.displayName;
              }

              final streak =
                  dailyAV.valueOrNull?.overallStreak.displayStreak ?? 0;
              final vacs = vacsAV.valueOrNull ?? const [];

              // Currently active = today is within [start, end] AND active=true.
              final now2 = DateTime.now();
              final today2 =
                  DateTime(now2.year, now2.month, now2.day);
              final activeVacs = vacs.where((v) {
                if (!v.active) return false;
                final s = DateTime(v.start.toLocal().year,
                    v.start.toLocal().month, v.start.toLocal().day);
                final e = DateTime(v.end.toLocal().year,
                    v.end.toLocal().month, v.end.toLocal().day);
                return !today2.isBefore(s) && !today2.isAfter(e);
              }).toList();

              final accountEmail = Supabase.instance.client.auth
                      .currentUser?.email ??
                  user.username;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          border: Border.all(color: col.green),
                          borderRadius: const BorderRadius.all(TH.r4),
                        ),
                        child: Center(
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: col.green,
                                fontSize: 18,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: TH.s14),
                      Expanded(
                        child: Text(user.displayName,
                            style: TextStyle(
                                color: col.fg,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                      GestureDetector(
                        onTap: () => SettingsDialog.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: TH.s8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: col.line2),
                            borderRadius: const BorderRadius.all(TH.r4),
                          ),
                          child: Text('[ ⚙ settings ]',
                              style:
                                  TextStyle(color: col.fgDim, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TH.s22),

                  // ── Profile block ──
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: col.line),
                      borderRadius: const BorderRadius.all(TH.r4),
                    ),
                    padding: const EdgeInsets.all(TH.s14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('── profile',
                            style:
                                TextStyle(color: col.fgMute, fontSize: 11)),
                        const SizedBox(height: TH.s8),
                        // Name (editable)
                        Row(
                          children: [
                            SizedBox(
                              width: 96,
                              child: Text('name:',
                                  style: TextStyle(
                                      color: col.fgDim, fontSize: 12)),
                            ),
                            if (_editingName)
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  autofocus: true,
                                  style: TextStyle(
                                      color: col.fg, fontSize: 12),
                                  onSubmitted: (_) =>
                                      _saveDisplayName(user),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 4),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: col.line2),
                                      borderRadius:
                                          const BorderRadius.all(TH.r4),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: col.green),
                                      borderRadius:
                                          const BorderRadius.all(TH.r4),
                                    ),
                                    fillColor: col.bg,
                                    filled: true,
                                  ),
                                  onTapOutside: (_) =>
                                      _saveDisplayName(user),
                                ),
                              )
                            else ...[
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    _nameCtrl.text = user.displayName;
                                    setState(() => _editingName = true);
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Text(user.displayName,
                                      style: TextStyle(
                                          color: col.fg, fontSize: 12)),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  _nameCtrl.text = user.displayName;
                                  setState(() => _editingName = true);
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(left: TH.s8),
                                  child: Icon(LucideIcons.pencil,
                                      size: 12, color: col.fgMute),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        _InfoRow('email', accountEmail, col: col),
                        _InfoRow('member since',
                            _fmtDate(user.createdAt.toLocal()), col: col),
                        _InfoRow('streak', '$streak days', col: col),
                      ],
                    ),
                  ),
                  const SizedBox(height: TH.s8),

                  // ── Vacation block ──
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: col.line),
                      borderRadius: const BorderRadius.all(TH.r4),
                    ),
                    padding: const EdgeInsets.all(TH.s14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('── vacation',
                            style:
                                TextStyle(color: col.fgMute, fontSize: 11)),
                        const SizedBox(height: TH.s8),

                        // Active vacations (today is in range)
                        for (final v in activeVacs) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_fmtShort(v.start)} → ${_fmtShort(v.end)}',
                                  style: TextStyle(
                                      color: col.amber, fontSize: 12),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _endVacation(v.id),
                                child: Text('[end now]',
                                    style: TextStyle(
                                        color: col.red, fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: TH.s8),
                        ],

                        // Buttons row
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _addVacation(col, user.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: TH.s8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: col.line2),
                                  borderRadius:
                                      const BorderRadius.all(TH.r4),
                                ),
                                child: Text('[add vacation]',
                                    style: TextStyle(
                                        color: col.fgDim, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: TH.s8),
                            GestureDetector(
                              onTap: () =>
                                  showVacationManager(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: TH.s8, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: col.line2),
                                  borderRadius:
                                      const BorderRadius.all(TH.r4),
                                ),
                                child: Text('[manage]',
                                    style: TextStyle(
                                        color: col.fgDim, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TH.s22),

                  // ── Log out ──
                  GestureDetector(
                    onTap: _logOut,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s14, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.red),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text('[ log out ]',
                          style: TextStyle(color: col.red, fontSize: 12)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors col;
  const _InfoRow(this.label, this.value, {required this.col});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text('$label:',
                style: TextStyle(color: col.fgDim, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: col.fg, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day} ${d.year}';
}

String _fmtShort(DateTime d) {
  final local = d.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../../data/database.dart';
import '../../domain/health_service.dart';
import '../../domain/health_sync.dart';
import '../../domain/schedule.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';
import '../widgets/icon_picker.dart';
import 'new_group_dialog.dart';

class NewHabitDialog extends ConsumerStatefulWidget {
  final DateTime? defaultStartDate;
  const NewHabitDialog({super.key, this.defaultStartDate});

  static Future<void> show(
    BuildContext context, {
    DateTime? defaultStartDate,
  }) =>
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) =>
            NewHabitDialog(defaultStartDate: defaultStartDate),
      );

  @override
  ConsumerState<NewHabitDialog> createState() => _NewHabitDialogState();
}

class _NewHabitDialogState extends ConsumerState<NewHabitDialog> {
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  String _schedule = 'daily';
  String _color = 'green';
  String? _groupId;
  late DateTime _startDate =
      widget.defaultStartDate ?? DateTime.now();
  String _tracking = 'checkbox';
  String? _healthSource; // only set when _tracking == 'health'
  String? _iconKey;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
    _noteCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    int? target;
    String? unit;
    if (_tracking == 'counter') {
      target = int.tryParse(_targetCtrl.text.trim());
    } else if (_tracking == 'duration') {
      target = int.tryParse(_targetCtrl.text.trim());
      unit = 'min';
    } else if (_tracking == 'health') {
      final raw = int.tryParse(_targetCtrl.text.trim());
      final cfg = _healthSource != null ? kHealthSources[_healthSource!] : null;
      if (cfg == null || raw == null || raw <= 0) {
        // Missing source or invalid goal — bail silently; UI shows hints.
        return;
      }
      target = cfg.goalToInternal(raw);
      unit = cfg.storedUnit;
    }

    if (target != null && target > 999999) {
      if (!context.mounted) return;
      await _showTargetOverflowDialog(context);
      return;
    }

    // Prompt for Health Connect permission as a best-effort step. The habit
    // is created regardless — if permission is missing, the next on-open
    // sync just won't auto-complete it, and the user can grant access in
    // Health Connect → App permissions whenever they want.
    bool healthGranted = true;
    if (_tracking == 'health') {
      healthGranted =
          await HealthService.requestPermissions([_healthSource!]);
    }

    setState(() => _saving = true);

    final scheduleJson = switch (_schedule) {
      'weekdays' => weekdaySchedule(),
      'weekends' => weekendSchedule(),
      _ => dailySchedule(),
    };

    final db = ref.read(dbProvider);
    final userId = ref.read(currentUserIdProvider);
    final habits = await db.getActiveHabits(userId);
    await db.createHabit(HabitsCompanion.insert(
      userId: Value(userId),
      groupId: _groupId ?? 'general',
      name: name,
      icon: Value(_iconKey ?? 'circle'),
      color: Value(_color),
      tracking: _tracking,
      target: Value(target),
      unit: Value(unit),
      schedule: scheduleJson,
      note: Value(_noteCtrl.text.trim().isEmpty
          ? null
          : _noteCtrl.text.trim()),
      sortIndex: habits.length,
      startDate: Value(_startDate),
      endDate: Value(_endDate),
      healthSource: Value(_tracking == 'health' ? _healthSource : null),
    ));

    if (!mounted) return;
    if (_tracking == 'health' && !healthGranted) {
      // Habit is saved — just warn that auto-sync won't work until they grant.
      await _showHealthDeniedDialog(context);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDateRange() async {
    DateTime tempStart = _startDate;
    DateTime? tempEnd = _endDate;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final col = AppColors.of(ctx);
        return Dialog(
          backgroundColor: col.bg2,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(TH.r10)),
          child: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: TH.s14, vertical: TH.s8),
                  child: Row(
                    children: [
                      Text(r'$ date --range',
                          style:
                              TextStyle(color: col.fg, fontSize: 13)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Text('[done]',
                            style: TextStyle(
                                color: col.green, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                Divider(color: col.line, height: 1),
                Padding(
                  padding: const EdgeInsets.all(TH.s14),
                  child: SfDateRangePicker(
                    selectionMode:
                        DateRangePickerSelectionMode.range,
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
                      textStyle: TextStyle(
                          color: col.fg, fontSize: 12),
                      todayTextStyle: TextStyle(
                          color: col.green, fontSize: 12),
                      leadingDatesTextStyle: TextStyle(
                          color: col.fgFaint, fontSize: 12),
                      trailingDatesTextStyle: TextStyle(
                          color: col.fgFaint, fontSize: 12),
                    ),
                    yearCellStyle: DateRangePickerYearCellStyle(
                      textStyle: TextStyle(
                          color: col.fg, fontSize: 12),
                      todayTextStyle: TextStyle(
                          color: col.green, fontSize: 12),
                      leadingDatesTextStyle: TextStyle(
                          color: col.fgFaint, fontSize: 12),
                    ),
                    onSelectionChanged:
                        (DateRangePickerSelectionChangedArgs args) {
                      if (args.value is PickerDateRange) {
                        final range =
                            args.value as PickerDateRange;
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
      },
    );

    setState(() {
      _startDate = tempStart;
      // Same-day range = no end date (infinite habit).
      final end = tempEnd;
      final sameDay = end != null &&
          end.year == tempStart.year &&
          end.month == tempStart.month &&
          end.day == tempStart.day;
      _endDate = (end == null || sameDay) ? null : end;
    });
  }

  Future<void> _newGroup() async {
    final result = await NewGroupDialog.show(context);
    if (result == null) return;
    final db = ref.read(dbProvider);
    final created = await db.createGroup(
        ref.read(currentUserIdProvider), result.name,
        icon: result.icon, note: result.note);
    if (mounted) setState(() => _groupId = created.id);
  }

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final colorMap = {
      'green': col.green,
      'amber': col.amber,
      'blue': col.blue,
      'purple': col.purple,
      'teal': col.teal,
      'red': col.red,
    };
    final groupsAV = ref.watch(groupsProvider);
    final groups = groupsAV.valueOrNull ?? const <Group>[];
    if (_groupId == null && groups.isNotEmpty) {
      _groupId = groups.any((g) => g.id == 'general')
          ? 'general'
          : groups.first.id;
    }

    final iconData = lucideIconData(_iconKey);
    final iconColor = colorMap[_color] ?? col.green;

    return Dialog(
      backgroundColor: col.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(TH.r10)),
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(TH.s14, TH.s8, TH.s14, TH.s14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header bar ─────────────────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('[cancel]',
                        style:
                            TextStyle(color: col.fgMute, fontSize: 12)),
                  ),
                  const Spacer(),
                  Text(r'$ habit --new',
                      style: TextStyle(color: col.fg, fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Text(
                      _saving ? 'saving...' : '[save]',
                      style: TextStyle(
                          color: _saving ? col.fgMute : col.green,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TH.s8),
              Divider(color: col.line, height: 1),

              // ── Body ────────────────────────────────────────────────────────
              // / name ─────────────────────────────────────────────────
                    _SecHeader(LucideIcons.pencil, 'name', col: col),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final key = await IconPickerDialog.show(
                                context,
                                initial: _iconKey);
                            if (key != null) {
                              setState(() => _iconKey = key);
                            }
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            margin: const EdgeInsets.only(
                                right: TH.s8, top: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: col.line2),
                              borderRadius:
                                  const BorderRadius.all(TH.r4),
                              color: col.bg1,
                            ),
                            child: Center(
                              child: Icon(
                                iconData ?? LucideIcons.circle,
                                size: 14,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _CountedField(
                            controller: _nameCtrl,
                            hint: 'e.g. meditate, journal',
                            maxChars: 50,
                            col: col,
                            autofocus: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(
                                  RegExp(r'\n')),
                              LengthLimitingTextInputFormatter(50),
                            ],
                            onSubmitted: (_) => _save(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TH.s8),
                    _CountedField(
                      controller: _noteCtrl,
                      hint: 'comment (optional)',
                      maxChars: 30,
                      col: col,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\n')),
                        LengthLimitingTextInputFormatter(30),
                      ],
                    ),

                    // 📅 dates ────────────────────────────────────────────
                    _SecHeader(LucideIcons.calendar, 'dates', col: col),
                    _DateRow(
                      label: 'start',
                      value: _formatDate(_startDate),
                      col: col,
                      onTap: _pickDateRange,
                    ),
                    const SizedBox(height: TH.s8),
                    Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text('end',
                              style: TextStyle(
                                  color: col.fgDim, fontSize: 12)),
                        ),
                        GestureDetector(
                          onTap: _pickDateRange,
                          child: Text(
                            _endDate != null
                                ? _formatDate(_endDate!)
                                : 'no end date',
                            style: TextStyle(
                                color: _endDate != null
                                    ? col.fg
                                    : col.fgFaint,
                                fontSize: 12),
                          ),
                        ),
                        if (_endDate != null) ...[
                          const SizedBox(width: TH.s8),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _endDate = null),
                            child: Text('[clear]',
                                style: TextStyle(
                                    color: col.fgMute,
                                    fontSize: 11)),
                          ),
                        ],
                      ],
                    ),

                    // ○ schedule ───────────────────────────────────────────
                    _SecHeader(LucideIcons.clock, 'schedule', col: col),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final s in ['daily', 'weekdays', 'weekends'])
                          _Pill(
                            label: s,
                            selected: _schedule == s,
                            col: col,
                            onTap: () =>
                                setState(() => _schedule = s),
                          ),
                      ],
                    ),

                    // ≡ tracking ─────────────────────────────────────────
                    _SecHeader(LucideIcons.settings, 'tracking', col: col),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final t in [
                          'checkbox',
                          'counter',
                          'duration',
                          if (Platform.isAndroid) 'health',
                        ])
                          _Pill(
                            label: t,
                            selected: _tracking == t,
                            col: col,
                            onTap: () => setState(() {
                              _tracking = t;
                              _targetCtrl.clear();
                              if (t != 'health') _healthSource = null;
                              if (t == 'health') _healthSource ??= 'steps';
                            }),
                          ),
                      ],
                    ),
                    if (_tracking == 'health') ...[
                      const SizedBox(height: TH.s8),
                      Text('// source',
                          style: TextStyle(
                              color: col.fgMute, fontSize: 11)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final s in kHealthSources.keys)
                            _Pill(
                              label: s,
                              selected: _healthSource == s,
                              col: col,
                              onTap: () => setState(() {
                                _healthSource = s;
                                _targetCtrl.clear();
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: TH.s8),
                      Row(
                        children: [
                          SizedBox(
                            width: 96,
                            child: TextField(
                              controller: _targetCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              style: TextStyle(
                                  color: col.fg, fontSize: 13),
                              decoration: _fieldDeco(
                                _healthSource != null
                                    ? kHealthSources[_healthSource!]!.hint
                                    : '',
                                col,
                              ),
                              onSubmitted: (_) => _save(),
                            ),
                          ),
                          const SizedBox(width: TH.s8),
                          Text(
                            _healthSource != null
                                ? 'daily goal (${kHealthSources[_healthSource!]!.goalUnitLabel})'
                                : 'daily goal',
                            style: TextStyle(
                                color: col.fgMute, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: TH.s8),
                      GestureDetector(
                        onTap: () async {
                          final source = _healthSource;
                          if (source == null) return;
                          final msg = await HealthService.diagnose(source);
                          if (!context.mounted) return;
                          await showDialog<void>(
                            context: context,
                            barrierColor: Colors.black54,
                            builder: (ctx) => Dialog(
                              backgroundColor: col.bg2,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      const BorderRadius.all(TH.r10)),
                              child: SizedBox(
                                width: 360,
                                child: Padding(
                                  padding: const EdgeInsets.all(TH.s22),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('health connect — $source',
                                          style: TextStyle(
                                              color: col.fg,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: TH.s8),
                                      Text(msg,
                                          style: TextStyle(
                                              color: col.fg, fontSize: 12)),
                                      const SizedBox(height: TH.s22),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          GestureDetector(
                                            onTap: () =>
                                                Navigator.of(ctx).pop(),
                                            child: Text('[ ok ]',
                                                style: TextStyle(
                                                    color: col.green,
                                                    fontSize: 13)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: TH.s8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: col.line2),
                            borderRadius: const BorderRadius.all(TH.r4),
                          ),
                          child: Text('[ test health connect ]',
                              style: TextStyle(
                                  color: col.fgDim, fontSize: 11)),
                        ),
                      ),
                    ],
                    if (_tracking == 'counter' ||
                        _tracking == 'duration') ...[
                      const SizedBox(height: TH.s8),
                      Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: TextField(
                              controller: _targetCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              style: TextStyle(
                                  color: col.fg, fontSize: 13),
                              decoration: _fieldDeco(
                                _tracking == 'duration' ? '30' : '10',
                                col,
                              ),
                              onSubmitted: (_) => _save(),
                            ),
                          ),
                          const SizedBox(width: TH.s8),
                          Text(
                            _tracking == 'duration'
                                ? 'target min'
                                : 'min count',
                            style: TextStyle(
                                color: col.fgMute, fontSize: 12),
                          ),
                        ],
                      ),
                    ],

                    // ◎ color ────────────────────────────────────────────
                    _SecHeader(LucideIcons.palette, 'color', col: col),
                    Row(
                      children: [
                        for (final c in colorMap.keys)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _ColorDot(
                              color: colorMap[c]!,
                              selected: _color == c,
                              onTap: () =>
                                  setState(() => _color = c),
                            ),
                          ),
                      ],
                    ),

                    // # group ─────────────────────────────────────────────
                    _SecHeader(LucideIcons.tag, 'group', col: col),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final g in groups)
                          _Pill(
                            label: g.name,
                            selected: _groupId == g.id,
                            col: col,
                            onTap: () =>
                                setState(() => _groupId = g.id),
                          ),
                        _Pill(
                          label: '+ new',
                          selected: false,
                          accent: true,
                          col: col,
                          onTap: _newGroup,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

Future<void> _showTargetOverflowDialog(BuildContext context) {
  final col = AppColors.of(context);
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: col.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('target too large',
                  style: TextStyle(
                      color: col.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s8),
              Text('target must be 999999 or less.',
                  style:
                      TextStyle(color: col.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s22),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: TH.s22, vertical: TH.s8),
                    decoration: BoxDecoration(
                      border: Border.all(color: col.green),
                      borderRadius:
                          const BorderRadius.all(TH.r4),
                    ),
                    child: Text('[ understood ]',
                        style: TextStyle(
                            color: col.green, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _showHealthDeniedDialog(BuildContext context) {
  final col = AppColors.of(context);
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: col.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('health connect permission needed',
                  style: TextStyle(
                      color: col.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s8),
              Text(
                'the habit is saved, but auto-completion needs read\n'
                'access to health connect data. to grant it:',
                style: TextStyle(color: col.fgDim, fontSize: 12),
              ),
              const SizedBox(height: TH.s14),
              Text(
                '1. open the health connect app\n'
                '2. tap "app permissions"\n'
                '3. find "TerminalHabits"\n'
                '4. toggle on the data you want (steps, etc.)',
                style: TextStyle(color: col.fg, fontSize: 12),
              ),
              const SizedBox(height: TH.s8),
              Text(
                "// then reopen this app or pull-to-refresh and the habit\n// will auto-complete when you've hit the goal.",
                style: TextStyle(color: col.fgFaint, fontSize: 11),
              ),
              const SizedBox(height: TH.s22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s22, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.green),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text('[ got it ]',
                          style:
                              TextStyle(color: col.green, fontSize: 13)),
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

InputDecoration _fieldDeco(String hint, AppColors col) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: col.fgFaint, fontSize: 13),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: col.line2),
        borderRadius: const BorderRadius.all(TH.r4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: col.green),
        borderRadius: const BorderRadius.all(TH.r4),
      ),
      fillColor: col.bg1,
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: TH.s8, vertical: TH.s8),
    );

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day} ${d.year}';
}

// ── Section header ─────────────────────────────────────────────────────────

class _SecHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColors col;
  const _SecHeader(this.icon, this.label, {required this.col});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: TH.s22, bottom: TH.s8),
      child: Row(
        children: [
          Icon(icon, size: 11, color: col.fgMute),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: col.fgDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Counted text field (label + N/max counter above field) ─────────────────

class _CountedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxChars;
  final AppColors col;
  final bool autofocus;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String>? onSubmitted;

  const _CountedField({
    required this.controller,
    required this.hint,
    required this.maxChars,
    required this.col,
    this.autofocus = false,
    this.inputFormatters = const [],
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          autofocus: autofocus,
          style: TextStyle(color: col.fg, fontSize: 13),
          decoration: _fieldDeco(hint, col),
          inputFormatters: inputFormatters,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 2),
        Text(
          '${controller.text.length}/$maxChars',
          style: TextStyle(color: col.fgMute, fontSize: 10),
        ),
      ],
    );
  }
}

// ── Date row ───────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors col;
  final VoidCallback onTap;
  const _DateRow({
    required this.label,
    required this.value,
    required this.col,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: TextStyle(color: col.fgDim, fontSize: 12)),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(value,
              style: TextStyle(color: col.fg, fontSize: 12)),
        ),
      ],
    );
  }
}

// ── Pill ───────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;
  final AppColors col;
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.col,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? col.green
        : accent
            ? col.amber
            : col.line2;
    final textColor = selected
        ? col.green
        : accent
            ? col.amber
            : col.fgDim;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: TH.s8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: const BorderRadius.all(TH.r4),
          color: selected ? col.bg3 : Colors.transparent,
        ),
        child: Text(label,
            style: TextStyle(color: textColor, fontSize: 12)),
      ),
    );
  }
}

// ── Color dot ──────────────────────────────────────────────────────────────

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorDot(
      {required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 1.0 : 0.4),
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Colors.white24, width: 2)
              : null,
        ),
      ),
    );
  }
}

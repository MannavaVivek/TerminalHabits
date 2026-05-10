import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../domain/schedule.dart';
import '../../domain/streaks.dart' show localMidnightUtc;
import '../../state/providers.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';
import '../widgets/icon_picker.dart';
import 'new_group_dialog.dart';

class EditHabitDialog extends ConsumerStatefulWidget {
  final Habit habit;
  const EditHabitDialog({super.key, required this.habit});

  static Future<void> show(BuildContext context, Habit habit) => showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => EditHabitDialog(habit: habit),
      );

  @override
  ConsumerState<EditHabitDialog> createState() => _EditHabitDialogState();
}

class _EditHabitDialogState extends ConsumerState<EditHabitDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _targetCtrl;
  late String _scheduleKey;
  late String _color;
  late String _groupId;
  late DateTime _startDate;
  late String _tracking;
  DateTime? _endDate;
  String? _iconKey;
  bool _saving = false;
  bool _hasCompletions = false;
  List<Completion> _completions = const [];

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _nameCtrl = TextEditingController(text: h.name);
    _noteCtrl = TextEditingController(text: h.note ?? '');
    _targetCtrl = TextEditingController(
        text: h.target != null ? '${h.target}' : '');
    // If the stored icon is a lucide key, use it; otherwise keep null
    // (the preview will show the fallback icon).
    _iconKey = lucideIconData(h.icon) != null ? h.icon : null;
    _scheduleKey = _scheduleKeyFromJson(h.schedule);
    _color = h.color;
    _groupId = h.groupId;
    _startDate = h.startDate;
    _tracking = h.tracking;
    _endDate = h.endDate;
    _loadCompletionFlag();
  }

  Future<void> _loadCompletionFlag() async {
    final comps =
        await ref.read(dbProvider).getCompletionsForHabit(widget.habit.id);
    if (mounted) setState(() {
      _completions = comps;
      _hasCompletions = comps.isNotEmpty;
    });
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

    final newScheduleJson = _scheduleJsonFromKey(_scheduleKey);
    final scheduleChanged = newScheduleJson != widget.habit.schedule;
    final typeChanged = _tracking != widget.habit.tracking;
    final newStartUtc = localMidnightUtc(_startDate);
    final oldStartUtc = localMidnightUtc(widget.habit.startDate);
    final startMovedLater = newStartUtc.isAfter(oldStartUtc);

    // Pre-compute schedule overlap so we can choose the right warning and action.
    final oldDays = scheduleChanged
        ? (jsonDecode(widget.habit.schedule)['days'] as List).cast<int>().toSet()
        : const <int>{};
    final newDays = scheduleChanged
        ? (jsonDecode(newScheduleJson)['days'] as List).cast<int>().toSet()
        : const <int>{};
    final removedDays = oldDays.difference(newDays); // days leaving the schedule
    final noOverlap = scheduleChanged && oldDays.intersection(newDays).isEmpty;
    final isExpanding = scheduleChanged && newDays.containsAll(oldDays);
    final isContracting = scheduleChanged && !isExpanding && !noOverlap;

    // ── warnings ─────────────────────────────────────────────────────────────

    // Type change clears everything — show first, it's the most severe.
    if (typeChanged && _hasCompletions) {
      if (!mounted) return;
      final ok = await _warnDestructive(
        context,
        'Tracking type changed',
        'Changing the tracking type permanently deletes all recorded '
            'completions for this habit. This cannot be undone.',
      );
      if (ok != true) return;
    }

    // Schedule change — skip if type also changed (type warning already covers it).
    if (scheduleChanged && _hasCompletions && !typeChanged) {
      if (!mounted) return;
      final String title;
      final String body;
      if (noOverlap) {
        title = 'Schedule changed';
        body = 'There is no overlap between the old and new schedules. '
            'All recorded completions will be permanently deleted. '
            'This cannot be undone.';
      } else if (isContracting) {
        final removed = _dayNames(removedDays);
        final kept = _dayNames(newDays);
        title = 'Schedule narrowed';
        body = 'Completions on $removed will be permanently deleted. '
            'Completions on $kept are preserved. '
            'This cannot be undone.';
      } else {
        // Expanding (e.g. weekdays/weekends → daily).
        final added = _dayNames(newDays.difference(oldDays));
        title = 'Schedule expanded';
        body = '$added will be added to the tracked schedule. '
            'Existing completions are kept, but your streak will reset '
            'because those days have no prior completions. '
            'This cannot be undone.';
      }
      final ok = await _warnDestructive(context, title, body);
      if (ok != true) return;
    }

    // Start date moved later — only if no other change already clears data.
    if (!typeChanged && !scheduleChanged && startMovedLater) {
      final hasEarlierComps =
          _completions.any((c) => c.day.toUtc().isBefore(newStartUtc));
      if (hasEarlierComps) {
        if (!mounted) return;
        final ok = await _warnDestructive(
          context,
          'Start date moved forward',
          'Moving the start date to ${_formatDate(_startDate)} permanently '
              'deletes all completions recorded before that date. '
              'This cannot be undone.',
        );
        if (ok != true) return;
      }
    }

    // ── target validation ────────────────────────────────────────────────────
    int? target;
    String? unit;
    if (_tracking == 'counter') {
      target = int.tryParse(_targetCtrl.text.trim());
    } else if (_tracking == 'duration') {
      target = int.tryParse(_targetCtrl.text.trim());
      unit = 'min';
    }

    if (target != null && target > 999) {
      if (!mounted) return;
      await _showTargetTooLarge(context);
      return;
    }

    setState(() => _saving = true);

    final db = ref.read(dbProvider);

    // ── data cleanup ─────────────────────────────────────────────────────────
    if (typeChanged) {
      // Clears all completions and resets schedule history.
      await db.clearHabitProgress(
          widget.habit.id, newStartUtc, newScheduleJson, _tracking);
    } else if (scheduleChanged) {
      if (noOverlap) {
        // No shared days — delete everything.
        await db.clearHabitProgress(
            widget.habit.id, newStartUtc, newScheduleJson, _tracking);
      } else if (isContracting) {
        // Remove completions only on days leaving the schedule; keep the rest.
        await db.clearCompletionsOnDays(widget.habit.id, removedDays);
        await db.replaceScheduleHistory(
            widget.habit.id, newStartUtc, newScheduleJson, _tracking);
      } else {
        // Expanding — keep all completions, just update schedule history.
        await db.replaceScheduleHistory(
            widget.habit.id, newStartUtc, newScheduleJson, _tracking);
      }
    } else if (startMovedLater) {
      await db.clearCompletionsBefore(widget.habit.id, newStartUtc);
    }

    await db.patchHabit(
      widget.habit.id,
      HabitsCompanion(
        name: Value(name),
        icon: Value(_iconKey ?? widget.habit.icon),
        color: Value(_color),
        tracking: Value(_tracking),
        target: Value(target),
        unit: Value(unit),
        schedule: Value(newScheduleJson),
        note: Value(_noteCtrl.text.trim().isEmpty
            ? null
            : _noteCtrl.text.trim()),
        groupId: Value(_groupId),
        startDate: Value(_startDate),
        endDate: Value(_endDate),
      ),
    );

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: TH.green,
            onPrimary: TH.bg,
            surface: TH.bg2,
            onSurface: TH.fg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: TH.green,
            onPrimary: TH.bg,
            surface: TH.bg2,
            onSurface: TH.fg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _newGroup() async {
    final result = await NewGroupDialog.show(context);
    if (result == null) return;
    final created = await ref.read(dbProvider).createGroup(
        ref.read(currentUserIdProvider), result.name,
        icon: result.icon, note: result.note);
    if (mounted) setState(() => _groupId = created.id);
  }

  @override
  Widget build(BuildContext context) {
    final groupsAV = ref.watch(groupsProvider);
    final groups = groupsAV.valueOrNull ?? const <Group>[];

    return Dialog(
      backgroundColor: TH.bg2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('edit habit',
                      style: TextStyle(
                          color: TH.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text('[ cancel ]',
                        style:
                            TextStyle(color: TH.fgMute, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: TH.s14),
              _Label('name'),
              _StyledField(
                controller: _nameCtrl,
                hint: 'habit name',
                maxLength: 60,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: TH.s14),
              _Label('group'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in groups)
                    _Pill(
                      label: g.name,
                      selected: _groupId == g.id,
                      onTap: () => setState(() => _groupId = g.id),
                    ),
                  _Pill(
                    label: '+ new',
                    selected: false,
                    accent: true,
                    onTap: _newGroup,
                  ),
                ],
              ),
              const SizedBox(height: TH.s14),
              _Label('schedule'),
              Row(
                children: [
                  for (final s in const ['daily', 'weekdays', 'weekends'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Pill(
                        label: s,
                        selected: _scheduleKey == s,
                        onTap: () =>
                            setState(() => _scheduleKey = s),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: TH.s14),
              _Label('type'),
              Row(
                children: [
                  for (final t in const [
                    'checkbox',
                    'counter',
                    'duration'
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Pill(
                        label: t,
                        selected: _tracking == t,
                        onTap: () => setState(() {
                          _tracking = t;
                          _targetCtrl.clear();
                        }),
                      ),
                    ),
                ],
              ),
              if (_tracking == 'counter') ...[
                const SizedBox(height: TH.s8),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: _StyledField(
                        controller: _targetCtrl,
                        hint: '10',
                        keyboardType: TextInputType.number,
                        digitsOnly: true,
                        maxLength: 3,
                      ),
                    ),
                    const SizedBox(width: TH.s8),
                    const Text('min count',
                        style: TextStyle(
                            color: TH.fgMute, fontSize: 12)),
                  ],
                ),
              ],
              if (_tracking == 'duration') ...[
                const SizedBox(height: TH.s8),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: _StyledField(
                        controller: _targetCtrl,
                        hint: '30',
                        keyboardType: TextInputType.number,
                        digitsOnly: true,
                        maxLength: 3,
                      ),
                    ),
                    const SizedBox(width: TH.s8),
                    const Text('target min',
                        style: TextStyle(
                            color: TH.fgMute, fontSize: 12)),
                  ],
                ),
              ],
              const SizedBox(height: TH.s14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('icon'),
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                border: Border.all(color: TH.line2),
                                borderRadius: BorderRadius.all(TH.r4),
                                color: TH.bg1,
                              ),
                              child: Center(
                                child: () {
                                  final d = lucideIconData(_iconKey) ??
                                      lucideIconData(widget.habit.icon);
                                  final c = _colorMap[_color] ?? TH.green;
                                  return d != null
                                      ? Icon(d, size: 18, color: c)
                                      : Text(widget.habit.icon,
                                          style: TextStyle(
                                              color: c, fontSize: 16));
                                }(),
                              ),
                            ),
                            const SizedBox(width: TH.s8),
                            GestureDetector(
                              onTap: () async {
                                final key = await IconPickerDialog.show(
                                    context,
                                    initial: _iconKey ??
                                        (lucideIconData(widget.habit.icon) !=
                                                null
                                            ? widget.habit.icon
                                            : null));
                                if (key != null) {
                                  setState(() => _iconKey = key);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: TH.s8, vertical: TH.s4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: TH.line2),
                                  borderRadius: BorderRadius.all(TH.r4),
                                ),
                                child: const Text('[ pick icon ]',
                                    style: TextStyle(
                                        color: TH.fgDim, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TH.s14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('color'),
                      Row(
                        children: [
                          for (final c in _colorMap.keys)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ColorDot(
                                color: _colorMap[c]!,
                                selected: _color == c,
                                onTap: () => setState(() => _color = c),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: TH.s14),
              _Label('start date'),
              GestureDetector(
                onTap: _pickStartDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: TH.s8, vertical: TH.s8),
                  decoration: BoxDecoration(
                    border: Border.all(color: TH.line2),
                    borderRadius: BorderRadius.all(TH.r4),
                  ),
                  child: Text(
                    _formatDate(_startDate),
                    style: const TextStyle(color: TH.fg, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: TH.s14),
              _Label('end date (optional)'),
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickEndDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s8, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: TH.line2),
                        borderRadius: BorderRadius.all(TH.r4),
                      ),
                      child: Text(
                        _endDate != null
                            ? _formatDate(_endDate!)
                            : '— no end date —',
                        style: TextStyle(
                            color:
                                _endDate != null ? TH.fg : TH.fgFaint,
                            fontSize: 13),
                      ),
                    ),
                  ),
                  if (_endDate != null) ...[
                    const SizedBox(width: TH.s8),
                    GestureDetector(
                      onTap: () => setState(() => _endDate = null),
                      child: const Text('[ clear ]',
                          style: TextStyle(
                              color: TH.fgMute, fontSize: 12)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: TH.s14),
              _Label('note (optional)'),
              _StyledField(
                controller: _noteCtrl,
                hint: '// shown under the row',
                maxLines: 1,
                maxLength: 100,
                denyNewlines: true,
              ),
              const SizedBox(height: TH.s22),
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: TH.s8),
                  decoration: BoxDecoration(
                    border: Border.all(color: TH.green),
                    borderRadius: BorderRadius.all(TH.r4),
                  ),
                  child: Center(
                    child: Text(
                      _saving ? 'saving...' : '[ save ]',
                      style: const TextStyle(
                          color: TH.green, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _colorMap = {
    'green': TH.green,
    'amber': TH.amber,
    'blue': TH.blue,
    'purple': TH.purple,
    'teal': TH.teal,
    'red': TH.red,
  };
}

String _scheduleKeyFromJson(String json) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  final days = (map['days'] as List).cast<int>()..sort();
  if (days.length == 7) return 'daily';
  if (days.length == 5 && days.first == 0 && days.last == 4) return 'weekdays';
  if (days.length == 2 && days.first == 5) return 'weekends';
  return 'daily';
}

String _scheduleJsonFromKey(String key) {
  switch (key) {
    case 'weekdays':
      return weekdaySchedule();
    case 'weekends':
      return weekendSchedule();
    default:
      return dailySchedule();
  }
}

// Formats a set of weekday indices (0=Mon..6=Sun) as a human-readable list.
String _dayNames(Set<int> days) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return (days.toList()..sort()).map((d) => names[d]).join(', ');
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day} ${d.year}';
}

// Destructive-action confirmation: returns true (proceed) or false/null (cancel).
Future<bool?> _warnDestructive(
        BuildContext context, String title, String body) =>
    showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: TH.bg2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(TH.r10)),
        child: SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.all(TH.s22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: TH.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: TH.s8),
                Text(body,
                    style: const TextStyle(
                        color: TH.fgDim, fontSize: 12)),
                const SizedBox(height: TH.s22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: const Text('[ cancel ]',
                          style: TextStyle(
                              color: TH.fgMute, fontSize: 12)),
                    ),
                    const SizedBox(width: TH.s14),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: TH.s14, vertical: TH.s8),
                        decoration: BoxDecoration(
                          border: Border.all(color: TH.red),
                          borderRadius: BorderRadius.all(TH.r4),
                        ),
                        child: const Text('[ proceed ]',
                            style: TextStyle(
                                color: TH.red, fontSize: 12)),
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

Future<void> _showTargetTooLarge(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: TH.bg2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(TH.r10)),
        child: SizedBox(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.all(TH.s22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Target too large',
                    style: TextStyle(
                        color: TH.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: TH.s8),
                const Text('Target must be 999 or less.',
                    style: TextStyle(
                        color: TH.fgDim, fontSize: 12)),
                const SizedBox(height: TH.s22),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s22, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: TH.green),
                        borderRadius: BorderRadius.all(TH.r4),
                      ),
                      child: const Text('[ understood ]',
                          style: TextStyle(
                              color: TH.green, fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: TH.s4),
        child: Text(text,
            style: const TextStyle(color: TH.fgDim, fontSize: 12)),
      );
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool denyNewlines;
  final bool digitsOnly;
  final void Function(String)? onSubmitted;

  const _StyledField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.denyNewlines = false,
    this.digitsOnly = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final formatters = <TextInputFormatter>[
      if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
      if (maxLength != null && digitsOnly)
        LengthLimitingTextInputFormatter(maxLength),
      if (denyNewlines) FilteringTextInputFormatter.deny(RegExp(r'\n')),
    ];
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: formatters.isEmpty ? null : formatters,
      style: const TextStyle(color: TH.fg, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: TH.fgFaint, fontSize: 14),
        counterText: '',
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: TH.line2),
          borderRadius: BorderRadius.all(TH.r4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: TH.green),
          borderRadius: BorderRadius.all(TH.r4),
        ),
        fillColor: TH.bg1,
        filled: true,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: TH.s8, vertical: TH.s8),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? TH.green
        : accent
            ? TH.amber
            : TH.line2;
    final textColor = selected
        ? TH.green
        : accent
            ? TH.amber
            : TH.fgDim;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: TH.s8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.all(TH.r4),
          color: selected ? TH.bg3 : Colors.transparent,
        ),
        child: Text(label,
            style: TextStyle(color: textColor, fontSize: 12)),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

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

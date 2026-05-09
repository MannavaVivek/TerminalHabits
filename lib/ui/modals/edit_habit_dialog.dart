import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../domain/schedule.dart';
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
  late String _originalTracking;
  String? _iconKey;
  bool _saving = false;
  bool _hasCompletions = false;

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
    _originalTracking = h.tracking;
    _loadCompletionFlag();
  }

  Future<void> _loadCompletionFlag() async {
    final comps =
        await ref.read(dbProvider).getCompletionsForHabit(widget.habit.id);
    if (mounted) setState(() => _hasCompletions = comps.isNotEmpty);
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

    // Step 1: warn if tracking type changed while completions exist.
    if (_tracking != _originalTracking && _hasCompletions) {
      if (!mounted) return;
      await _warnTypeChange(context);
      if (!mounted) return;
    }

    // Step 2: warn if schedule change will orphan past completions.
    if (scheduleChanged && _hasCompletions) {
      final losing = await _completionsOnDroppedDays(
          widget.habit, newScheduleJson);
      if (losing > 0) {
        if (!mounted) return;
        final go = await _confirmScheduleOverwrite(context, losing);
        if (!go) return;
      }
    }

    setState(() => _saving = true);

    int? target;
    String? unit;
    if (_tracking == 'counter') {
      target = int.tryParse(_targetCtrl.text.trim());
      unit = null;
    } else if (_tracking == 'duration') {
      target = int.tryParse(_targetCtrl.text.trim());
      unit = 'min';
    }

    final db = ref.read(dbProvider);
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
      ),
    );

    if (mounted) Navigator.of(context).pop();
  }

  // Counts completions on days the new schedule no longer flags as due.
  Future<int> _completionsOnDroppedDays(
      Habit current, String newScheduleJson) async {
    final db = ref.read(dbProvider);
    final comps = await db.getCompletionsForHabit(current.id);
    final patched = current.copyWith(schedule: newScheduleJson);
    var count = 0;
    for (final c in comps) {
      if (!isHabitDueOn(patched, c.day.toLocal())) count++;
    }
    return count;
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

  Future<void> _newGroup() async {
    final result = await NewGroupDialog.show(context);
    if (result == null) return;
    final created = await ref
        .read(dbProvider)
        .createGroup(result.name, icon: result.icon, note: result.note);
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

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day} ${d.year}';
}

Future<void> _warnTypeChange(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: TH.bg2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(TH.r10)),
        child: SizedBox(
          width: 380,
          child: Padding(
            padding: const EdgeInsets.all(TH.s22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('tracking type changed',
                    style: TextStyle(
                        color: TH.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: TH.s8),
                const Text(
                  'existing completions are kept, but done-logic and '
                  'progress display will reflect the new type. '
                  'past streaks may shift.',
                  style: TextStyle(color: TH.fgDim, fontSize: 12),
                ),
                const SizedBox(height: TH.s22),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s22, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: TH.amber),
                        borderRadius: BorderRadius.all(TH.r4),
                      ),
                      child: const Text('[ understood ]',
                          style: TextStyle(
                              color: TH.amber, fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

Future<bool> _confirmScheduleOverwrite(
    BuildContext context, int losingCount) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: TH.bg2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('overwrite past completions?',
                  style: TextStyle(
                      color: TH.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s8),
              Text(
                '$losingCount completion${losingCount == 1 ? '' : 's'} '
                'fall on days the new schedule no longer covers.\n'
                "they'll stay in the database but stop counting toward "
                'streaks/stats. (phase 5 will preserve full history.)',
                style: const TextStyle(color: TH.fgDim, fontSize: 12),
              ),
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
                        border: Border.all(color: TH.amber),
                        borderRadius: BorderRadius.all(TH.r4),
                      ),
                      child: const Text('[ overwrite ]',
                          style: TextStyle(
                              color: TH.amber, fontSize: 12)),
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
  return ok ?? false;
}

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
  final void Function(String)? onSubmitted;

  const _StyledField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.denyNewlines = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: denyNewlines
          ? [FilteringTextInputFormatter.deny(RegExp(r'\n'))]
          : null,
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

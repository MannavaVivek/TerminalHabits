import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/database.dart';
import '../../domain/schedule.dart';
import '../../state/providers.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';
import '../widgets/icon_picker.dart';
import 'new_group_dialog.dart';

class NewHabitDialog extends ConsumerStatefulWidget {
  // Pre-fills the start date. Pass selectedDay when opening from the daily
  // view so a habit added while looking at last Tuesday starts on Tuesday.
  // Leave null when opening from the command palette / ⌘N (defaults to today).
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
  String? _iconKey;
  DateTime? _endDate;
  bool _saving = false;

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
      unit = null;
    } else if (_tracking == 'duration') {
      target = int.tryParse(_targetCtrl.text.trim());
      unit = 'min';
    }

    if (target != null && target > 999) {
      if (!context.mounted) return;
      await _showTargetOverflowDialog(context);
      return;
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
    ));

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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
      initialDate: _endDate ?? _startDate,
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
    final db = ref.read(dbProvider);
    final created = await db.createGroup(
        ref.read(currentUserIdProvider), result.name,
        icon: result.icon, note: result.note);
    if (mounted) setState(() => _groupId = created.id);
  }

  @override
  Widget build(BuildContext context) {
    final groupsAV = ref.watch(groupsProvider);
    final groups = groupsAV.valueOrNull ?? const <Group>[];
    if (_groupId == null && groups.isNotEmpty) {
      _groupId = groups.any((g) => g.id == 'general')
          ? 'general'
          : groups.first.id;
    }

    final iconData = lucideIconData(_iconKey);
    final iconColor = _colorMap[_color] ?? TH.green;

    return Dialog(
      backgroundColor: TH.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('new habit',
                      style: TextStyle(
                          color: TH.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text('[ cancel ]',
                        style: TextStyle(
                            color: TH.fgMute, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: TH.s22),

              // ── name ─────────────────────────────────────────────
              _Label('name'),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                maxLength: 60,
                style: const TextStyle(color: TH.fg, fontSize: 14),
                decoration: _fieldDeco('e.g. meditate, read, journal'),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n')),
                ],
                onSubmitted: (_) => _save(),
              ),

              // ── icon + color (side by side) ───────────────────────
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
                                borderRadius:
                                    BorderRadius.all(TH.r4),
                                color: TH.bg1,
                              ),
                              child: Center(
                                child: iconData != null
                                    ? Icon(iconData,
                                        size: 18, color: iconColor)
                                    : Icon(LucideIcons.circle,
                                        size: 18, color: iconColor),
                              ),
                            ),
                            const SizedBox(width: TH.s8),
                            GestureDetector(
                              onTap: () async {
                                final key =
                                    await IconPickerDialog.show(
                                        context,
                                        initial: _iconKey);
                                if (key != null) {
                                  setState(() => _iconKey = key);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: TH.s8,
                                    vertical: TH.s4),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: TH.line2),
                                  borderRadius:
                                      BorderRadius.all(TH.r4),
                                ),
                                child: const Text('[ pick ]',
                                    style: TextStyle(
                                        color: TH.fgDim,
                                        fontSize: 12)),
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
                              padding:
                                  const EdgeInsets.only(right: 8),
                              child: _ColorDot(
                                color: _colorMap[c]!,
                                selected: _color == c,
                                onTap: () =>
                                    setState(() => _color = c),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // ── group ─────────────────────────────────────────────
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

              // ── schedule ──────────────────────────────────────────
              const SizedBox(height: TH.s14),
              _Label('schedule'),
              Row(
                children: [
                  for (final s in ['daily', 'weekdays', 'weekends'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Pill(
                        label: s,
                        selected: _schedule == s,
                        onTap: () =>
                            setState(() => _schedule = s),
                      ),
                    ),
                ],
              ),

              // ── tracking type ─────────────────────────────────────
              const SizedBox(height: TH.s14),
              _Label('type'),
              Row(
                children: [
                  for (final t in ['checkbox', 'counter', 'duration'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Pill(
                        label: t,
                        selected: _tracking == t,
                        onTap: () {
                          setState(() {
                            _tracking = t;
                            _targetCtrl.clear();
                          });
                        },
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
                      child: TextField(
                        controller: _targetCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        style: const TextStyle(
                            color: TH.fg, fontSize: 13),
                        decoration: _fieldDeco('10'),
                        onSubmitted: (_) => _save(),
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
                      child: TextField(
                        controller: _targetCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        style: const TextStyle(
                            color: TH.fg, fontSize: 13),
                        decoration: _fieldDeco('30'),
                        onSubmitted: (_) => _save(),
                      ),
                    ),
                    const SizedBox(width: TH.s8),
                    const Text('target min',
                        style: TextStyle(
                            color: TH.fgMute, fontSize: 12)),
                  ],
                ),
              ],

              // ── start date ────────────────────────────────────────
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
                    style: const TextStyle(
                        color: TH.fg, fontSize: 13),
                  ),
                ),
              ),

              // ── end date ─────────────────────────────────────────
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
                            color: _endDate != null
                                ? TH.fg
                                : TH.fgFaint,
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

              // ── note ──────────────────────────────────────────────
              const SizedBox(height: TH.s14),
              _Label('note (optional)'),
              TextField(
                controller: _noteCtrl,
                maxLines: 1,
                maxLength: 100,
                style: const TextStyle(color: TH.fg, fontSize: 13),
                decoration:
                    _fieldDeco('// shown under the row in daily view'),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n')),
                ],
              ),

              // ── save ──────────────────────────────────────────────
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

Future<void> _showTargetOverflowDialog(BuildContext context) =>
    showDialog<void>(
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
                const Text('target too large',
                    style: TextStyle(
                        color: TH.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: TH.s8),
                const Text('target must be 999 or less.',
                    style: TextStyle(color: TH.fgDim, fontSize: 12)),
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

InputDecoration _fieldDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: TH.fgFaint, fontSize: 13),
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
    );

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day} ${d.year}';
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
  const _ColorDot(
      {required this.color, required this.selected, required this.onTap});

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

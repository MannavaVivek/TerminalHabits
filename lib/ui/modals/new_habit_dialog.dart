import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/database.dart';
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
    final col = context.col;
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: col.green,
            onPrimary: col.bg,
            surface: col.bg2,
            onSurface: col.fg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final col = context.col;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: col.green,
            onPrimary: col.bg,
            surface: col.bg2,
            onSurface: col.fg,
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
                  Text('new habit',
                      style: TextStyle(
                          color: col.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('[ cancel ]',
                        style: TextStyle(
                            color: col.fgMute, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: TH.s22),

              _Label('name', col: col),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                maxLength: 60,
                style: TextStyle(color: col.fg, fontSize: 14),
                decoration: _fieldDeco('e.g. meditate, read, journal', col),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n')),
                ],
                onSubmitted: (_) => _save(),
              ),

              const SizedBox(height: TH.s14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('icon', col: col),
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                border: Border.all(color: col.line2),
                                borderRadius:
                                    const BorderRadius.all(TH.r4),
                                color: col.bg1,
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
                                      Border.all(color: col.line2),
                                  borderRadius:
                                      const BorderRadius.all(TH.r4),
                                ),
                                child: Text('[ pick ]',
                                    style: TextStyle(
                                        color: col.fgDim,
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
                      _Label('color', col: col),
                      Row(
                        children: [
                          for (final c in colorMap.keys)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 8),
                              child: _ColorDot(
                                color: colorMap[c]!,
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

              const SizedBox(height: TH.s14),
              _Label('group', col: col),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in groups)
                    _Pill(
                      label: g.name,
                      selected: _groupId == g.id,
                      col: col,
                      onTap: () => setState(() => _groupId = g.id),
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

              const SizedBox(height: TH.s14),
              _Label('schedule', col: col),
              Row(
                children: [
                  for (final s in ['daily', 'weekdays', 'weekends'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Pill(
                        label: s,
                        selected: _schedule == s,
                        col: col,
                        onTap: () =>
                            setState(() => _schedule = s),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: TH.s14),
              _Label('type', col: col),
              Row(
                children: [
                  for (final t in ['checkbox', 'counter', 'duration'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Pill(
                        label: t,
                        selected: _tracking == t,
                        col: col,
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
                        style: TextStyle(
                            color: col.fg, fontSize: 13),
                        decoration: _fieldDeco('10', col),
                        onSubmitted: (_) => _save(),
                      ),
                    ),
                    const SizedBox(width: TH.s8),
                    Text('min count',
                        style: TextStyle(
                            color: col.fgMute, fontSize: 12)),
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
                        style: TextStyle(
                            color: col.fg, fontSize: 13),
                        decoration: _fieldDeco('30', col),
                        onSubmitted: (_) => _save(),
                      ),
                    ),
                    const SizedBox(width: TH.s8),
                    Text('target min',
                        style: TextStyle(
                            color: col.fgMute, fontSize: 12)),
                  ],
                ),
              ],

              const SizedBox(height: TH.s14),
              _Label('start date', col: col),
              GestureDetector(
                onTap: _pickStartDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: TH.s8, vertical: TH.s8),
                  decoration: BoxDecoration(
                    border: Border.all(color: col.line2),
                    borderRadius: const BorderRadius.all(TH.r4),
                  ),
                  child: Text(
                    _formatDate(_startDate),
                    style: TextStyle(
                        color: col.fg, fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(height: TH.s14),
              _Label('end date (optional)', col: col),
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickEndDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s8, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.line2),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text(
                        _endDate != null
                            ? _formatDate(_endDate!)
                            : '— no end date —',
                        style: TextStyle(
                            color: _endDate != null
                                ? col.fg
                                : col.fgFaint,
                            fontSize: 13),
                      ),
                    ),
                  ),
                  if (_endDate != null) ...[
                    const SizedBox(width: TH.s8),
                    GestureDetector(
                      onTap: () => setState(() => _endDate = null),
                      child: Text('[ clear ]',
                          style: TextStyle(
                              color: col.fgMute, fontSize: 12)),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: TH.s14),
              _Label('note (optional)', col: col),
              TextField(
                controller: _noteCtrl,
                maxLines: 1,
                maxLength: 100,
                style: TextStyle(color: col.fg, fontSize: 13),
                decoration:
                    _fieldDeco('// shown under the row in daily view', col),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n')),
                ],
              ),

              const SizedBox(height: TH.s22),
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: TH.s8),
                  decoration: BoxDecoration(
                    border: Border.all(color: col.green),
                    borderRadius: const BorderRadius.all(TH.r4),
                  ),
                  child: Center(
                    child: Text(
                      _saving ? 'saving...' : '[ save ]',
                      style: TextStyle(
                          color: col.green, fontSize: 13),
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
              Text('target must be 999 or less.',
                  style: TextStyle(color: col.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s22),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: TH.s22, vertical: TH.s8),
                    decoration: BoxDecoration(
                      border: Border.all(color: col.green),
                      borderRadius: const BorderRadius.all(TH.r4),
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

InputDecoration _fieldDeco(String hint, AppColors col) => InputDecoration(
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
  final AppColors col;
  const _Label(this.text, {required this.col});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: TH.s4),
        child: Text(text,
            style: TextStyle(color: col.fgDim, fontSize: 12)),
      );
}

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
        padding:
            const EdgeInsets.symmetric(horizontal: TH.s8, vertical: 4),
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

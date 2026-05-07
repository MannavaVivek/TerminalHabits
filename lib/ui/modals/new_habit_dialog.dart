import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../domain/schedule.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';

class NewHabitDialog extends ConsumerStatefulWidget {
  const NewHabitDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => const NewHabitDialog(),
      );

  @override
  ConsumerState<NewHabitDialog> createState() => _NewHabitDialogState();
}

class _NewHabitDialogState extends ConsumerState<NewHabitDialog> {
  final _nameCtrl = TextEditingController();
  String _schedule = 'daily';
  String _color = 'green';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    final scheduleJson = switch (_schedule) {
      'weekdays' => weekdaySchedule(),
      'weekends' => weekendSchedule(),
      _ => dailySchedule(),
    };

    final db = ref.read(dbProvider);
    final habits = await db.getActiveHabits();
    await db.createHabit(HabitsCompanion.insert(
      groupId: 'general',
      name: name,
      color: Value(_color),
      tracking: 'checkbox',
      schedule: scheduleJson,
      sortIndex: habits.length,
    ));

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TH.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 400,
        child: Padding(
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
                        style: TextStyle(color: TH.fgMute, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: TH.s22),
              const Text('name',
                  style: TextStyle(color: TH.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s4),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                style: const TextStyle(color: TH.fg, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. meditate, read, journal',
                  hintStyle:
                      const TextStyle(color: TH.fgFaint, fontSize: 14),
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: TH.s8, vertical: TH.s8),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: TH.s14),
              const Text('schedule',
                  style: TextStyle(color: TH.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s4),
              Row(
                children: [
                  for (final s in ['daily', 'weekdays', 'weekends'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Pill(
                        label: s,
                        selected: _schedule == s,
                        onTap: () => setState(() => _schedule = s),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: TH.s14),
              const Text('color',
                  style: TextStyle(color: TH.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s4),
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
                      style:
                          const TextStyle(color: TH.green, fontSize: 13),
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

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Pill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: TH.s8, vertical: 4),
        decoration: BoxDecoration(
          border:
              Border.all(color: selected ? TH.green : TH.line2),
          borderRadius: BorderRadius.all(TH.r4),
          color: selected ? TH.bg3 : Colors.transparent,
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? TH.green : TH.fgDim,
                fontSize: 12)),
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
          color: color.withOpacity(selected ? 1.0 : 0.4),
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Colors.white24, width: 2)
              : null,
        ),
      ),
    );
  }
}

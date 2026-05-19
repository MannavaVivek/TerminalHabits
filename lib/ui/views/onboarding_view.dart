import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database.dart';
import '../../domain/schedule.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/icon_library.dart';
import '../../theme/tokens.dart';
import '../widgets/prompt_line.dart';
import 'app_scaffold.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  int _step = 0;
  static const _totalSteps = 4;
  bool _finishing = false;

  final _nameCtrl = TextEditingController();
  final _selectedHabits = <String>{};

  final _stepTitles = const [
    'who are you?',
    'pick a theme.',
    'first habits.',
    'ready.',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) await prefs.setString('userName', name);

    final db = ref.read(dbProvider);
    final userId = ref.read(currentUserIdProvider);
    if (name.isNotEmpty) await db.updateDisplayName(userId, name);

    if (_selectedHabits.isNotEmpty) {
      final existing = await db.getActiveHabits(userId);
      var sortIndex = existing.length;
      final now = DateTime.now();
      for (final key in _selectedHabits) {
        final h = _starterDefs[key]!;
        await db.createHabit(HabitsCompanion.insert(
          userId: Value(userId),
          groupId: 'general',
          name: h.$1,
          icon: Value(h.$2),
          tracking: 'checkbox',
          schedule: dailySchedule(),
          startDate: Value(now),
          sortIndex: sortIndex++,
        ));
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const AppScaffold(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  static const _starterDefs = {
    'meditate': ('meditate',       'brain'),
    'journal':  ('journal',        'pencil'),
    'exercise': ('exercise',       'dumbbell'),
    'read':     ('read',           'book'),
    'water':    ('drink water',    'droplets'),
    'sleep':    ('sleep on time',  'moon'),
  };

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Scaffold(
      backgroundColor: col.bg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.all(TH.s22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PromptLine(user: 'you', command: 'onboarding'),
                        const SizedBox(height: TH.s22),
                        _StepIndicator(current: _step, total: _totalSteps),
                        const SizedBox(height: TH.s22),
                        _buildStepBody(context),
                        const SizedBox(height: TH.s36),
                        Row(
                          children: [
                            _TermButton(
                              label: _finishing
                                  ? '[ ... ]'
                                  : _step < _totalSteps - 1
                                      ? '[ next ]'
                                      : '[ begin ]',
                              onTap: _finishing ? null : _next,
                              accent: true,
                            ),
                            const SizedBox(width: TH.s14),
                            _TermButton(label: '[ skip ]', onTap: _finishing ? null : _finish),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepBody(BuildContext context) {
    return switch (_step) {
      0 => _NameStep(title: _stepTitles[0], controller: _nameCtrl),
      1 => const _ThemeStep(),
      2 => _StarterHabitsStep(
          title: _stepTitles[2],
          selected: _selectedHabits,
          onToggle: (key) => setState(() {
            if (_selectedHabits.contains(key)) {
              _selectedHabits.remove(key);
            } else {
              _selectedHabits.add(key);
            }
          }),
          starterDefs: _starterDefs,
        ),
      _ => _ReadyStep(
          title: _stepTitles[3],
          name: _nameCtrl.text.trim(),
          habitCount: _selectedHabits.length,
        ),
    };
  }
}

// ── Step shell ────────────────────────────────────────────────────────────────

class _StepShell extends StatelessWidget {
  final String title;
  final Widget child;
  const _StepShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: col.bg1,
        border: Border.fromBorderSide(BorderSide(color: col.line, width: 1)),
        borderRadius: const BorderRadius.all(TH.r6),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('> $title',
                  style: TextStyle(
                      fontSize: 15,
                      color: col.fg,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 0: name ────────────────────────────────��─────────────────────────────

class _NameStep extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  const _NameStep({required this.title, required this.controller});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return _StepShell(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('what should we call you?',
              style: TextStyle(color: col.fgDim, fontSize: 12)),
          const SizedBox(height: TH.s8),
          TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: col.fg, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'your name or handle',
              hintStyle: TextStyle(color: col.fgFaint, fontSize: 14),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: col.line2),
                borderRadius: const BorderRadius.all(TH.r4),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: col.green),
                borderRadius: const BorderRadius.all(TH.r4),
              ),
              fillColor: col.bg,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: TH.s8, vertical: TH.s8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: theme ─────────────────────────────────────────────────────────────

class _ThemeStep extends ConsumerWidget {
  const _ThemeStep();

  static const _themes = [
    (id: 'matrix',    label: 'matrix',    accent: Color(0xFF5CE39A), bg: Color(0xFF0B1014)),
    (id: 'hacker',    label: 'hacker',    accent: Color(0xFF00FF41), bg: Color(0xFF000000)),
    (id: 'nord',      label: 'nord',      accent: Color(0xFF88C0D0), bg: Color(0xFF2E3440)),
    (id: 'solarized', label: 'solarized', accent: Color(0xFF268BD2), bg: Color(0xFF002B36)),
    (id: 'monokai',   label: 'monokai',   accent: Color(0xFFA6E22E), bg: Color(0xFF272822)),
    (id: 'gruvbox',   label: 'gruvbox',   accent: Color(0xFFB8BB26), bg: Color(0xFF282828)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final themeId = ref.watch(themeIdProvider).valueOrNull ?? 'matrix';
    final db = ref.read(dbProvider);

    return _StepShell(
      title: 'pick a theme.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('changes apply instantly:',
              style: TextStyle(color: col.fgDim, fontSize: 12)),
          const SizedBox(height: TH.s8),
          ..._themes.map((t) {
            final isSel = themeId == t.id;
            return GestureDetector(
              onTap: () => db.setSetting('themeId', t.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Text(isSel ? '[●]' : '[ ]',
                      style: TextStyle(
                          color: isSel ? t.accent : col.fgMute,
                          fontSize: 13)),
                  const SizedBox(width: TH.s8),
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: t.bg,
                      border: Border.all(color: t.accent, width: 1),
                    ),
                  ),
                  const SizedBox(width: TH.s8),
                  Text(t.label,
                      style: TextStyle(
                          color: isSel ? col.fg : col.fgDim,
                          fontSize: 13)),
                ]),
              ),
            );
          }),
          const SizedBox(height: TH.s8),
          Text('// change anytime via settings.',
              style: TextStyle(color: col.fgFaint, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Step 2: starter habits ────────────────────────────────────────────────────

class _StarterHabitsStep extends StatelessWidget {
  final String title;
  final Set<String> selected;
  final void Function(String) onToggle;
  final Map<String, (String, String)> starterDefs;

  const _StarterHabitsStep({
    required this.title,
    required this.selected,
    required this.onToggle,
    required this.starterDefs,
  });

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return _StepShell(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pick some habits to get started (or skip):',
              style: TextStyle(color: col.fgDim, fontSize: 12)),
          const SizedBox(height: TH.s8),
          ...starterDefs.entries.map((e) {
            final isSel = selected.contains(e.key);
            return GestureDetector(
              onTap: () => onToggle(e.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(isSel ? '[✓]' : '[ ]',
                        style: TextStyle(
                            color: isSel ? col.green : col.fgMute,
                            fontSize: 13)),
                    const SizedBox(width: TH.s8),
                    Icon(lucideIconData(e.value.$2),
                        size: 14,
                        color: isSel ? col.green : col.fgMute),
                    const SizedBox(width: TH.s8),
                    Text(e.value.$1,
                        style: TextStyle(
                            color: isSel ? col.fg : col.fgDim,
                            fontSize: 13)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Step 3: ready ─────────────────────────────────────────────────────────────

class _ReadyStep extends StatelessWidget {
  final String title;
  final String name;
  final int habitCount;

  const _ReadyStep({
    required this.title,
    required this.name,
    required this.habitCount,
  });

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final displayName = name.isEmpty ? 'you' : name;
    final habitLine = habitCount == 0
        ? 'no starter habits — add them any time with ⌘N.'
        : '$habitCount habit${habitCount == 1 ? '' : 's'} queued up.';

    return _StepShell(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('welcome, $displayName.',
              style: TextStyle(
                  color: col.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: TH.s8),
          Text(habitLine,
              style: TextStyle(color: col.fgDim, fontSize: 12)),
          const SizedBox(height: TH.s14),
          Text(
            'press [ begin ] to open your dashboard.\n'
            'use ⌘N to add habits · ⌘K to run commands · j/k to navigate.',
            style: TextStyle(color: col.fgFaint, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Shared UI ─────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Text(
      'step ${current + 1} of $total  —  '
      '${List.generate(total, (i) => i <= current ? '●' : '○').join(' ')}',
      style: TextStyle(fontSize: 12, color: context.col.fgMute),
    );
  }
}

class _TermButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool accent;

  const _TermButton(
      {required this.label, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: accent ? col.green : col.line, width: 1),
          borderRadius: const BorderRadius.all(TH.r4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: TH.s14, vertical: TH.s8),
          child: Text(
            label,
            style: TextStyle(
                fontSize: 13, color: accent ? col.green : col.fgDim),
          ),
        ),
      ),
    );
  }
}

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database.dart';
import '../../domain/schedule.dart';
import '../../state/providers.dart';
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) await prefs.setString('userName', name);

    if (_selectedHabits.isNotEmpty) {
      final db = ref.read(dbProvider);
      final existing = await db.getActiveHabits();
      var sortIndex = existing.length;
      for (final key in _selectedHabits) {
        final h = _starterDefs[key]!;
        await db.createHabit(HabitsCompanion.insert(
          groupId: 'general',
          name: h.$1,
          icon: Value(h.$2),
          tracking: 'checkbox',
          schedule: dailySchedule(),
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

  // (name, icon)
  static const _starterDefs = {
    'meditate': ('meditate', '🧘'),
    'journal': ('journal', '📓'),
    'exercise': ('exercise', '💪'),
    'read': ('read', '📚'),
    'water': ('drink water', '💧'),
    'sleep': ('sleep on time', '🌙'),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TH.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PromptLine(user: 'you', command: 'onboarding'),
              const SizedBox(height: TH.s22),
              _StepIndicator(current: _step, total: _totalSteps),
              const SizedBox(height: TH.s22),
              _buildStepBody(),
              const SizedBox(height: TH.s36),
              Row(
                children: [
                  _TermButton(
                    label: _step < _totalSteps - 1 ? '[ next ]' : '[ begin ]',
                    onTap: _next,
                    accent: true,
                  ),
                  const SizedBox(width: TH.s14),
                  _TermButton(label: '[ skip ]', onTap: _finish),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    return switch (_step) {
      0 => _NameStep(title: _stepTitles[0], controller: _nameCtrl),
      1 => const _ThemeStep(title: 'pick a theme.'),
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

// ── Step containers ───────────────────────────────────────────────────────────

class _StepShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _StepShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TH.bg1,
        border:
            Border.fromBorderSide(BorderSide(color: TH.line, width: 1)),
        borderRadius: BorderRadius.all(TH.r6),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('> $title',
                  style: const TextStyle(
                      fontSize: 15,
                      color: TH.fg,
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

// ── Step 0: name ──────────────────────────────────────────────────────────────

class _NameStep extends StatelessWidget {
  final String title;
  final TextEditingController controller;

  const _NameStep({required this.title, required this.controller});

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('what should we call you?',
              style: TextStyle(color: TH.fgDim, fontSize: 12)),
          const SizedBox(height: TH.s8),
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: TH.fg, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'your name or handle',
              hintStyle:
                  const TextStyle(color: TH.fgFaint, fontSize: 14),
              enabledBorder: OutlineInputBorder(
                borderSide:
                    const BorderSide(color: TH.line2),
                borderRadius: BorderRadius.all(TH.r4),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide:
                    const BorderSide(color: TH.green),
                borderRadius: BorderRadius.all(TH.r4),
              ),
              fillColor: TH.bg,
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

class _ThemeStep extends StatelessWidget {
  final String title;

  const _ThemeStep({required this.title});

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: title,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('theme: matrix',
              style: TextStyle(
                  color: TH.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: TH.s8),
          Text(
            'dark background · green accent · monospace font\n'
            'looks best with JetBrains Mono or Fira Code.',
            style: TextStyle(color: TH.fgDim, fontSize: 12),
          ),
          SizedBox(height: TH.s14),
          Text(
            '// more themes (amber, solarized) coming in Phase 2.',
            style: TextStyle(color: TH.fgFaint, fontSize: 11),
          ),
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
    return _StepShell(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('pick some habits to get started (or skip):',
              style: TextStyle(color: TH.fgDim, fontSize: 12)),
          const SizedBox(height: TH.s8),
          ...starterDefs.entries.map((e) {
            final isSelected = selected.contains(e.key);
            return GestureDetector(
              onTap: () => onToggle(e.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(isSelected ? '[✓]' : '[ ]',
                        style: TextStyle(
                            color: isSelected ? TH.green : TH.fgMute,
                            fontSize: 13)),
                    const SizedBox(width: TH.s8),
                    Text(e.value.$2,
                        style:
                            const TextStyle(fontSize: 13)),
                    const SizedBox(width: TH.s8),
                    Text(e.value.$1,
                        style: TextStyle(
                            color: isSelected ? TH.fg : TH.fgDim,
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
              style: const TextStyle(
                  color: TH.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: TH.s8),
          Text(habitLine,
              style: const TextStyle(color: TH.fgDim, fontSize: 12)),
          const SizedBox(height: TH.s14),
          const Text(
            'press [ begin ] to open your dashboard.\n'
            'use ⌘N to add habits · ⌘K to run commands · j/k to navigate.',
            style: TextStyle(color: TH.fgFaint, fontSize: 12),
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
      style: const TextStyle(fontSize: 12, color: TH.fgMute),
    );
  }
}

class _TermButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool accent;

  const _TermButton(
      {required this.label, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: accent ? TH.green : TH.line,
            width: 1,
          ),
          borderRadius: const BorderRadius.all(TH.r4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: TH.s14, vertical: TH.s8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: accent ? TH.green : TH.fgDim,
            ),
          ),
        ),
      ),
    );
  }
}

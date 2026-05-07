import 'package:flutter/material.dart';
import '../../theme/tokens.dart';
import '../widgets/prompt_line.dart';

// Phase 0 stub: 4-step onboarding skeleton.
// Full implementation (name input, theme pick, starter habits) is Phase 1.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  int _step = 0;
  static const _totalSteps = 4;

  final _stepTitles = const [
    'who are you?',
    'pick a theme.',
    'first habits.',
    'ready.',
  ];

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _finish() {
    // Phase 1 will push DailyView here.
    // For Phase 0, return to splash so we can test the round-trip.
    Navigator.of(context).pop();
  }

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
              _StepBody(step: _step, title: _stepTitles[_step]),
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
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Text(
      'step ${current + 1} of $total  —  ${List.generate(total, (i) => i <= current ? '●' : '○').join(' ')}',
      style: const TextStyle(fontSize: 12, color: TH.fgMute),
    );
  }
}

class _StepBody extends StatelessWidget {
  final int step;
  final String title;

  const _StepBody({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TH.bg1,
        border: Border.fromBorderSide(BorderSide(color: TH.line, width: 1)),
        borderRadius: BorderRadius.all(TH.r6),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '> $title',
                style: const TextStyle(fontSize: 15, color: TH.fg, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: TH.s14),
              Text(
                '// placeholder — step ${step + 1} will be implemented in Phase 1.',
                style: const TextStyle(fontSize: 12, color: TH.fgMute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool accent;

  const _TermButton({required this.label, required this.onTap, this.accent = false});

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
          padding: const EdgeInsets.symmetric(horizontal: TH.s14, vertical: TH.s8),
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

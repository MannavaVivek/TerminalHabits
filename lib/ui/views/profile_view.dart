import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../widgets/prompt_line.dart';
import 'login_view.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final col = context.col;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final habits = ref.watch(habitsProvider).valueOrNull ?? [];
    final name = user?.displayName.isNotEmpty == true ? user!.displayName : '—';
    final email = user?.username ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(TH.s14),
          child: PromptLine(user: name, command: 'profile'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(TH.s14),
            children: [
              _Block(label: 'account', col: col, children: [
                _Row('name', name, col: col),
                _Row('email', email, col: col),
                _Row('habits', '${habits.length} active', col: col),
              ]),
              const SizedBox(height: TH.s22),
              GestureDetector(
                onTap: () => _logout(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: TH.s14, vertical: TH.s8),
                  decoration: BoxDecoration(
                    border: Border.all(color: col.red),
                    borderRadius: const BorderRadius.all(TH.r4),
                  ),
                  child: Text('[ logout ]',
                      style: TextStyle(color: col.red, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedInUserId');
    await prefs.remove('seenOnboarding');
    ref.read(currentUserIdProvider.notifier).state = 0;
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const LoginView(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }
}

class _Block extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final AppColors col;
  const _Block({required this.label, required this.children, required this.col});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: col.line),
        borderRadius: const BorderRadius.all(TH.r4),
      ),
      padding: const EdgeInsets.all(TH.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('── $label',
              style: TextStyle(color: col.fgMute, fontSize: 11)),
          const SizedBox(height: TH.s4),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final AppColors col;
  const _Row(this.label, this.value, {required this.col});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
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

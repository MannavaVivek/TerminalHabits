import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/prompt_line.dart';
import 'login_view.dart';
import 'onboarding_view.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwd2Ctrl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _pwd2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final pwd = _pwdCtrl.text;
    final pwd2 = _pwd2Ctrl.text;

    if (email.isEmpty || pwd.isEmpty) {
      setState(() => _error = 'email and password required.');
      return;
    }
    if (pwd != pwd2) {
      setState(() => _error = 'passwords do not match.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final db = ref.read(dbProvider);
    final existing = await db.getUserByUsername(email);
    if (existing != null) {
      setState(() { _loading = false; _error = 'email already registered.'; });
      return;
    }

    final userId = await db.createUser(email, '', pwd);
    await db.createGroup(userId, 'general');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('loggedInUserId', userId);
    // New account always sees onboarding regardless of any stale pref.
    await prefs.remove('seenOnboarding');
    ref.read(currentUserIdProvider.notifier).state = userId;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const OnboardingView(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }

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
              child: Padding(
                padding: const EdgeInsets.all(TH.s22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const PromptLine(user: 'new', command: 'register'),
                const SizedBox(height: TH.s22),
                AuthField(label: 'email', controller: _emailCtrl,
                    autofocus: true),
                const SizedBox(height: TH.s14),
                AuthField(label: 'password', controller: _pwdCtrl,
                    obscure: true),
                const SizedBox(height: TH.s14),
                AuthField(label: 'confirm password', controller: _pwd2Ctrl,
                    obscure: true, onSubmit: _submit),
                if (_error != null) ...[
                  const SizedBox(height: TH.s8),
                  Text(_error!,
                      style: TextStyle(color: col.red, fontSize: 12)),
                ],
                const SizedBox(height: TH.s22),
                Row(
                  children: [
                    AuthButton(
                      label: _loading ? '[ ... ]' : '[ create account ]',
                      accent: true,
                      onTap: _loading ? null : _submit,
                    ),
                  ],
                ),
                const SizedBox(height: TH.s14),
                GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacement(
                    PageRouteBuilder<void>(
                      pageBuilder: (_, __, ___) => const LoginView(),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  ),
                  child: Text('already have an account? [ login ]',
                      style: TextStyle(color: col.fgDim, fontSize: 12)),
                ),
              ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}


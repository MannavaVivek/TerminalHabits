import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/prompt_line.dart';
import 'app_scaffold.dart';
import 'forgot_password_view.dart';
import 'onboarding_view.dart';
import 'register_view.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _userCtrl.text.trim().toLowerCase();
    final pwd = _pwdCtrl.text;

    if (email.isEmpty || pwd.isEmpty) {
      setState(() => _error = 'enter email and password.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final db = ref.read(dbProvider);
    final user = await db.getUserByUsername(email);

    if (user == null || user.password != pwd) {
      setState(() { _loading = false; _error = 'invalid email or password.'; });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('loggedInUserId', user.id);
    ref.read(currentUserIdProvider.notifier).state = user.id;

    if (!mounted) return;
    final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) =>
          seenOnboarding ? const AppScaffold() : const OnboardingView(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }

  void _goRegister() => Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const RegisterView(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );

  void _goForgot() => Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const ForgotPasswordView(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Scaffold(
      backgroundColor: col.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(TH.s22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PromptLine(user: '?', command: 'login'),
                const SizedBox(height: TH.s22),
                AuthField(label: 'email', controller: _userCtrl,
                    autofocus: true),
                const SizedBox(height: TH.s14),
                AuthField(label: 'password', controller: _pwdCtrl,
                    obscure: true, onSubmit: _submit),
                if (_error != null) ...[
                  const SizedBox(height: TH.s8),
                  Text(_error!,
                      style: TextStyle(color: col.red, fontSize: 12)),
                ],
                const SizedBox(height: TH.s22),
                AuthButton(
                  label: _loading ? '[ ... ]' : '[ login ]',
                  accent: true,
                  onTap: _loading ? null : _submit,
                ),
                const SizedBox(height: TH.s22),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _goRegister,
                      child: Text('[ register ]',
                          style: TextStyle(color: col.fgDim, fontSize: 12)),
                    ),
                    const SizedBox(width: TH.s22),
                    GestureDetector(
                      onTap: _goForgot,
                      child: Text('[ forgot password ]',
                          style: TextStyle(color: col.fgDim, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

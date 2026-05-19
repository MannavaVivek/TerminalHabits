import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    if (pwd.length < 6) {
      setState(() => _error = 'password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final res = await Supabase.instance.client.auth
          .signUp(email: email, password: pwd);
      if (res.user == null) {
        setState(() { _loading = false; _error = 'registration failed. try again.'; });
        return;
      }
      if (res.session == null) {
        // Email confirmation is enabled, or account already existed.
        // Redirect to login — they can sign in immediately once confirmed.
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const LoginView(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ));
        return;
      }
    } on AuthException catch (e) {
      setState(() { _loading = false; _error = e.message; });
      return;
    } catch (e) {
      setState(() { _loading = false; _error = 'network error. check your connection.'; });
      return;
    }

    final db = ref.read(dbProvider);
    await db.ensurePlaceholderUser(email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('seenOnboarding');
    ref.read(currentUserIdProvider.notifier).state = 1;

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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
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
                        AuthButton(
                          label: _loading ? '[ ... ]' : '[ create account ]',
                          accent: true,
                          onTap: _loading ? null : _submit,
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
              ),
            ),
          );
        }),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/sync_service.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/prompt_line.dart';
import 'app_scaffold.dart';
import 'forgot_password_view.dart';
import 'register_view.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final pwd = _pwdCtrl.text;

    if (email.isEmpty || pwd.isEmpty) {
      setState(() => _error = 'enter email and password.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final res = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: pwd);
      if (res.session == null) {
        setState(() { _loading = false; _error = 'login failed. try again.'; });
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
    final prefs = await SharedPreferences.getInstance();
    final newUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final lastUid = prefs.getString('last_auth_uid');
    if (lastUid != null && lastUid != newUid) {
      await db.clearAllUserData();
      await prefs.remove('seenOnboarding');
    }
    await prefs.setString('last_auth_uid', newUid);
    await db.ensurePlaceholderUser(email);
    // Restore display name from Supabase metadata (set during onboarding).
    final metaName = Supabase.instance.client.auth.currentUser
        ?.userMetadata?['display_name'] as String?;
    if (metaName != null && metaName.isNotEmpty) {
      await db.updateDisplayName(1, metaName);
    }
    ref.read(currentUserIdProvider.notifier).state = 1;

    bool hadServerData = false;
    try { hadServerData = await SyncService(db).pullAll(); } catch (_) {}
    if (!hadServerData) {
      try { await SyncService(db).pushAll(); } catch (_) {}
    }

    if (!mounted) return;
    // Login always goes to the main app — onboarding is only for new
    // registrations. Showing onboarding after login would silently overwrite
    // data if the server happened to be empty (race, first push in-flight, etc).
    await prefs.setBool('seenOnboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const AppScaffold(),
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
                        const PromptLine(user: '?', command: 'login'),
                        const SizedBox(height: TH.s22),
                        AuthField(label: 'email', controller: _emailCtrl,
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
            ),
          );
        }),
      ),
    );
  }
}

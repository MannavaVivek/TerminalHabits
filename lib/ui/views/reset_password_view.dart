import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/prompt_line.dart';
import 'login_view.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pwd = _pwdCtrl.text;
    final confirm = _confirmCtrl.text;

    if (pwd.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'enter and confirm your new password.');
      return;
    }
    if (pwd != confirm) {
      setState(() => _error = 'passwords do not match.');
      return;
    }
    if (pwd.length < 6) {
      setState(() => _error = 'password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: pwd));
      // Sign out all sessions on all devices so they must log in with the new password.
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.global);
    } on AuthException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
      return;
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'network error. check your connection.'; });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const LoginView(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (_) => false,
    );
  }

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
                const PromptLine(user: '?', command: 'reset-password'),
                const SizedBox(height: TH.s8),
                Text(
                  '// enter a new password for your account.',
                  style: TextStyle(color: col.fgMute, fontSize: 12),
                ),
                const SizedBox(height: TH.s22),
                AuthField(
                  label: 'new password',
                  controller: _pwdCtrl,
                  obscure: true,
                  autofocus: true,
                  onSubmit: _submit,
                ),
                const SizedBox(height: TH.s14),
                AuthField(
                  label: 'confirm password',
                  controller: _confirmCtrl,
                  obscure: true,
                  onSubmit: _submit,
                ),
                if (_error != null) ...[
                  const SizedBox(height: TH.s8),
                  Text(_error!,
                      style: TextStyle(color: col.red, fontSize: 12)),
                ],
                const SizedBox(height: TH.s22),
                AuthButton(
                  label: _loading ? '[ ... ]' : '[ change password ]',
                  accent: true,
                  onTap: _loading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

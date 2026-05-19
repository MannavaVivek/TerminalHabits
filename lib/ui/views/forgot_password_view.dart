import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/prompt_line.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailCtrl = TextEditingController();
  String? _error;
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _error = 'enter your email address.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) setState(() { _loading = false; _sent = true; });
    } on AuthException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'network error. check your connection.'; });
    }
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
                const PromptLine(user: '?', command: 'forgot-password'),
                const SizedBox(height: TH.s22),
                if (_sent) ...[
                  Container(
                    padding: const EdgeInsets.all(TH.s14),
                    decoration: BoxDecoration(
                      border: Border.all(color: col.green),
                      borderRadius: const BorderRadius.all(TH.r4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('email sent.',
                            style: TextStyle(
                                color: col.green,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: TH.s8),
                        Text(
                          'check your inbox for a password reset link.\n'
                          'the link expires in 1 hour.',
                          style: TextStyle(color: col.fgDim, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TH.s22),
                ] else ...[
                  AuthField(
                    label: 'email',
                    controller: _emailCtrl,
                    autofocus: true,
                    onSubmit: _submit,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: TH.s8),
                    Text(_error!,
                        style: TextStyle(color: col.red, fontSize: 12)),
                  ],
                  const SizedBox(height: TH.s22),
                  AuthButton(
                    label: _loading ? '[ ... ]' : '[ send reset email ]',
                    accent: true,
                    onTap: _loading ? null : _submit,
                  ),
                  const SizedBox(height: TH.s14),
                ],
                AuthButton(
                  label: '[ back ]',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/prompt_line.dart';

// Temporary local dev feature — Phase 11 replaces with email recovery.
class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() =>
      _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  final _userCtrl = TextEditingController();
  String? _password;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final username = _userCtrl.text.trim();
    if (username.isEmpty) {
      setState(() { _error = 'enter a username.'; _password = null; });
      return;
    }
    final user = await ref.read(dbProvider).getUserByUsername(username);
    if (user == null) {
      setState(() { _error = 'no account found.'; _password = null; });
    } else {
      setState(() { _error = null; _password = user.password; });
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
                AuthField(
                  label: 'username',
                  controller: _userCtrl,
                  autofocus: true,
                  onSubmit: _lookup,
                ),
                if (_error != null) ...[
                  const SizedBox(height: TH.s8),
                  Text(_error!,
                      style: TextStyle(color: col.red, fontSize: 12)),
                ],
                if (_password != null) ...[
                  const SizedBox(height: TH.s14),
                  Container(
                    padding: const EdgeInsets.all(TH.s8),
                    decoration: BoxDecoration(
                      border: Border.all(color: col.line),
                      borderRadius: const BorderRadius.all(TH.r4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('password:',
                            style: TextStyle(
                                color: col.fgMute, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(_password!,
                            style: TextStyle(
                                color: col.amber,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: TH.s8),
                  Text(
                    '// temporary dev feature — Phase 11 replaces this with email recovery.',
                    style: TextStyle(color: col.fgFaint, fontSize: 11),
                  ),
                ],
                const SizedBox(height: TH.s22),
                Row(
                  children: [
                    AuthButton(
                      label: '[ look up ]',
                      accent: true,
                      onTap: _lookup,
                    ),
                    const SizedBox(width: TH.s14),
                    AuthButton(
                      label: '[ back ]',
                      onTap: () => Navigator.of(context).pop(),
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

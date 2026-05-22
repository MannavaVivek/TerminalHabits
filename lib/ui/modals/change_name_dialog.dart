import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

/// Dialog for changing the user's display name. Persists to both the local
/// `users` table and Supabase user metadata so the new name is available
/// on every device after the next pull / login.
Future<void> showChangeNameDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _ChangeNameDialog(),
    );

class _ChangeNameDialog extends ConsumerStatefulWidget {
  const _ChangeNameDialog();

  @override
  ConsumerState<_ChangeNameDialog> createState() => _ChangeNameDialogState();
}

class _ChangeNameDialogState extends ConsumerState<_ChangeNameDialog> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save(User user) async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'name cannot be empty.');
      return;
    }
    if (name == user.displayName) {
      Navigator.of(context).pop();
      return;
    }
    setState(() { _saving = true; _error = null; });
    await ref.read(dbProvider).updateDisplayName(user.id, name);
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(data: {'display_name': name}));
    } catch (_) {
      // Network error — local change still persists; cloud will sync later.
    }
    // Force-refresh the FutureProvider so the UI picks up the new name.
    ref.invalidate(currentUserProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    final userAV = ref.watch(currentUserProvider);

    return Dialog(
      backgroundColor: col.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: userAV.when(
            loading: () => Center(
              child: Text('loading...',
                  style: TextStyle(color: col.fgDim, fontSize: 12)),
            ),
            error: (e, _) => Text('error: $e',
                style: TextStyle(color: col.red, fontSize: 12)),
            data: (user) {
              if (user == null) return const SizedBox();
              if (!_initialized) {
                _ctrl.text = user.displayName;
                _initialized = true;
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('change name',
                      style: TextStyle(
                          color: col.fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: TH.s14),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    maxLength: 40,
                    style: TextStyle(color: col.fg, fontSize: 13),
                    onSubmitted: (_) => _save(user),
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      hintText: 'your name',
                      hintStyle:
                          TextStyle(color: col.fgFaint, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: TH.s8, vertical: TH.s8),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: col.line2),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: col.green),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      fillColor: col.bg,
                      filled: true,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: TH.s8),
                    Text(_error!,
                        style: TextStyle(color: col.red, fontSize: 12)),
                  ],
                  const SizedBox(height: TH.s14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text('[ cancel ]',
                            style:
                                TextStyle(color: col.fgMute, fontSize: 12)),
                      ),
                      const SizedBox(width: TH.s14),
                      GestureDetector(
                        onTap: _saving ? null : () => _save(user),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: TH.s14, vertical: TH.s8),
                          decoration: BoxDecoration(
                            border: Border.all(color: col.green),
                            borderRadius: const BorderRadius.all(TH.r4),
                          ),
                          child: Text(_saving ? '[ ... ]' : '[ save ]',
                              style: TextStyle(
                                  color: col.green, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../views/login_view.dart';
import 'settings_dialog.dart';

Future<void> showUserWindow(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _UserWindowDialog(),
    );

class _UserWindowDialog extends ConsumerStatefulWidget {
  const _UserWindowDialog();

  @override
  ConsumerState<_UserWindowDialog> createState() => _UserWindowDialogState();
}

class _UserWindowDialogState extends ConsumerState<_UserWindowDialog> {
  late final TextEditingController _nameCtrl;
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName(User user) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || name == user.displayName) {
      setState(() => _editingName = false);
      return;
    }
    await ref.read(dbProvider).updateDisplayName(user.id, name);
    setState(() => _editingName = false);
  }

  Future<void> _logOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedInUserId');
    ref.read(currentUserIdProvider.notifier).state = 0;
    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const LoginView(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final userAV = ref.watch(currentUserProvider);
    final dailyAV = ref.watch(dailyStateProvider);

    return Dialog(
      backgroundColor: TH.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: userAV.when(
            loading: () => const Center(
              child: Text('loading...',
                  style: TextStyle(color: TH.fgDim, fontSize: 12)),
            ),
            error: (e, _) => Text('error: $e',
                style: const TextStyle(color: TH.red, fontSize: 12)),
            data: (user) {
              if (user == null) return const SizedBox();
              if (_nameCtrl.text.isEmpty && !_editingName) {
                _nameCtrl.text = user.displayName;
              }

              final streak = dailyAV.valueOrNull?.overallStreak.displayStreak ?? 0;
              final completions =
                  dailyAV.valueOrNull?.totalCompletionsAllTime ?? 0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── header ──────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          border: Border.all(color: TH.green),
                          borderRadius: BorderRadius.all(TH.r4),
                        ),
                        child: Center(
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: TH.green,
                                fontSize: 18,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: TH.s14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.displayName,
                                style: const TextStyle(
                                    color: TH.fg,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Text('@${user.username}',
                                style: const TextStyle(
                                    color: TH.fgMute, fontSize: 11)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => SettingsDialog.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: TH.s8, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: TH.line2),
                            borderRadius: BorderRadius.all(TH.r4),
                          ),
                          child: const Text('[ ⚙ settings ]',
                              style: TextStyle(
                                  color: TH.fgDim, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TH.s22),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: TH.line),
                      borderRadius: BorderRadius.all(TH.r4),
                    ),
                    padding: const EdgeInsets.all(TH.s14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('── profile',
                            style: TextStyle(
                                color: TH.fgMute, fontSize: 11)),
                        const SizedBox(height: TH.s8),
                        // display name — editable
                        Row(
                          children: [
                            const SizedBox(
                              width: 88,
                              child: Text('display name:',
                                  style: TextStyle(
                                      color: TH.fgDim, fontSize: 12)),
                            ),
                            if (_editingName)
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  autofocus: true,
                                  style: const TextStyle(
                                      color: TH.fg, fontSize: 12),
                                  onSubmitted: (_) =>
                                      _saveDisplayName(user),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 4),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                          color: TH.line2),
                                      borderRadius:
                                          BorderRadius.all(TH.r4),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                          color: TH.green),
                                      borderRadius:
                                          BorderRadius.all(TH.r4),
                                    ),
                                    fillColor: TH.bg,
                                    filled: true,
                                  ),
                                  onTapOutside: (_) =>
                                      _saveDisplayName(user),
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () {
                                  _nameCtrl.text = user.displayName;
                                  setState(() => _editingName = true);
                                },
                                child: Text(user.displayName,
                                    style: const TextStyle(
                                        color: TH.fg, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _InfoRow('username', '@${user.username}'),
                        _InfoRow('member since',
                            _fmtDate(user.createdAt.toLocal())),
                        _InfoRow('completions', '$completions'),
                        _InfoRow('streak', '$streak days'),
                      ],
                    ),
                  ),
                  const SizedBox(height: TH.s22),
                  GestureDetector(
                    onTap: _logOut,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s14, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: TH.red),
                        borderRadius: BorderRadius.all(TH.r4),
                      ),
                      child: const Text('[ log out ]',
                          style: TextStyle(color: TH.red, fontSize: 12)),
                    ),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text('$label:',
                style: const TextStyle(color: TH.fgDim, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: TH.fg, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day} ${d.year}';
}

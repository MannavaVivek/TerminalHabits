import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../widgets/ascii_art.dart';
import 'app_scaffold.dart';
import 'login_view.dart';
import 'onboarding_view.dart';
import 'register_view.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView>
    with SingleTickerProviderStateMixin {
  String _logoText = '';
  bool _cursorVisible = true;
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _loadLogo();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(() {
      setState(() {
        _cursorVisible = _cursorController.value < 0.5;
      });
    });
    _cursorController.repeat();
  }

  Future<void> _loadLogo() async {
    final text = await rootBundle.loadString('assets/ascii/logo.txt');
    if (mounted) setState(() => _logoText = text);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenSplash', true);
    if (!mounted) return;

    final db = ref.read(dbProvider);
    final savedId = prefs.getInt('loggedInUserId');

    if (savedId != null) {
      final user = await db.getUserById(savedId);
      if (user != null) {
        ref.read(currentUserIdProvider.notifier).state = savedId;
        if (!mounted) return;
        final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
        Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) =>
              seenOnboarding ? const AppScaffold() : const OnboardingView(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ));
        return;
      }
      await prefs.remove('loggedInUserId');
    }

    final userCount = await db.getUserCount();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) =>
          userCount == 0 ? const RegisterView() : const LoginView(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TH.bg,
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            _proceed();
          }
        },
        child: GestureDetector(
          onTap: _proceed,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_logoText.isNotEmpty) ...[
                    AsciiArt(_logoText, fontSize: 11, color: TH.green),
                    const SizedBox(height: TH.s22),
                  ],
                  _SystemInfoBox(),
                  const SizedBox(height: TH.s22),
                  const Text(
                    '// no nudges. no streak panic.',
                    style: TextStyle(fontSize: 13, color: TH.fgMute),
                  ),
                  const SizedBox(height: TH.s14),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, color: TH.fgDim),
                      children: [
                        const TextSpan(
                          text: '> press enter, or click anywhere — yours to shape.',
                        ),
                        TextSpan(
                          text: '_',
                          style: TextStyle(
                            color: _cursorVisible ? TH.green : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemInfoBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final platform = Platform.isMacOS
        ? 'macOS'
        : Platform.isLinux
            ? 'Linux'
            : Platform.isAndroid
                ? 'Android'
                : 'unknown';

    const borderSide = BorderSide(color: TH.line, width: 1);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(borderSide),
        borderRadius: BorderRadius.all(TH.r6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TH.s14, vertical: TH.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'platform', value: platform),
            _InfoRow(label: 'version ', value: 'v0.1.0'),
            _InfoRow(
              label: 'build   ',
              value: const bool.fromEnvironment('dart.vm.product')
                  ? 'release'
                  : 'debug',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(fontSize: 12, color: TH.fgMute),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontSize: 12, color: TH.fgDim),
          ),
        ]),
      ),
    );
  }
}

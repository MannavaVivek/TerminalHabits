import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state/providers.dart';
import 'theme/app_colors.dart';
import 'theme/theme.dart';
import 'ui/views/login_view.dart';
import 'ui/views/reset_password_view.dart';
import 'ui/views/splash_view.dart';

double _fontScale(String size) => switch (size) {
      'sm' => 0.87,
      'lg' => 1.13,
      _ => 1.0,
    };

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initAuthListener();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) await _handleLink(initial);
    } catch (_) {}
    _linkSub = appLinks.uriLinkStream.listen(_handleLink, onError: (_) {});
  }

  Future<void> _handleLink(Uri uri) async {
    if (uri.scheme != 'terminalhabits') return;
    // Pass the URI to Supabase; it handles both PKCE (?code=) and
    // implicit (#access_token=) recovery flows. Navigation is driven by
    // the passwordRecovery auth event in _initAuthListener.
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (_) {
      // Expired or already-used link — do nothing.
    }
  }

  void _initAuthListener() {
    bool wasSignedIn = Supabase.instance.client.auth.currentSession != null;

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        wasSignedIn = true;
      }

      if (data.event == AuthChangeEvent.passwordRecovery) {
        // Mark recovery active so SplashView doesn't override navigation.
        ref.read(passwordRecoveryActiveProvider.notifier).state = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            PageRouteBuilder<void>(
              pageBuilder: (_, __, ___) => const ResetPasswordView(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
            (_) => false,
          );
        });
      }

      if (data.event == AuthChangeEvent.signedOut && wasSignedIn) {
        wasSignedIn = false;
        ref.read(passwordRecoveryActiveProvider.notifier).state = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            PageRouteBuilder<void>(
              pageBuilder: (_, __, ___) => const LoginView(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
            (_) => false,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeId  = ref.watch(themeIdProvider).valueOrNull  ?? 'matrix';
    final fontSize = ref.watch(fontSizeProvider).valueOrNull ?? 'md';
    final colors   = AppColors.all[themeId] ?? AppColors.matrix;
    final scale    = _fontScale(fontSize);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'TerminalHabits',
      theme: buildTheme(colors),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
            textScaler: Platform.isAndroid
                ? TextScaler.noScaling
                : TextScaler.linear(scale)),
        child: child!,
      ),
      home: const SplashView(),
      debugShowCheckedModeBanner: false,
    );
  }
}

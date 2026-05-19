import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'config/supabase_config.dart';
import 'data/database.dart';
import 'state/providers.dart';
import 'theme/tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts are bundled in assets/fonts/ — never fetch from the network.
  GoogleFonts.config.allowRuntimeFetching = false;

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: TH.bg,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: TH.bg1,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  if (Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    const opts = WindowOptions(
      size: Size(1280, 820),
      minimumSize: Size(1080, 680),
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: TH.bg,
      center: true,
      title: 'TerminalHabits',
    );

    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final db = await openAppDatabase();

  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
      ],
      child: const App(),
    ),
  );
}

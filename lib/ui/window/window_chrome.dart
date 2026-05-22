import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../app_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

const _chromeHeight = 38.0;

class WindowChrome extends StatelessWidget {
  const WindowChrome({super.key});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return SizedBox(
      height: _chromeHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: col.bg1,
          border: Border(bottom: BorderSide(color: col.line, width: 1)),
        ),
        child: DragToMoveArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: TH.s14),
            child: Row(
              children: [
                const SizedBox(width: 72),
                Expanded(
                  child: Center(
                    child: Text(
                      'TerminalHabits',
                      style: TextStyle(fontSize: 12, color: col.fgDim),
                    ),
                  ),
                ),
                _VersionMeta(col: col),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionMeta extends StatelessWidget {
  final AppColors col;
  const _VersionMeta({required this.col});

  @override
  Widget build(BuildContext context) {
    return Text(
      'v$kAppVersion · matrix',
      style: TextStyle(fontSize: 11, color: col.fgMute),
    );
  }
}
